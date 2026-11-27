'use strict';

const { getServerConfig, resolveServerOpenAiApiKey } = require('./config');
const { PlannerV2Error } = require('./errors');
const { loadVerifiedCatalog } = require('./curriculum_catalog_loader');
const { assertAuthorizedActor, InMemoryAtomicQuotaStore } = require('./auth_and_quota_guard');
const { validateGeneratedPlan } = require('./plan_validator');
const { inspectPayloadForForbiddenKeysOrUrls, HEURISTIC_PRIVACY_DISCLAIMER } = require('./pii_and_injection_guard');
const { PlannerTelemetryLogger } = require('./telemetry');
const { OpenAiStructuredProvider } = require('./llm_adapter');
const { COPILOT_CONTRACT_VERSION, computeDraftVersionHash } = require('./copilot_schema');
const { buildCopilotContext, buildCopilotPrompts } = require('./copilot_context_and_prompt');
const { applyCopilotOperationsToPlan, buildCopilotDiffSummary } = require('./copilot_operations');
const { SimulatedCopilotProvider } = require('./copilot_simulated_provider');

/**
 * Pedagogical Copilot V1 orchestrator (`PED-04C3`).
 * - Supports informative consultation (`consult`) and typed controlled mutations (`propose_changes`).
 * - Never auto-applies changes, never exposes Firestore/code execution, never mutates pilot 8/8 budget.
 * - Enforces draft version check (`DRAFT_VERSION_CONFLICT`) and full `validateGeneratedPlan` gate.
 */
async function runPedagogicalCopilotV1({
  request,
  authContext = {},
  deps = {},
  serverOverrides = {},
  nowMs = Date.now(),
}) {
  const serverConfig = getServerConfig(serverOverrides);
  const telemetry = deps.telemetry || new PlannerTelemetryLogger();
  const quotaStore = deps.quotaStore || new InMemoryAtomicQuotaStore();
  const copilotBudgetGuard = deps.budgetGuard || null;
  const resourceRepository = deps.resourceRepository || { async getResourcesByIds() { return new Map(); } };

  let actor = { actorId: 'unauthenticated' };
  let requestId = String(request?.request_id || `req_copilot_${nowMs}`).trim();
  let slotAcquired = false;
  let billableAttemptStarted = false;
  let budgetReserved = false;
  let providerNameForTelemetry = serverConfig.providerMode === 'openai' ? 'openai' : 'simulated-copilot';
  let actualCostForFailure = 0;

  try {
    const catalog = deps.catalog || loadVerifiedCatalog();
    actor = assertAuthorizedActor(authContext, serverConfig);

    const copilotContext = await buildCopilotContext({
      request,
      actor,
      catalog,
      resourceRepository,
    });
    requestId = copilotContext.requestId;

    // 1. Optimistic draft concurrency check (prevents stale proposals overwriting manual edits)
    if (
      copilotContext.baseDraftVersion &&
      copilotContext.baseDraftVersion !== copilotContext.computedDraftVersion
    ) {
      throw new PlannerV2Error(
        'DRAFT_VERSION_CONFLICT',
        'El borrador fue editado manualmente desde que comenzó la consulta. Reenvía tu instrucción sobre la versión actual.',
        {
          httpStatus: 409,
          retryable: true,
          details: {
            expected_base_draft_version: copilotContext.baseDraftVersion,
            current_draft_version: copilotContext.computedDraftVersion,
          },
        }
      );
    }

    // 2. Verify zero forbidden keys or raw URLs leak into the LLM context
    const llmLeakViolations = inspectPayloadForForbiddenKeysOrUrls(copilotContext.llmContext);
    if (llmLeakViolations.length > 0) {
      throw new PlannerV2Error(
        'PRIVACY_LEAK_BLOCKED',
        `Bloqueado envío con identificadores o URLs no permitidas hacia IA: ${llmLeakViolations.join(', ')}`,
        { httpStatus: 500 }
      );
    }

    // 3. Atomic quota & idempotency
    const slot = await quotaStore.acquireSlot({
      actorId: actor.actorId,
      requestId,
      nowMs,
      dailyLimit: serverConfig.quota.dailyLimit,
      perMinuteLimit: serverConfig.quota.perMinuteLimit,
    });
    if (slot.status === 'replay') {
      return {
        ...slot.cachedResponse,
        generation_meta: {
          ...slot.cachedResponse.generation_meta,
          idempotent_replay: true,
        },
      };
    }
    slotAcquired = true;

    // 4. Resolve server-controlled provider (never trusts client overrides)
    let provider = deps.provider || null;
    if (!provider) {
      if (serverConfig.providerMode === 'openai') {
        if (serverConfig.realProviderEnabled !== true) {
          throw new PlannerV2Error(
            'REAL_PROVIDER_DISABLED',
            'El proveedor LLM real del copiloto está deshabilitado hasta autorización explícita.',
            { httpStatus: 503 }
          );
        }
        const openai = new OpenAiStructuredProvider({ apiKey: resolveServerOpenAiApiKey() });
        provider = {
          name: 'openai',
          async proposeTurn({ copilotContext: ctxArg }) {
            const promptBundle = buildCopilotPrompts(ctxArg);
            const gen = await openai.generateStructured({
              promptBundle,
              schema: promptBundle.schema,
              model: serverConfig.primaryModel,
              timeoutMs: 40000,
              maxOutputTokens: 1600,
              temperature: 0.25,
              serverConfig,
              context: ctxArg.validationContext,
            });
            return { rawOutput: gen.rawPlan, usage: gen.usage };
          },
        };
      } else {
        provider = new SimulatedCopilotProvider({ catalog });
      }
    }
    providerNameForTelemetry = provider.name;

    const promptBundle = buildCopilotPrompts(copilotContext);
    if (provider.name === 'openai' && copilotBudgetGuard) {
      await copilotBudgetGuard.reserveGeneration({
        requestId,
        model: serverConfig.primaryModel,
        estimatedInputTokens: promptBundle.estimatedInputTokens,
        maxOutputTokens: 1600,
        maxRepairAttempts: 0,
      });
      budgetReserved = true;
    }
    billableAttemptStarted = provider.name === 'openai';

    const t0 = Date.now();
    const turnResult = await provider.proposeTurn({ copilotContext, catalog });
    const latencyMs = Date.now() - t0;
    const rawOut = turnResult?.rawOutput || {};
    const usage = turnResult?.usage || { inputTokens: 0, outputTokens: 0, estimatedCostUsd: 0 };
    actualCostForFailure = Number(usage.estimatedCostUsd || 0);

    if (budgetReserved && copilotBudgetGuard) {
      await copilotBudgetGuard.settleGeneration({
        requestId,
        actualCostUsd: actualCostForFailure,
        actualCalls: 1,
        succeeded: true,
      });
      budgetReserved = false;
    }

    let finalMode = rawOut.mode === 'propose_changes' ? 'propose_changes' : rawOut.mode === 'conflict' ? 'conflict' : 'consult';
    let assistantMessage = String(rawOut.assistant_message || '').trim() || 'Consulta procesada.';
    let pedagogicalNotes = Array.isArray(rawOut.pedagogical_notes)
      ? rawOut.pedagogical_notes.map((n) => String(n || '').trim()).filter(Boolean)
      : [];
    let conflictReason = rawOut.conflict_reason ? String(rawOut.conflict_reason).trim() : null;
    let safeAlternative = rawOut.safe_alternative ? String(rawOut.safe_alternative).trim() : null;
    let operations = Array.isArray(rawOut.operations) ? rawOut.operations : [];
    let proposedPlan = null;
    let resultingDraftVersion = copilotContext.computedDraftVersion;
    let diffSummary = [];
    let validationReport = null;

    if (finalMode === 'propose_changes' && operations.length > 0) {
      try {
        const candidatePlan = applyCopilotOperationsToPlan(copilotContext.plan, operations, {
          context: copilotContext.validationContext,
          catalog,
          resourceMap: copilotContext.resourceMap,
        });

        // Update validationContext duration if redistribute_duration changed duracion_total
        const validationCtx = {
          ...copilotContext.validationContext,
          durationMin: Number(candidatePlan.duracion_total || copilotContext.validationContext.durationMin),
          selectedResources: [
            ...copilotContext.validationContext.selectedResources,
            ...[...new Set(candidatePlan.bloques.flatMap((b) => (b.ejercicios || []).flatMap((e) => e.linked_resource_ids || [])))]
              .filter(
                (rId) => !copilotContext.validationContext.selectedResources.some((existing) => existing.resource_id === rId)
              )
              .map((rId) => {
                const rm = copilotContext.resourceMap.get(rId);
                return {
                  resource_id: rId,
                  title: rm?.title || 'Recurso de Pizarra',
                  category: rm?.category || 'General',
                  notes: rm?.notes || '',
                  has_external_video: Boolean(rm?.hasExternalVideo || rm?.has_external_video),
                  priority: 'required',
                };
              }),
          ],
        };

        const fullValidation = validateGeneratedPlan(candidatePlan, validationCtx, catalog);
        validationReport = {
          structural: {
            passed: fullValidation.structuralValidation.passed,
            errors: fullValidation.structuralValidation.errors,
            warnings: fullValidation.structuralValidation.warnings,
            duration_sum_exact: fullValidation.structuralValidation.duration_sum_exact,
            curriculum_track_respected: fullValidation.structuralValidation.curriculum_track_respected,
          },
          pedagogical_heuristic: fullValidation.pedagogicalHeuristicEvaluation,
        };

        if (!fullValidation.structuralValidation.passed) {
          finalMode = 'conflict';
          conflictReason = fullValidation.structuralValidation.errors.map((e) => `${e.code}: ${e.message}`).join(' | ');
          safeAlternative =
            'El cambio propuesto entra en conflicto con las reglas pedagógicas o de seguridad del planificador. Pide una alternativa segura compatible con el espacio y los niveles actuales.';
          assistantMessage = `Detecté un conflicto pedagógico o de seguridad antes de aplicar cambios: ${conflictReason}`;
          operations = [];
          proposedPlan = null;
          diffSummary = [];
        } else {
          proposedPlan = candidatePlan;
          resultingDraftVersion = computeDraftVersionHash(candidatePlan);
          diffSummary = buildCopilotDiffSummary(copilotContext.plan, candidatePlan, operations);
        }
      } catch (applyErr) {
        finalMode = 'conflict';
        conflictReason = applyErr.message || 'No se pudo aplicar la operación de forma segura.';
        safeAlternative =
          'Verifica que el bloque/ejercicio siga existiendo o formula el ajuste sobre un movimiento y material confirmados.';
        assistantMessage = `No es posible aplicar esta modificación: ${conflictReason}`;
        operations = [];
        proposedPlan = null;
        diffSummary = [];
      }
    } else if (finalMode === 'propose_changes' && operations.length === 0) {
      finalMode = 'consult';
    }

    const response = {
      contract_version: COPILOT_CONTRACT_VERSION,
      status: 'ok',
      mode: finalMode,
      base_draft_version: copilotContext.computedDraftVersion,
      resulting_draft_version: resultingDraftVersion,
      selected_block_id: copilotContext.selectedBlock?.block_id || null,
      selected_exercise_id: copilotContext.selectedExercise?.exercise_id || null,
      assistant_message: assistantMessage,
      pedagogical_notes: pedagogicalNotes,
      conflict_reason: conflictReason,
      safe_alternative: safeAlternative,
      operations,
      diff_summary: diffSummary,
      proposed_plan: proposedPlan,
      validation_report: validationReport,
      privacy_notice: {
        heuristic_disclaimer: HEURISTIC_PRIVACY_DISCLAIMER,
      },
      generation_meta: {
        provider: provider.name,
        model: provider.name === 'openai' ? serverConfig.primaryModel : 'simulated-copilot-v1',
        is_simulated: provider.name !== 'openai',
        idempotent_replay: false,
        actor_mode: actor.actorMode,
      },
      cost_telemetry: {
        input_tokens: Number(usage.inputTokens || 0),
        output_tokens: Number(usage.outputTokens || 0),
        estimated_cost_usd: Number(usage.estimatedCostUsd || 0),
        latency_ms: latencyMs,
        calls_made: 1,
        copilot_budget: copilotBudgetGuard ? copilotBudgetGuard.getSnapshot() : null,
      },
    };

    await quotaStore.commitResult({
      actorId: actor.actorId,
      requestId,
      response,
    });

    telemetry.record({
      actorId: actor.actorId,
      requestId,
      audienceType: copilotContext.validationContext.audienceType,
      curriculumScope: copilotContext.validationContext.curriculumScope,
      provider: provider.name,
      model: response.generation_meta.model,
      isSimulated: response.generation_meta.is_simulated,
      status: `copilot_${finalMode}`,
      inputTokens: response.cost_telemetry.input_tokens,
      outputTokens: response.cost_telemetry.output_tokens,
      estimatedCostUsd: response.cost_telemetry.estimated_cost_usd,
      latencyMs,
      piiRedactionsCount: copilotContext.piiRedactionsCount,
      injectionSignalsCount: copilotContext.injectionSignals.length,
    });

    return response;
  } catch (err) {
    if (budgetReserved && copilotBudgetGuard && requestId) {
      await copilotBudgetGuard.settleGeneration({
        requestId,
        actualCostUsd: actualCostForFailure,
        actualCalls: billableAttemptStarted ? 1 : 0,
        succeeded: false,
      });
    }
    if (slotAcquired && requestId) {
      await quotaStore.releaseOnFailure({
        actorId: actor.actorId,
        requestId,
        nowMs,
        billable: billableAttemptStarted,
      });
    }
    if (err instanceof PlannerV2Error) {
      throw err;
    }
    throw new PlannerV2Error('INTERNAL_ERROR', err?.message || 'Error inesperado en Copiloto GINGA.', {
      httpStatus: 500,
    });
  }
}

module.exports = {
  runPedagogicalCopilotV1,
};

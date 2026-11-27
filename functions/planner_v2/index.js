'use strict';

const {
  getServerConfig,
  resolveMaxOutputTokens,
  resolveServerOpenAiApiKey,
  hasServerOpenAiCredentials,
} = require('./config');
const { PlannerV2Error } = require('./errors');
const { loadVerifiedCatalog } = require('./curriculum_catalog_loader');
const {
  assertAuthorizedActor,
  InMemoryAtomicQuotaStore,
  FirestoreTransactionQuotaStore,
} = require('./auth_and_quota_guard');
const { AtomicPilotBudgetGuard } = require('./pilot_budget_guard');
const { buildValidatedContext } = require('./context_builder');
const { buildPlannerPrompts, buildSingleBlockPrompts } = require('./prompt_builder');
const { CLASS_PLAN_V2_JSON_SCHEMA } = require('./response_schema');
const { OpenAiStructuredProvider, listAccessibleOpenAiModels } = require('./llm_adapter');
const { SimulatedPlannerProvider } = require('./simulated_provider');
const { validateAndRepairPlan, generateAndValidateModularPlan } = require('./plan_repairer');
const { HEURISTIC_PRIVACY_DISCLAIMER } = require('./pii_and_injection_guard');
const { PlannerTelemetryLogger } = require('./telemetry');
const { runPedagogicalCopilotV1 } = require('./copilot_engine');
const {
  COPILOT_CONTRACT_VERSION,
  COPILOT_OPERATION_TYPES,
  OPENAI_STRICT_COPILOT_V1_JSON_SCHEMA,
  computeDraftVersionHash,
} = require('./copilot_schema');
const { applyCopilotOperationsToPlan, buildCopilotDiffSummary } = require('./copilot_operations');
const { SimulatedCopilotProvider } = require('./copilot_simulated_provider');

function buildExcludedAndTransparencyNotices(context, repairResult) {
  const notices = [];
  if (context.selectedResources.some((r) => r.has_external_video)) {
    notices.push(
      'Los recursos con video externo se integraron únicamente usando título, notas y usage_note escritos; el motor no analiza visualmente videos.'
    );
  }
  if (!context.space.floorType || context.space.floorType === 'desconocido' || context.space.availableMats === null) {
    notices.push(
      'No se asumieron tatami ni colchonetas al no estar declarados explícitamente en las condiciones del espacio.'
    );
  }
  if (!context.materialsKnown) {
    notices.push(
      'No se declaró lista de materiales disponibles; verificar en sala antes de impartir.'
    );
  }
  if (context.audienceType === 'infantil') {
    notices.push(
      'Currículo Infantil FIU pendiente de extracción: no se atribuyeron graduaciones infantiles oficiales a las propuestas generadas.'
    );
  }
  if (repairResult.repairAttemptsUsed > 0) {
    notices.push(`Se aplicó ${repairResult.repairAttemptsUsed} pase controlado de reparación estructural.`);
  }
  return notices;
}

/**
 * Main orchestrator for GINGA Pedagogical Engine V2 (offline in PED-04C2-B).
 */
async function generateClassPlanV2({
  request,
  authContext = {},
  deps = {},
  serverOverrides = {},
  nowMs = Date.now(),
}) {
  const serverConfig = getServerConfig(serverOverrides);
  const telemetry = deps.telemetry || new PlannerTelemetryLogger();
  const quotaStore = deps.quotaStore || new InMemoryAtomicQuotaStore();
  const budgetGuard = deps.budgetGuard || null;
  const resourceRepository = deps.resourceRepository || { async getResourcesByIds() { return new Map(); } };

  let actor = { actorId: 'unauthenticated' };
  let requestId = String(request?.request_id || '').trim();
  let slotAcquired = false;
  let billableAttemptStarted = false;
  let budgetReserved = false;
  let providerNameForTelemetry = serverConfig.providerMode === 'openai' ? 'openai' : 'simulated';
  let actualCostUsdForFailure = 0;
  let actualCallsForFailure = 0;

  try {
    // 1. Verified catalog integrity check
    const catalog = deps.catalog || loadVerifiedCatalog();

    // 2. Authorization via signed Custom Claims (never trusts Firestore mutable role)
    actor = assertAuthorizedActor(authContext, serverConfig);

    // 3. Validate request, reject client policy overrides, verify FIU & Pizarra ownership, Zero-PII & prompt-injection guard
    const context = await buildValidatedContext({
      request,
      actor,
      catalog,
      resourceRepository,
    });
    requestId = context.requestId || requestId;

    // 4. Atomic quota reservation + requestId idempotency
    const slot = await quotaStore.acquireSlot({
      actorId: actor.actorId,
      requestId,
      nowMs,
      dailyLimit: serverConfig.quota.dailyLimit,
      perMinuteLimit: serverConfig.quota.perMinuteLimit,
    });

    if (slot.status === 'replay') {
      telemetry.record({
        actorId: actor.actorId,
        requestId,
        audienceType: context.audienceType,
        curriculumScope: context.curriculumScope,
        provider: slot.cachedResponse.generation_meta?.provider,
        model: slot.cachedResponse.generation_meta?.model,
        isSimulated: slot.cachedResponse.generation_meta?.is_simulated,
        status: 'ok',
        idempotentReplay: true,
        inputTokens: 0,
        outputTokens: 0,
        estimatedCostUsd: 0,
        latencyMs: 1,
        piiRedactionsCount: context.sanitizationMeta.piiRedactionsCount,
        injectionSignalsCount: context.sanitizationMeta.injectionSignals.length,
        heuristicScore:
          slot.cachedResponse.validation_report?.pedagogical_heuristic?.score_total ?? null,
      });
      return {
        ...slot.cachedResponse,
        generation_meta: {
          ...slot.cachedResponse.generation_meta,
          idempotent_replay: true,
        },
      };
    }
    slotAcquired = true;

    // 5. Select server-controlled provider (OpenAI disabled unless explicitly authorized on server)
    let provider = deps.provider || null;
    if (!provider) {
      if (serverConfig.providerMode === 'openai') {
        provider = new OpenAiStructuredProvider({ apiKey: resolveServerOpenAiApiKey() });
      } else {
        provider = new SimulatedPlannerProvider({ catalog });
      }
    }
    providerNameForTelemetry = provider.name;

    if (provider.name === 'openai' && serverConfig.realProviderEnabled !== true) {
      throw new PlannerV2Error(
        'REAL_PROVIDER_DISABLED',
        'El proveedor LLM real está deshabilitado por defecto.',
        { httpStatus: 503 }
      );
    }

    let selectedModel = provider.name === 'openai' ? serverConfig.primaryModel : 'simulated-planner-v2';
    let modelFallbackFrom = null;

    const useModularStrategy =
      provider.supportsBlockGeneration === true && serverOverrides.useModularGeneration !== false;

    let repaired;
    let totalCallsMade = 1;
    let isSimulatedResult = provider.name !== 'openai';
    const generationStrategy = useModularStrategy ? 'modular_block_v2' : 'monolithic_v2';

    if (useModularStrategy) {
      const blockSpecs = context.temporalBlueprint?.blocks || [];
      const sampleBlockPrompt =
        blockSpecs.length > 0
          ? buildSingleBlockPrompts(context, blockSpecs[0], {
              blockIndex: 0,
              totalBlocks: blockSpecs.length,
            })
          : { estimatedInputTokens: 1100 };
      const estimatedBlockInputTokens = Math.max(900, sampleBlockPrompt.estimatedInputTokens || 1050);

      if (provider.name === 'openai' && budgetGuard) {
        await budgetGuard.reserveGeneration({
          requestId,
          model: selectedModel,
          estimatedInputTokens: estimatedBlockInputTokens,
          maxRepairAttempts: serverConfig.budget.maxRepairAttempts,
          mode: 'modular',
          blocksCount: blockSpecs.length || 4,
          blockMaxOutputTokens: serverConfig.budget.blockMaxOutputTokens,
        });
        budgetReserved = true;
      }

      billableAttemptStarted = provider.name === 'openai';

      try {
        repaired = await generateAndValidateModularPlan({
          context,
          catalog,
          provider,
          model: selectedModel,
          serverConfig,
          onProgress: deps.onProgress,
        });
      } catch (modErr) {
        const partialCalls = Number(modErr?.details?.partial_usage?.callsMade || 0);
        const canFallbackModel =
          provider.name === 'openai' &&
          modErr instanceof PlannerV2Error &&
          modErr.code === 'MODEL_ACCESS_DENIED' &&
          partialCalls === 0 &&
          serverConfig.fallbackModel &&
          serverConfig.fallbackModel !== selectedModel;

        if (!canFallbackModel) {
          throw modErr;
        }

        if (budgetReserved && budgetGuard) {
          await budgetGuard.settleGeneration({
            requestId,
            actualCostUsd: 0,
            actualCalls: 0,
            succeeded: false,
          });
          budgetReserved = false;
        }

        modelFallbackFrom = selectedModel;
        selectedModel = serverConfig.fallbackModel;

        if (budgetGuard) {
          await budgetGuard.reserveGeneration({
            requestId,
            model: selectedModel,
            estimatedInputTokens: estimatedBlockInputTokens,
            maxRepairAttempts: serverConfig.budget.maxRepairAttempts,
            mode: 'modular',
            blocksCount: blockSpecs.length || 4,
            blockMaxOutputTokens: serverConfig.budget.blockMaxOutputTokens,
          });
          budgetReserved = true;
        }

        repaired = await generateAndValidateModularPlan({
          context,
          catalog,
          provider,
          model: selectedModel,
          serverConfig,
          onProgress: deps.onProgress,
        });
      }

      totalCallsMade = Number(repaired.usageSummary?.callsMade || blockSpecs.length);
      actualCostUsdForFailure = repaired.usageSummary.estimatedCostUsd || 0;
      actualCallsForFailure = totalCallsMade;
    } else {
      // Legacy / Simulated monolithic flow
      const promptBundle = buildPlannerPrompts(context);
      const effectiveMaxOutputTokens = resolveMaxOutputTokens(context.durationMin, serverConfig);

      if (provider.name === 'openai' && budgetGuard) {
        await budgetGuard.reserveGeneration({
          requestId,
          model: selectedModel,
          estimatedInputTokens: promptBundle.estimatedInputTokens || 3000,
          maxOutputTokens: effectiveMaxOutputTokens,
          maxRepairAttempts: serverConfig.budget.maxRepairAttempts,
        });
        budgetReserved = true;
      }

      billableAttemptStarted = provider.name === 'openai';

      let initialGeneration;
      try {
        initialGeneration = await provider.generateStructured({
          promptBundle,
          schema: CLASS_PLAN_V2_JSON_SCHEMA,
          model: selectedModel,
          timeoutMs: serverConfig.budget.primaryTimeoutMs,
          maxOutputTokens: effectiveMaxOutputTokens,
          temperature: 0.45,
          serverConfig,
          context,
        });
      } catch (providerErr) {
        const canFallbackModel =
          provider.name === 'openai' &&
          providerErr instanceof PlannerV2Error &&
          providerErr.code === 'MODEL_ACCESS_DENIED' &&
          serverConfig.fallbackModel &&
          serverConfig.fallbackModel !== selectedModel;

        if (!canFallbackModel) {
          throw providerErr;
        }

        if (budgetReserved && budgetGuard) {
          await budgetGuard.settleGeneration({
            requestId,
            actualCostUsd: 0,
            actualCalls: 0,
            succeeded: false,
          });
          budgetReserved = false;
        }

        modelFallbackFrom = selectedModel;
        selectedModel = serverConfig.fallbackModel;

        if (budgetGuard) {
          await budgetGuard.reserveGeneration({
            requestId,
            model: selectedModel,
            estimatedInputTokens: promptBundle.estimatedInputTokens || 3000,
            maxOutputTokens: effectiveMaxOutputTokens,
            maxRepairAttempts: serverConfig.budget.maxRepairAttempts,
          });
          budgetReserved = true;
        }

        initialGeneration = await provider.generateStructured({
          promptBundle,
          schema: CLASS_PLAN_V2_JSON_SCHEMA,
          model: selectedModel,
          timeoutMs: serverConfig.budget.primaryTimeoutMs,
          maxOutputTokens: effectiveMaxOutputTokens,
          temperature: 0.45,
          serverConfig,
          context,
        });
      }
      actualCostUsdForFailure = initialGeneration.usage?.estimatedCostUsd || 0;
      actualCallsForFailure = 1;
      isSimulatedResult = initialGeneration.isSimulated === true;

      repaired = await validateAndRepairPlan({
        initialGeneration,
        context,
        catalog,
        provider,
        serverConfig: {
          ...serverConfig,
          budget: {
            ...serverConfig.budget,
            maxOutputTokens: effectiveMaxOutputTokens,
          },
        },
      });
      totalCallsMade = 1 + repaired.repairAttemptsUsed;
    }

    let pilotBudgetSnapshot = budgetGuard ? budgetGuard.getSnapshot() : null;
    if (budgetReserved && budgetGuard) {
      pilotBudgetSnapshot = await budgetGuard.settleGeneration({
        requestId,
        actualCostUsd: repaired.usageSummary.estimatedCostUsd,
        actualCalls: totalCallsMade,
        succeeded: true,
      });
      budgetReserved = false;
    }

    const planWithSnapshot = {
      ...repaired.plan,
      group_snapshot: {
        group_name: context.llmPayloadContext.group_profile.group_label,
        age_min: context.ageMin,
        age_max: context.ageMax,
        participants: context.participants,
        experience_distribution: context.expDist,
      },
      space_snapshot: {
        space_size: context.space.spaceSize,
        floor_type: context.space.floorType,
        available_mats: context.space.availableMats,
        instructors_available: context.instructorsAvailable,
      },
    };

    const response = {
      contract_version: serverConfig.contractVersion,
      status: 'ok',
      plan: planWithSnapshot,
      generation_meta: {
        engine_version: serverConfig.engineVersion,
        generation_strategy: generationStrategy,
        provider: provider.name,
        model: selectedModel,
        model_fallback_from: modelFallbackFrom,
        is_simulated: isSimulatedResult,
        idempotent_replay: false,
        actor_mode: actor.actorMode,
        generated_at: new Date(nowMs).toISOString(),
        repair_attempts_used: repaired.repairAttemptsUsed,
        repaired_block_ids: repaired.repairedBlockIds || [],
        llm_calls_made: totalCallsMade,
        deterministic_fixes_applied: repaired.deterministicFixesApplied,
        origin_breakdown: repaired.evaluation.structuralValidation.origin_breakdown,
        excluded_or_unlinked_inputs: context.excludedOptionalInputs,
        transparency_notices: [
          ...buildExcludedAndTransparencyNotices(context, repaired),
          ...(modelFallbackFrom
            ? [
                `Fallback controlado de modelo: el proyecto no tuvo acceso a ${modelFallbackFrom}; se utilizó ${selectedModel}.`,
              ]
            : []),
        ],
      },
      validation_report: {
        infrastructure: {
          passed: true,
          catalog_sha256_verified: catalog.sha256,
          custom_claims_verified: actor.actorMode === 'custom_claims',
          client_policy_overrides_blocked: true,
          atomic_quota_slot_reserved: true,
          llm_payload_zero_internal_ids: true,
        },
        structural: repaired.evaluation.structuralValidation,
        pedagogical_heuristic: repaired.evaluation.pedagogicalHeuristicEvaluation,
        human_evaluation_status: 'pending',
        real_llm_quality_status:
          isSimulatedResult
            ? 'pending_real_provider_disabled'
            : 'pending_human_evaluation',
      },
      cost_telemetry: {
        input_tokens: repaired.usageSummary.inputTokens,
        output_tokens: repaired.usageSummary.outputTokens,
        estimated_cost_usd: repaired.usageSummary.estimatedCostUsd,
        latency_ms: repaired.usageSummary.latencyMs,
        calls_made: totalCallsMade,
        quota_usage: slot.usageSnapshot,
        pilot_budget: pilotBudgetSnapshot,
      },
      privacy_notice: {
        pii_redactions_applied: context.sanitizationMeta.piiRedactionsCount,
        redaction_categories: context.sanitizationMeta.redactionCategories,
        injection_signals_detected: context.sanitizationMeta.injectionSignals,
        heuristic_disclaimer: HEURISTIC_PRIVACY_DISCLAIMER,
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
      audienceType: context.audienceType,
      curriculumScope: context.curriculumScope,
      provider: provider.name,
      model: selectedModel,
      isSimulated: isSimulatedResult,
      status: 'ok',
      repairAttemptsUsed: repaired.repairAttemptsUsed,
      inputTokens: repaired.usageSummary.inputTokens,
      outputTokens: repaired.usageSummary.outputTokens,
      estimatedCostUsd: repaired.usageSummary.estimatedCostUsd,
      latencyMs: repaired.usageSummary.latencyMs,
      piiRedactionsCount: context.sanitizationMeta.piiRedactionsCount,
      injectionSignalsCount: context.sanitizationMeta.injectionSignals.length,
      heuristicScore: repaired.evaluation.pedagogicalHeuristicEvaluation.score_total,
    });

    return response;
  } catch (err) {
    if (budgetReserved && budgetGuard && requestId) {
      const partial = err?.details?.partial_usage;
      const settledCost =
        typeof partial?.estimatedCostUsd === 'number'
          ? partial.estimatedCostUsd
          : actualCostUsdForFailure;
      const settledCalls =
        typeof partial?.callsMade === 'number'
          ? partial.callsMade
          : actualCallsForFailure;
      await budgetGuard.settleGeneration({
        requestId,
        actualCostUsd: settledCost,
        actualCalls: settledCalls,
        succeeded: false,
      });
    }

    if (slotAcquired && requestId) {
      const partialCalls = err?.details?.partial_usage?.callsMade;
      const effectiveCalls = typeof partialCalls === 'number' ? partialCalls : actualCallsForFailure;
      await quotaStore.releaseOnFailure({
        actorId: actor.actorId,
        requestId,
        nowMs,
        billable: billableAttemptStarted && effectiveCalls > 0,
      });
    }

    const normalized =
      err instanceof PlannerV2Error
        ? err
        : new PlannerV2Error('INTERNAL_ERROR', err?.message || 'Error inesperado en Planner V2.', { httpStatus: 500 });

    telemetry.record({
      actorId: actor.actorId,
      requestId,
      provider: providerNameForTelemetry,
      status: 'error',
      errorCode: normalized.code,
      isSimulated: providerNameForTelemetry !== 'openai',
    });

    throw normalized;
  }
}

module.exports = {
  generateClassPlanV2,
  runPedagogicalCopilotV1,
  applyCopilotOperationsToPlan,
  buildCopilotDiffSummary,
  computeDraftVersionHash,
  COPILOT_CONTRACT_VERSION,
  COPILOT_OPERATION_TYPES,
  OPENAI_STRICT_COPILOT_V1_JSON_SCHEMA,
  SimulatedCopilotProvider,
  getServerConfig,
  resolveServerOpenAiApiKey,
  hasServerOpenAiCredentials,
  PlannerV2Error,
  loadVerifiedCatalog,
  InMemoryAtomicQuotaStore,
  FirestoreTransactionQuotaStore,
  AtomicPilotBudgetGuard,
  OpenAiStructuredProvider,
  listAccessibleOpenAiModels,
  SimulatedPlannerProvider,
  PlannerTelemetryLogger,
};

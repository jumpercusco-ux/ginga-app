'use strict';

const { getServerConfig, resolveMaxOutputTokens } = require('./config');
const { PlannerV2Error } = require('./errors');
const { loadVerifiedCatalog } = require('./curriculum_catalog_loader');
const { assertAuthorizedActor, InMemoryAtomicQuotaStore } = require('./auth_and_quota_guard');
const { buildValidatedContext } = require('./context_builder');
const { buildPlannerPrompts } = require('./prompt_builder');
const { CLASS_PLAN_V2_JSON_SCHEMA } = require('./response_schema');
const { OpenAiStructuredProvider } = require('./llm_adapter');
const { SimulatedPlannerProvider } = require('./simulated_provider');
const { validateAndRepairPlan } = require('./plan_repairer');
const { HEURISTIC_PRIVACY_DISCLAIMER } = require('./pii_and_injection_guard');
const { PlannerTelemetryLogger } = require('./telemetry');

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
  const resourceRepository = deps.resourceRepository || { async getResourcesByIds() { return new Map(); } };

  let actor = { actorId: 'unauthenticated' };
  let requestId = String(request?.request_id || '').trim();
  let slotAcquired = false;
  let billableAttemptStarted = false;

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

    // 5. Select server-controlled provider (OpenAI strictly disabled in PED-04C2-B)
    let provider = deps.provider || null;
    if (!provider) {
      if (serverConfig.providerMode === 'openai') {
        provider = new OpenAiStructuredProvider({ apiKey: process.env.OPENAI_API_KEY || '' });
      } else {
        provider = new SimulatedPlannerProvider({ catalog });
      }
    }

    if (provider.name === 'openai' && serverConfig.realProviderEnabled !== true) {
      throw new PlannerV2Error(
        'REAL_PROVIDER_DISABLED',
        'El proveedor LLM real está deshabilitado en PED-04C2-B.',
        { httpStatus: 503 }
      );
    }

    const selectedModel = provider.name === 'openai' ? serverConfig.primaryModel : 'simulated-planner-v2';

    // 6. Build pedagogical prompt & strict schema
    const promptBundle = buildPlannerPrompts(context);
    billableAttemptStarted = provider.name === 'openai';

    // 7. Invoke provider with timeout and duration-scaled output budget
    const effectiveMaxOutputTokens = resolveMaxOutputTokens(context.durationMin, serverConfig);
    const initialGeneration = await provider.generateStructured({
      promptBundle,
      schema: CLASS_PLAN_V2_JSON_SCHEMA,
      model: selectedModel,
      timeoutMs: serverConfig.budget.primaryTimeoutMs,
      maxOutputTokens: effectiveMaxOutputTokens,
      temperature: 0.45,
      serverConfig,
      context,
    });

    // 8. Validate deterministically + bounded repair (Level 1 non-semantic + max 1 LLM pass)
    const repaired = await validateAndRepairPlan({
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
        provider: initialGeneration.provider,
        model: initialGeneration.model,
        is_simulated: initialGeneration.isSimulated === true,
        idempotent_replay: false,
        actor_mode: actor.actorMode,
        generated_at: new Date(nowMs).toISOString(),
        repair_attempts_used: repaired.repairAttemptsUsed,
        deterministic_fixes_applied: repaired.deterministicFixesApplied,
        origin_breakdown: repaired.evaluation.structuralValidation.origin_breakdown,
        excluded_or_unlinked_inputs: context.excludedOptionalInputs,
        transparency_notices: buildExcludedAndTransparencyNotices(context, repaired),
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
        real_llm_quality_status: 'pending_real_provider_disabled',
      },
      cost_telemetry: {
        input_tokens: repaired.usageSummary.inputTokens,
        output_tokens: repaired.usageSummary.outputTokens,
        estimated_cost_usd: repaired.usageSummary.estimatedCostUsd,
        latency_ms: repaired.usageSummary.latencyMs,
        quota_usage: slot.usageSnapshot,
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
      provider: initialGeneration.provider,
      model: initialGeneration.model,
      isSimulated: initialGeneration.isSimulated === true,
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
    if (slotAcquired && requestId) {
      await quotaStore.releaseOnFailure({
        actorId: actor.actorId,
        requestId,
        nowMs,
        billable: billableAttemptStarted,
      });
    }

    const normalized =
      err instanceof PlannerV2Error
        ? err
        : new PlannerV2Error('INTERNAL_ERROR', err?.message || 'Error inesperado en Planner V2.', { httpStatus: 500 });

    telemetry.record({
      actorId: actor.actorId,
      requestId,
      status: 'error',
      errorCode: normalized.code,
      isSimulated: true,
    });

    throw normalized;
  }
}

module.exports = {
  generateClassPlanV2,
  getServerConfig,
  PlannerV2Error,
  loadVerifiedCatalog,
  InMemoryAtomicQuotaStore,
  OpenAiStructuredProvider,
  SimulatedPlannerProvider,
  PlannerTelemetryLogger,
};

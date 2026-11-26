'use strict';

const { validateGeneratedPlan, computeExpectedAuthoringAndOrigins } = require('./plan_validator');
const { buildPlannerPrompts } = require('./prompt_builder');
const { CLASS_PLAN_V2_JSON_SCHEMA } = require('./response_schema');
const { PlannerV2Error } = require('./errors');

/**
 * Nivel 1: Strictly non-semantic deterministic repairs ONLY.
 * - Assigns missing block_id / exercise_id.
 * - Normalizes source_origins / activity_authoring when curriculum/resource IDs are already present.
 * - Appends mandatory video_reference_note when external video resource is already linked.
 *
 * NEVER modifies block/exercise durations silently.
 * NEVER removes mandatory movements/resources or alters pedagogical text.
 */
function applySafeDeterministicRepairs(rawPlan, context, catalog) {
  if (!rawPlan || typeof rawPlan !== 'object' || !Array.isArray(rawPlan.bloques)) {
    return { plan: rawPlan, fixesApplied: [] };
  }

  const plan = JSON.parse(JSON.stringify(rawPlan));
  const fixesApplied = [];
  const resMap = new Map(context.selectedResources.map((r) => [r.resource_id, r]));

  for (let bi = 0; bi < plan.bloques.length; bi++) {
    const blk = plan.bloques[bi];
    if (!blk || typeof blk !== 'object') continue;
    if (!blk.block_id || String(blk.block_id).trim() === '') {
      blk.block_id = `blk_${bi + 1}`;
      fixesApplied.push(`assign_missing_block_id:${bi}`);
    }

    const ejercicios = Array.isArray(blk.ejercicios) ? blk.ejercicios : [];
    for (let ei = 0; ei < ejercicios.length; ei++) {
      const ex = ejercicios[ei];
      if (!ex || typeof ex !== 'object') continue;

      if (!ex.exercise_id || String(ex.exercise_id).trim() === '') {
        ex.exercise_id = `ex_${bi + 1}_${ei + 1}`;
        fixesApplied.push(`assign_missing_exercise_id:${bi}.${ei}`);
      }

      const movIds = Array.isArray(ex.curriculum_movement_ids) ? ex.curriculum_movement_ids : [];
      const resIds = Array.isArray(ex.linked_resource_ids) ? ex.linked_resource_ids : [];
      const allMovsValid =
        context.curriculumScope === 'adulto_fiu' &&
        movIds.every((id) => catalog.movementsById.get(id)?.ai_planner_eligible === true);

      if (allMovsValid || movIds.length === 0) {
        const expected = computeExpectedAuthoringAndOrigins(ex, catalog);
        if (
          ex.content_origin !== expected.content_origin ||
          ex.activity_authoring !== expected.activity_authoring
        ) {
          ex.content_origin = expected.content_origin;
          ex.source_origins = expected.source_origins;
          ex.activity_authoring = expected.activity_authoring;
          fixesApplied.push(`normalize_origin_metadata:${ex.exercise_id}`);
        }
      }

      const hasExtVideo = resIds.some((id) => resMap.get(id)?.has_external_video === true);
      if (
        hasExtVideo &&
        (!ex.video_reference_note || !/no\s+inspecciona|notas\s+escritas/i.test(ex.video_reference_note))
      ) {
        ex.video_reference_note =
          'Recurso con video externo: integrado únicamente según título y notas escritas del profesor (el motor no inspecciona visualmente el video).';
        fixesApplied.push(`add_video_honesty_note:${ex.exercise_id}`);
      }
    }
  }

  return { plan, fixesApplied };
}

/**
 * Runs Level 1 non-semantic repair and, if structural errors remain,
 * triggers AT MOST 1 controlled LLM repair pass preserving full original context.
 */
async function validateAndRepairPlan({
  initialGeneration,
  context,
  catalog,
  provider,
  serverConfig,
}) {
  let repairAttemptsUsed = 0;
  let totalInputTokens = initialGeneration.usage.inputTokens;
  let totalOutputTokens = initialGeneration.usage.outputTokens;
  let totalCostUsd = initialGeneration.usage.estimatedCostUsd;
  let totalLatencyMs = initialGeneration.usage.latencyMs;

  const det1 = applySafeDeterministicRepairs(initialGeneration.rawPlan, context, catalog);
  let currentPlan = det1.plan;
  const allDetFixes = [...det1.fixesApplied];
  let evaluation = validateGeneratedPlan(currentPlan, context, catalog);

  if (!evaluation.structuralValidation.passed) {
    if (serverConfig.budget.maxRepairAttempts < 1) {
      throw new PlannerV2Error(
        'VALIDATION_FAILED_AFTER_REPAIR',
        'El plan generado falló la validación estructural.',
        {
          httpStatus: 422,
          details: { errors: evaluation.structuralValidation.errors },
        }
      );
    }

    repairAttemptsUsed = 1;
    const repairPromptBundle = buildPlannerPrompts(context, {
      repairErrors: evaluation.structuralValidation.errors,
      previousDraft: currentPlan,
    });

    const repairedGen = await provider.generateStructured({
      promptBundle: repairPromptBundle,
      schema: CLASS_PLAN_V2_JSON_SCHEMA,
      model: initialGeneration.model,
      timeoutMs: serverConfig.budget.repairTimeoutMs,
      maxOutputTokens: serverConfig.budget.maxOutputTokens,
      temperature: 0.2,
      serverConfig,
      context,
      repairErrors: evaluation.structuralValidation.errors,
      previousDraft: currentPlan,
    });

    totalInputTokens += repairedGen.usage.inputTokens;
    totalOutputTokens += repairedGen.usage.outputTokens;
    totalCostUsd = Number((totalCostUsd + repairedGen.usage.estimatedCostUsd).toFixed(6));
    totalLatencyMs += repairedGen.usage.latencyMs;

    const det2 = applySafeDeterministicRepairs(repairedGen.rawPlan, context, catalog);
    currentPlan = det2.plan;
    allDetFixes.push(...det2.fixesApplied);
    evaluation = validateGeneratedPlan(currentPlan, context, catalog);

    if (!evaluation.structuralValidation.passed) {
      throw new PlannerV2Error(
        'VALIDATION_FAILED_AFTER_REPAIR',
        'El plan no cumplió las reglas estructurales tras el único intento permitido de reparación.',
        {
          httpStatus: 422,
          details: {
            repair_attempts_used: repairAttemptsUsed,
            errors: evaluation.structuralValidation.errors,
          },
        }
      );
    }
  }

  return {
    plan: currentPlan,
    evaluation,
    repairAttemptsUsed,
    deterministicFixesApplied: allDetFixes,
    usageSummary: {
      inputTokens: totalInputTokens,
      outputTokens: totalOutputTokens,
      estimatedCostUsd: totalCostUsd,
      latencyMs: totalLatencyMs,
    },
  };
}

module.exports = {
  applySafeDeterministicRepairs,
  validateAndRepairPlan,
};

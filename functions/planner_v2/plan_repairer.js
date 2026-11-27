'use strict';

const { validateGeneratedPlan, computeExpectedAuthoringAndOrigins } = require('./plan_validator');
const { buildPlannerPrompts, buildSingleBlockPrompts } = require('./prompt_builder');
const {
  CLASS_PLAN_V2_JSON_SCHEMA,
  OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA,
  syncInternalTimingsIntoDetalle,
} = require('./response_schema');
const {
  assembleBlockFromAiDraft,
  assembleFullPlanFromBlocks,
  extractFailingBlockIndices,
} = require('./block_assembler');
const { PlannerV2Error } = require('./errors');

const NON_MATERIAL_PLACEHOLDERS_RE =
  /^(?:ninguno|ninguna|ningun\s+material|sin\s+material(?:es)?|no\s+(?:se\s+)?requiere(?:n)?|no\s+necesario|no\s+aplica|n\/?a|nada|-)$/i;

function normalizeNonSemanticAscii(value) {
  return String(value || '')
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function summarizePlanStructureZeroPii(plan, validation) {
  if (!plan || typeof plan !== 'object') return { valid_object: false };
  const bloques = Array.isArray(plan.bloques) ? plan.bloques : [];
  return {
    duracion_total: plan.duracion_total ?? null,
    blocks_count: bloques.length,
    blocks: bloques.map((b) => ({
      block_id: b?.block_id || null,
      fase_tipo: b?.fase_tipo || null,
      duracion_min: b?.duracion_min ?? null,
      exercises: Array.isArray(b?.ejercicios)
        ? b.ejercicios.map((e) => ({
            exercise_id: e?.exercise_id || null,
            duracion_min: e?.duracion_min ?? null,
            has_tiempos_internos: Array.isArray(e?.tiempos_internos) && e.tiempos_internos.length > 0,
          }))
        : [],
    })),
    errors: validation?.structuralValidation?.errors || [],
  };
}

/**
 * Safe bounded arithmetic reconciliation ONLY:
 * - Requires at least 2 blocks and every block >= 1 exercise with integer duracion_min >= 1.
 * - Never fabricates blocks, exercises, or missing internal timing segments.
 * - Reconciles minor block/exercise/total arithmetic mismatches (<= max(6, 25% of target))
 *   and re-syncs existing structured `tiempos_internos` without changing pedagogical text.
 */
function reconcileSafeArithmeticDurations(plan, context, fixesApplied) {
  const targetTotal = Number(context?.durationMin);
  if (!Number.isInteger(targetTotal) || targetTotal < 20) return;
  const bloques = Array.isArray(plan?.bloques) ? plan.bloques : [];
  if (bloques.length < 2 || bloques.length > 7) return;

  for (const blk of bloques) {
    const exs = Array.isArray(blk?.ejercicios) ? blk.ejercicios : [];
    if (exs.length === 0) return;
    if (!Number.isInteger(Number(blk.duracion_min)) || Number(blk.duracion_min) < 1) return;
    for (const ex of exs) {
      if (!Number.isInteger(Number(ex?.duracion_min)) || Number(ex.duracion_min) < 1) return;
    }
  }

  // Reconcile per-block sum if all exercises already sum cleanly to targetTotal
  const exerciseTotalAcrossPlan = bloques.reduce(
    (acc, b) => acc + b.ejercicios.reduce((ea, e) => ea + Number(e.duracion_min), 0),
    0
  );
  const currentBlockSum = bloques.reduce((acc, b) => acc + Number(b.duracion_min), 0);

  if (exerciseTotalAcrossPlan === targetTotal && currentBlockSum !== targetTotal) {
    for (const blk of bloques) {
      const exSum = blk.ejercicios.reduce((ea, e) => ea + Number(e.duracion_min), 0);
      if (blk.duracion_min !== exSum) {
        blk.duracion_min = exSum;
        fixesApplied.push(`reconcile_block_header_duration:${blk.block_id}`);
      }
    }
  } else {
    // Reconcile minor mismatch inside each block (exercise sum -> blk.duracion_min)
    for (const blk of bloques) {
      const bDur = Number(blk.duracion_min);
      let exSum = blk.ejercicios.reduce((ea, e) => ea + Number(e.duracion_min), 0);
      const maxBlkDrift = Math.max(4, Math.round(bDur * 0.25));
      if (exSum !== bDur && Math.abs(bDur - exSum) <= maxBlkDrift) {
        let delta = bDur - exSum;
        const sortedEx = [...blk.ejercicios].sort((a, b) => Number(b.duracion_min) - Number(a.duracion_min));
        let idx = 0;
        let guard = 0;
        while (delta !== 0 && guard < 100) {
          guard += 1;
          const targetEx = sortedEx[idx % sortedEx.length];
          if (delta > 0) {
            targetEx.duracion_min += 1;
            delta -= 1;
          } else if (targetEx.duracion_min > 1) {
            targetEx.duracion_min -= 1;
            delta += 1;
          }
          idx += 1;
        }
        fixesApplied.push(`reconcile_exercise_durations:${blk.block_id}`);
      }
    }

    // Reconcile minor total drift across blocks (if block sum is within 25% of targetTotal)
    const blockSumAfter = bloques.reduce((acc, b) => acc + Number(b.duracion_min), 0);
    const allBlocksInternallySynced = bloques.every(
      (b) => b.ejercicios.reduce((ea, e) => ea + Number(e.duracion_min), 0) === Number(b.duracion_min)
    );
    const maxTotalDrift = Math.max(6, Math.round(targetTotal * 0.25));
    if (allBlocksInternallySynced && blockSumAfter !== targetTotal && Math.abs(targetTotal - blockSumAfter) <= maxTotalDrift) {
      let delta = targetTotal - blockSumAfter;
      const sortedBlocks = [...bloques].sort((a, b) => Number(b.duracion_min) - Number(a.duracion_min));
      let idx = 0;
      let guard = 0;
      while (delta !== 0 && guard < 120) {
        guard += 1;
        const blk = sortedBlocks[idx % sortedBlocks.length];
        const longestEx = [...blk.ejercicios].sort((a, b) => Number(b.duracion_min) - Number(a.duracion_min))[0];
        if (delta > 0) {
          blk.duracion_min += 1;
          longestEx.duracion_min += 1;
          delta -= 1;
        } else if (blk.duracion_min > 2 && longestEx.duracion_min > 1) {
          blk.duracion_min -= 1;
          longestEx.duracion_min -= 1;
          delta += 1;
        }
        idx += 1;
      }
      fixesApplied.push('reconcile_total_duration:blocks_and_exercises');
    }
  }

  const finalBlockSum = bloques.reduce((acc, b) => acc + Number(b.duracion_min), 0);
  if (finalBlockSum === targetTotal && plan.duracion_total !== targetTotal) {
    plan.duracion_total = targetTotal;
    fixesApplied.push('sync_duracion_total_header');
  }

  // Reconcile minor drift inside structured tiempos_internos (only when already present & non-empty)
  for (const blk of bloques) {
    for (const ex of blk.ejercicios) {
      if (!Array.isArray(ex.tiempos_internos) || ex.tiempos_internos.length === 0) continue;
      const validItems = ex.tiempos_internos.filter(
        (t) => String(t?.etapa || '').trim().length > 0 && Number.isInteger(Number(t?.minutos)) && Number(t.minutos) >= 1
      );
      if (validItems.length !== ex.tiempos_internos.length) continue;
      const tSum = validItems.reduce((acc, t) => acc + Number(t.minutos), 0);
      const maxSubDrift = Math.max(3, Math.round(ex.duracion_min * 0.35));
      if (tSum !== ex.duracion_min && Math.abs(ex.duracion_min - tSum) <= maxSubDrift) {
        let delta = ex.duracion_min - tSum;
        const sortedItems = [...validItems].sort((a, b) => Number(b.minutos) - Number(a.minutos));
        let idx = 0;
        let guard = 0;
        while (delta !== 0 && guard < 60) {
          guard += 1;
          const item = sortedItems[idx % sortedItems.length];
          if (delta > 0) {
            item.minutos = Number(item.minutos) + 1;
            delta -= 1;
          } else if (Number(item.minutos) > 1) {
            item.minutos = Number(item.minutos) - 1;
            delta += 1;
          }
          idx += 1;
        }
        ex.tiempos_internos = validItems;
        syncInternalTimingsIntoDetalle(ex);
        fixesApplied.push(`reconcile_internal_timings:${ex.exercise_id}`);
      }
    }
  }
}

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

      if (Array.isArray(ex.materiales)) {
        const cleanedMats = ex.materiales.filter((m) => !NON_MATERIAL_PLACEHOLDERS_RE.test(normalizeNonSemanticAscii(m)));
        if (cleanedMats.length !== ex.materiales.length) {
          ex.materiales = cleanedMats;
          fixesApplied.push(`strip_empty_material_placeholders:${ex.exercise_id}`);
        }
      }

      if (ex.cancionero_reference && typeof ex.cancionero_reference === 'object') {
        const rawCantiga = ex.cancionero_reference.cantiga_id;
        if (
          rawCantiga !== null &&
          rawCantiga !== undefined &&
          /^(?:|null|none|undefined|n\/?a|ninguno|sin_id)$/i.test(String(rawCantiga).trim())
        ) {
          ex.cancionero_reference.cantiga_id = null;
          fixesApplied.push(`normalize_null_cantiga_id:${ex.exercise_id}`);
        }
      }
    }
  }

  reconcileSafeArithmeticDurations(plan, context, fixesApplied);

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
  const initialSummary = summarizePlanStructureZeroPii(currentPlan, evaluation);

  if (!evaluation.structuralValidation.passed) {
    if (serverConfig.budget.maxRepairAttempts < 1) {
      throw new PlannerV2Error(
        'VALIDATION_FAILED_AFTER_REPAIR',
        'El plan generado falló la validación estructural.',
        {
          httpStatus: 422,
          details: {
            errors: evaluation.structuralValidation.errors,
            initial_summary: initialSummary,
          },
        }
      );
    }

    repairAttemptsUsed = 1;
    const repairPromptBundle = buildPlannerPrompts(context, {
      repairErrors: evaluation.structuralValidation.errors,
      previousDraft: currentPlan,
    });

    let repairedGen;
    try {
      repairedGen = await provider.generateStructured({
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
    } catch (repairErr) {
      if (repairErr instanceof PlannerV2Error) {
        repairErr.details = {
          ...(repairErr.details || {}),
          repair_attempts_used: repairAttemptsUsed,
          initial_summary: initialSummary,
          partial_usage: {
            inputTokens: totalInputTokens,
            outputTokens: totalOutputTokens,
            estimatedCostUsd: totalCostUsd,
            latencyMs: totalLatencyMs,
            callsMade: 1 + repairAttemptsUsed,
          },
        };
      }
      throw repairErr;
    }

    totalInputTokens += repairedGen.usage.inputTokens;
    totalOutputTokens += repairedGen.usage.outputTokens;
    totalCostUsd = Number((totalCostUsd + repairedGen.usage.estimatedCostUsd).toFixed(6));
    totalLatencyMs += repairedGen.usage.latencyMs;

    const det2 = applySafeDeterministicRepairs(repairedGen.rawPlan, context, catalog);
    currentPlan = det2.plan;
    allDetFixes.push(...det2.fixesApplied);
    evaluation = validateGeneratedPlan(currentPlan, context, catalog);

    if (!evaluation.structuralValidation.passed) {
      const repairedSummary = summarizePlanStructureZeroPii(currentPlan, evaluation);
      throw new PlannerV2Error(
        'VALIDATION_FAILED_AFTER_REPAIR',
        'El plan no cumplió las reglas estructurales tras el único intento permitido de reparación.',
        {
          httpStatus: 422,
          details: {
            repair_attempts_used: repairAttemptsUsed,
            errors: evaluation.structuralValidation.errors,
            initial_summary: initialSummary,
            repaired_summary: repairedSummary,
            deterministic_fixes_applied: allDetFixes,
            partial_usage: {
              inputTokens: totalInputTokens,
              outputTokens: totalOutputTokens,
              estimatedCostUsd: totalCostUsd,
              latencyMs: totalLatencyMs,
              callsMade: 2,
            },
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

function safeNotifyProgress(onProgress, event) {
  if (typeof onProgress !== 'function') return;
  try {
    onProgress({
      ...event,
      updated_at: new Date().toISOString(),
    });
  } catch (_) {
    // Ignore progress listener errors
  }
}

/**
 * Modular Block-by-Block Orchestrator + Targeted Single-Block Repair (`PED-04C2-D`).
 * Generates each block independently with a slim strict schema, bounded wave concurrency,
 * deterministic code assembly for IDs/durations/origins/bindings, and targeted repair of ONLY
 * the failing block (never regenerating valid blocks).
 */
async function generateAndValidateModularPlan({
  context,
  catalog,
  provider,
  model,
  serverConfig,
  onProgress = null,
}) {
  const blockSpecs = Array.isArray(context.temporalBlueprint?.blocks)
    ? context.temporalBlueprint.blocks
    : [];
  if (blockSpecs.length < 2) {
    throw new PlannerV2Error(
      'INVALID_REQUEST',
      'El esqueleto temporal determinista requiere al menos 2 bloques.',
      { httpStatus: 400 }
    );
  }

  const concurrency = Math.max(1, Math.min(4, Number(serverConfig?.budget?.blockConcurrency || 2)));
  const blockMaxOutputTokens = Number(serverConfig?.budget?.blockMaxOutputTokens || 1600);
  const blockTimeoutMs = Number(serverConfig?.budget?.blockTimeoutMs || 30000);
  const blockRepairTimeoutMs = Number(serverConfig?.budget?.blockRepairTimeoutMs || 30000);
  const maxRepairAttempts = Number(serverConfig?.budget?.maxRepairAttempts ?? 1);

  const startedAtMs = Date.now();
  const usageAcc = {
    inputTokens: 0,
    outputTokens: 0,
    estimatedCostUsd: 0,
    callsMade: 0,
  };
  const assembledBlocks = new Array(blockSpecs.length);
  let completedBlocksCount = 0;

  safeNotifyProgress(onProgress, {
    status: 'running',
    stage: 'generating_blocks',
    completed_blocks: 0,
    total_blocks: blockSpecs.length,
    current_block_ids: [],
  });

  // Execute in bounded waves so a wave-1 rejection/timeout stops subsequent waves cleanly.
  for (let offset = 0; offset < blockSpecs.length; offset += concurrency) {
    const waveIndices = [];
    for (let j = offset; j < Math.min(blockSpecs.length, offset + concurrency); j++) {
      waveIndices.push(j);
    }

    safeNotifyProgress(onProgress, {
      status: 'running',
      stage: 'generating_blocks',
      completed_blocks: completedBlocksCount,
      total_blocks: blockSpecs.length,
      current_block_ids: waveIndices.map((idx) => blockSpecs[idx].block_id),
    });

    const waveResults = await Promise.allSettled(
      waveIndices.map(async (bi) => {
        const spec = blockSpecs[bi];
        const blockPrompts = buildSingleBlockPrompts(context, spec, {
          blockIndex: bi,
          totalBlocks: blockSpecs.length,
        });
        const gen = await provider.generateStructured({
          promptBundle: blockPrompts,
          schema: OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA,
          model,
          timeoutMs: blockTimeoutMs,
          maxOutputTokens: blockMaxOutputTokens,
          temperature: 0.45,
          serverConfig,
          context,
          blockSpec: spec,
          blockIndex: bi,
        });
        return { bi, spec, gen };
      })
    );

    let firstWaveError = null;
    for (let wi = 0; wi < waveResults.length; wi++) {
      const outcome = waveResults[wi];
      if (outcome.status === 'fulfilled') {
        const { bi, spec, gen } = outcome.value;
        usageAcc.inputTokens += Number(gen.usage?.inputTokens || 0);
        usageAcc.outputTokens += Number(gen.usage?.outputTokens || 0);
        usageAcc.estimatedCostUsd = Number(
          (usageAcc.estimatedCostUsd + Number(gen.usage?.estimatedCostUsd || 0)).toFixed(6)
        );
        usageAcc.callsMade += 1;
        assembledBlocks[bi] = assembleBlockFromAiDraft(gen.rawPlan, spec, context, catalog);
        completedBlocksCount += 1;
      } else if (!firstWaveError) {
        firstWaveError = {
          err: outcome.reason,
          failedBlockId: blockSpecs[waveIndices[wi]].block_id,
        };
      }
    }

    if (firstWaveError) {
      const errObj = firstWaveError.err;
      const wrapped =
        errObj instanceof PlannerV2Error
          ? errObj
          : new PlannerV2Error('PROVIDER_REJECTED', errObj?.message || 'Error generando bloque.', {
              httpStatus: 502,
              retryable: true,
            });
      const partialBlocks = assembledBlocks.filter(Boolean);
      wrapped.details = {
        ...(wrapped.details || {}),
        repair_attempts_used: 0,
        failed_block_id: firstWaveError.failedBlockId,
        initial_summary:
          partialBlocks.length > 0
            ? summarizePlanStructureZeroPii(
                assembleFullPlanFromBlocks(partialBlocks, context),
                null
              )
            : null,
        partial_usage: {
          inputTokens: usageAcc.inputTokens,
          outputTokens: usageAcc.outputTokens,
          estimatedCostUsd: usageAcc.estimatedCostUsd,
          latencyMs: Date.now() - startedAtMs,
          callsMade: usageAcc.callsMade,
        },
      };
      throw wrapped;
    }
  }

  safeNotifyProgress(onProgress, {
    status: 'running',
    stage: 'validating',
    completed_blocks: blockSpecs.length,
    total_blocks: blockSpecs.length,
    current_block_ids: [],
  });

  const allDetFixes = [];
  let repairAttemptsUsed = 0;
  const repairedBlockIds = [];

  const initialAssembled = assembleFullPlanFromBlocks(assembledBlocks, context);
  const det1 = applySafeDeterministicRepairs(initialAssembled, context, catalog);
  let currentPlan = det1.plan;
  allDetFixes.push(...det1.fixesApplied);
  let evaluation = validateGeneratedPlan(currentPlan, context, catalog);
  const initialSummary = summarizePlanStructureZeroPii(currentPlan, evaluation);

  if (!evaluation.structuralValidation.passed) {
    if (maxRepairAttempts < 1) {
      throw new PlannerV2Error(
        'VALIDATION_FAILED_AFTER_REPAIR',
        'El plan modular generado falló la validación estructural.',
        {
          httpStatus: 422,
          details: {
            repair_attempts_used: 0,
            errors: evaluation.structuralValidation.errors,
            initial_summary: initialSummary,
            deterministic_fixes_applied: allDetFixes,
            partial_usage: {
              ...usageAcc,
              latencyMs: Date.now() - startedAtMs,
            },
          },
        }
      );
    }

    // Identify the exact failing block subset and repair them in 1 single bounded parallel pass
    const failingIndices = extractFailingBlockIndices(evaluation.structuralValidation.errors, currentPlan);
    let targetIndices = failingIndices.length > 0 ? [...failingIndices] : [];
    if (targetIndices.length === 0) {
      const resourceBlockIdx = blockSpecs.findIndex((b) =>
        (b.exercise_slots || []).some(
          (s) => (s.assigned_resource_ids?.length || 0) > 0 || (s.assigned_movement_ids?.length || 0) > 0
        )
      );
      targetIndices = [resourceBlockIdx >= 0 ? resourceBlockIdx : 0];
    }

    const targetBlockIds = targetIndices.map((idx) => blockSpecs[idx].block_id);
    repairAttemptsUsed = 1;
    repairedBlockIds.push(...targetBlockIds);

    safeNotifyProgress(onProgress, {
      status: 'running',
      stage: 'repairing_block',
      completed_blocks: blockSpecs.length,
      total_blocks: blockSpecs.length,
      current_block_ids: targetBlockIds,
    });

    for (let offset = 0; offset < targetIndices.length; offset += concurrency) {
      const repairWave = targetIndices.slice(offset, offset + concurrency);
      const waveOutcomes = await Promise.allSettled(
        repairWave.map(async (bi) => {
          const targetSpec = blockSpecs[bi];
          const targetBlockId = targetSpec.block_id;
          const relevantErrors = evaluation.structuralValidation.errors.filter((e) => {
            const m = String(e?.message || '');
            return m.includes(targetBlockId) || targetIndices.length <= 1;
          });
          const repairPrompts = buildSingleBlockPrompts(context, targetSpec, {
            blockIndex: bi,
            totalBlocks: blockSpecs.length,
            repairErrors:
              relevantErrors.length > 0 ? relevantErrors : evaluation.structuralValidation.errors,
            previousBlockDraft: currentPlan.bloques[bi] || assembledBlocks[bi],
          });
          const gen = await provider.generateStructured({
            promptBundle: repairPrompts,
            schema: OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA,
            model,
            timeoutMs: blockRepairTimeoutMs,
            maxOutputTokens: blockMaxOutputTokens,
            temperature: 0.2,
            serverConfig,
            context,
            blockSpec: targetSpec,
            blockIndex: bi,
            repairErrors: relevantErrors,
            previousDraft: currentPlan.bloques[bi],
          });
          return { bi, targetSpec, gen };
        })
      );

      let firstRepairError = null;
      for (let wi = 0; wi < waveOutcomes.length; wi++) {
        const outcome = waveOutcomes[wi];
        if (outcome.status === 'fulfilled') {
          const { bi, targetSpec, gen } = outcome.value;
          usageAcc.inputTokens += Number(gen.usage?.inputTokens || 0);
          usageAcc.outputTokens += Number(gen.usage?.outputTokens || 0);
          usageAcc.estimatedCostUsd = Number(
            (usageAcc.estimatedCostUsd + Number(gen.usage?.estimatedCostUsd || 0)).toFixed(6)
          );
          usageAcc.callsMade += 1;
          assembledBlocks[bi] = assembleBlockFromAiDraft(gen.rawPlan, targetSpec, context, catalog);
        } else if (!firstRepairError) {
          firstRepairError = {
            err: outcome.reason,
            failedBlockId: blockSpecs[repairWave[wi]].block_id,
          };
        }
      }

      if (firstRepairError) {
        const repairErr = firstRepairError.err;
        const wrapped =
          repairErr instanceof PlannerV2Error
            ? repairErr
            : new PlannerV2Error('PROVIDER_REJECTED', repairErr?.message || 'Error reparando bloque.', {
                httpStatus: 502,
                retryable: true,
              });
        wrapped.details = {
          ...(wrapped.details || {}),
          repair_attempts_used: repairAttemptsUsed,
          repaired_block_ids: repairedBlockIds,
          failed_block_id: firstRepairError.failedBlockId,
          initial_summary: initialSummary,
          deterministic_fixes_applied: allDetFixes,
          partial_usage: {
            ...usageAcc,
            latencyMs: Date.now() - startedAtMs,
          },
        };
        throw wrapped;
      }
    }

    const reassembled = assembleFullPlanFromBlocks(assembledBlocks, context);
    const det2 = applySafeDeterministicRepairs(reassembled, context, catalog);
    currentPlan = det2.plan;
    allDetFixes.push(...det2.fixesApplied);
    evaluation = validateGeneratedPlan(currentPlan, context, catalog);

    if (!evaluation.structuralValidation.passed) {
      const repairedSummary = summarizePlanStructureZeroPii(currentPlan, evaluation);
      throw new PlannerV2Error(
        'VALIDATION_FAILED_AFTER_REPAIR',
        'El bloque reparado no cumplió las reglas estructurales tras el intento permitido de reparación.',
        {
          httpStatus: 422,
          details: {
            repair_attempts_used: repairAttemptsUsed,
            repaired_block_ids: repairedBlockIds,
            errors: evaluation.structuralValidation.errors,
            initial_summary: initialSummary,
            repaired_summary: repairedSummary,
            deterministic_fixes_applied: allDetFixes,
            partial_usage: {
              ...usageAcc,
              latencyMs: Date.now() - startedAtMs,
            },
          },
        }
      );
    }
  }

  return {
    plan: currentPlan,
    evaluation,
    repairAttemptsUsed,
    repairedBlockIds,
    deterministicFixesApplied: allDetFixes,
    usageSummary: {
      inputTokens: usageAcc.inputTokens,
      outputTokens: usageAcc.outputTokens,
      estimatedCostUsd: usageAcc.estimatedCostUsd,
      latencyMs: Date.now() - startedAtMs,
      callsMade: usageAcc.callsMade,
    },
  };
}

module.exports = {
  applySafeDeterministicRepairs,
  validateAndRepairPlan,
  generateAndValidateModularPlan,
};

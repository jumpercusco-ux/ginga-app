'use strict';

const { COPILOT_OPERATION_TYPES } = require('./copilot_schema');
const { distributeExactMinutes } = require('./temporal_planner');
const { syncInternalTimingsIntoDetalle } = require('./response_schema');
const { computeExpectedAuthoringAndOrigins } = require('./plan_validator');
const { PlannerV2Error } = require('./errors');

function clonePlan(plan) {
  return JSON.parse(JSON.stringify(plan));
}

function nextUniqueId(prefix, existingSet) {
  let i = existingSet.size + 1;
  let candidate = `${prefix}_${i}`;
  while (existingSet.has(candidate)) {
    i += 1;
    candidate = `${prefix}_${i}`;
  }
  existingSet.add(candidate);
  return candidate;
}

function scaleInternalTimingsForDuration(existingTimings, targetDur) {
  const safeDur = Math.max(1, Number(targetDur || 1));
  const valid = (Array.isArray(existingTimings) ? existingTimings : []).filter(
    (t) => String(t?.etapa || '').trim().length > 0 && Number(t?.minutos || 0) >= 1
  );

  if (safeDur < 4) {
    const label = valid[0]?.etapa || 'Ejecución continua';
    return [{ etapa: label, minutos: safeDur }];
  }

  if (valid.length >= 2) {
    const scaled = distributeExactMinutes(
      safeDur,
      valid.map((v) => Math.max(1, Number(v.minutos || 1)))
    );
    return valid.map((v, idx) => ({
      etapa: String(v.etapa).trim(),
      minutos: scaled[idx],
    }));
  }

  const prepMin = Math.min(2, Math.max(1, Math.floor(safeDur / 3)));
  const execMin = Math.max(1, safeDur - prepMin);
  return [
    { etapa: valid[0]?.etapa ? `${valid[0].etapa} (inicio y señales)` : 'Preparación y señales', minutos: prepMin },
    { etapa: 'Ejecución guiada y ajuste', minutos: execMin },
  ];
}

function applyExercisePatchFields(targetEx, op, context, catalog) {
  const stringFields = [
    'nombre',
    'tipo_actividad',
    'detalle',
    'organizacion',
    'seguridad',
    'diferenciacion_principiantes',
    'diferenciacion_intermedios',
    'diferenciacion_avanzados',
    'sugerencias_ia',
  ];
  for (const f of stringFields) {
    if (typeof op[f] === 'string' && op[f] !== null) {
      targetEx[f] = op[f].trim();
    }
  }
  if (Number.isInteger(op.duracion_min) && op.duracion_min >= 1) {
    targetEx.duracion_min = op.duracion_min;
  }
  if (Array.isArray(op.materiales)) {
    targetEx.materiales = op.materiales.map((m) => String(m || '').trim()).filter(Boolean);
  }
  if (Array.isArray(op.technical_movement_refs)) {
    targetEx.technical_movement_refs = [
      ...new Set(op.technical_movement_refs.map((m) => String(m || '').trim()).filter(Boolean)),
    ];
  }
  if (Array.isArray(op.curriculum_movement_ids)) {
    if (context.audienceType !== 'adultos' || context.curriculumScope !== 'adulto_fiu') {
      if (op.curriculum_movement_ids.length > 0) {
        throw new PlannerV2Error(
          'FORBIDDEN_FIU_IN_NON_ADULT_SCOPE',
          'No se permite asignar movimientos del currículo adulto FIU a grupos infantiles o mixtos.',
          { httpStatus: 400 }
        );
      }
      targetEx.curriculum_movement_ids = [];
    } else {
      targetEx.curriculum_movement_ids = [
        ...new Set(op.curriculum_movement_ids.map((m) => String(m || '').trim()).filter(Boolean)),
      ];
    }
  }
  if (Array.isArray(op.tiempos_internos) && op.tiempos_internos.length > 0) {
    targetEx.tiempos_internos = op.tiempos_internos.map((t) => ({
      etapa: String(t?.etapa || '').trim(),
      minutos: Number(t?.minutos || 1),
    }));
    syncInternalTimingsIntoDetalle(targetEx);
  }
  const meta = computeExpectedAuthoringAndOrigins(targetEx, catalog);
  targetEx.content_origin = meta.content_origin;
  targetEx.source_origins = meta.source_origins;
  targetEx.activity_authoring = meta.activity_authoring;
}

function findBlockOrThrow(plan, blockId, opType) {
  const blk = (plan.bloques || []).find((b) => b.block_id === blockId);
  if (!blk) {
    throw new PlannerV2Error(
      'INVALID_COPILOT_OPERATION',
      `Operación '${opType}' refiere a block_id inexistente '${blockId}'.`,
      { httpStatus: 400 }
    );
  }
  return blk;
}

function findExerciseOrThrow(blk, exerciseId, opType) {
  const ex = (blk.ejercicios || []).find((e) => e.exercise_id === exerciseId);
  if (!ex) {
    throw new PlannerV2Error(
      'INVALID_COPILOT_OPERATION',
      `Operación '${opType}' refiere a exercise_id inexistente '${exerciseId}' en bloque '${blk.block_id}'.`,
      { httpStatus: 400 }
    );
  }
  return ex;
}

/**
 * Applies a limited, strictly typed array of copilot operations deterministically
 * over a deep-cloned plan without touching unaffected IDs, origins, resources, or siblings.
 */
function applyCopilotOperationsToPlan(basePlan, operations, { context, catalog, resourceMap = new Map() }) {
  if (!basePlan || typeof basePlan !== 'object' || !Array.isArray(basePlan.bloques)) {
    throw new PlannerV2Error('INVALID_REQUEST', 'El plan base es inválido.', { httpStatus: 400 });
  }
  if (!Array.isArray(operations)) {
    throw new PlannerV2Error('INVALID_COPILOT_OPERATION', 'El arreglo de operaciones debe ser una lista.', {
      httpStatus: 400,
    });
  }

  const nextPlan = clonePlan(basePlan);
  const blockIds = new Set(nextPlan.bloques.map((b) => b.block_id));
  const exerciseIds = new Set(nextPlan.bloques.flatMap((b) => (b.ejercicios || []).map((e) => e.exercise_id)));

  for (const op of operations) {
    if (!op || typeof op !== 'object' || !COPILOT_OPERATION_TYPES.includes(op.type)) {
      throw new PlannerV2Error(
        'INVALID_COPILOT_OPERATION',
        `Operación de copiloto no permitida: '${op?.type || 'desconocida'}'.`,
        { httpStatus: 400 }
      );
    }

    switch (op.type) {
      case 'update_exercise': {
        const blk = findBlockOrThrow(nextPlan, op.block_id, op.type);
        const ex = findExerciseOrThrow(blk, op.exercise_id, op.type);
        applyExercisePatchFields(ex, op, context, catalog);
        break;
      }

      case 'replace_exercise': {
        const blk = findBlockOrThrow(nextPlan, op.block_id, op.type);
        const ex = findExerciseOrThrow(blk, op.exercise_id, op.type);
        const preservedId = ex.exercise_id;
        const preservedDur = Number.isInteger(op.duracion_min) && op.duracion_min >= 1 ? op.duracion_min : ex.duracion_min;
        // Reset semantic fields cleanly for the replacement while keeping ID and slot duration
        ex.curriculum_movement_ids = [];
        ex.linked_resource_ids = [];
        ex.resource_usage_notes = {};
        ex.video_reference_note = null;
        ex.observaciones_profesor = '';
        ex.duracion_min = preservedDur;
        ex.exercise_id = preservedId;
        applyExercisePatchFields(ex, op, context, catalog);
        break;
      }

      case 'add_exercise': {
        const blk = findBlockOrThrow(nextPlan, op.block_id, op.type);
        const newId =
          typeof op.exercise_id === 'string' && op.exercise_id.trim() && !exerciseIds.has(op.exercise_id.trim())
            ? op.exercise_id.trim()
            : nextUniqueId(`${blk.block_id}_ex`, exerciseIds);
        exerciseIds.add(newId);
        const newDur = Math.max(1, Number(op.duracion_min || 5));
        const newEx = {
          exercise_id: newId,
          nombre: String(op.nombre || 'Actividad complementaria').trim(),
          tipo_actividad: String(op.tipo_actividad || 'ejercicio_tecnico').trim(),
          detalle: String(op.detalle || 'Preparación y práctica guiada.').trim(),
          duracion_min: newDur,
          organizacion: String(op.organizacion || 'Todos simultáneamente').trim(),
          supervision_instructors_needed: 1,
          materiales: Array.isArray(op.materiales) ? op.materiales : [],
          seguridad: String(op.seguridad || 'Supervisión directa del instructor.').trim(),
          diferenciacion_principiantes: String(op.diferenciacion_principiantes || '').trim(),
          diferenciacion_intermedios: String(op.diferenciacion_intermedios || '').trim(),
          diferenciacion_avanzados: String(op.diferenciacion_avanzados || '').trim(),
          sugerencias_ia: String(op.sugerencias_ia || '').trim(),
          observaciones_profesor: '',
          technical_movement_refs: Array.isArray(op.technical_movement_refs) ? op.technical_movement_refs : [],
          curriculum_movement_ids: [],
          linked_resource_ids: [],
          resource_usage_notes: {},
          tiempos_internos:
            Array.isArray(op.tiempos_internos) && op.tiempos_internos.length > 0
              ? op.tiempos_internos
              : scaleInternalTimingsForDuration([], newDur),
          cancionero_reference: null,
          video_reference_note: null,
        };
        applyExercisePatchFields(newEx, op, context, catalog);
        blk.ejercicios.push(newEx);
        blk.duracion_min = blk.ejercicios.reduce((acc, item) => acc + Number(item.duracion_min || 0), 0);
        nextPlan.duracion_total = nextPlan.bloques.reduce((acc, b) => acc + Number(b.duracion_min || 0), 0);
        break;
      }

      case 'remove_exercise': {
        const blk = findBlockOrThrow(nextPlan, op.block_id, op.type);
        findExerciseOrThrow(blk, op.exercise_id, op.type);
        blk.ejercicios = blk.ejercicios.filter((e) => e.exercise_id !== op.exercise_id);
        break;
      }

      case 'update_block': {
        const blk = findBlockOrThrow(nextPlan, op.block_id, op.type);
        if (typeof op.fase === 'string' && op.fase.trim()) blk.fase = op.fase.trim();
        if (typeof op.fase_tipo === 'string' && op.fase_tipo.trim()) blk.fase_tipo = op.fase_tipo.trim();
        if (Number.isInteger(op.duracion_min) && op.duracion_min >= 2) blk.duracion_min = op.duracion_min;
        break;
      }

      case 'add_block': {
        const newBlockId =
          typeof op.block_id === 'string' && op.block_id.trim() && !blockIds.has(op.block_id.trim())
            ? op.block_id.trim()
            : nextUniqueId('blk', blockIds);
        blockIds.add(newBlockId);
        nextPlan.bloques.push({
          block_id: newBlockId,
          fase: String(op.fase || 'Nuevo bloque').trim(),
          fase_tipo: String(op.fase_tipo || 'tecnica').trim(),
          duracion_min: Math.max(2, Number(op.duracion_min || 10)),
          ejercicios: [],
        });
        break;
      }

      case 'remove_block': {
        findBlockOrThrow(nextPlan, op.block_id, op.type);
        nextPlan.bloques = nextPlan.bloques.filter((b) => b.block_id !== op.block_id);
        break;
      }

      case 'redistribute_duration': {
        const targetTotal = Math.max(20, Math.min(180, Number(op.target_duration_min || op.duracion_min || 45)));
        if (nextPlan.bloques.length === 0) break;
        const blockWeights = nextPlan.bloques.map((b) => Math.max(2, Number(b.duracion_min || 10)));
        const newBlockDurs = distributeExactMinutes(targetTotal, blockWeights);
        nextPlan.duracion_total = targetTotal;
        for (let bi = 0; bi < nextPlan.bloques.length; bi++) {
          const blk = nextPlan.bloques[bi];
          const bDur = newBlockDurs[bi];
          blk.duracion_min = bDur;
          const exs = Array.isArray(blk.ejercicios) ? blk.ejercicios : [];
          if (exs.length === 0) continue;
          const exWeights = exs.map((e) => Math.max(1, Number(e.duracion_min || 1)));
          const newExDurs = distributeExactMinutes(bDur, exWeights);
          for (let ei = 0; ei < exs.length; ei++) {
            const ex = exs[ei];
            const nextExDur = newExDurs[ei];
            ex.duracion_min = nextExDur;
            ex.tiempos_internos = scaleInternalTimingsForDuration(ex.tiempos_internos, nextExDur);
            syncInternalTimingsIntoDetalle(ex);
          }
        }
        break;
      }

      case 'link_resource': {
        const blk = findBlockOrThrow(nextPlan, op.block_id, op.type);
        const ex = findExerciseOrThrow(blk, op.exercise_id, op.type);
        const resId = String(op.resource_id || '').trim();
        const resMeta = resourceMap.get(resId);
        if (!resId || !resMeta) {
          throw new PlannerV2Error(
            'INVALID_RESOURCE_LINK',
            `El recurso '${resId}' no existe o no pertenece al profesor autorizado.`,
            { httpStatus: 400 }
          );
        }
        const existingResIds = Array.isArray(ex.linked_resource_ids) ? [...ex.linked_resource_ids] : [];
        if (!existingResIds.includes(resId)) {
          existingResIds.push(resId);
        }
        ex.linked_resource_ids = existingResIds;
        ex.resource_usage_notes = {
          ...(ex.resource_usage_notes || {}),
          [resId]:
            String(op.resource_usage_note || '').trim() ||
            resMeta.usage_note ||
            resMeta.notes ||
            `Integrar recurso '${resMeta.title}' en la dinámica.`,
        };
        if (typeof op.nombre === 'string' && op.nombre.trim()) ex.nombre = op.nombre.trim();
        if (typeof op.detalle === 'string' && op.detalle.trim()) ex.detalle = op.detalle.trim();
        const hasVideoUrl =
          resMeta.hasExternalVideo === true ||
          resMeta.has_external_video === true ||
          /^https?:\/\//i.test(String(resMeta.url || '').trim());
        if (hasVideoUrl) {
          ex.video_reference_note =
            'Recurso con video externo: integrado únicamente según título y notas escritas del profesor (el motor no inspecciona visualmente el video).';
        }
        const meta = computeExpectedAuthoringAndOrigins(ex, catalog);
        ex.content_origin = meta.content_origin;
        ex.source_origins = meta.source_origins;
        ex.activity_authoring = meta.activity_authoring;
        break;
      }

      case 'update_internal_timings': {
        const blk = findBlockOrThrow(nextPlan, op.block_id, op.type);
        const ex = findExerciseOrThrow(blk, op.exercise_id, op.type);
        if (!Array.isArray(op.tiempos_internos) || op.tiempos_internos.length === 0) {
          throw new PlannerV2Error(
            'INVALID_COPILOT_OPERATION',
            `Operación 'update_internal_timings' requiere tiempos_internos no vacío.`,
            { httpStatus: 400 }
          );
        }
        ex.tiempos_internos = op.tiempos_internos.map((t) => ({
          etapa: String(t?.etapa || '').trim(),
          minutos: Number(t?.minutos || 1),
        }));
        syncInternalTimingsIntoDetalle(ex);
        break;
      }

      default:
        break;
    }
  }

  return nextPlan;
}

function buildCopilotDiffSummary(beforePlan, afterPlan, operations) {
  if (!afterPlan) return [];
  const diffs = [];
  const beforeBlocksById = new Map((beforePlan?.bloques || []).map((b) => [b.block_id, b]));
  const afterBlocksById = new Map((afterPlan?.bloques || []).map((b) => [b.block_id, b]));

  for (const op of operations || []) {
    if (op.type === 'redistribute_duration') {
      diffs.push({
        operation_type: op.type,
        scope_label: 'Toda la clase',
        field_label: 'Duración total y distribución',
        before: `${beforePlan.duracion_total} min (${(beforePlan.bloques || []).map((b) => `${b.duracion_min}m`).join('+')})`,
        after: `${afterPlan.duracion_total} min (${(afterPlan.bloques || []).map((b) => `${b.duracion_min}m`).join('+')})`,
      });
      continue;
    }

    const bBefore = beforeBlocksById.get(op.block_id);
    const bAfter = afterBlocksById.get(op.block_id);
    const exBefore = (bBefore?.ejercicios || []).find((e) => e.exercise_id === op.exercise_id);
    const exAfter = (bAfter?.ejercicios || []).find((e) => e.exercise_id === op.exercise_id);
    const scopeLabel = exAfter?.nombre || exBefore?.nombre || bAfter?.fase || bBefore?.fase || op.block_id || 'Clase';

    if (op.type === 'replace_exercise' && exBefore && exAfter) {
      diffs.push({
        operation_type: op.type,
        scope_label: `${bAfter?.fase || 'Bloque'} · ${op.exercise_id}`,
        field_label: 'Sustitución de ejercicio',
        before: `${exBefore.nombre} (${exBefore.duracion_min} min)`,
        after: `${exAfter.nombre} (${exAfter.duracion_min} min)`,
      });
    } else if (op.type === 'link_resource' && exAfter) {
      diffs.push({
        operation_type: op.type,
        scope_label: scopeLabel,
        field_label: 'Recurso de Pizarra vinculado',
        before: (exBefore?.linked_resource_ids || []).length > 0 ? exBefore.linked_resource_ids.join(', ') : 'Sin recurso vinculado',
        after: (exAfter.linked_resource_ids || []).join(', '),
      });
    } else if (exBefore && exAfter) {
      const beforeStages = (exBefore.tiempos_internos || []).map((t) => `${t.etapa} ${t.minutos}m`).join(' · ');
      const afterStages = (exAfter.tiempos_internos || []).map((t) => `${t.etapa} ${t.minutos}m`).join(' · ');
      const changedLevels =
        exBefore.diferenciacion_principiantes !== exAfter.diferenciacion_principiantes ||
        exBefore.diferenciacion_avanzados !== exAfter.diferenciacion_avanzados;
      diffs.push({
        operation_type: op.type,
        scope_label: scopeLabel,
        field_label: changedLevels ? 'Progresión diferenciada por niveles' : 'Ajuste de ejercicio / tiempos',
        before: changedLevels
          ? `Init: ${exBefore.diferenciacion_principiantes || '-'} | Av: ${exBefore.diferenciacion_avanzados || '-'}`
          : beforeStages || exBefore.organizacion,
        after: changedLevels
          ? `Init: ${exAfter.diferenciacion_principiantes || '-'} | Av: ${exAfter.diferenciacion_avanzados || '-'}`
          : afterStages || exAfter.organizacion,
      });
    } else {
      diffs.push({
        operation_type: op.type,
        scope_label: scopeLabel,
        field_label: op.type,
        before: bBefore ? `${bBefore.fase} (${bBefore.duracion_min} min)` : 'No existía',
        after: bAfter ? `${bAfter.fase} (${bAfter.duracion_min} min)` : 'Eliminado',
      });
    }
  }

  return diffs;
}

module.exports = {
  applyCopilotOperationsToPlan,
  buildCopilotDiffSummary,
  scaleInternalTimingsForDuration,
};

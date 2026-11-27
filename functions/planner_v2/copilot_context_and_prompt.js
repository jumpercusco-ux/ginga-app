'use strict';

const { PlannerV2Error } = require('./errors');
const { OPENAI_STRICT_COPILOT_V1_JSON_SCHEMA, computeDraftVersionHash } = require('./copilot_schema');
const { sanitizeFreeTextServer, detectPromptInjection } = require('./pii_and_injection_guard');
const { estimateTokensFromText } = require('./config');
const { extractRequestedTechnicalMovements, detectSimultaneousParticipationRequested } = require('./context_builder');
const { computeExpectedAuthoringAndOrigins } = require('./plan_validator');

function inferTipoActividadFromFaseTipo(faseTipo, nombre = '', cancionero = null) {
  if (cancionero) return 'musicalidad_roda';
  const ft = String(faseTipo || '').trim().toLowerCase();
  const n = String(nombre || '').toLowerCase();
  if (ft === 'calentamiento') return 'calentamiento';
  if (ft === 'juegos' || /juego/.test(n)) return 'juego_dinamico';
  if (ft === 'acrobacias_suelo') return 'progresion_suelo';
  if (ft === 'roda_musicalidad' || ft === 'musicalidad') return 'musicalidad_roda';
  return 'ejercicio_tecnico';
}

function normalizeIncomingPlanForCopilot(rawPlan, catalog) {
  const plan = JSON.parse(JSON.stringify(rawPlan));
  plan.bloques = (Array.isArray(plan.bloques) ? plan.bloques : []).map((b, bi) => {
    const blk = { ...b };
    if (!blk.block_id) blk.block_id = `blk_${bi + 1}`;
    blk.ejercicios = (Array.isArray(blk.ejercicios) ? blk.ejercicios : []).map((e, ei) => {
      const ex = { ...e };
      if (!ex.exercise_id) ex.exercise_id = `${blk.block_id}_ex_${ei + 1}`;
      ex.materiales = Array.isArray(ex.materiales) ? ex.materiales : [];
      ex.technical_movement_refs = Array.isArray(ex.technical_movement_refs) ? ex.technical_movement_refs : [];
      ex.curriculum_movement_ids = Array.isArray(ex.curriculum_movement_ids) ? ex.curriculum_movement_ids : [];
      ex.linked_resource_ids = Array.isArray(ex.linked_resource_ids) ? ex.linked_resource_ids : [];
      ex.resource_usage_notes =
        ex.resource_usage_notes && typeof ex.resource_usage_notes === 'object' ? ex.resource_usage_notes : {};
      ex.tiempos_internos = Array.isArray(ex.tiempos_internos) ? ex.tiempos_internos : [];
      if (!ex.tipo_actividad) {
        ex.tipo_actividad = inferTipoActividadFromFaseTipo(blk.fase_tipo, ex.nombre, ex.cancionero_reference);
      }
      if (!ex.content_origin || !ex.activity_authoring || !Array.isArray(ex.source_origins) || ex.source_origins.length === 0) {
        const expected = computeExpectedAuthoringAndOrigins(ex, catalog);
        ex.content_origin = ex.content_origin || expected.content_origin;
        ex.activity_authoring = ex.activity_authoring || expected.activity_authoring;
        ex.source_origins =
          Array.isArray(ex.source_origins) && ex.source_origins.length > 0 ? ex.source_origins : expected.source_origins;
      }
      return ex;
    });
    return blk;
  });
  return plan;
}

function normalizeMaterialKey(val) {
  return String(val || '')
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function summarizeOpenPlanForCopilotLlm(plan) {
  const bloques = Array.isArray(plan?.bloques) ? plan.bloques : [];
  return {
    titulo: plan?.titulo || '',
    duracion_total: Number(plan?.duracion_total || 60),
    audience_type: plan?.audience_type || 'adultos',
    curriculum_scope: plan?.curriculum_scope || 'none_manual',
    enfoque: plan?.enfoque || '',
    objetivos: Array.isArray(plan?.objetivos) ? plan.objetivos : [],
    bloques: bloques.map((b) => ({
      block_id: b.block_id,
      fase: b.fase,
      fase_tipo: b.fase_tipo,
      duracion_min: b.duracion_min,
      ejercicios: (b.ejercicios || []).map((e) => ({
        exercise_id: e.exercise_id,
        nombre: e.nombre,
        tipo_actividad: e.tipo_actividad,
        duracion_min: e.duracion_min,
        organizacion: e.organizacion,
        technical_movement_refs: e.technical_movement_refs || [],
        curriculum_movement_ids: e.curriculum_movement_ids || [],
        linked_resource_ids: e.linked_resource_ids || [],
        tiempos_internos: e.tiempos_internos || [],
      })),
    })),
  };
}

function findSelectedBlockAndExercise(plan, selectedBlockId, selectedExerciseId) {
  const bloques = Array.isArray(plan?.bloques) ? plan.bloques : [];
  let selectedBlock = selectedBlockId ? bloques.find((b) => b.block_id === selectedBlockId) || null : null;
  let selectedExercise = null;
  if (selectedBlock && selectedExerciseId) {
    selectedExercise = (selectedBlock.ejercicios || []).find((e) => e.exercise_id === selectedExerciseId) || null;
  } else if (selectedExerciseId) {
    for (const b of bloques) {
      const hit = (b.ejercicios || []).find((e) => e.exercise_id === selectedExerciseId);
      if (hit) {
        selectedBlock = b;
        selectedExercise = hit;
        break;
      }
    }
  }
  return { selectedBlock, selectedExercise };
}

function buildPertinentCurriculumSlice(catalog, audienceType, curriculumScope, messageText, plan) {
  if (audienceType !== 'adultos' || curriculumScope !== 'adulto_fiu') {
    return [];
  }
  const msgLower = normalizeMaterialKey(messageText);
  const usedIds = new Set(
    (plan?.bloques || []).flatMap((b) => (b.ejercicios || []).flatMap((e) => e.curriculum_movement_ids || []))
  );
  const eligible = (catalog?.eligibleMovements || []).filter((m) => m.ai_planner_eligible === true);
  const matched = eligible.filter(
    (m) => usedIds.has(m.movement_id) || msgLower.includes(normalizeMaterialKey(m.canonical_name))
  );
  const fallbackList = matched.length > 0 ? matched : eligible;
  return fallbackList.slice(0, 12).map((m) => ({
    movement_id: m.movement_id,
    canonical_name: m.canonical_name,
    category_id: m.category_id,
    entry_kind: m.entry_kind,
  }));
}

async function buildCopilotContext({ request, actor, catalog, resourceRepository }) {
  if (!request || typeof request !== 'object') {
    throw new PlannerV2Error('INVALID_REQUEST', 'Solicitud de copiloto inválida.', { httpStatus: 400 });
  }
  const rawPlan = request.plan;
  if (!rawPlan || typeof rawPlan !== 'object' || !Array.isArray(rawPlan.bloques)) {
    throw new PlannerV2Error('INVALID_REQUEST', 'Debe enviarse el plan abierto válido en `plan`.', {
      httpStatus: 400,
    });
  }
  const rawMessage = String(request.message || '').trim();
  if (!rawMessage) {
    throw new PlannerV2Error('INVALID_REQUEST', 'El mensaje al copiloto no puede estar vacío.', {
      httpStatus: 400,
    });
  }

  const requestId = String(request.request_id || `req_copilot_${Date.now()}`).trim();
  const baseDraftVersion = request.base_draft_version ? String(request.base_draft_version).trim() : null;
  const computedDraftVersion = computeDraftVersionHash(rawPlan);
  const plan = normalizeIncomingPlanForCopilot(rawPlan, catalog);

  // Sanitize user message & detect injection/bypass attempts
  const msgSan = sanitizeFreeTextServer(rawMessage);
  const msgInj = detectPromptInjection(rawMessage);

  // Resolve available Pizarra resources (selected in plan + available preview/repo ids)
  const planResourceIds = new Set(
    (plan.bloques || []).flatMap((b) => (b.ejercicios || []).flatMap((e) => e.linked_resource_ids || []))
  );
  const reqAvailIds = Array.isArray(request.available_resource_ids)
    ? request.available_resource_ids.map((id) => String(id || '').trim()).filter(Boolean)
    : [];
  const allLookupIds = [...new Set([...planResourceIds, ...reqAvailIds])];
  const repoMap =
    allLookupIds.length > 0 && resourceRepository?.getResourcesByIds
      ? await resourceRepository.getResourcesByIds(allLookupIds, actor)
      : new Map();

  // Merge inline resource metadata if provided for preview/tests (without raw external URLs sent to LLM)
  const resourceMap = new Map(repoMap);
  if (Array.isArray(request.available_resources)) {
    for (const r of request.available_resources) {
      const id = String(r?.resource_id || '').trim();
      if (!id || resourceMap.has(id)) continue;
      if (r.ownerId && actor.actorMode !== 'local_dev_simulated_unauthenticated' && r.ownerId !== actor.actorId && r.shared !== true) {
        continue;
      }
      resourceMap.set(id, {
        resourceId: id,
        resource_id: id,
        title: String(r.title || 'Recurso de Pizarra'),
        type: String(r.type || 'nota'),
        category: String(r.category || 'General'),
        notes: String(r.notes || ''),
        usage_note: String(r.usage_note || ''),
        has_external_video: r.has_external_video === true,
        hasExternalVideo: r.has_external_video === true,
      });
    }
  }

  const audienceType = String(plan.audience_type || 'adultos');
  let curriculumScope = String(plan.curriculum_scope || 'infantil_fiu_pending');
  if (audienceType !== 'adultos' && curriculumScope === 'adulto_fiu') {
    curriculumScope = audienceType === 'infantil' ? 'infantil_fiu_pending' : 'mixed_no_official_track';
  }

  const spaceSnapshot = plan.space_snapshot || {};
  const groupSnapshot = plan.group_snapshot || {};
  const rawMaterialsKnown = request.materials_known === true || Array.isArray(request.confirmed_materials);
  const confirmedMaterials = Array.isArray(request.confirmed_materials)
    ? request.confirmed_materials.map((m) => String(m || '').trim()).filter(Boolean)
    : [];

  const objectives = Array.isArray(plan.objetivos) ? plan.objetivos : plan.objetivo ? [String(plan.objetivo)] : [];
  const focuses = String(plan.enfoque || '')
    .split(/[·,]/)
    .map((s) => s.trim())
    .filter(Boolean);

  const requestedMovs = extractRequestedTechnicalMovements(objectives, plan.consejos_instructor || '');
  const simultaneousReq =
    detectSimultaneousParticipationRequested(audienceType, objectives, `${plan.consejos_instructor || ''} ${rawMessage}`);

  const selectedResourcesList = [];
  for (const rId of planResourceIds) {
    const r = resourceMap.get(rId);
    if (r) {
      const hasExtVid =
        Boolean(r.hasExternalVideo || r.has_external_video) ||
        /^https?:\/\//i.test(String(r.url || '').trim());
      selectedResourcesList.push({
        resource_id: rId,
        title: r.title,
        category: r.category || 'General',
        notes: sanitizeFreeTextServer(r.notes || '').text,
        has_external_video: hasExtVid,
        priority: 'required',
      });
    }
  }

  const availableResourcesCompact = [...resourceMap.entries()].slice(0, 8).map(([id, r]) => ({
    resource_id: id,
    title: r.title,
    type: r.type || 'nota',
    category: r.category || 'General',
    notes: sanitizeFreeTextServer(r.notes || '').text,
    has_external_video:
      Boolean(r.hasExternalVideo || r.has_external_video) ||
      /^https?:\/\//i.test(String(r.url || '').trim()),
  }));

  const { selectedBlock, selectedExercise } = findSelectedBlockAndExercise(
    plan,
    request.selected_block_id || null,
    request.selected_exercise_id || null
  );

  const history = Array.isArray(request.conversation_history)
    ? request.conversation_history.slice(-6).map((turn) => ({
        role: turn?.role === 'assistant' ? 'assistant' : 'user',
        text: sanitizeFreeTextServer(String(turn?.text || '').slice(0, 400)).text,
      }))
    : [];

  const curriculumSlice = buildPertinentCurriculumSlice(catalog, audienceType, curriculumScope, rawMessage, plan);
  const rawContinuity =
    request.continuity_context && typeof request.continuity_context === 'object'
      ? request.continuity_context
      : null;
  const sanitizedContinuity = rawContinuity
    ? {
        group_label: sanitizeFreeTextServer(String(rawContinuity.group_label || groupSnapshot.group_name || 'Grupo')).text,
        audience_type: String(rawContinuity.audience_type || audienceType),
        worked_movements: Array.isArray(rawContinuity.worked_movements)
          ? rawContinuity.worked_movements
              .slice(0, 12)
              .map((m) => sanitizeFreeTextServer(String(m || '')).text)
              .filter(Boolean)
          : [],
        reinforce_content: rawContinuity.reinforce_content
          ? sanitizeFreeTextServer(String(rawContinuity.reinforce_content)).text
          : '',
        continuity_proposal: rawContinuity.continuity_proposal
          ? sanitizeFreeTextServer(String(rawContinuity.continuity_proposal)).text
          : '',
        difficulties: rawContinuity.difficulties
          ? sanitizeFreeTextServer(String(rawContinuity.difficulties)).text
          : '',
        teacher_observations: rawContinuity.teacher_observations
          ? sanitizeFreeTextServer(String(rawContinuity.teacher_observations)).text
          : '',
      }
    : null;

  const llmContext = {
    message: msgInj.neutralizedText ? sanitizeFreeTextServer(msgInj.neutralizedText).text : msgSan.text,
    history,
    selected_block_id: selectedBlock?.block_id || null,
    selected_exercise_id: selectedExercise?.exercise_id || null,
    selected_exercise_detail: selectedExercise || null,
    open_plan_summary: summarizeOpenPlanForCopilotLlm(plan),
    group_conditions: {
      audience_type: audienceType,
      curriculum_scope: curriculumScope,
      age_min: groupSnapshot.age_min ?? null,
      age_max: groupSnapshot.age_max ?? null,
      participants: Number(groupSnapshot.participants || 10),
      experience_distribution: groupSnapshot.experience_distribution || {
        principiantes: 4,
        intermedios: 4,
        avanzados: 2,
      },
    },
    ...(sanitizedContinuity ? { group_continuity: sanitizedContinuity } : {}),
    space_and_materials: {
      space_size: spaceSnapshot.space_size || 'desconocido',
      floor_type: spaceSnapshot.floor_type || 'desconocido',
      available_mats: spaceSnapshot.available_mats ?? null,
      instructors_available: Number(spaceSnapshot.instructors_available || 1),
      materials_known: rawMaterialsKnown,
      confirmed_materials: confirmedMaterials,
    },
    available_pizarra_resources: availableResourcesCompact,
    pertinent_fiu_movements: curriculumSlice,
  };

  // Validation context compatible with functions/planner_v2/plan_validator.js
  const expRaw = groupSnapshot.experience_distribution || {};
  const validationContext = {
    requestId,
    audienceType,
    curriculumScope,
    durationMin: Number(plan.duracion_total || 60),
    focuses,
    objectives,
    freeInstructions: '',
    instructorsAvailable: Number(spaceSnapshot.instructors_available || 1),
    participants: Number(groupSnapshot.participants || 10),
    expDist: {
      principiantes: Number(expRaw.principiantes ?? 4),
      intermedios: Number(expRaw.intermedios ?? 4),
      avanzados: Number(expRaw.avanzados ?? 2),
    },
    space: {
      spaceSize: spaceSnapshot.space_size || 'desconocido',
      floorType: spaceSnapshot.floor_type || 'desconocido',
      availableMats: spaceSnapshot.available_mats ?? null,
    },
    materialsKnown: rawMaterialsKnown,
    materials: confirmedMaterials,
    selectedMovements: [],
    selectedResources: selectedResourcesList,
    requestedTechnicalMovements: requestedMovs,
    simultaneousParticipationRequested: simultaneousReq,
    allowAiComplementaryProposals: true,
    includeMusicalityRoda: (plan.bloques || []).some((b) => /musicalidad|roda/i.test(`${b.fase} ${b.fase_tipo}`)),
  };

  return {
    requestId,
    actor,
    rawMessage,
    sanitizedMessage: msgSan.text,
    injectionSignals: msgInj.signals,
    piiRedactionsCount: msgSan.redactionsCount,
    baseDraftVersion,
    computedDraftVersion,
    plan,
    selectedBlock,
    selectedExercise,
    resourceMap,
    availableResourcesCompact,
    curriculumSlice,
    llmContext,
    validationContext,
  };
}

function buildCopilotPrompts(copilotContext) {
  const ctx = copilotContext.llmContext;
  const isInfantil = ctx.group_conditions.audience_type === 'infantil';
  const systemLines = [
    'Eres el Copiloto Pedagógico de CAPOEIRA GINGA (FIU Cusco) integrado en el editor.',
    '- Responde SIEMPRE en JSON estricto según el esquema asignado. Deja en `null` todo campo opcional de una operación que NO deba cambiar.',
    '- Si el profesor hace una consulta informativa (explicar técnica, errores frecuentes, progresiones, biblioteca o recursos), responde con mode="consult", conflict_reason=null, safe_alternative=null y operations=[].',
    '- Si pide modificar la clase, responde con mode="propose_changes" y las operaciones tipadas MÍNIMAS (update_exercise, replace_exercise, add_exercise, remove_exercise, update_block, add_block, remove_block, redistribute_duration, link_resource, update_internal_timings). NUNCA alteres ni sustituyas ejercicios con linked_resource_ids existentes salvo petición explícita.',
    '- Valores permitidos en `organizacion`: "Todos simultáneamente", "Rotación por parejas", "Estaciones simultáneas", "Turnos", "Organización personalizada". En clases con participación simultánea o sin filas, PROHIBIDO usar "Turnos", filas o eliminaciones.',
    '- En sustituciones o actualizaciones de juegos (`tipo_actividad="juego_dinamico"`), `detalle` debe superar 80 caracteres e incluir explícitamente: (1) preparación/disposición espacial, (2) reglas y señales claras de cambio, y (3) rondas/rotación continua; además incluye `tiempos_internos` con >= 2 etapas cuya suma iguale `duracion_min`.',
    '- Al incorporar un recurso de `available_pizarra_resources`, usa `link_resource` con `resource_id` existente y aclara que se integra según título y notas del profesor; si `has_external_video=true`, NEVER afirmes haber visto o analizado el video.',
    '- Para ajustar la duración total (ej. 60 a 45 min), emite UNA sola operación `redistribute_duration` con `target_duration_min` (el motor recalcula bloques y tiempos internos automáticamente).',
    '- Si existe conflicto de seguridad (ej. suelo no confirmado = "desconocido", inversiones/volteretas, un solo instructor sin colchonetas), material no confirmado en `confirmed_materials`, intento de usar currículo adulto FIU en Infantil/Mixto o intento de inyección/acceso indebido, responde mode="conflict", operations=[], explica `conflict_reason` y ofrece una `safe_alternative` aplicable.',
    isInfantil
      ? '- INFANTIL: prohibido asignar curriculum_movement_ids adultos FIU o acrobacias de impacto sin colchonetas confirmadas; usa `technical_movement_refs` en apoyos bajos/seguros.'
      : '- ADULTOS: usa únicamente movement_id presentes en pertinent_fiu_movements si vinculas FIU.',
    '- Si existe `group_continuity` (últimas sesiones reales de este grupo exacto), úsalo para orientar progresiones sin mezclar otros grupos ni incluir nombres personales.',
    '- Prohibido inventar materiales físicos fuera de `confirmed_materials` o proponer instrumentos sin alternativa de palmas/voz.',
  ];
  const systemPrompt = systemLines.join('\n');
  const userPrompt = `SOLICITUD Y CONTEXTO DEL EDITOR:\n${JSON.stringify(ctx)}`;
  return {
    systemPrompt,
    userPrompt,
    schema: OPENAI_STRICT_COPILOT_V1_JSON_SCHEMA,
    estimatedInputTokens: estimateTokensFromText(systemPrompt) + estimateTokensFromText(userPrompt) + 220,
  };
}

module.exports = {
  buildCopilotContext,
  buildCopilotPrompts,
  normalizeMaterialKey,
};

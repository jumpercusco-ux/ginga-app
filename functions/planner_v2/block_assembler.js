'use strict';

const { computeExpectedAuthoringAndOrigins } = require('./plan_validator');
const { syncInternalTimingsIntoDetalle, ORGANIZATION_MODE_ENUM, FASE_TIPO_ENUM } = require('./response_schema');

function humanReadableFaseLabel(faseTipo, context) {
  const focuses = Array.isArray(context?.focuses) ? context.focuses.join(' ').toLowerCase() : '';
  switch (faseTipo) {
    case 'calentamiento':
      return 'Calentamiento';
    case 'tecnica':
      return 'Técnica y progresiones';
    case 'juegos':
      return 'Juegos de capoeira';
    case 'acrobacias_suelo':
      return 'Acrobacias y movimientos de suelo';
    case 'musicalidad':
      return 'Musicalidad y ritmo';
    case 'angola':
      return 'Juego y diálogo de Angola';
    case 'roda_musicalidad':
      return 'Roda y musicalidad';
    case 'vuelta_calma':
      return 'Vuelta a la calma y cierre';
    case 'recurso_profesor':
      return 'Bloque con recursos del profesor';
    default:
      return 'Bloque de clase';
  }
}

function normalizeOrganizationLabel(rawOrg, context) {
  const txt = String(rawOrg || '').trim();
  if (ORGANIZATION_MODE_ENUM.includes(txt)) {
    return txt;
  }
  const low = txt.toLowerCase();
  if (/pareja/i.test(low)) return 'Rotación por parejas';
  if (/estaci[oó]n/i.test(low) && !((context?.instructorsAvailable || 1) === 1 && (context?.participants || 0) >= 15)) {
    return 'Estaciones simultáneas';
  }
  if (/turno|fila/i.test(low) && !context?.simultaneousParticipationRequested) {
    return 'Turnos';
  }
  return 'Todos simultáneamente';
}

/**
 * Deterministically wraps a slim AI block draft with authoritative IDs,
 * exact slot durations, resource/movement bindings, origin metadata, and honesty notes.
 */
function assembleBlockFromAiDraft(aiBlock, blockSpec, context, catalog) {
  const slots = Array.isArray(blockSpec?.exercise_slots) ? blockSpec.exercise_slots : [];
  const rawExs = Array.isArray(aiBlock?.ejercicios) ? aiBlock.ejercicios : [];
  const resMap = new Map((context.selectedResources || []).map((r) => [r.resource_id, r]));

  const assembledExercises = [];
  const loopCount = rawExs.length === slots.length ? slots.length : rawExs.length;

  for (let ei = 0; ei < loopCount; ei++) {
    const rawEx = rawExs[ei] && typeof rawExs[ei] === 'object' ? rawExs[ei] : {};
    const slot = slots[ei] || null;
    const exerciseId = slot ? slot.exercise_id : `${blockSpec.block_id}_ex_${ei + 1}`;
    const duracionMin = slot ? slot.duracion_min : Math.max(1, Number(rawEx.duracion_min || 1));

    const linkedResourceIds = slot ? [...(slot.assigned_resource_ids || [])] : [];
    const curriculumMovementIds =
      context.curriculumScope === 'adulto_fiu' && slot ? [...(slot.assigned_movement_ids || [])] : [];

    const resourceUsageNotes = {};
    let hasExternalVideo = false;
    for (const rId of linkedResourceIds) {
      const resMeta = resMap.get(rId);
      if (resMeta) {
        resourceUsageNotes[rId] =
          resMeta.usage_note || resMeta.notes || `Integración del recurso "${resMeta.title}".`;
        if (resMeta.has_external_video === true) {
          hasExternalVideo = true;
        }
      }
    }

    const expectedMeta = computeExpectedAuthoringAndOrigins(
      {
        curriculum_movement_ids: curriculumMovementIds,
        linked_resource_ids: linkedResourceIds,
      },
      catalog
    );

    let cancioneroRef = null;
    if (
      rawEx.cancionero_reference &&
      typeof rawEx.cancionero_reference === 'object' &&
      String(rawEx.cancionero_reference.song_title || '').trim().length >= 2
    ) {
      cancioneroRef = {
        song_title: String(rawEx.cancionero_reference.song_title).trim(),
        rhythm: String(rawEx.cancionero_reference.rhythm || 'Corrido').trim(),
        audience_fit: ['infantil', 'adultos', 'todos'].includes(rawEx.cancionero_reference.audience_fit)
          ? rawEx.cancionero_reference.audience_fit
          : context.audienceType === 'infantil'
            ? 'infantil'
            : context.audienceType === 'adultos'
              ? 'adultos'
              : 'todos',
        cantiga_id: null,
        lookup_hint: String(
          rawEx.cancionero_reference.lookup_hint ||
            `Buscar "${rawEx.cancionero_reference.song_title}" en el Cancionero GINGA`
        ).trim(),
      };
    }

    const technicalMovementRefs = [
      ...new Set(
        (Array.isArray(rawEx.technical_movement_refs) ? rawEx.technical_movement_refs : [])
          .map((m) => String(m || '').trim())
          .filter(Boolean)
      ),
    ];

    const assembledEx = {
      exercise_id: exerciseId,
      nombre: String(rawEx.nombre || `Actividad ${ei + 1}`).trim(),
      tipo_actividad: String(rawEx.tipo_actividad || 'ejercicio_tecnico').trim(),
      detalle: String(rawEx.detalle || '').trim(),
      duracion_min: duracionMin,
      organizacion: normalizeOrganizationLabel(rawEx.organizacion, context),
      supervision_instructors_needed: 1,
      materiales: Array.isArray(rawEx.materiales)
        ? rawEx.materiales.map((m) => String(m || '').trim()).filter(Boolean)
        : [],
      seguridad: String(rawEx.seguridad || 'Supervisión directa del instructor y control del ritmo.').trim(),
      diferenciacion_principiantes: String(rawEx.diferenciacion_principiantes || '').trim(),
      diferenciacion_intermedios: String(rawEx.diferenciacion_intermedios || '').trim(),
      diferenciacion_avanzados: String(rawEx.diferenciacion_avanzados || '').trim(),
      sugerencias_ia: String(rawEx.sugerencias_ia || '').trim(),
      observaciones_profesor: '',
      technical_movement_refs: technicalMovementRefs,
      content_origin: expectedMeta.content_origin,
      source_origins: expectedMeta.source_origins,
      activity_authoring: expectedMeta.activity_authoring,
      curriculum_movement_ids: curriculumMovementIds,
      linked_resource_ids: linkedResourceIds,
      resource_usage_notes: resourceUsageNotes,
      tiempos_internos: Array.isArray(rawEx.tiempos_internos) ? rawEx.tiempos_internos : [],
      cancionero_reference: cancioneroRef,
      video_reference_note: hasExternalVideo
        ? 'Recurso con video externo: integrado únicamente según título y notas escritas del profesor (el motor no inspecciona visualmente el video).'
        : null,
    };

    syncInternalTimingsIntoDetalle(assembledEx);
    assembledExercises.push(assembledEx);
  }

  const rawFase = String(aiBlock?.fase || '').trim();
  const isRawTechnicalLabel =
    !rawFase ||
    FASE_TIPO_ENUM.includes(rawFase.toLowerCase()) ||
    /^[a-z0-9_]+$/.test(rawFase) ||
    /^bloque\s+blk_/i.test(rawFase);

  return {
    block_id: blockSpec.block_id,
    fase: isRawTechnicalLabel ? humanReadableFaseLabel(blockSpec.fase_tipo, context) : rawFase,
    fase_tipo: blockSpec.fase_tipo,
    duracion_min: blockSpec.duracion_min,
    ejercicios: assembledExercises,
  };
}

function buildPlanHeaderMetadata(assembledBlocks, context) {
  const nivelLiteral =
    context.audienceType === 'infantil'
      ? 'Infantil'
      : context.audienceType === 'mixto'
        ? 'Mixto'
        : 'Adultos';

  const groupLabel = context.llmPayloadContext?.group_profile?.group_label || `Grupo ${nivelLiteral}`;
  const focusSummary = context.focusLabel || 'Capoeira General';

  const titulo = `${groupLabel} · ${focusSummary} (${context.durationMin} min)`;

  const objetivos =
    Array.isArray(context.objectives) && context.objectives.length > 0
      ? [...context.objectives]
      : [
          `Desarrollar ${focusSummary.toLowerCase()} de forma segura y progresiva (${context.durationMin} min).`,
          'Mantener participación simultánea y diferenciación adaptada al nivel real del grupo.',
          ...(context.selectedResources || [])
            .filter((r) => r.priority === 'required')
            .map((r) => `Integrar el recurso del profesor "${r.title}".`),
        ].slice(0, 5);

  const objetivo = objetivos[0];

  const advices = [];
  if (context.audienceType === 'infantil') {
    advices.push('Currículo Infantil FIU en preparación: propuestas lúdicas sin atribuir cordas infantiles oficiales.');
  } else if (context.curriculumScope === 'adulto_fiu' && context.cordaMeta) {
    advices.push(`Referencia curricular FIU Adulto: ${context.cordaMeta.nombre_manual}.`);
  }
  if (context.space.floorType === 'desconocido' || context.space.availableMats !== true) {
    advices.push('Superficie sin tatami/colchonetas confirmados: evitar inversiones o caídas de impacto.');
  }
  advices.push(`Mantener visibilidad y control continuo (${context.instructorsAvailable} instructor/es).`);

  let continuityNote =
    'Sin historial reciente registrado; progresión inicial equilibrada según perfil del grupo.';
  if (context.continuityContext) {
    const cc = context.continuityContext;
    const parts = [];
    if (cc.pending_exercises?.length) parts.push(`retoma pendientes (${cc.pending_exercises.join(', ')})`);
    if (cc.difficulties) parts.push(`atiende dificultad (${cc.difficulties})`);
    if (cc.reinforce_content) parts.push(`refuerza ${cc.reinforce_content}`);
    if (cc.continuity_proposal) parts.push(cc.continuity_proposal);
    continuityNote =
      parts.length > 0
        ? `Continuidad aplicada: ${parts.join('; ')}.`
        : 'Continuidad pedagógica aplicada según las observaciones recientes del instructor.';
  } else if (context.continuitySummary) {
    continuityNote = `Continuidad aplicada: ${context.continuitySummary}`;
  }

  return {
    titulo,
    duracion_total: context.durationMin,
    nivel: nivelLiteral,
    audience_type: context.audienceType,
    curriculum_scope: context.curriculumScope,
    enfoque: focusSummary,
    objetivo,
    objetivos,
    bloques: assembledBlocks,
    consejos_instructor: advices.join(' '),
    continuity_applied_note: continuityNote,
  };
}

function assembleFullPlanFromBlocks(assembledBlocks, context) {
  return buildPlanHeaderMetadata(assembledBlocks, context);
}

/**
 * Extracts `[0..blocks.length-1]` indices of blocks referenced by structural validation errors
 * so modular repair targets ONLY failing blocks instead of regenerating valid ones.
 */
function extractFailingBlockIndices(validationErrors, plan) {
  const indices = new Set();
  const bloques = Array.isArray(plan?.bloques) ? plan.bloques : [];

  const blockIdToIndex = new Map();
  const exerciseIdToBlockIndex = new Map();
  bloques.forEach((b, bi) => {
    if (b?.block_id) blockIdToIndex.set(String(b.block_id), bi);
    (b?.ejercicios || []).forEach((e) => {
      if (e?.exercise_id) exerciseIdToBlockIndex.set(String(e.exercise_id), bi);
    });
  });

  for (const err of validationErrors || []) {
    const msg = String(err?.message || '');
    for (const [exId, bi] of exerciseIdToBlockIndex.entries()) {
      if (msg.includes(exId)) {
        indices.add(bi);
      }
    }
    for (const [bId, bi] of blockIdToIndex.entries()) {
      if (msg.includes(bId)) {
        indices.add(bi);
      }
    }
  }

  return [...indices].sort((a, b) => a - b);
}

module.exports = {
  assembleBlockFromAiDraft,
  assembleFullPlanFromBlocks,
  extractFailingBlockIndices,
};

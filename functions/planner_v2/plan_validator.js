'use strict';

const { isEligibleAdultoMovement, getMovement } = require('./curriculum_catalog_loader');
const { scanResidualPiiHeuristic } = require('./pii_and_injection_guard');
const { ACTIVITY_AUTHORING_ENUM, CONTENT_ORIGIN_ENUM } = require('./response_schema');

const COMPLEX_ACROBATICS_RE =
  /\b(s-?dobrado|mortal|parafuso|flick|macaco\s+solto|pi[aã]o\s+de\s+cabe[cç]a|chapa\s+voada|a[uú]\s+chibata|a[uú]\s+batendo|bananeira\s+sin\s+apoyo)\b/i;

const FORBIDDEN_UNVALIDATED_INFANTIL_FIU_CLAIM_RE =
  /(?:seg[uú]n|del|pertenece\s+al|oficial(?:es)?\s+del)\s+curr[ií]culo\s+infantil\s+fiu|\binfantil_corda_\d{2}\b/i;

const EXIGENT_INVERSION_RE =
  /\b(bananeira|ponte|parada\s+de\s+m[aã]o|queda\s+de\s+rim)\b/i;

const GENERIC_NON_CAPOEIRA_GAME_RE =
  /\b(juego\s+de\s+las\s+estatuas|juego\s+de\s+la\s+silla|carrera\s+de\s+(?:los\s+)?animales|carrera\s+de\s+relevos)\b/i;

const CAPOEIRA_CORE_TERM_RE =
  /\b(ginga|cocorinha|esquiva|armada|queixada|a[uú]|rol[eê]|negativa|b[eê]n[cç][aã]o|martelo|roda|berimbau|pandeiro|atabaque|corrido|ladainha|angola)\b/i;

const ELIMINATION_MECHANIC_RE =
  /\b(queda\s+eliminado|eliminando\s+una\s+silla|el\s+[uú]ltimo\s+en\s+quedar|van\s+saliendo\s+eliminados)\b/i;

const QUEUE_LINE_MECHANIC_RE =
  /\b(se\s+coloca(?:n)?\s+en\s+fila|formar\s+una\s+fila|cola\s+de\s+espera|esperan\s+su\s+turno\s+en\s+fila)\b/i;

const UNSAFE_ROLL_TUMBLE_RE =
  /\b(voltereta|rodar\s+hacia\s+adelante|rodar\s+como\s+una\s+bola|maroma)\b/i;

const UNDECLARED_CHAIR_PROSE_RE =
  /\b(coloca\s+sillas|sillas\s+en\s+c[ií]rculo|sin\s+silla|una\s+silla|las\s+sillas)\b/i;

const UNDECLARED_CONE_PROSE_RE =
  /\b(conos\s+en\s+el\s+suelo|coloca\s+conos|entre\s+conos)\b/i;

const INSTRUMENT_MENTION_RE = /\b(berimbau|pandeiro|atabaque)\b/i;
const INSTRUMENT_ALTERNATIVE_RE =
  /\b(palmas|voz|canto|corporal|alternativa|si\s+no\s+hay|si\s+est[aá]\s+disponible|sin\s+instrumento)\b/i;

function normalizeMaterialKey(value) {
  return String(value || '')
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function hasInversionPreconditions(context) {
  const confirmedSurface = context.space.floorType === 'tatami' && context.space.availableMats === true;
  const sufficientSupervision = context.instructorsAvailable >= 2 || context.participants <= 8;
  const explicitPreparation =
    context.focuses.some((f) => /acrobacia/i.test(f)) ||
    /\b(bananeira|ponte|parada\s+de\s+m[aã]o|queda\s+de\s+rim|invertid)/i.test(context.freeInstructions || '');
  return confirmedSurface && sufficientSupervision && explicitPreparation;
}

function computeExpectedAuthoringAndOrigins(ex, catalog) {
  const movIds = Array.isArray(ex.curriculum_movement_ids) ? ex.curriculum_movement_ids : [];
  const resIds = Array.isArray(ex.linked_resource_ids) ? ex.linked_resource_ids : [];

  if (resIds.length > 0 && movIds.length > 0) {
    return {
      content_origin: 'teacher_resource',
      source_origins: ['teacher_resource', 'official_fiu_curriculum'],
      activity_authoring: 'teacher_resource_with_official_fiu_movements',
    };
  }
  if (resIds.length > 0) {
    return {
      content_origin: 'teacher_resource',
      source_origins: ['teacher_resource'],
      activity_authoring: 'teacher_resource',
    };
  }
  if (movIds.length > 0) {
    const isLiteralCombo =
      movIds.length === 1 && getMovement(catalog, movIds[0])?.entry_kind === 'combinacao_solo';
    return {
      content_origin: 'official_fiu_curriculum',
      source_origins: isLiteralCombo
        ? ['official_fiu_curriculum']
        : ['official_fiu_curriculum', 'ai_designed_activity'],
      activity_authoring: isLiteralCombo ? 'official_fiu_sequence' : 'ai_exercise_from_official_fiu',
    };
  }
  return {
    content_origin: 'ai_complementary_proposal',
    source_origins: ['ai_complementary_proposal'],
    activity_authoring: 'ai_complementary_proposal',
  };
}

/**
 * Performs strict deterministic structural validation (`structuralValidation`)
 * plus transparent offline heuristic quality scoring (`pedagogicalHeuristicEvaluation`).
 * Heuristic evaluation NEVER substitutes human review or real LLM evaluation.
 */
function validateGeneratedPlan(plan, context, catalog) {
  const errors = [];
  const warnings = [];
  const addError = (code, message) => errors.push({ code, message });
  const addWarning = (code, message) => warnings.push({ code, message });

  if (!plan || typeof plan !== 'object') {
    addError('INVALID_PLAN_OBJECT', 'El plan devuelto no es un objeto JSON válido.');
    return {
      structuralValidation: { passed: false, errors, warnings },
      pedagogicalHeuristicEvaluation: {
        evaluation_kind: 'heuristic_offline_not_human_or_real_llm',
        score_total: 0,
        dimensions: {},
      },
    };
  }

  // 1. Metadata & duration math
  if (plan.duracion_total !== context.durationMin) {
    addError(
      'DURATION_TOTAL_MISMATCH',
      `duracion_total (${plan.duracion_total}) no coincide con lo solicitado (${context.durationMin}).`
    );
  }
  if (plan.audience_type !== context.audienceType) {
    addError('AUDIENCE_MISMATCH', `audience_type '${plan.audience_type}' difiere de '${context.audienceType}'.`);
  }
  if (plan.curriculum_scope !== context.curriculumScope) {
    addError('SCOPE_MISMATCH', `curriculum_scope '${plan.curriculum_scope}' difiere de '${context.curriculumScope}'.`);
  }

  const bloques = Array.isArray(plan.bloques) ? plan.bloques : [];
  if (bloques.length < 2 || bloques.length > 7) {
    addError('INVALID_BLOCKS_COUNT', `Cantidad de bloques fuera de rango flexible (2..7): ${bloques.length}`);
  }

  let blockSum = 0;
  const coveredMovementIds = new Set();
  const coveredResourceIds = new Set();
  const originCounts = {
    official_fiu_curriculum: 0,
    teacher_resource: 0,
    ai_complementary_proposal: 0,
  };

  const multiLevelActive =
    [
      context.expDist.principiantes > 0,
      context.expDist.intermedios > 0,
      context.expDist.avanzados > 0,
    ].filter(Boolean).length >= 2;

  const resourceById = new Map(context.selectedResources.map((r) => [r.resource_id, r]));
  const hasAcrobaciasFocus = context.focuses.some((f) => /acrobacia/i.test(f));
  const declaredMaterialsLower = new Set(context.materials.map((m) => normalizeMaterialKey(m)));

  let allExercisesCount = 0;
  let simultaneousMinutes = 0;
  let stepByStepOkCount = 0;
  let differentiationOkCount = 0;

  for (let bi = 0; bi < bloques.length; bi++) {
    const blk = bloques[bi];
    if (!blk || typeof blk !== 'object') {
      addError('INVALID_BLOCK', `Bloque ${bi} inválido.`);
      continue;
    }
    if (!blk.block_id || String(blk.block_id).trim() === '') {
      addError('MISSING_BLOCK_ID', `Bloque ${bi} sin block_id.`);
    }
    const bDur = Number(blk.duracion_min);
    if (!Number.isInteger(bDur) || bDur < 1) {
      addError('INVALID_BLOCK_DURATION', `Bloque ${blk.block_id || bi} con duracion_min inválida: ${blk.duracion_min}`);
    } else {
      blockSum += bDur;
    }

    const ejercicios = Array.isArray(blk.ejercicios) ? blk.ejercicios : [];
    if (ejercicios.length === 0) {
      addError('EMPTY_BLOCK_EXERCISES', `Bloque ${blk.block_id || bi} sin ejercicios.`);
      continue;
    }

    let exSum = 0;
    for (let ei = 0; ei < ejercicios.length; ei++) {
      const ex = ejercicios[ei];
      allExercisesCount += 1;

      if (!ex.exercise_id || String(ex.exercise_id).trim() === '') {
        addError('MISSING_EXERCISE_ID', `Ejercicio ${bi}.${ei} sin exercise_id.`);
      }
      const eDur = Number(ex.duracion_min);
      if (!Number.isInteger(eDur) || eDur < 1) {
        addError('INVALID_EXERCISE_DURATION', `Ejercicio ${ex.exercise_id || ei} con duracion_min inválida.`);
      } else {
        exSum += eDur;
      }

      if (!CONTENT_ORIGIN_ENUM.includes(ex.content_origin)) {
        addError('INVALID_CONTENT_ORIGIN', `content_origin inválido en ${ex.exercise_id}: ${ex.content_origin}`);
      } else {
        originCounts[ex.content_origin] += 1;
      }

      if (!ACTIVITY_AUTHORING_ENUM.includes(ex.activity_authoring)) {
        addError(
          'INVALID_ACTIVITY_AUTHORING',
          `activity_authoring inválido en ${ex.exercise_id}: ${ex.activity_authoring}`
        );
      }

      const movIds = Array.isArray(ex.curriculum_movement_ids) ? ex.curriculum_movement_ids : [];
      const resIds = Array.isArray(ex.linked_resource_ids) ? ex.linked_resource_ids : [];

      // Curriculum checks
      for (const mId of movIds) {
        if (context.curriculumScope !== 'adulto_fiu') {
          addError(
            'FORBIDDEN_FIU_IN_NON_ADULT_SCOPE',
            `Ejercicio ${ex.exercise_id} incluye movement_id '${mId}' fuera de scope 'adulto_fiu'.`
          );
          continue;
        }
        if (!isEligibleAdultoMovement(catalog, mId)) {
          addError(
            'INELIGIBLE_OR_UNKNOWN_MOVEMENT_ID',
            `Ejercicio ${ex.exercise_id} referencia movimiento inválido o excluido: '${mId}'.`
          );
        } else {
          coveredMovementIds.add(mId);
        }
      }

      // Origin & authoring consistency & precedence
      const expectedMeta = computeExpectedAuthoringAndOrigins(ex, catalog);
      if (ex.content_origin !== expectedMeta.content_origin) {
        addError(
          'ORIGIN_PRECEDENCE_MISMATCH',
          `Ejercicio ${ex.exercise_id} tiene content_origin='${ex.content_origin}' pero por vínculos corresponde '${expectedMeta.content_origin}'.`
        );
      }
      if (ex.activity_authoring !== expectedMeta.activity_authoring) {
        addError(
          'ACTIVITY_AUTHORING_MISMATCH',
          `Ejercicio ${ex.exercise_id} tiene activity_authoring='${ex.activity_authoring}' pero corresponde '${expectedMeta.activity_authoring}'.`
        );
      }

      // Allow_ai_complementary_proposals=false enforcement
      if (!context.allowAiComplementaryProposals && ex.content_origin === 'ai_complementary_proposal') {
        addError(
          'DISALLOWED_AI_COMPLEMENTARY_PROPOSAL',
          `Ejercicio ${ex.exercise_id} es propuesta complementaria IA pero allow_ai_complementary_proposals=false.`
        );
      }

      // Teacher resource verification + video honesty
      for (const rId of resIds) {
        const resMeta = resourceById.get(rId);
        if (!resMeta) {
          addError(
            'UNKNOWN_LINKED_RESOURCE_ID',
            `Ejercicio ${ex.exercise_id} referencia un recurso no perteneciente a la solicitud: '${rId}'.`
          );
        } else {
          coveredResourceIds.add(rId);
          if (resMeta.has_external_video) {
            const vNote = String(ex.video_reference_note || '').trim();
            if (!vNote || !/no\s+inspecciona|notas\s+escritas|t[ií]tulo/i.test(vNote)) {
              addError(
                'MISSING_VIDEO_HONESTY_NOTE',
                `Ejercicio ${ex.exercise_id} vincula recurso con video externo '${rId}' sin video_reference_note honesto.`
              );
            }
          }
        }
      }

      // Infantil protections
      if (context.audienceType === 'infantil') {
        if (ex.content_origin === 'official_fiu_curriculum') {
          addError('OFFICIAL_FIU_FORBIDDEN_IN_INFANTIL', `Ejercicio ${ex.exercise_id} usa origin oficial FIU en Infantil.`);
        }
        const combinedText = `${ex.nombre} ${ex.detalle} ${ex.observaciones_profesor || ''}`;
        if (FORBIDDEN_UNVALIDATED_INFANTIL_FIU_CLAIM_RE.test(combinedText)) {
          addError(
            'UNVALIDATED_INFANTIL_FIU_CLAIM',
            `Ejercicio ${ex.exercise_id} atribuye graduación o currículo FIU infantil no validado.`
          );
        }
        if (COMPLEX_ACROBATICS_RE.test(combinedText)) {
          addError(
            'COMPLEX_ACROBATICS_FORBIDDEN_IN_INFANTIL',
            `Ejercicio ${ex.exercise_id} introduce acrobacia compleja inapropiada en Infantil.`
          );
        }
        if (ex.tipo_actividad === 'juego_dinamico') {
          const detBody = String(ex.detalle || '')
            .replace(/\s*Tiempos internos\s*\([^)]*\)\.?/gi, '')
            .trim();
          // Verify 3 distinct executable dimensions (never satisfied by repeating 1 keyword):
          // 1) Spatial/group setup, 2) Rules/cues/win-action, 3) Rounds/turns/rotation.
          const hasSetup =
            /preparaci[oó]n|c[ií]rculo|parejas|espacio|organiza|ubicad|formaci[oó]n|distancia|grupos?|estaci[oó]n|frente\s+a\s+frente|l[ií]nea/i.test(
              detBody
            );
          const hasRuleOrCue =
            /regla|se[nñ]al|consigna|indicaci[oó]n|toque|pandeiro|berimbau|palmas|silbato|comando|cuando\s+suen|al\s+escuchar|si\s+el\s+profesor|deben|sin\s+contacto|espejo/i.test(
              detBody
            );
          const hasRoundsOrRotation =
            /ronda|rotaci[oó]n|rotan|turno|intercambi|cambian\s+de|alternan|cada\s+\d+\s*(?:seg|min)|series?|repeticion/i.test(
              detBody
            );
          if (detBody.length < 75 || !hasSetup || !hasRuleOrCue || !hasRoundsOrRotation) {
            addError(
              'GAME_MISSING_EXECUTABLE_RULES',
              `Juego infantil ${ex.exercise_id} carece de preparación espacial, reglas/señales y rondas/rotación ejecutables.`
            );
          }
        }
      }

      // Pedagogical quality rules (PED-04C2-E)
      const exPedagogicalText = `${ex.nombre} ${ex.detalle} ${ex.diferenciacion_principiantes || ''} ${ex.diferenciacion_intermedios || ''} ${ex.diferenciacion_avanzados || ''}`;
      if (GENERIC_NON_CAPOEIRA_GAME_RE.test(`${ex.nombre} ${ex.detalle}`)) {
        addError(
          'GENERIC_NON_CAPOEIRA_EXERCISE',
          `Ejercicio ${ex.exercise_id} propone una dinámica genérica ajena a la Capoeira ("${ex.nombre}").`
        );
      }
      if (
        context.simultaneousParticipationRequested === true &&
        (ELIMINATION_MECHANIC_RE.test(`${ex.nombre} ${ex.detalle}`) ||
          QUEUE_LINE_MECHANIC_RE.test(`${ex.nombre} ${ex.detalle}`) ||
          String(ex.organizacion || '').trim() === 'Turnos')
      ) {
        addError(
          'ELIMINATION_OR_QUEUE_WHEN_SIMULTANEOUS_REQUESTED',
          `Ejercicio ${ex.exercise_id} introduce filas, eliminaciones o turnos pasivos cuando se requiere participación simultánea.`
        );
      }
      if (String(ex.organizacion || '').trim().length > 50) {
        addError(
          'UNSTRUCTURED_ORGANIZATION_PROSE',
          `Ejercicio ${ex.exercise_id} usa texto libre extenso en 'organizacion' en lugar de una modalidad pedagógica estándar.`
        );
      }
      if (
        (context.space.floorType !== 'tatami' || context.space.availableMats !== true) &&
        UNSAFE_ROLL_TUMBLE_RE.test(exPedagogicalText)
      ) {
        addError(
          'UNSAFE_ROLL_OR_TUMBLE_ON_UNCONFIRMED_FLOOR',
          `Ejercicio ${ex.exercise_id} incluye voltereta o rodada en suelo sin tatami ni colchonetas confirmados.`
        );
      }
      const linkedResourcesText = (context.selectedResources || [])
        .filter((r) => resIds.includes(r.resource_id))
        .map((r) => `${r.title || ''} ${r.notes || ''} ${r.usage_note || ''}`)
        .join(' ');
      if (
        UNDECLARED_CHAIR_PROSE_RE.test(ex.detalle || '') &&
        !declaredMaterialsLower.has('silla') &&
        !declaredMaterialsLower.has('sillas') &&
        !/\bsillas?\b/i.test(linkedResourcesText)
      ) {
        addError(
          'UNDECLARED_MATERIAL_OR_INSTRUMENT_IN_PROSE',
          `Ejercicio ${ex.exercise_id} exige sillas en su descripción sin material declarado.`
        );
      }
      if (
        resIds.length === 0 &&
        UNDECLARED_CONE_PROSE_RE.test(ex.detalle || '') &&
        !declaredMaterialsLower.has('cono') &&
        !declaredMaterialsLower.has('conos')
      ) {
        addError(
          'UNDECLARED_MATERIAL_OR_INSTRUMENT_IN_PROSE',
          `Ejercicio ${ex.exercise_id} exige conos en su descripción sin material declarado.`
        );
      }
      const mentionedInstrumentMatch = String(ex.detalle || '').match(INSTRUMENT_MENTION_RE);
      if (
        mentionedInstrumentMatch &&
        !declaredMaterialsLower.has(normalizeMaterialKey(mentionedInstrumentMatch[1])) &&
        !INSTRUMENT_ALTERNATIVE_RE.test(
          `${ex.detalle || ''} ${ex.seguridad || ''} ${ex.sugerencias_ia || ''} ${ex.observaciones_profesor || ''}`
        )
      ) {
        addError(
          'UNDECLARED_MATERIAL_OR_INSTRUMENT_IN_PROSE',
          `Ejercicio ${ex.exercise_id} menciona '${mentionedInstrumentMatch[1]}' no confirmado sin indicar alternativa viable (palmas/voz/percusión corporal).`
        );
      }

      // Acrobacias / combat separation & unrequested complex acrobatics
      if (blk.fase_tipo === 'tecnica' && ex.tipo_actividad === 'progresion_suelo') {
        addError(
          'ACROBATICS_MIXED_IN_TECH_BLOCK',
          `Progresión de suelo/acrobacia ${ex.exercise_id} mezclada dentro de bloque técnico.`
        );
      }
      if (!hasAcrobaciasFocus && COMPLEX_ACROBATICS_RE.test(`${ex.nombre} ${ex.detalle}`)) {
        addError(
          'UNREQUESTED_COMPLEX_ACROBATICS',
          `Ejercicio ${ex.exercise_id} introduce acrobacia compleja sin haberla solicitado ni ser adecuada al perfil.`
        );
      }
      if (EXIGENT_INVERSION_RE.test(`${ex.nombre} ${ex.detalle}`) && !hasInversionPreconditions(context)) {
        addError(
          'UNPREPARED_INVERSION_OR_BRIDGE',
          `Ejercicio ${ex.exercise_id} propone inversión/puente exigente sin condiciones explícitas de preparación, superficie (tatami + colchonetas) y supervisión.`
        );
      }

      // Internal timing breakdown coherence for structured tiempos_internos + games/infantile activities
      const structuredTimings = Array.isArray(ex.tiempos_internos) ? ex.tiempos_internos : [];
      let validStructuredTimingSum = null;
      if (structuredTimings.length > 0) {
        let sum = 0;
        let allValid = true;
        for (const item of structuredTimings) {
          const etapa = String(item?.etapa || '').trim();
          const mins = Number(item?.minutos);
          if (!etapa || !Number.isInteger(mins) || mins < 1) {
            allValid = false;
            addError(
              'INVALID_INTERNAL_TIMING_ENTRY',
              `Ejercicio ${ex.exercise_id} tiene entrada inválida en tiempos_internos.`
            );
          } else {
            sum += mins;
          }
        }
        if (allValid && Number.isInteger(eDur)) {
          validStructuredTimingSum = sum;
          if (sum !== eDur) {
            addError(
              'INTERNAL_TIMING_SUM_MISMATCH',
              `Los tiempos_internos de ${ex.exercise_id} suman ${sum} min pero duracion_min=${eDur} min.`
            );
          }
        }
        if (structuredTimings.length === 1 && Number(eDur) >= 4) {
          addError(
            'TRIVIAL_INTERNAL_TIMINGS',
            `Ejercicio ${ex.exercise_id} (${eDur} min) repite una sola etapa en tiempos_internos en lugar de desglosar fases reales de ejecución.`
          );
        }
      }

      if ((ex.tipo_actividad === 'juego_dinamico' || context.audienceType === 'infantil') && Number.isInteger(eDur)) {
        const det = String(ex.detalle || '');
        const hasTextTimingBreakdown = /\d+\s*(?:min|minutos?|seg|segundos?)|\b\d+\s*rondas?\b/i.test(det);
        const hasTimingBreakdown = validStructuredTimingSum === eDur || hasTextTimingBreakdown;
        if (!hasTimingBreakdown) {
          addError(
            'MISSING_INTERNAL_TIMING_BREAKDOWN',
            `Ejercicio ${ex.exercise_id} (${eDur} min) carece de desglose temporal interno (detalle o tiempos_internos).`
          );
        }
        const exactTotalMatch = det.match(/total\s*[:=]?\s*(\d+)\s*min/i);
        if (exactTotalMatch && Number(exactTotalMatch[1]) !== eDur) {
          addError(
            'INTERNAL_TIMING_SUM_MISMATCH',
            `El desglose interno de ${ex.exercise_id} declara ${exactTotalMatch[1]} min pero duracion_min=${eDur} min.`
          );
        }
      }

      // Cancionero reference: must NEVER invent cantiga_id
      if (ex.cancionero_reference && typeof ex.cancionero_reference === 'object') {
        if (ex.cancionero_reference.cantiga_id !== null && ex.cancionero_reference.cantiga_id !== undefined) {
          addError(
            'INVENTED_CANTIGA_ID',
            `Ejercicio ${ex.exercise_id} incluye cantiga_id='${ex.cancionero_reference.cantiga_id}' no verificado en servidor (debe ser null).`
          );
        }
        if (!ex.cancionero_reference.song_title || String(ex.cancionero_reference.song_title).trim().length < 2) {
          addError(
            'INVALID_CANCIONERO_REFERENCE',
            `Ejercicio ${ex.exercise_id} tiene cancionero_reference sin song_title válido.`
          );
        }
      }

      // Supervision constraints
      const supNeeded = Number(ex.supervision_instructors_needed || 1);
      if (supNeeded > context.instructorsAvailable) {
        addError(
          'SUPERVISION_EXCEEDS_INSTRUCTORS',
          `Ejercicio ${ex.exercise_id} requiere ${supNeeded} instructores pero solo hay ${context.instructorsAvailable} disponible(s).`
        );
      }
      if (
        context.instructorsAvailable === 1 &&
        context.participants >= 15 &&
        /estaciones/i.test(ex.organizacion || '') &&
        ex.tipo_actividad === 'progresion_suelo'
      ) {
        addError(
          'UNSAFE_UNSUPERVISED_STATIONS',
          `Ejercicio ${ex.exercise_id} propone estaciones de suelo simultáneas con grupo numeroso (${context.participants}) y 1 solo instructor.`
        );
      }

      // Space & unknown material honesty
      const exMaterials = Array.isArray(ex.materiales) ? ex.materiales : [];
      for (const mat of exMaterials) {
        const mLow = normalizeMaterialKey(mat);
        if (mLow.includes('colchoneta') && context.space.availableMats !== true && !declaredMaterialsLower.has(mLow)) {
          addError(
            'ASSUMED_UNAVAILABLE_MATS',
            `Ejercicio ${ex.exercise_id} asume colchonetas cuando available_mats=${context.space.availableMats}.`
          );
        }
        if (context.materialsKnown && !declaredMaterialsLower.has(mLow)) {
          addError(
            'UNDECLARED_MATERIAL_USED',
            `Ejercicio ${ex.exercise_id} exige material '${mat}' no incluido en la lista declarada.`
          );
        }
      }
      if (
        context.space.floorType !== 'tatami' &&
        /\bsobre\s+el\s+tatami\b|\ben\s+todo\s+el\s+tatami\b/i.test(ex.detalle || '')
      ) {
        addError(
          'ASSUMED_TATAMI_WHEN_UNKNOWN_OR_HARD_FLOOR',
          `Ejercicio ${ex.exercise_id} asume tatami cuando floor_type='${context.space.floorType}'.`
        );
      }
      if (
        (context.space.floorType === 'cemento' || context.space.floorType === 'desconocido' || context.space.availableMats !== true) &&
        ex.tipo_actividad === 'progresion_suelo' &&
        /\b(ca[ií]da|mortal|puente\s+invertido|parada\s+de\s+m[aã]o\s+sin\s+soporte)\b/i.test(ex.detalle || '')
      ) {
        addError(
          'UNSAFE_FLOOR_ACROBATICS',
          `Ejercicio ${ex.exercise_id} propone movimiento de impacto sin piso tatami/colchonetas confirmados.`
        );
      }

      // Differentiation quality check
      const bDiff = String(ex.diferenciacion_principiantes || '').trim();
      const iDiff = String(ex.diferenciacion_intermedios || '').trim();
      const aDiff = String(ex.diferenciacion_avanzados || '').trim();
      if (multiLevelActive) {
        const populated = [
          context.expDist.principiantes > 0 ? bDiff : 'na',
          context.expDist.intermedios > 0 ? iDiff : 'na',
          context.expDist.avanzados > 0 ? aDiff : 'na',
        ];
        if (populated.some((v) => v === '')) {
          addError(
            'MISSING_LEVEL_DIFFERENTIATION',
            `Ejercicio ${ex.exercise_id} omite variante para uno de los niveles activos en el grupo.`
          );
        } else if (bDiff && aDiff && bDiff.toLowerCase() === aDiff.toLowerCase()) {
          addError(
            'IDENTICAL_LEVEL_VARIANTS',
            `Ejercicio ${ex.exercise_id} repite exactamente la misma variante para principiantes y avanzados.`
          );
        } else {
          differentiationOkCount += 1;
        }
      } else {
        differentiationOkCount += 1;
      }

      // Organization & step-by-step stats for heuristics
      if (!ex.organizacion || String(ex.organizacion).trim().length < 3) {
        addError('MISSING_ORGANIZATION', `Ejercicio ${ex.exercise_id} sin organización.`);
      } else if (/simult[aá]ne|parejas|estaciones|c[ií]rculo/i.test(ex.organizacion)) {
        simultaneousMinutes += Number.isInteger(eDur) ? eDur : 0;
      }

      if (!ex.seguridad || String(ex.seguridad).trim().length < 5) {
        addError('MISSING_SAFETY_NOTE', `Ejercicio ${ex.exercise_id} sin nota de seguridad.`);
      }

      if (String(ex.detalle || '').trim().length >= 55) {
        stepByStepOkCount += 1;
      }
    }

    if (Number.isInteger(bDur) && exSum !== bDur) {
      addError(
        'BLOCK_EXERCISES_DURATION_MISMATCH',
        `Suma de ejercicios (${exSum} min) en bloque '${blk.block_id}' no iguala duracion_min del bloque (${bDur} min).`
      );
    }
  }

  if (blockSum !== context.durationMin) {
    addError(
      'BLOCKS_DURATION_SUM_MISMATCH',
      `Suma de duraciones de bloques (${blockSum} min) no iguala duracion_total (${context.durationMin} min).`
    );
  }

  // Required FIU movements & required Pizarra resources must 100% be covered
  for (const reqMov of context.selectedMovements) {
    if (reqMov.priority === 'required' && !coveredMovementIds.has(reqMov.movement_id)) {
      addError(
        'MISSING_REQUIRED_MOVEMENT',
        `El movimiento FIU obligatorio '${reqMov.movement_id}' (${reqMov.canonical_name}) no fue incluido en ningún ejercicio.`
      );
    }
  }
  for (const reqRes of context.selectedResources) {
    if (reqRes.priority === 'required' && !coveredResourceIds.has(reqRes.resource_id)) {
      addError(
        'MISSING_REQUIRED_RESOURCE',
        `El recurso obligatorio '${reqRes.resource_id}' (${reqRes.title}) no fue incluido en ningún ejercicio.`
      );
    }
  }

  // Capoeira specialization, requested technical movements, and executable musicality checks (PED-04C2-E)
  const serializedBlocksText = JSON.stringify(bloques);
  if (context.allowAiComplementaryProposals !== false && !CAPOEIRA_CORE_TERM_RE.test(serializedBlocksText)) {
    addError(
      'GENERIC_NON_CAPOEIRA_EXERCISE',
      'La clase generada carece de vocabulario y contenidos técnicos reales de Capoeira.'
    );
  }
  const requestedTech =
    context.allowAiComplementaryProposals !== false && Array.isArray(context.requestedTechnicalMovements)
      ? context.requestedTechnicalMovements
      : [];
  const executionCoverageText = bloques
    .flatMap((b) => [
      b.fase || '',
      ...(Array.isArray(b.ejercicios) ? b.ejercicios : []).flatMap((e) => [
        e.nombre || '',
        e.detalle || '',
        e.diferenciacion_principiantes || '',
        e.diferenciacion_intermedios || '',
        e.diferenciacion_avanzados || '',
        ...(Array.isArray(e.technical_movement_refs) ? e.technical_movement_refs : []),
        ...(Array.isArray(e.curriculum_movement_ids) ? e.curriculum_movement_ids : []),
      ]),
    ])
    .join(' ');
  const normalizedBlocksAscii = executionCoverageText
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[_-]+/g, ' ')
    .toLowerCase();
  for (const movName of requestedTech) {
    const cleanMov = movName
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[_-]+/g, ' ')
      .toLowerCase();
    const escapedMov = cleanMov.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const patternBody = cleanMov === 'esquiva' ? 'esquivas?' : escapedMov;
    const movWordRe = new RegExp(`\\b${patternBody}\\b`, 'i');
    if (!movWordRe.test(normalizedBlocksAscii)) {
      addError(
        'MISSING_REQUESTED_MOVEMENT_COVERAGE',
        `El movimiento solicitado explícitamente '${movName}' no fue cubierto en la clase.`
      );
    }
  }
  const musicalityRequested = context.focuses.some((f) => /musicalidad|roda/i.test(f));
  if (musicalityRequested) {
    const musicBlocks = bloques.filter((b) => b.fase_tipo === 'musicalidad' || b.fase_tipo === 'roda_musicalidad');
    for (const mb of musicBlocks) {
      const mText = (mb.ejercicios || [])
        .map((e) => `${e.nombre || ''} ${e.detalle || ''}`)
        .join(' ');
      const hasVocal = /\b(canto|cantar|cantando|coro|responsorial|estribillo|melod[ií]a)\b/i.test(mText);
      const hasRhythm = /\b(palmas|pulso|ritmo|toques?|berimbau|pandeiro|atabaque|eco\s+r[ií]tmico)\b/i.test(mText);
      const hasRodaOrGroupPractice =
        /\b(roda|c[ií]rculo|juego|alternan|rotaci[oó]n|rondas?|ensamble|grupal|parejas|arcos|puxador)\b/i.test(mText);
      const isExecutable =
        mb.fase_tipo === 'roda_musicalidad'
          ? hasVocal && hasRhythm && hasRodaOrGroupPractice
          : (hasVocal || hasRhythm) && hasRodaOrGroupPractice;
      if (!isExecutable) {
        const missingDims = [];
        if (mb.fase_tipo === 'roda_musicalidad') {
          if (!hasVocal) missingDims.push('canto/coro responsorial');
          if (!hasRhythm) missingDims.push('palmas/pulso rítmico');
          if (!hasRodaOrGroupPractice) missingDims.push('práctica grupal/roda en círculo');
        } else {
          if (!hasVocal && !hasRhythm) missingDims.push('canto o palmas/ritmo');
          if (!hasRodaOrGroupPractice) missingDims.push('práctica grupal/roda en círculo');
        }
        addError(
          'NON_EXECUTABLE_MUSICALITY',
          `Bloque musical '${mb.block_id}' no describe práctica ejecutable completa. Falta explícitamente: ${missingDims.join(', ')}.`
        );
      }
    }
  }

  // Heuristic output PII scan
  const serializedOut = JSON.stringify(plan);
  const piiCheck = scanResidualPiiHeuristic(serializedOut);
  if (!piiCheck.cleanHeuristic) {
    addError('RESIDUAL_PII_DETECTED', `Se detectó posible PII residual en la salida: ${piiCheck.hits.join(', ')}`);
  }

  // --- Pedagogical Heuristic Evaluation (0-100), explicitly marked as heuristic ---
  const focusJoined = context.focuses.join(' ').toLowerCase();
  const matchesFocus =
    bloques.some((b) => focusJoined.includes(b.fase_tipo.replace('_musicalidad', '').replace('_suelo', '')) || true) &&
    (focusJoined.includes('musicalidad')
      ? bloques.filter((b) => /musicalidad|roda/i.test(`${b.fase} ${b.fase_tipo}`)).length >= 2
      : true);

  const focusScore = matchesFocus ? 20 : 12;
  const stepRatio = allExercisesCount > 0 ? stepByStepOkCount / allExercisesCount : 0;
  const executableScore = Math.round(stepRatio * 20);
  const simRatio = context.durationMin > 0 ? Math.min(1, simultaneousMinutes / context.durationMin) : 0;
  const simScore = context.participants >= 6 ? Math.round(Math.min(1, simRatio / 0.65) * 15) : 15;
  const diffRatio = allExercisesCount > 0 ? differentiationOkCount / allExercisesCount : 0;
  const diffScore = Math.round(diffRatio * 15);

  // Respect teacher-only resources without penalizing lack of origin diversity!
  const requiredCoveredAll = errors.every(
    (e) => e.code !== 'MISSING_REQUIRED_MOVEMENT' && e.code !== 'MISSING_REQUIRED_RESOURCE'
  );
  const resourcesAlignmentScore = requiredCoveredAll ? 10 : 3;

  let continuityScore = 10;
  if (context.continuityContext && String(plan.continuity_applied_note || '').trim().length < 10) {
    continuityScore = 4;
    addWarning('WEAK_CONTINUITY_NOTE', 'La nota de continuidad aplicada es demasiado breve.');
  }

  const safetySpaceScore = errors.some((e) =>
    ['SUPERVISION_EXCEEDS_INSTRUCTORS', 'UNSAFE_UNSUPERVISED_STATIONS', 'ASSUMED_UNAVAILABLE_MATS', 'UNSAFE_FLOOR_ACROBATICS'].includes(e.code)
  )
    ? 2
    : 10;

  const totalHeuristicScore =
    focusScore + executableScore + simScore + diffScore + resourcesAlignmentScore + continuityScore + safetySpaceScore;

  return {
    structuralValidation: {
      passed: errors.length === 0,
      errors,
      warnings,
      duration_sum_exact: blockSum === context.durationMin && errors.every((e) => e.code !== 'BLOCK_EXERCISES_DURATION_MISMATCH'),
      required_movements_covered: errors.every((e) => e.code !== 'MISSING_REQUIRED_MOVEMENT'),
      required_resources_covered: errors.every((e) => e.code !== 'MISSING_REQUIRED_RESOURCE'),
      curriculum_track_respected: errors.every(
        (e) => e.code !== 'FORBIDDEN_FIU_IN_NON_ADULT_SCOPE' && e.code !== 'OFFICIAL_FIU_FORBIDDEN_IN_INFANTIL'
      ),
      pii_heuristic_clean: piiCheck.cleanHeuristic,
      origin_breakdown: originCounts,
    },
    pedagogicalHeuristicEvaluation: {
      evaluation_kind: 'heuristic_offline_not_human_or_real_llm',
      score_total: totalHeuristicScore,
      threshold_suggested: 80,
      dimensions: {
        focus_coherence: focusScore,
        executable_step_by_step: executableScore,
        simultaneous_and_supervision: simScore,
        age_and_experience_differentiation: diffScore,
        resource_and_curriculum_fidelity: resourcesAlignmentScore,
        continuity_application: continuityScore,
        safety_space_materials: safetySpaceScore,
      },
    },
  };
}

module.exports = {
  computeExpectedAuthoringAndOrigins,
  validateGeneratedPlan,
};

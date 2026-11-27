'use strict';

const { PlannerV2Error } = require('./errors');
const { estimateTokensFromText } = require('./config');
const { getMovement } = require('./curriculum_catalog_loader');

function distributeMinutes(total, weights) {
  const sumWeights = weights.reduce((a, b) => a + b, 0);
  const raw = weights.map((w) => Math.max(2, Math.floor((total * w) / sumWeights)));
  let diff = total - raw.reduce((a, b) => a + b, 0);
  let idx = 0;
  while (diff !== 0) {
    if (diff > 0) {
      raw[idx % raw.length] += 1;
      diff -= 1;
    } else if (raw[idx % raw.length] > 2) {
      raw[idx % raw.length] -= 1;
      diff += 1;
    }
    idx += 1;
  }
  return raw;
}

function splitDurationAmongCount(blockMin, count) {
  const base = Math.max(1, Math.floor(blockMin / count));
  const out = Array(count).fill(base);
  let diff = blockMin - out.reduce((a, b) => a + b, 0);
  let i = 0;
  while (diff !== 0) {
    if (diff > 0) {
      out[i % count] += 1;
      diff -= 1;
    } else if (out[i % count] > 1) {
      out[i % count] -= 1;
      diff += 1;
    }
    i += 1;
  }
  return out;
}

/**
 * Splits an exercise's duration into exact integer sub-segments whose sum equals totalMin.
 */
function buildTimedBreakdown(totalMin, segmentNames) {
  const parts = splitDurationAmongCount(totalMin, segmentNames.length);
  const items = segmentNames.map((label, i) => `${parts[i]} min ${label}`);
  return `Tiempos internos (${items.join(' + ')} = total: ${totalMin} min).`;
}

function makeVariants(context, bText, iText, aText) {
  return {
    diferenciacion_principiantes: context.expDist.principiantes > 0 ? bText : 'Mantener progresión base del grupo.',
    diferenciacion_intermedios: context.expDist.intermedios > 0 ? iText : 'Ajustar ritmo técnico manteniendo fluidez.',
    diferenciacion_avanzados: context.expDist.avanzados > 0 ? aText : 'Explorar precisión de tiempo y lectura.',
  };
}

function buildFloorHonestNote(context) {
  if (context.space.floorType === 'tatami') return 'en el área despejada del tatami';
  if (context.space.floorType === 'cemento') return 'en zona delimitada sobre piso de cemento (evitando impactos directos)';
  if (context.space.floorType === 'madera') return 'en la superficie de madera del salón';
  return 'en la zona de práctica delimitada confirmando condiciones de piso';
}

function pickAvailableMaterialList(context, preferred) {
  const declaredLower = new Set(context.materials.map((m) => m.toLowerCase()));
  return preferred.filter((m) => declaredLower.has(m.toLowerCase()));
}

function buildResourceUsageMap(resItem) {
  if (!resItem.usage_note) return {};
  return { [resItem.resource_id]: resItem.usage_note };
}

function buildVideoNote(resItem) {
  if (!resItem.has_external_video) return null;
  return 'Recurso con video externo: integrado únicamente según título y notas escritas del profesor (el motor no inspecciona visualmente el video).';
}

function buildCancioneroRef(songTitle, rhythm, audienceFit) {
  return {
    song_title: songTitle,
    rhythm,
    audience_fit: audienceFit,
    cantiga_id: null,
    lookup_hint: `Consultar por título '${songTitle}' en Cancionero GINGA (colección cantigas); sin ID inventado.`,
  };
}

function canIncludeControlledInversion(context) {
  const confirmedSurface = context.space.floorType === 'tatami' && context.space.availableMats === true;
  const sufficientSupervision = context.instructorsAvailable >= 2 || context.participants <= 8;
  const explicitPrep =
    context.focuses.some((f) => /acrobacia/i.test(f)) ||
    /\b(bananeira|ponte|invertid)/i.test(context.freeInstructions || '');
  return confirmedSurface && sufficientSupervision && explicitPrep;
}

/**
 * Deterministic zero-cost simulated provider (`SimulatedProvider`) for PED-04C2-B/C offline verification.
 * Also supports fault injection in unit tests ONLY via constructor options (never from client payload).
 */
class SimulatedPlannerProvider {
  constructor({ catalog, faultSequence = [] } = {}) {
    this.catalog = catalog;
    this.faultSequence = Array.isArray(faultSequence) ? [...faultSequence] : [];
    this.callCount = 0;
  }

  get name() {
    return 'simulated';
  }

  async generateStructured({ promptBundle, context, repairErrors = null }) {
    this.callCount += 1;
    const fault = this.faultSequence.shift() || null;

    if (fault === 'timeout') {
      throw new PlannerV2Error(
        'PROVIDER_TIMEOUT',
        'Simulación de timeout del proveedor LLM tras exceder el presupuesto temporal.',
        { httpStatus: 504, retryable: true }
      );
    }
    if (fault === 'truncated') {
      throw new PlannerV2Error(
        'PROVIDER_TRUNCATED_OUTPUT',
        'Simulación de respuesta truncada (finish_reason=length).',
        { httpStatus: 502, retryable: true }
      );
    }
    if (fault === 'provider_rejected') {
      throw new PlannerV2Error(
        'PROVIDER_REJECTED',
        'Simulación de rechazo HTTP del proveedor LLM.',
        { httpStatus: 502, retryable: true }
      );
    }

    const plan = this._synthesizePlan(context, { repairErrors });

    if (fault === 'duration_mismatch') {
      plan.bloques[0].duracion_min += 4;
    } else if (fault === 'missing_required_resource') {
      for (const blk of plan.bloques) {
        for (const ex of blk.ejercicios) {
          ex.linked_resource_ids = [];
          ex.resource_usage_notes = {};
          ex.video_reference_note = null;
          ex.content_origin = ex.curriculum_movement_ids.length > 0 ? 'official_fiu_curriculum' : 'ai_complementary_proposal';
          ex.activity_authoring =
            ex.curriculum_movement_ids.length > 0 ? 'ai_exercise_from_official_fiu' : 'ai_complementary_proposal';
        }
      }
    } else if (fault === 'invalid_fiu_in_kids') {
      plan.bloques[0].ejercicios[0].curriculum_movement_ids = ['queixada'];
      plan.bloques[0].ejercicios[0].content_origin = 'official_fiu_curriculum';
    } else if (fault === 'unrepairable') {
      this.faultSequence.unshift('missing_required_resource');
      for (const blk of plan.bloques) {
        for (const ex of blk.ejercicios) {
          ex.linked_resource_ids = [];
          ex.resource_usage_notes = {};
          ex.video_reference_note = null;
          ex.content_origin = ex.curriculum_movement_ids.length > 0 ? 'official_fiu_curriculum' : 'ai_complementary_proposal';
          ex.activity_authoring =
            ex.curriculum_movement_ids.length > 0 ? 'ai_exercise_from_official_fiu' : 'ai_complementary_proposal';
        }
      }
    }

    for (const blk of plan.bloques || []) {
      for (const ex of blk.ejercicios || []) {
        if (!Array.isArray(ex.tiempos_internos) || ex.tiempos_internos.length === 0) {
          const d = Math.max(1, Number(ex.duracion_min || 1));
          if (d >= 3) {
            const p1 = Math.max(1, Math.floor(d / 3));
            ex.tiempos_internos = [
              { etapa: 'preparación guiada', minutos: p1 },
              { etapa: 'práctica activa y rotación', minutos: d - p1 },
            ];
          } else {
            ex.tiempos_internos = [{ etapa: 'ejecución continua', minutos: d }];
          }
        }
      }
    }

    const outJson = JSON.stringify(plan);
    const inputTokens = promptBundle?.estimatedInputTokens || 2200;
    const outputTokens = estimateTokensFromText(outJson);

    return {
      provider: 'simulated',
      model: 'simulated-planner-v2',
      isSimulated: true,
      rawPlan: plan,
      usage: {
        inputTokens,
        outputTokens,
        estimatedCostUsd: 0,
        latencyMs: 18,
      },
    };
  }

  _buildStrictTeacherOnlyPlan(context) {
    const resources = context.selectedResources;
    const movs = context.selectedMovements;
    const floorPhrase = buildFloorHonestNote(context);
    const total = context.durationMin;

    const blockSpecs = [];
    if (resources.length === 1) {
      const half = Math.floor(total / 2);
      blockSpecs.push({
        block_id: 'blk_res_1',
        fase: `Bloque Práctico · ${resources[0].category}`,
        fase_tipo: 'recurso_profesor',
        duracion_min: half,
        items: [resources[0]],
      });
      blockSpecs.push({
        block_id: 'blk_res_2',
        fase: 'Aplicación Guiada del Recurso',
        fase_tipo: 'recurso_profesor',
        duracion_min: total - half,
        items: [resources[0]],
      });
    } else {
      const durations = distributeMinutes(
        total,
        resources.map((_, idx) => (idx === 0 ? 2 : 3))
      );
      resources.forEach((res, idx) => {
        blockSpecs.push({
          block_id: `blk_prof_${idx + 1}`,
          fase: `Práctica de Pizarra: ${res.title}`,
          fase_tipo: /musica/i.test(res.category) ? 'musicalidad' : 'recurso_profesor',
          duracion_min: durations[idx],
          items: [res],
        });
      });
    }

    const singleInstructorGuard = context.instructorsAvailable === 1 && context.participants >= 15;
    const orgLabel = singleInstructorGuard ? 'Todos simultáneamente' : 'Rotación por parejas';

    const bloques = blockSpecs.map((spec, bi) => {
      const durs = splitDurationAmongCount(spec.duracion_min, spec.items.length);
      return {
        block_id: spec.block_id,
        fase: spec.fase,
        fase_tipo: spec.fase_tipo,
        duracion_min: spec.duracion_min,
        ejercicios: spec.items.map((res, ei) => {
          const exDur = durs[ei];
          const isMusic = /musica|roda|canto/i.test(`${res.category} ${res.title}`);
          const attachMovs = bi === 0 && ei === 0 && context.curriculumScope === 'adulto_fiu' ? movs.map((m) => m.movement_id) : [];
          return {
            exercise_id: `ex_prof_${bi + 1}_${ei + 1}`,
            nombre: res.title,
            tipo_actividad: isMusic ? 'musicalidad_roda' : 'ejercicio_tecnico',
            detalle: `Ejecución centrada exclusivamente en el recurso del profesor (${res.category}) ${floorPhrase}. ${res.usage_note ? `Indicaciones de uso: ${res.usage_note}. ` : ''}${res.notes || 'Trabajar por rondas continuas con ajuste técnico.'} ${buildTimedBreakdown(exDur, ['preparación y pauta', 'rondas activas en paralelo', 'ajuste y cierre breve'])}`,
            duracion_min: exDur,
            organizacion: orgLabel,
            supervision_instructors_needed: 1,
            materiales: [],
            seguridad: 'Mantener distancia visible entre participantes y ajustar altura según el espacio disponible.',
            ...makeVariants(
              context,
              'Ejecutar el patrón base del recurso a tempo lento cuidando estabilidad.',
              'Encadenar repeticiones fluidas manteniendo postura y mirada activa.',
              'Añadir variación rítmica o cambio de ángulo tras cada secuencia.'
            ),
            observaciones_profesor: 'Sesión construida exclusivamente con recursos del profesor sin propuestas complementarias IA.',
            content_origin: 'teacher_resource',
            source_origins: attachMovs.length > 0 ? ['teacher_resource', 'official_fiu_curriculum'] : ['teacher_resource'],
            activity_authoring:
              attachMovs.length > 0 ? 'teacher_resource_with_official_fiu_movements' : 'teacher_resource',
            curriculum_movement_ids: attachMovs,
            linked_resource_ids: [res.resource_id],
            resource_usage_notes: buildResourceUsageMap(res),
            cancionero_reference: isMusic
              ? buildCancioneroRef('Paraná ê', 'Benguela', context.audienceType === 'infantil' ? 'infantil' : 'adultos')
              : null,
            video_reference_note: buildVideoNote(res),
          };
        }),
      };
    });

    return {
      titulo: `Sesión Basada en Pizarra · ${context.llmPayloadContext.group_profile.group_label}`,
      duracion_total: total,
      nivel: context.audienceType === 'infantil' ? 'Infantil' : context.audienceType === 'mixto' ? 'Mixto' : 'Adultos',
      audience_type: context.audienceType,
      curriculum_scope: context.curriculumScope,
      enfoque: context.focusLabel,
      objetivo:
        context.objectives[0] ||
        'Desarrollar íntegramente los recursos seleccionados de Pizarra respetando el ritmo y espacio del grupo.',
      objetivos: context.objectives.length > 0 ? context.objectives : ['Ejecutar los recursos propios del profesor con progresión por niveles.'],
      bloques,
      consejos_instructor: 'Las propuestas complementarias IA fueron deshabilitadas por configuración: todo el guión respeta estrictamente tus recursos seleccionados.',
      continuity_applied_note: context.continuityContext
        ? `Continuidad tomada en cuenta sobre recursos propios: ${context.continuityContext.continuity_proposal || context.continuityContext.reinforce_content || 'ajuste de dificultades previas'}.`
        : '',
    };
  }

  _buildMusicalityFocusedPlan(context) {
    const total = context.durationMin;
    const blockDurs = distributeMinutes(total, [2, 3, 3, 2]);
    const floorPhrase = buildFloorHonestNote(context);
    const availInst = pickAvailableMaterialList(context, ['Berimbau', 'Pandeiro', 'Atabaque', 'Agogô']);
    const musicResources = context.selectedResources.filter((r) => /musica|roda|canto/i.test(r.category + ' ' + r.title));
    const otherResources = context.selectedResources.filter((r) => !musicResources.includes(r));
    const allRes = [...musicResources, ...otherResources];
    const songTitle = context.audienceType === 'infantil' ? 'Marinheiro só' : 'Paraná ê';
    const audienceFit = context.audienceType === 'infantil' ? 'infantil' : 'adultos';

    const res0 = allRes[0] || null;
    const res1 = allRes[1] || null;
    const block2Exercises = [];
    if (res0) {
      const subDurs = res1 ? splitDurationAmongCount(blockDurs[1], 2) : [blockDurs[1]];
      block2Exercises.push({
        exercise_id: 'ex_mus_2_1',
        nombre: res0.title,
        tipo_actividad: 'musicalidad_roda',
        detalle: `Trabajo de sección rítmica ${floorPhrase} siguiendo el recurso de Pizarra. ${res0.usage_note ? `Uso: ${res0.usage_note}. ` : ''}${res0.notes || 'Alternar palmas de 3 tiempos y base instrumental rotativa.'} ${buildTimedBreakdown(subDurs[0], ['demostración y pulso', 'práctica grupal por rondas', 'ensamble coral'])}`,
        duracion_min: subDurs[0],
        organizacion: 'Todos simultáneamente',
        supervision_instructors_needed: 1,
        materiales: availInst.slice(0, 2),
        seguridad: 'Mantener postura relajada de hombros y volumen progresivo de palmas.',
        ...makeVariants(
          context,
          'Sostener palmas continuas al pulso base sin acelerar.',
          'Alternar palmas y respuesta coral mientras se marca ginga suave.',
          'Rotar por toque de pandeiro o berimbau guiando cambios de pulso.'
        ),
        observaciones_profesor: 'Enfoque 100% musicalidad sin bloques forzados de combate o acrobacia.',
        content_origin: 'teacher_resource',
        source_origins: ['teacher_resource'],
        activity_authoring: 'teacher_resource',
        curriculum_movement_ids: [],
        linked_resource_ids: [res0.resource_id],
        resource_usage_notes: buildResourceUsageMap(res0),
        cancionero_reference: buildCancioneroRef(songTitle, 'Benguela', audienceFit),
        video_reference_note: buildVideoNote(res0),
      });
      if (res1) {
        block2Exercises.push({
          exercise_id: 'ex_mus_2_2',
          nombre: res1.title,
          tipo_actividad: 'musicalidad_roda',
          detalle: `Integración del segundo recurso de Pizarra: ${res1.usage_note || res1.notes || res1.title}. ${buildTimedBreakdown(subDurs[1], ['lectura de frase', 'repetición coral'])}`,
          duracion_min: subDurs[1],
          organizacion: 'Todos simultáneamente',
          supervision_instructors_needed: 1,
          materiales: availInst.slice(0, 1),
          seguridad: 'Cuidar respiración diafragmática antes de proyectar el canto.',
          ...makeVariants(
            context,
            'Cantar el estribillo mirando al instructor para seguir la entrada.',
            'Sostener respuesta coral firme durante todo el ciclo.',
            'Liderar una estrofa corta en turno de solista.'
          ),
          observaciones_profesor: 'Integra recurso adicional manteniendo ritmo grupal.',
          content_origin: 'teacher_resource',
          source_origins: ['teacher_resource'],
          activity_authoring: 'teacher_resource',
          curriculum_movement_ids: [],
          linked_resource_ids: [res1.resource_id],
          resource_usage_notes: buildResourceUsageMap(res1),
          cancionero_reference: buildCancioneroRef('Dona Maria do Camboatá', 'Corrido', 'todos'),
          video_reference_note: buildVideoNote(res1),
        });
      }
    } else {
      block2Exercises.push({
        exercise_id: 'ex_mus_2_1',
        nombre: 'Laboratorio de Toques: Angola, São Bento Pequeno y Benguela',
        tipo_actividad: 'musicalidad_roda',
        detalle: `1) Reconocimiento auditivo de los tres toques (${context.materialsKnown ? 'usando instrumentos disponibles' : 'con palmas corporales si no hay instrumentos declarados'}). 2) El grupo se divide en dos arcos que alternan grave y agudo manteniendo escucha activa. ${buildTimedBreakdown(blockDurs[1], ['escucha e identificación', 'práctica simultánea en dos arcos', 'ensamble con berimbau'])}`,
        duracion_min: blockDurs[1],
        organizacion: 'Todos simultáneamente',
        supervision_instructors_needed: 1,
        materiales: availInst,
        seguridad: 'Evitar tensión en muñecas al practicar baqueta/pandeiro; descansar manos cada 3 minutos.',
        ...makeVariants(
          context,
          'Distinguir con palmas el pulso lento de Angola frente al pulso medio de Benguela.',
          'Sostener patrón continuo de pandeiro o atabaque sin acelerar en el coro.',
          'Ejecutar variaciones limpias de dobrão en berimbau manteniendo estabilidad de tempo.'
        ),
        observaciones_profesor: 'Prioriza escucha colectiva por encima del volumen.',
        content_origin: 'ai_complementary_proposal',
        source_origins: ['ai_complementary_proposal'],
        activity_authoring: 'ai_complementary_proposal',
        curriculum_movement_ids: [],
        linked_resource_ids: [],
        resource_usage_notes: {},
        cancionero_reference: null,
        video_reference_note: null,
      });
    }

    return {
      titulo: `Inmersión de Musicalidad & Bateria · ${context.llmPayloadContext.group_profile.group_label}`,
      duracion_total: total,
      nivel: context.audienceType === 'infantil' ? 'Infantil' : context.audienceType === 'mixto' ? 'Mixto' : 'Adultos',
      audience_type: context.audienceType,
      curriculum_scope: context.curriculumScope,
      enfoque: context.focusLabel,
      objetivo: context.objectives[0] || 'Consolidar pulso, lectura de toques de bateria y canto responsorial en roda.',
      objetivos: context.objectives.length > 0 ? context.objectives : ['Diferenciar toques tradicionales y sostener el coro con energía pareja.'],
      bloques: [
        {
          block_id: 'blk_mus_1',
          fase: 'Activación Rítmica & Pulso Corporal',
          fase_tipo: 'calentamiento',
          duracion_min: blockDurs[0],
          ejercicios: [
            {
              exercise_id: 'ex_mus_1_1',
              nombre: 'Pulso en círculo, movilidad de muñecas y palmas de 3 tiempos',
              tipo_actividad: 'musicalidad_roda',
              detalle: `Todos en círculo ${floorPhrase}: movilidad de dedos y muñecas seguida de juego de eco rítmico trasladando el pulso de los pies a dos tipos de palmas tradicionales. ${buildTimedBreakdown(blockDurs[0], ['movilidad articular', 'juego de eco en palmas por rondas'])}`,
              duracion_min: blockDurs[0],
              organizacion: 'Todos simultáneamente',
              supervision_instructors_needed: 1,
              materiales: [],
              seguridad: 'Aflojar muñecas progresivamente sin golpear palmas con rigidez.',
              ...makeVariants(
                context,
                'Marcar pulso simple de palmas sin perder la cuenta grupal.',
                'Alternar palma plana y palma ahuecada siguiendo cambios de tempo.',
                'Coordinar desplazamiento suave de ginga mientras mantiene palmas estables.'
              ),
              observaciones_profesor: 'Estructura flexible de 4 bloques centrada exclusivamente en musicalidad.',
              content_origin: 'ai_complementary_proposal',
              source_origins: ['ai_complementary_proposal'],
              activity_authoring: 'ai_complementary_proposal',
              curriculum_movement_ids: [],
              linked_resource_ids: [],
              resource_usage_notes: {},
              cancionero_reference: null,
              video_reference_note: null,
            },
          ],
        },
        {
          block_id: 'blk_mus_2',
          fase: 'Toques, Bateria & Ritmo Colectivo',
          fase_tipo: 'musicalidad',
          duracion_min: blockDurs[1],
          ejercicios: block2Exercises,
        },
        {
          block_id: 'blk_mus_3',
          fase: 'Ladainha, Chula & Coro Responsorial',
          fase_tipo: 'musicalidad',
          duracion_min: blockDurs[2],
          ejercicios: [
            {
              exercise_id: 'ex_mus_3_1',
              nombre: `Canto responsorial tradicional ("${songTitle}") y cambios de intensidad`,
              tipo_actividad: 'musicalidad_roda',
              detalle: `Práctica frase por frase y ensamble del coro responsorial con turnos voluntarios de puxador manteniendo pulso estable. ${buildTimedBreakdown(blockDurs[2], ['dicción y melodía base', 'rondas responsoriales con cambio de puxador', 'modulación de energía'])}`,
              duracion_min: blockDurs[2],
              organizacion: 'Todos simultáneamente',
              supervision_instructors_needed: 1,
              materiales: availInst.slice(0, 2),
              seguridad: 'Cantar sin forzar cuerdas vocales; hidratación breve entre corridos.',
              ...makeVariants(
                context,
                'Memorizar con claridad el estribillo principal y responder a tiempo.',
                'Cuidar pronunciación en portugués y sostener volumen uniforme del coro.',
                'Iniciar un corrido tras la chula manteniendo afinación y llamada clara al juego.'
              ),
              observaciones_profesor: 'Referencia directa al cancionero por título sin inventar IDs.',
              content_origin: 'ai_complementary_proposal',
              source_origins: ['ai_complementary_proposal'],
              activity_authoring: 'ai_complementary_proposal',
              curriculum_movement_ids: [],
              linked_resource_ids: [],
              resource_usage_notes: {},
              cancionero_reference: buildCancioneroRef(songTitle, 'Corrido', audienceFit),
              video_reference_note: null,
            },
          ],
        },
        {
          block_id: 'blk_mus_4',
          fase: 'Roda Musical & Cierre Reflexivo',
          fase_tipo: 'vuelta_calma',
          duracion_min: blockDurs[3],
          ejercicios: [
            {
              exercise_id: 'ex_mus_4_1',
              nombre: 'Roda guiada por cambios de toque y descarga vocal/corporal',
              tipo_actividad: 'cierre',
              detalle: `Roda aplicada donde la pareja del centro adapta su cadencia únicamente según el toque que marca la bateria, seguida de respiración y cierre verbal. ${buildTimedBreakdown(blockDurs[3], ['roda musical rotativa', 'descarga de brazos y reflexión final'])}`,
              duracion_min: blockDurs[3],
              organizacion: 'Todos simultáneamente',
              supervision_instructors_needed: 1,
              materiales: availInst.slice(0, 1),
              seguridad: 'Juego simbólico suave y sin golpes de riesgo; prioridad absoluta al ritmo.',
              ...makeVariants(
                context,
                'Sostener palmas constantes cuando no está en el centro y entrar con ginga fluida.',
                'Cambiar de ritmo corporal entre Angola y Benguela al escuchar el aviso.',
                'Coordinar transición de puxador y cierre limpio al pie del berimbau.'
              ),
              observaciones_profesor: context.materialsKnown ? '' : 'Confirmar disponibilidad física de instrumentos antes de iniciar.',
              content_origin: 'ai_complementary_proposal',
              source_origins: ['ai_complementary_proposal'],
              activity_authoring: 'ai_complementary_proposal',
              curriculum_movement_ids: [],
              linked_resource_ids: [],
              resource_usage_notes: {},
              cancionero_reference: buildCancioneroRef('A hora é essa', 'São Bento Grande', audienceFit),
              video_reference_note: null,
            },
          ],
        },
      ],
      consejos_instructor: 'Esta sesión omite bloques acrobáticos o de combate técnico para respetar el enfoque exclusivo en musicalidad.',
      continuity_applied_note: context.continuityContext
        ? `Continuidad aplicada a musicalidad: ${context.continuityContext.continuity_proposal || context.continuityContext.reinforce_content || 'refuerzo rítmico'}.`
        : '',
    };
  }

  _buildInfantilPlan(context) {
    const total = context.durationMin;
    const includeRoda = context.includeMusicalityRoda;
    const blockDurs = distributeMinutes(total, includeRoda ? [2, 3, 2, 2, 1] : [2, 4, 2, 1]);
    const floorPhrase = buildFloorHonestNote(context);
    const singleInstructorGuard = context.instructorsAvailable === 1 && context.participants >= 15;
    const safeMats = context.space.availableMats === true || context.materials.some((m) => /colchoneta/i.test(m));
    const allowControlledInversions = canIncludeControlledInversion(context);
    const wantsArmadaAu = /armada/i.test(context.freeInstructions) && /a[uú]/i.test(context.freeInstructions);

    const reqResources = context.selectedResources;
    const gameMats = pickAvailableMaterialList(context, ['Conos', 'Pandeiro']);
    const soilMats = safeMats ? pickAvailableMaterialList(context, ['Colchonetas', 'Conos']) : pickAvailableMaterialList(context, ['Conos']);
    const rodaMats = pickAvailableMaterialList(context, ['Berimbau', 'Pandeiro']);

    // Favor several brief exercises per block in Infantil classes
    const warmupDurs = splitDurationAmongCount(blockDurs[0], 2);
    const warmupExercises = [
      {
        exercise_id: 'ex_inf_1_1',
        nombre: 'Activación lúdica "Animales de la Selva" (Sapo, Cangrejo y movilidad)',
        tipo_actividad: 'juego_dinamico',
        detalle: `Preparación: todos dispersos a 1.5 m ${floorPhrase}. Reglas: desplazarse imitando animales al toque del pandeiro cambiando de dirección con la señal "¡Estatua!". Rotación libre en todo el espacio sin filas. ${buildTimedBreakdown(warmupDurs[0], ['preparación e inicio suave', '2 rondas de desplazamiento animal', 'soltar muñecas y tobillos'])}`,
        duracion_min: warmupDurs[0],
        organizacion: 'Todos simultáneamente',
        supervision_instructors_needed: 1,
        materiales: gameMats.slice(0, 1),
        seguridad: 'Mirar hacia donde avanzan para evitar tropiezos o choques.',
        ...makeVariants(
          context,
          'Pasos amplios y pausados de cangrejo o rana corta sin prisa.',
          'Alternar desplazamiento bajo con giro rápido al escuchar la señal.',
          'Conectar cambio de animal con postura equilibrada de alerta.'
        ),
        observaciones_profesor: 'Actividad breve de alta activación sin espera.',
        content_origin: 'ai_complementary_proposal',
        source_origins: ['ai_complementary_proposal'],
        activity_authoring: 'ai_complementary_proposal',
        curriculum_movement_ids: [],
        linked_resource_ids: [],
        resource_usage_notes: {},
        cancionero_reference: null,
        video_reference_note: null,
      },
      {
        exercise_id: 'ex_inf_1_2',
        nombre: 'Juego "El Semáforo de Ginga y Cocorinha"',
        tipo_actividad: 'juego_dinamico',
        detalle: `Preparación: marcas visuales separadas 1.5 m ${floorPhrase}. Reglas: todos en Ginga continua al pulso; señal "¡Águila!" = bajar a Cocorinha protegiendo el rostro; señal "¡Cambio!" = girar hacia otro frente. Rondas rápidas con variantes por edad. ${buildTimedBreakdown(warmupDurs[1], ['reglas con demo visual', '3 rondas activas con cambio de señal', 'pausa breve de agua'])}`,
        duracion_min: warmupDurs[1],
        organizacion: 'Todos simultáneamente',
        supervision_instructors_needed: 1,
        materiales: gameMats,
        seguridad: 'Proteger el rostro con un brazo al bajar a Cocorinha manteniendo vista al frente.',
        ...makeVariants(
          context,
          'Solo 2 señales con ritmo lento guiado visualmente por el instructor.',
          'Alternar las señales manteniendo el vaivén rítmico de Ginga sin frenar.',
          'Salir de Cocorinha cambiando de ángulo con guardia alta.'
        ),
        observaciones_profesor: 'Prepara reflejo de esquiva antes de las progresiones técnicas.',
        content_origin: 'ai_complementary_proposal',
        source_origins: ['ai_complementary_proposal'],
        activity_authoring: 'ai_complementary_proposal',
        curriculum_movement_ids: [],
        linked_resource_ids: [],
        resource_usage_notes: {},
        cancionero_reference: null,
        video_reference_note: null,
      },
    ];

    // Block 2: Independent technical progressions BEFORE combining (plus teacher resources if selected)
    const techSlotsCount = 2 + reqResources.length;
    const techDurs = splitDurationAmongCount(blockDurs[1], techSlotsCount);
    const pairOrg = singleInstructorGuard ? 'Todos simultáneamente' : 'Rotación por parejas';
    const coreTechExercises = [
      {
        exercise_id: 'ex_inf_2_1',
        nombre: wantsArmadaAu
          ? 'Progresión técnica independiente 1: Ginga y giro de Armada controlado'
          : 'Progresión técnica independiente 1: Base de Ginga y Cocorinha en espejo',
        tipo_actividad: 'juego_dinamico',
        detalle: wantsArmadaAu
          ? `Preparación: parejas a 2 metros de distancia ${floorPhrase}. Reglas: antes de combinar movimientos, practican de forma independiente la Armada controlada girando cadera y pasando el pie sobre un marcador imaginario al escuchar la señal "¡Viento!". Rondas alternadas por rol con rotación cada 2 minutos y variantes por edad (${context.ageMin}–${context.ageMax} años). ${buildTimedBreakdown(techDurs[0], ['preparación y postura de pies', 'rondas alternadas por rol con rotación', 'feedback breve'])}`
          : `Preparación: todos en 2 líneas paralelas enfrentadas ${floorPhrase}. Reglas: trabajan de forma independiente la postura de Ginga y el descenso seguro de Cocorinha al ritmo del profesor, rotando pareja cada ronda con variantes según experiencia. ${buildTimedBreakdown(techDurs[0], ['alineación base de Ginga', 'rondas en espejo con Cocorinha y rotación'])}`,
        duracion_min: techDurs[0],
        organizacion: pairOrg,
        supervision_instructors_needed: 1,
        materiales: gameMats,
        seguridad: 'Cero contacto físico; respetar distancia de giro de Armada manteniendo vista al compañero.',
        ...makeVariants(
          context,
          'Recién inicia: enfocarse en pasos amplios de Ginga y media rotación controlada sin perder balance.',
          'Nivel intermedio: ejecutar Armada limpia retornando directo a la base trasera.',
          'Con experiencia previa: enlazar retorno de Armada con Cocorinha protectora estable.'
        ),
        observaciones_profesor: 'Progresión independiente previa antes de combinar con desplazamientos de manos.',
        content_origin: 'ai_complementary_proposal',
        source_origins: ['ai_complementary_proposal'],
        activity_authoring: 'ai_complementary_proposal',
        curriculum_movement_ids: [],
        linked_resource_ids: [],
        resource_usage_notes: {},
        cancionero_reference: null,
        video_reference_note: null,
      },
      {
        exercise_id: 'ex_inf_2_2',
        nombre: wantsArmadaAu
          ? 'Progresión independiente 2 + Juego integrador: De Aú lateral a "El Puente y el Viento"'
          : 'Progresión técnica independiente 2: Aú inicial y desplazamiento cooperativo',
        tipo_actividad: 'juego_dinamico',
        detalle: `Preparación: carril visual amplio ${floorPhrase}. Reglas: primero practican 2 minutos de Aú independiente por oleadas paralelas y luego juegan a la señal "¡Estrella!" (Aú controlado) y señal "${wantsArmadaAu ? '¡Viento!' : '¡Escudo!'}" (${wantsArmadaAu ? 'Armada al aire' : 'Cocorinha'}), cambiando pareja al sonar palmas en rondas cortas y con variantes por nivel. ${buildTimedBreakdown(techDurs[1], ['progresión técnica aislada de Aú', 'rondas de juego combinando señales con rotación', 'recuperación'])}`,
        duracion_min: techDurs[1],
        organizacion: 'Todos simultáneamente',
        supervision_instructors_needed: 1,
        materiales: gameMats,
        seguridad: 'Apoyar manos firmes con dedos separados antes de elevar pies; mantener carril libre.',
        ...makeVariants(
          context,
          'Principiante en Aú: pasar un pie a la vez sobre línea imaginaria manteniendo cadera baja.',
          'Nivel intermedio: elevar cadera lateralmente aterrizando suave sobre pie guía.',
          'Avanzado que ya ejecuta Aú: encadenar aterrizaje fluido hacia base de Ginga sin añadir saltos ni giros complejos.'
        ),
        observaciones_profesor: 'Integra progresión técnica previa antes del juego combinado; sin atribución FIU infantil no validada.',
        content_origin: 'ai_complementary_proposal',
        source_origins: ['ai_complementary_proposal'],
        activity_authoring: 'ai_complementary_proposal',
        curriculum_movement_ids: [],
        linked_resource_ids: [],
        resource_usage_notes: {},
        cancionero_reference: null,
        video_reference_note: null,
      },
    ];

    for (let ri = 0; ri < reqResources.length; ri++) {
      const r0 = reqResources[ri];
      coreTechExercises.push({
        exercise_id: `ex_inf_2_${3 + ri}`,
        nombre: r0.title,
        tipo_actividad: 'juego_dinamico',
        detalle: `Preparación y dinámica del recurso del profesor ${floorPhrase}. Reglas y rotaciones continuas por señal sonora: ${r0.usage_note || r0.notes || 'participación simultánea en rondas cortas con variantes por nivel.'} ${buildTimedBreakdown(techDurs[2 + ri], ['preparación del recurso', 'rondas de ejecución guiada'])}`,
        duracion_min: techDurs[2 + ri],
        organizacion: 'Todos simultáneamente',
        supervision_instructors_needed: 1,
        materiales: [],
        seguridad: 'Supervisión visual directa del instructor en todo el espacio.',
        ...makeVariants(
          context,
          'Ritmo guiado paso a paso con demostración frontal.',
          'Secuencia continua sin pausas entre repeticiones.',
          'Variar lado dominante manteniendo postura limpia.'
        ),
        observaciones_profesor: 'Recurso de Pizarra adaptado al público infantil.',
        content_origin: 'teacher_resource',
        source_origins: ['teacher_resource'],
        activity_authoring: 'teacher_resource',
        curriculum_movement_ids: [],
        linked_resource_ids: [r0.resource_id],
        resource_usage_notes: buildResourceUsageMap(r0),
        cancionero_reference: null,
        video_reference_note: buildVideoNote(r0),
      });
    }

    const sueloOrg = singleInstructorGuard ? 'Todos simultáneamente' : 'Rotación por parejas';
    const soilExercise = allowControlledInversions
      ? {
          exercise_id: 'ex_inf_3_1',
          nombre: 'Progresiones supervisadas sobre colchonetas: Aú controlado y apoyos de equilibrio',
          tipo_actividad: 'progresion_suelo',
          detalle: `Preparación: zona con colchonetas confirmadas y supervisión múltiple. Reglas: trabajo por oleadas de 4 niños en Aú alineado y apoyo invertido asistido por pareja/instructor en 3 rondas con descanso de muñecas. ${buildTimedBreakdown(blockDurs[2], ['preparación de muñecas', 'rondas progresivas con asistencia y rotación'])}`,
          duracion_min: blockDurs[2],
          organizacion: sueloOrg,
          supervision_instructors_needed: context.instructorsAvailable >= 2 ? 2 : 1,
          materiales: soilMats,
          seguridad: 'Solo con tatami + colchonetas confirmadas y supervisión directa constante.',
          ...makeVariants(
            context,
            'Apoyos de manos cortos en L baja con pies cerca del suelo.',
            'Aú lateral completo con caderas altas y aterrizaje silencioso.',
            'Sostener 2 segundos de control vertical asistido antes de regresar a base.'
          ),
          observaciones_profesor: 'Condiciones explícitas de superficie, colchonetas y supervisión verificadas.',
          content_origin: 'ai_complementary_proposal',
          source_origins: ['ai_complementary_proposal'],
          activity_authoring: 'ai_complementary_proposal',
          curriculum_movement_ids: [],
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        }
      : {
          exercise_id: 'ex_inf_3_1',
          nombre: 'Movilidad en suelo segura: Aú bajito, Rolê lateral y desplazamientos animales',
          tipo_actividad: 'progresion_suelo',
          detalle: `Sin condiciones explícitas de inversión exigente (${context.space.floorType}, colchonetas=${context.space.availableMats === null ? 'sin confirmar' : context.space.availableMats}, instructores=${context.instructorsAvailable}): todo el grupo en frente visual único alterna rolê lateral lento y Aú bajito en oleadas simultáneas sin inversiones verticales ni puentes exigentes. ${buildTimedBreakdown(blockDurs[2], ['movilidad de apoyo bajo', 'oleadas simultáneas de Aú y rolê con rotación'])}`,
          duracion_min: blockDurs[2],
          organizacion: 'Todos simultáneamente',
          supervision_instructors_needed: 1,
          materiales: soilMats,
          seguridad: 'Cero inversiones verticales forzadas; mantener control suave de manos y rodillas.',
          ...makeVariants(
            context,
            'Rolê amplio apoyando manos firmes y manteniendo mirada al frente.',
            'Alternar rolê lateral con Aú controlado sin perder ritmo.',
            'Encadenar dos desplazamientos bajos limpios aterrizando directo en Ginga.'
          ),
          observaciones_profesor: 'Evita ejercicios invertidos exigentes cuando faltan superficie/colchonetas, preparación o supervisión suficiente.',
          content_origin: 'ai_complementary_proposal',
          source_origins: ['ai_complementary_proposal'],
          activity_authoring: 'ai_complementary_proposal',
          curriculum_movement_ids: [],
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        };

    const bloques = [
      {
        block_id: 'blk_inf_1',
        fase: 'Calentamiento Lúdico & Juegos Motores',
        fase_tipo: 'calentamiento',
        duracion_min: blockDurs[0],
        ejercicios: warmupExercises,
      },
      {
        block_id: 'blk_inf_2',
        fase: 'Progresiones Técnicas & Juegos por Niveles',
        fase_tipo: 'juegos',
        duracion_min: blockDurs[1],
        ejercicios: coreTechExercises,
      },
      {
        block_id: 'blk_inf_3',
        fase: 'Control Corporal & Desplazamientos en Suelo',
        fase_tipo: 'acrobacias_suelo',
        duracion_min: blockDurs[2],
        ejercicios: [soilExercise],
      },
    ];

    if (includeRoda) {
      const rodaDurs = splitDurationAmongCount(blockDurs[3], 2);
      bloques.push({
        block_id: 'blk_inf_4',
        fase: 'Roda Infantil & Musicalidad',
        fase_tipo: 'roda_musicalidad',
        duracion_min: blockDurs[3],
        ejercicios: [
          {
            exercise_id: 'ex_inf_4_1',
            nombre: 'Canto y palmas rítmicas: "Marinheiro só"',
            tipo_actividad: 'musicalidad_roda',
            detalle: `Preparación: círculo sentado o de pie. Reglas: aprendizaje responsorial del estribillo tradicional infantil "Marinheiro só" acompañando con palmas de 3 tiempos en dos rondas de intensidad. ${buildTimedBreakdown(rodaDurs[0], ['enseñanza de estribillo y palmas', 'rondas cantadas en coro'])}`,
            duracion_min: rodaDurs[0],
            organizacion: 'Todos simultáneamente',
            supervision_instructors_needed: 1,
            materiales: rodaMats,
            seguridad: 'Cantar con voz natural y palmas coordinadas sin golpear manos con tensión.',
            ...makeVariants(
              context,
              'Responder el coro principal manteniendo palmas parejas.',
              'Cantar estrofa y coro siguiendo las variaciones de velocidad.',
              'Apoyar sosteniendo pulso en pandeiro o iniciando una estrofa corta.'
            ),
            observaciones_profesor: 'Canción infantil concreta preparada para buscar en Cancionero GINGA sin inventar IDs.',
            content_origin: 'ai_complementary_proposal',
            source_origins: ['ai_complementary_proposal'],
            activity_authoring: 'ai_complementary_proposal',
            curriculum_movement_ids: [],
            linked_resource_ids: [],
            resource_usage_notes: {},
            cancionero_reference: buildCancioneroRef('Marinheiro só', 'Corrido', 'infantil'),
            video_reference_note: null,
          },
          {
            exercise_id: 'ex_inf_4_2',
            nombre: 'Roda infantil cooperativa por turnos cortos',
            tipo_actividad: 'musicalidad_roda',
            detalle: `Preparación: círculo amplio sosteniendo palmas y el canto "Sim sim sim, não não não". Reglas: parejas entran al centro por turnos de 30–40 segundos aplicando Ginga, Cocorinha, Armada o Aú según nivel, rotando al toque de señal. ${buildTimedBreakdown(rodaDurs[1], ['apertura de juego guiado', 'rondas rápidas garantizando participación de todos'])}`,
            duracion_min: rodaDurs[1],
            organizacion: 'Turnos',
            supervision_instructors_needed: 1,
            materiales: rodaMats,
            seguridad: 'Juego cooperativo sin contacto; mantener tamaño uniforme de la roda.',
            ...makeVariants(
              context,
              'Entrar 20 s mostrando Ginga firme y Cocorinha.',
              'Integrar Aú lateral limpio y saludo al centro.',
              'Modular ritmo y altura al jugar con compañeros menores.'
            ),
            observaciones_profesor: 'Propuesta infantil general; sin atribuir graduaciones FIU infantiles no validadas.',
            content_origin: 'ai_complementary_proposal',
            source_origins: ['ai_complementary_proposal'],
            activity_authoring: 'ai_complementary_proposal',
            curriculum_movement_ids: [],
            linked_resource_ids: [],
            resource_usage_notes: {},
            cancionero_reference: buildCancioneroRef('Sim sim sim, não não não', 'Corrido', 'infantil'),
            video_reference_note: null,
          },
        ],
      });
    }

    bloques.push({
      block_id: 'blk_inf_5',
      fase: 'Vuelta a la Calma & Valores',
      fase_tipo: 'vuelta_calma',
      duracion_min: blockDurs[blockDurs.length - 1],
      ejercicios: [
        {
          exercise_id: 'ex_inf_5_1',
          nombre: 'Respiración guiada y círculo de compañerismo',
          tipo_actividad: 'cierre',
          detalle: `En círculo tranquilo: estiramiento suave de espalda y piernas seguido de respiraciones lentas y cierre breve sobre cuidado mutuo y escucha. ${buildTimedBreakdown(blockDurs[blockDurs.length - 1], ['estiramiento y respiración', 'círculo de valores'])}`,
          duracion_min: blockDurs[blockDurs.length - 1],
          organizacion: 'Todos simultáneamente',
          supervision_instructors_needed: 1,
          materiales: [],
          seguridad: 'Estiramientos suaves sin forzar articulaciones.',
          ...makeVariants(
            context,
            'Imitar la postura de respiración guiada por el instructor.',
            'Mantener respiración nasal lenta y postura erguida.',
            'Ayudar al instructor a ordenar el espacio y despedir la roda.'
          ),
          observaciones_profesor: 'Cierre sereno adecuado a edades tempranas.',
          content_origin: 'ai_complementary_proposal',
          source_origins: ['ai_complementary_proposal'],
          activity_authoring: 'ai_complementary_proposal',
          curriculum_movement_ids: [],
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        },
      ],
    });

    return {
      titulo: wantsArmadaAu
        ? `Capoeira Infantil: Juegos con Armada, Aú y Ritmo (${context.ageMin}–${context.ageMax} años)`
        : `Selva y Ritmo: Ginga, Esquivas Lúdicas y Aú (${context.ageMin}–${context.ageMax} años)`,
      duracion_total: total,
      nivel: 'Infantil',
      audience_type: 'infantil',
      curriculum_scope: context.curriculumScope,
      enfoque: context.focusLabel,
      objetivo:
        context.objectives[0] ||
        `Desarrollar coordinación motriz, ritmo y base técnica infantil (${context.ageMin}–${context.ageMax} años) mediante ejercicios breves y juegos simultáneos.`,
      objetivos:
        context.objectives.length > 0
          ? context.objectives
          : [
              'Diferenciar retos de Ginga, esquiva y Aú según edad y experiencia técnica real',
              'Mantener participación activa simultánea cuidando supervisión y seguridad',
            ],
      bloques,
      consejos_instructor: 'Currículo Infantil FIU en fase de extracción oficial pendiente: todas las técnicas nombradas (Ginga, Cocorinha, Armada, Aú) se proponen como práctica general infantil sin asignaciones oficiales de corda FIU.',
      continuity_applied_note: context.continuityContext
        ? `Continuidad infantil aplicada: ${context.continuityContext.continuity_proposal || context.continuityContext.reinforce_content || 'refuerzo coordinativo'}.`
        : '',
    };
  }

  _buildAdultOrMixedPlan(context) {
    const total = context.durationMin;
    const includeRoda = context.includeMusicalityRoda;
    const isAngola = context.focuses.some((f) => /angola/i.test(f));
    const singleInstructorGuard = context.instructorsAvailable === 1 && context.participants >= 15;
    const floorPhrase = buildFloorHonestNote(context);
    const safeMats = context.space.availableMats === true || context.materials.some((m) => /colchoneta/i.test(m));

    const weights = includeRoda ? [2, 4, 2, 2, 1] : [2, 5, 2, 1];
    const blockDurs = distributeMinutes(total, weights);

    const movs = context.selectedMovements;
    const resources = context.selectedResources;
    const reqMovIds = movs.map((m) => m.movement_id);
    const movNames = movs.map((m) => m.canonical_name);

    const isCordaMatch = context.cordaMeta ? `${context.cordaMeta.nombre_manual}` : 'Base general';
    const pairOrg = singleInstructorGuard ? 'Todos simultáneamente' : 'Rotación por parejas';
    const techMats = pickAvailableMaterialList(context, ['Conos', 'Pandeiro']);
    const soilMats = safeMats ? pickAvailableMaterialList(context, ['Colchonetas']) : [];
    const rodaMats = pickAvailableMaterialList(context, ['Berimbau', 'Pandeiro', 'Atabaque']);

    const wantsRepeat =
      /repetir|repasar/i.test(context.freeInstructions) ||
      Boolean(context.continuityContext?.reinforce_content);

    const techExercises = [];
    const techRes = resources.find((r) => !/musica|roda/i.test(r.category + ' ' + r.title)) || null;
    const musRes = resources.find((r) => /musica|roda/i.test(r.category + ' ' + r.title)) || null;
    const extraResources = resources.filter((r) => r !== techRes && r !== musRes);

    // Add independent technical progression BEFORE combining when >=2 FIU movements are selected
    const addPrepStep = reqMovIds.length >= 2 && !techRes ? 1 : 0;
    const needSlots =
      techRes && reqMovIds.length > 0
        ? 1 + (reqMovIds.length > 1 ? 1 : 0) + extraResources.length
        : (techRes ? 1 : 0) + (reqMovIds.length > 0 || !techRes ? 1 : 0) + addPrepStep + extraResources.length;
    const techSubDurs = splitDurationAmongCount(blockDurs[1], Math.max(1, needSlots));
    let slotIdx = 0;

    if (techRes && reqMovIds.length > 0) {
      const primaryMovId = reqMovIds[0];
      const primaryMovName = movNames[0];
      const remainingMovIds = reqMovIds.slice(1);
      const dur1 = techSubDurs[slotIdx++];

      techExercises.push({
        exercise_id: 'ex_ad_2_1',
        nombre: `${techRes.title} con ${primaryMovName}`,
        tipo_actividad: isAngola ? 'angola_dialogo' : 'drill_parejas',
        detalle: `Ejercicio combinado que integra el recurso del profesor ('${techRes.title}') preparando de forma progresiva '${primaryMovName}' ${floorPhrase}. ${techRes.usage_note ? `Uso indicado: ${techRes.usage_note}. ` : ''}${techRes.notes || 'Trabajo simultáneo por parejas.'} ${buildTimedBreakdown(dur1, ['progresión técnica aislada de base', 'rondas alternadas en triángulo con rotación'])}`,
        duracion_min: dur1,
        organizacion: pairOrg,
        supervision_instructors_needed: 1,
        materiales: techMats,
        seguridad: 'Mantener distancia de brazo + 1 paso; controlar trayectoria de salida antes de acelerar.',
        ...makeVariants(
          context,
          `Ejecutar ${primaryMovName} lento siguiendo la referencia espacial del recurso.`,
          `Encadenar ${primaryMovName} con retorno fluido manteniendo guardia alta.`,
          `Variar ángulo y ritmo de entrada aplicando lectura de tiempo sobre el compañero.`
        ),
        observaciones_profesor: 'Combina recurso propio del profesor con movimiento oficial FIU (precedencia: teacher_resource).',
        content_origin: 'teacher_resource',
        source_origins: ['teacher_resource', 'official_fiu_curriculum'],
        activity_authoring: 'teacher_resource_with_official_fiu_movements',
        curriculum_movement_ids: [primaryMovId],
        linked_resource_ids: [techRes.resource_id],
        resource_usage_notes: buildResourceUsageMap(techRes),
        cancionero_reference: null,
        video_reference_note: buildVideoNote(techRes),
      });

      if (remainingMovIds.length > 0) {
        const remNames = remainingMovIds.map((id) => getMovement(this.catalog, id)?.canonical_name || id).join(' + ');
        const dur2 = techSubDurs[slotIdx++];
        techExercises.push({
          exercise_id: 'ex_ad_2_2',
          nombre: `Secuencia técnica diseñada por IA: ${remNames} (${isCordaMatch})`,
          tipo_actividad: isAngola ? 'angola_dialogo' : 'drill_parejas',
          detalle: `Secuencia de diálogo continuo ${floorPhrase} conectando ${remNames} tras su progresión independiente en parejas sin tiempos muertos.${wantsRepeat ? ` Incluye repetición guiada sobre '${context.continuityContext?.reinforce_content || 'la base de la clase previa'}' para consolidar técnica.` : ''} ${buildTimedBreakdown(dur2, ['repaso técnico aislado por lado', 'rondas continuas con cambio de pareja'])}`,
          duracion_min: dur2,
          organizacion: pairOrg,
          supervision_instructors_needed: 1,
          materiales: [],
          seguridad: 'Controlar rango articular y mirada constante al compañero durante la esquiva.',
          ...makeVariants(
            context,
            'Marcar cada fase con pausa breve de verificación en base.',
            'Mantener fluidez continua entre ataque y esquiva sin cruzar los pies.',
            'Integrar finta previa y contragolpe inmediato ajustado al tempo del juego.'
          ),
          observaciones_profesor: 'Actividad diseñada por IA a partir de movimientos oficiales FIU (distinta al movimiento aislado).',
          content_origin: 'official_fiu_curriculum',
          source_origins: ['official_fiu_curriculum', 'ai_designed_activity'],
          activity_authoring: 'ai_exercise_from_official_fiu',
          curriculum_movement_ids: remainingMovIds,
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        });
      }
    } else {
      if (techRes) {
        const durT = techSubDurs[slotIdx++];
        techExercises.push({
          exercise_id: 'ex_ad_2_1',
          nombre: techRes.title,
          tipo_actividad: 'drill_parejas',
          detalle: `Aplicación práctica del recurso del profesor ${floorPhrase}: ${techRes.usage_note || techRes.notes || 'trabajo en parejas simultáneas.'} ${buildTimedBreakdown(durT, ['pauta técnica inicial', 'rondas de práctica con rotación'])}`,
          duracion_min: durT,
          organizacion: pairOrg,
          supervision_instructors_needed: 1,
          materiales: techMats,
          seguridad: 'Mantener control de distancia y postura equilibrada.',
          ...makeVariants(
            context,
            'Ejecutar patrón completo a ritmo pausado.',
            'Aumentar continuidad y precisión de ángulos.',
            'Variar velocidad según lectura del compañero.'
          ),
          observaciones_profesor: 'Recurso directo de la Pizarra del instructor.',
          content_origin: 'teacher_resource',
          source_origins: ['teacher_resource'],
          activity_authoring: 'teacher_resource',
          curriculum_movement_ids: [],
          linked_resource_ids: [techRes.resource_id],
          resource_usage_notes: buildResourceUsageMap(techRes),
          cancionero_reference: null,
          video_reference_note: buildVideoNote(techRes),
        });
      }

      if (addPrepStep > 0) {
        const prepDur = techSubDurs[slotIdx++];
        techExercises.push({
          exercise_id: `ex_ad_2_${slotIdx}`,
          nombre: `Progresión técnica independiente previa: ${movNames[0]}`,
          tipo_actividad: isAngola ? 'angola_dialogo' : 'ejercicio_tecnico',
          detalle: `Antes de combinar los movimientos seleccionados, todo el grupo practica de manera independiente la mecánica de ${movNames[0]} ${floorPhrase} corrigiendo apoyos y cadera. ${buildTimedBreakdown(prepDur, ['repeticiones bilaterales guiadas', 'ajuste fino de guardia y retorno'])}`,
          duracion_min: prepDur,
          organizacion: 'Todos simultáneamente',
          supervision_instructors_needed: 1,
          materiales: [],
          seguridad: 'Controlar alineación de rodilla de apoyo antes de aumentar velocidad.',
          ...makeVariants(
            context,
            'Dividir el gesto en dos tiempos claros con pausa en base.',
            'Fluidez bilateral continua manteniendo altura media.',
            'Modular amplitud y ritmo sin perder equilibrio.'
          ),
          observaciones_profesor: 'Progresión previa independiente antes de la secuencia combinada.',
          content_origin: 'official_fiu_curriculum',
          source_origins: ['official_fiu_curriculum', 'ai_designed_activity'],
          activity_authoring: 'ai_exercise_from_official_fiu',
          curriculum_movement_ids: [reqMovIds[0]],
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        });
      }

      if (reqMovIds.length > 0) {
        const durSeq = techSubDurs[slotIdx++];
        techExercises.push({
          exercise_id: `ex_ad_2_${slotIdx}`,
          nombre: `Secuencia guiada desde currículo FIU: ${movNames.join(' + ')}`,
          tipo_actividad: isAngola ? 'angola_dialogo' : 'drill_parejas',
          detalle: `Actividad diseñada en parejas ${floorPhrase} integrando ${movNames.join(' y ')} sin colas ni pausas muertas.${wantsRepeat ? ` Retoma explícitamente el refuerzo pendiente: ${context.continuityContext?.reinforce_content || 'repetición técnica justificada'}.` : ''} ${buildTimedBreakdown(durSeq, ['acoplamiento lento en pareja', 'rondas de diálogo continuo con rotación'])}`,
          duracion_min: durSeq,
          organizacion: pairOrg,
          supervision_instructors_needed: 1,
          materiales: [],
          seguridad: 'Mantener distancia controlada sin impacto físico y cuidar retorno a ginga estable.',
          ...makeVariants(
            context,
            'Base estable de pies con ritmo moderado antes de girar.',
            'Conectar entrada y salida manteniendo mirada continua.',
            'Añadir contraataque encadenado o variación de ritmo en tiempo real.'
          ),
          observaciones_profesor: 'Secuencia diseñada a partir de movimientos FIU validados.',
          content_origin: 'official_fiu_curriculum',
          source_origins: ['official_fiu_curriculum', 'ai_designed_activity'],
          activity_authoring: 'ai_exercise_from_official_fiu',
          curriculum_movement_ids: reqMovIds,
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        });
      } else if (!techRes) {
        const durBase = techSubDurs[slotIdx++];
        techExercises.push({
          exercise_id: 'ex_ad_2_1',
          nombre: isAngola
            ? 'Diálogo de Juego Bajo: Negativa, Chamada y Salida Circular'
            : 'Secuencia adaptativa en parejas de base, esquiva y salida lateral',
          tipo_actividad: isAngola ? 'angola_dialogo' : 'drill_parejas',
          detalle: `Práctica simultánea en parejas ${floorPhrase} adaptada al alcance '${context.curriculumScope}' sin atribución automática al currículo Adulto FIU. ${buildTimedBreakdown(durBase, ['progresión técnica individual', 'rondas continuas cambiando pareja'])}`,
          duracion_min: durBase,
          organizacion: pairOrg,
          supervision_instructors_needed: 1,
          materiales: techMats,
          seguridad: 'Regular altura y velocidad según diferencia de edad o nivel de cada pareja.',
          ...makeVariants(
            context,
            'Priorizar estabilidad postural y lectura visual lenta.',
            'Encadenar dos acciones continuas en base media.',
            'Modular tempo y distancia para sostener un diálogo fluido.'
          ),
          observaciones_profesor: 'Propuesta sin pista curricular FIU automática.',
          content_origin: 'ai_complementary_proposal',
          source_origins: ['ai_complementary_proposal'],
          activity_authoring: 'ai_complementary_proposal',
          curriculum_movement_ids: [],
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        });
      }
    }

    for (const extraRes of extraResources) {
      const durExtra = techSubDurs[slotIdx++] || 5;
      techExercises.push({
        exercise_id: `ex_ad_2_${slotIdx}`,
        nombre: extraRes.title,
        tipo_actividad: 'drill_parejas',
        detalle: `Integración del recurso de Pizarra ${floorPhrase}: ${extraRes.usage_note || extraRes.notes || 'ejecución simultánea por parejas.'} ${buildTimedBreakdown(durExtra, ['explicación breve', 'ejecución por rondas'])}`,
        duracion_min: durExtra,
        organizacion: pairOrg,
        supervision_instructors_needed: 1,
        materiales: [],
        seguridad: 'Cuidar espacio lateral respecto a las demás parejas.',
        ...makeVariants(
          context,
          'Ejecución pausada cuidando técnica básica.',
          'Ritmo sostenido con cambio fluido.',
          'Integración dinámica en secuencia continua.'
        ),
        observaciones_profesor: 'Recurso adicional de Pizarra.',
        content_origin: 'teacher_resource',
        source_origins: ['teacher_resource'],
        activity_authoring: 'teacher_resource',
        curriculum_movement_ids: [],
        linked_resource_ids: [extraRes.resource_id],
        resource_usage_notes: buildResourceUsageMap(extraRes),
        cancionero_reference: null,
        video_reference_note: buildVideoNote(extraRes),
      });
    }

    const soloOrControlBlock = {
      block_id: 'blk_ad_3',
      fase: safeMats ? 'Transiciones de Suelo & Control Corporal' : 'Transiciones Bajas & Desplazamiento Seguro en Piso',
      fase_tipo: 'acrobacias_suelo',
      duracion_min: blockDurs[2],
      ejercicios: [
        {
          exercise_id: 'ex_ad_3_1',
          nombre: safeMats
            ? 'Progresión controlada de transición baja y rolê con apoyo'
            : 'Desplazamientos bajos sin impacto: troca de base y salida en rolê controlada',
          tipo_actividad: 'progresion_suelo',
          detalle: safeMats
            ? `Trabajo ${singleInstructorGuard ? 'simultáneo en línea frente al instructor' : 'en parejas sobre zona con colchonetas'} enlazando transición baja y salida en rolê limpia con mirada al centro. ${buildTimedBreakdown(blockDurs[2], ['preparación de muñecas y apoyos', 'series alternadas de rolê y retorno'])}`
            : `Dado que el piso es '${context.space.floorType}' sin protección amortiguada confirmada, se trabaja movilidad baja controlada (sin saltos ni caídas invertidas): descenso controlado en esquiva, apoyo firme de palma y paso amplio hacia la nueva base. ${buildTimedBreakdown(blockDurs[2], ['movilidad de base baja', 'rondas controladas de rolê y cambio de ángulo'])}`,
          duracion_min: blockDurs[2],
          organizacion: singleInstructorGuard ? 'Todos simultáneamente' : 'Rotación por parejas',
          supervision_instructors_needed: 1,
          materiales: soilMats,
          seguridad: 'Sin saltos acrobáticos ni caídas bruscas sobre piso duro; mantener control de muñecas y mirada frontal.',
          ...makeVariants(
            context,
            'Realizar la transición lenta en 3 apoyos manteniendo cadera equilibrada.',
            'Unir ambos lados de forma continua sin cruzar los pies.',
            'Conectar la salida con cambio de dirección de 90 grados.'
          ),
          observaciones_profesor: 'Bloque separado del trabajo técnico de combate y adaptado al piso real.',
          content_origin: 'ai_complementary_proposal',
          source_origins: ['ai_complementary_proposal'],
          activity_authoring: 'ai_complementary_proposal',
          curriculum_movement_ids: [],
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        },
      ],
    };

    const bloques = [
      {
        block_id: 'blk_ad_1',
        fase: 'Movilidad Articular & Activación Simultánea',
        fase_tipo: 'calentamiento',
        duracion_min: blockDurs[0],
        ejercicios: [
          {
            exercise_id: 'ex_ad_1_1',
            nombre: 'Preparación articular de muñecas/caderas y ginga progresiva',
            tipo_actividad: 'ejercicio_tecnico',
            detalle: `Todos simultáneamente ${floorPhrase} realizando movilidad articular ascendente seguida de ginga con cambios de frente al pulso del grupo para activar equilibrio sin filas. ${buildTimedBreakdown(blockDurs[0], ['movilidad de muñecas, hombros y cadera', 'ginga progresiva en paralelo'])}`,
            duracion_min: blockDurs[0],
            organizacion: 'Todos simultáneamente',
            supervision_instructors_needed: 1,
            materiales: [],
            seguridad: 'Mantener al menos 1.5 m de separación lateral.',
            ...makeVariants(
              context,
              'Pausa breve en cada apoyo de ginga para estabilizar rodilla y tobillo.',
              'Ritmo fluido bajando centro de gravedad en la base trasera.',
              'Integrar cambios de nivel suaves preparando el bloque principal.'
            ),
            observaciones_profesor: 'Activación paralela para aprovechar el tiempo desde el minuto 1.',
            content_origin: 'ai_complementary_proposal',
            source_origins: ['ai_complementary_proposal'],
            activity_authoring: 'ai_complementary_proposal',
            curriculum_movement_ids: [],
            linked_resource_ids: [],
            resource_usage_notes: {},
            cancionero_reference: null,
            video_reference_note: null,
          },
        ],
      },
      {
        block_id: 'blk_ad_2',
        fase: isAngola ? 'Fundamentos & Diálogo de Capoeira Angola' : 'Técnica Marcial & Secuencias en Parejas',
        fase_tipo: isAngola ? 'angola' : 'tecnica',
        duracion_min: blockDurs[1],
        ejercicios: techExercises,
      },
      soloOrControlBlock,
    ];

    if (includeRoda) {
      const rodaSongTitle = isAngola ? 'Saudades de Angola' : 'Paraná ê';
      bloques.push({
        block_id: 'blk_ad_4',
        fase: 'Roda de Treino & Musicalidad Aplicada',
        fase_tipo: 'roda_musicalidad',
        duracion_min: blockDurs[3],
        ejercicios: [
          {
            exercise_id: 'ex_ad_4_1',
            nombre: musRes ? musRes.title : `Roda cadenciada ("${rodaSongTitle}") con rotación continua`,
            tipo_actividad: 'musicalidad_roda',
            detalle: musRes
              ? `Aplicación en roda del recurso '${musRes.title}' ${floorPhrase}. ${musRes.usage_note || musRes.notes || 'Rotaciones rápidas manteniendo coro activo y diálogo técnico.'} ${buildTimedBreakdown(blockDurs[3], ['afinación de coro y palmas', 'rondas continuas de roda'])}`
              : `Roda guiada en círculo único ${floorPhrase} cantando "${rodaSongTitle}" y aplicando el objetivo del día en turnos rápidos de 45–60 segundos. ${buildTimedBreakdown(blockDurs[3], ['apertura vocal e instrumental', 'entradas rotativas de juego dialogado'])}`,
            duracion_min: blockDurs[3],
            organizacion: 'Todos simultáneamente',
            supervision_instructors_needed: 1,
            materiales: rodaMats,
            seguridad: 'Juego dialogado sin golpes de contacto; el círculo mantiene atención visual constante.',
            ...makeVariants(
              context,
              'Priorizar ritmo de ginga, defensa clara y palmas firmes fuera del centro.',
              'Aplicar una secuencia completa trabajada en la sesión.',
              'Adaptar velocidad al compañero y sostener canto o instrumento.'
            ),
            observaciones_profesor: musRes ? 'Integra recurso musical de Pizarra.' : 'Referencia al cancionero por título sin inventar IDs.',
            content_origin: musRes ? 'teacher_resource' : 'ai_complementary_proposal',
            source_origins: musRes ? ['teacher_resource'] : ['ai_complementary_proposal'],
            activity_authoring: musRes ? 'teacher_resource' : 'ai_complementary_proposal',
            curriculum_movement_ids: [],
            linked_resource_ids: musRes ? [musRes.resource_id] : [],
            resource_usage_notes: musRes ? buildResourceUsageMap(musRes) : {},
            cancionero_reference: buildCancioneroRef(rodaSongTitle, isAngola ? 'Angola' : 'Benguela', 'adultos'),
            video_reference_note: musRes ? buildVideoNote(musRes) : null,
          },
        ],
      });
    }

    bloques.push({
      block_id: 'blk_ad_last',
      fase: 'Vuelta a la Calma & Cierre',
      fase_tipo: 'vuelta_calma',
      duracion_min: blockDurs[blockDurs.length - 1],
      ejercicios: [
        {
          exercise_id: 'ex_ad_last_1',
          nombre: 'Descarga muscular, respiración y retroalimentación técnica',
          tipo_actividad: 'cierre',
          detalle: `En círculo ${floorPhrase}: estiramiento suave de caderas, isquiotibiales y muñecas acompañado de 5 respiraciones nasales profundas y síntesis para el registro post-clase. ${buildTimedBreakdown(blockDurs[blockDurs.length - 1], ['estiramiento y respiración', 'síntesis verbal'])}`,
          duracion_min: blockDurs[blockDurs.length - 1],
          organizacion: 'Todos simultáneamente',
          supervision_instructors_needed: 1,
          materiales: [],
          seguridad: 'Movilidad pasiva suave sin dolor articular.',
          ...makeVariants(
            context,
            'Usar apoyo de manos si hay rigidez posterior.',
            'Controlar exhalación lenta para bajar pulsaciones.',
            'Aportar observación técnica sobre ritmo y distancia percibidos.'
          ),
          observaciones_profesor: 'Cierre de sesión limpio sin exceder el tiempo total.',
          content_origin: 'ai_complementary_proposal',
          source_origins: ['ai_complementary_proposal'],
          activity_authoring: 'ai_complementary_proposal',
          curriculum_movement_ids: [],
          linked_resource_ids: [],
          resource_usage_notes: {},
          cancionero_reference: null,
          video_reference_note: null,
        },
      ],
    });

    const continuityMsg = context.continuityContext
      ? wantsRepeat
        ? `Continuidad aplicada: se retomaron los pendientes ('${context.continuityContext.pending_exercises?.[0] || 'transiciones'}') y se permitió refuerzo/repetición justificada sobre '${context.continuityContext.reinforce_content || context.continuityContext.continuity_proposal}'.`
        : `Continuidad aplicada: ${context.continuityContext.continuity_proposal || 'progresión ajustada al último cierre'}.`
      : 'Sin historial previo vinculado para este grupo.';

    return {
      titulo: `${context.focusLabel} · ${context.llmPayloadContext.group_profile.group_label}`,
      duracion_total: total,
      nivel: context.audienceType === 'mixto' ? 'Mixto' : 'Adultos',
      audience_type: context.audienceType,
      curriculum_scope: context.curriculumScope,
      enfoque: context.focusLabel,
      objetivo:
        context.objectives[0] ||
        `Desarrollar ${context.focusLabel} manteniendo fluidez grupal y progresiones diferenciadas.`,
      objetivos:
        context.objectives.length > 0
          ? context.objectives
          : ['Consolidar técnica y transiciones fluidas manteniendo participación simultánea.'],
      bloques,
      consejos_instructor:
        context.space.spaceSize === 'reducido'
          ? `Espacio reducido (${context.space.floorType}): orientar todas las filas de parejas en paralelo y regular la amplitud de giro.`
          : 'Supervisar ritmo parejo del grupo y ajustar la exigencia de cada trío de variantes según respuesta real.',
      continuity_applied_note: continuityMsg,
    };
  }

  _synthesizePlan(context) {
    if (!context.allowAiComplementaryProposals && context.selectedResources.length > 0) {
      return this._buildStrictTeacherOnlyPlan(context);
    }

    const onlyMusicality =
      context.focuses.length === 1 && /^musicalidad$/i.test(context.focuses[0].trim());
    if (onlyMusicality) {
      return this._buildMusicalityFocusedPlan(context);
    }

    if (context.audienceType === 'infantil') {
      return this._buildInfantilPlan(context);
    }

    return this._buildAdultOrMixedPlan(context);
  }
}

module.exports = {
  SimulatedPlannerProvider,
};

#!/usr/bin/env node
'use strict';

/**
 * PED-04C2-E Pedagogical Quality Regression Suite (100% Offline, 0 Paid Calls).
 *
 * Covers the 10 mandatory quality dimensions identified after the real pilot audit:
 * 1. Coverage of requested Capoeira movements (Ginga, Armada, Aú)
 * 2. Coverage of selected session focuses
 * 3. Simultaneous participation without queues/eliminations + structured organizacion
 * 4. Unconfirmed materials/instruments (rejects invented chairs/conos; requires palms/voice fallback)
 * 5. Real technical progressions differentiated by beginner/intermediate/advanced levels
 * 6. Safety by age, unconfirmed floor (rejects voltereta/rodar como bola) & supervision
 * 7. Block coherence & human-readable labels independent of block_id/fase_tipo
 * 8. Multi-stage internal timings (rejects trivial 1-stage summary equal to full duration)
 * 9. Pedagogical Pizarra resource assignment (idea_res_02 -> blk_2, NOT roda_musicalidad)
 * 10. Executable musicality (canto responsorial + palmas + roda, never just a song citation)
 */

const assert = require('assert');
const {
  generateClassPlanV2,
  loadVerifiedCatalog,
  InMemoryAtomicQuotaStore,
  OpenAiStructuredProvider,
} = require('../functions/planner_v2');
const { buildValidatedContext } = require('../functions/planner_v2/context_builder');
const { validateGeneratedPlan } = require('../functions/planner_v2/plan_validator');
const { assembleFullPlanFromBlocks, assembleBlockFromAiDraft } = require('../functions/planner_v2/block_assembler');

function makeResourceRepo() {
  return {
    async getResourcesByIds(ids) {
      const m = new Map();
      if (ids.includes('idea_res_02')) {
        m.set('idea_res_02', {
          resourceId: 'idea_res_02',
          ownerId: 'local_dev_simulated_instructor',
          shared: true,
          title: 'Juego espejo de esquivas por señales',
          type: 'juego',
          mediaKind: 'nota',
          category: 'Juegos',
          notes: 'Trabajo por parejas a distancia segura cambiando esquiva al sonido del pandeiro.',
          url: '',
        });
      }
      return m;
    },
  };
}

function makeRichInfantilRequest(overrides = {}) {
  return {
    request_id: overrides.request_id || 'req_ped04c2e_01',
    creation_mode: 'avanzada',
    group_context: {
      group_label: 'Infantil M/J 18:00',
      audience_type: 'infantil',
      age_min: 5,
      age_max: 11,
      estimated_participants: 10,
      experience_distribution: {
        principiantes: 6,
        intermedios: 2,
        avanzados: 2,
        manually_confirmed: true,
      },
    },
    curriculum_context: {
      scope: 'infantil_fiu_pending',
    },
    space_context: {
      space_size: 'mediano',
      floor_type: overrides.floor_type || 'desconocido',
      ...(overrides.available_mats !== undefined ? { available_mats: overrides.available_mats } : {}),
      instructors_available: 1,
    },
    session_config: {
      duration_min: 60,
      focuses: ['Técnicas', 'Juegos', 'Acrobacias', 'Musicalidad'],
      objectives: ['Trabajar progresiones base de Ginga, Armada y Aú mediante juegos técnicos'],
      include_musicality_roda: true,
      allow_ai_complementary_proposals: true,
      free_instructions:
        'Mantener participación simultánea sin filas y diferenciar claramente a los más pequeños.',
      ...(overrides.materials !== undefined ? { materials: overrides.materials } : {}),
    },
    selected_movements: [],
    selected_resources: [
      {
        resource_id: 'idea_res_02',
        title: 'Juego espejo de esquivas por señales',
        type: 'juego',
        category: 'Juegos',
        notes: 'Trabajo por parejas a distancia segura cambiando esquiva al sonido del pandeiro.',
        usage_note: 'Aplicar como dinámica principal de reacción.',
        has_external_video: false,
        priority: 'required',
      },
    ],
  };
}

function buildGoodDraftForBlock(spec) {
  const mkSplit = (dur) => {
    if (dur < 4) return [{ etapa: 'ejecución continua', minutos: dur }];
    const p1 = Math.max(1, Math.floor(dur / 3));
    const p2 = Math.max(1, Math.floor((dur - p1) / 2));
    const p3 = Math.max(1, dur - p1 - p2);
    return [
      { etapa: 'preparación y demostración', minutos: p1 },
      { etapa: 'progresión técnica guiada', minutos: p2 },
      { etapa: 'rondas y ajuste técnico', minutos: p3 },
    ];
  };

  const exercises = spec.exercise_slots.map((slot, idx) => {
    const dur = slot.duracion_min;
    const hasRes = (slot.assigned_resource_ids || []).length > 0;
    if (spec.fase_tipo === 'calentamiento') {
      return {
        nombre: idx === 0 ? 'Ginga al pulso y movilidad animal de capoeira' : 'Juego semáforo de Cocorinha y Esquiva',
        tipo_actividad: 'juego_dinamico',
        detalle:
          'Objetivo: activar articulaciones y base de Ginga. Preparación: dispersos a 1.5 m en el espacio. ' +
          'Reglas y señales: con palmas del profesor (alternativa si no hay pandeiro), pasan de Ginga a Cocorinha o desplazamientos de cangrejo. ' +
          'Rondas y rotación: 3 rondas activas de 90 s sin eliminaciones.',
        organizacion: 'Todos simultáneamente',
        materiales: [],
        seguridad: 'Mantener 1.5 m entre compañeros y proteger el rostro al bajar en Cocorinha.',
        diferenciacion_principiantes: 'Ginga lenta con pausa clara en cada paso trasero.',
        diferenciacion_intermedios: 'Conectar Ginga fluida con Cocorinha al primer pulso.',
        diferenciacion_avanzados: 'Alternar salida en Rolê corto manteniendo postura erguida.',
        sugerencias_ia: 'Corregir mirada al frente al agacharse en Cocorinha.',
        technical_movement_refs: ['Ginga', 'Cocorinha', 'Rolê'],
        tiempos_internos: mkSplit(dur),
        cancionero_reference: null,
      };
    }
    if (spec.fase_tipo === 'tecnica') {
      return {
        nombre: idx === 0
          ? 'Progresión técnica independiente: Ginga base y Armada controlada'
          : 'Progresión técnica de Esquiva lateral y salida en Aú',
        tipo_actividad: 'ejercicio_tecnico',
        detalle:
          'Objetivo: enseñar mecánica limpia de Ginga, Armada y Esquiva lateral antes de combinarlas en juego. ' +
          'Preparación: todos en frente amplio paralelo con 2 metros libres por alumno. ' +
          'Paso a paso: practicar rotación de cadera en Armada y descenso controlado en Esquiva en 3 rondas activas manteniendo participación simultánea.',
        organizacion: 'Todos simultáneamente',
        materiales: [],
        seguridad: 'Cero contacto físico; respetar radio de giro antes de ejecutar Armada.',
        diferenciacion_principiantes: 'Ginga estable y media rotación de Armada con apoyo cercano.',
        diferenciacion_intermedios: 'Armada continua retornando a base y Esquiva lateral fluida.',
        diferenciacion_avanzados: 'Enlazar Armada limpia con Esquiva lateral y preparación hacia Aú.',
        sugerencias_ia: 'Evitar que crucen pies en la base trasera de Armada.',
        technical_movement_refs: ['Ginga', 'Armada', 'Esquiva lateral', 'Aú'],
        tiempos_internos: mkSplit(dur),
        cancionero_reference: null,
      };
    }
    if (spec.fase_tipo === 'juegos') {
      return {
        nombre: hasRes
          ? 'Juego espejo de esquivas por señales con Ginga'
          : 'Juego cooperativo "El Puente y el Viento" con Ginga y Armada',
        tipo_actividad: 'juego_dinamico',
        detalle: hasRes
          ? 'Objetivo: aplicar esquivas laterales por estímulo visual y sonoro. Preparación: parejas frente a frente a 2 m sin espera en fila. Reglas y señales: cambian esquema de esquiva y Ginga con palmas (o pandeiro si está disponible). Rondas y rotación: rotar parejas cada 2 minutos.'
          : 'Objetivo: consolidar mecánica limpia de Ginga y Armada en dinámica lúdica. Preparación: organizados en carriles visuales paralelos. Reglas y señales: a la señal sonora practican rotación de cadera de Armada o base de Ginga sin contacto. Rondas y rotación: 4 rondas alternando lado cada minuto.',
        organizacion: 'Rotación por parejas',
        materiales: [],
        seguridad: 'Respetar distancia de giro de Armada y cero contacto físico.',
        diferenciacion_principiantes: 'Ginga base y media rotación de cadera en Armada con pie bajo.',
        diferenciacion_intermedios: 'Armada continua retornando a base y desplazamiento lateral.',
        diferenciacion_avanzados: 'Enlazar Armada limpia con Esquiva lateral controlada.',
        sugerencias_ia: 'Evitar que crucen pies en Armada al volver a base.',
        technical_movement_refs: ['Ginga', 'Armada', 'Esquiva lateral'],
        tiempos_internos: mkSplit(dur),
        cancionero_reference: null,
      };
    }
    if (spec.fase_tipo === 'acrobacias_suelo') {
      return {
        nombre: idx === 0 ? 'Aú bajito sobre línea imaginaria y apoyo de manos' : 'Rolê lateral y Negativa controlada',
        tipo_actividad: 'progresion_suelo',
        detalle:
          'Objetivo: ganar fuerza y control bajo en el suelo sin impactos sobre piso no confirmado. ' +
          'Preparación: todos en paralelo frente al instructor. Ejecución paso a paso: apoyar palmas firmes y pasar piernas en Aú bajo o salir en Rolê lateral lento desde Negativa en 3 rondas activas.',
        organizacion: 'Todos simultáneamente',
        materiales: [],
        seguridad: 'Sin inversiones verticales mantenidas ni volteretas sobre piso no amortiguado.',
        diferenciacion_principiantes: 'Aú rasante pasando un pie a la vez con cadera baja.',
        diferenciacion_intermedios: 'Aú fluido con manos alineadas aterrizando suave.',
        diferenciacion_avanzados: 'Conectar Aú lateral con salida continua en Rolê a ambos lados.',
        sugerencias_ia: 'Vigilar separación de dedos al apoyar manos en Aú.',
        technical_movement_refs: ['Aú', 'Rolê', 'Negativa'],
        tiempos_internos: mkSplit(dur),
        cancionero_reference: null,
      };
    }
    return {
      nombre: 'Coro responsorial, palmas y mini-roda dialogada ("Marinheiro só")',
      tipo_actividad: 'musicalidad_roda',
      detalle:
        'Objetivo: integrar ritmo, canto responsorial y juego cooperativo en roda. Preparación: círculo amplio sosteniendo palmas en 3 tiempos (con voz y palmas como alternativa si no hay pandeiro). Rondas y rotación: parejas entran al centro en rondas de 45 segundos mostrando Ginga, Esquiva y Aú mientras todo el grupo responde al coro, cerrando con respiración tranquila.',
      organizacion: 'Rotación por parejas',
      materiales: [],
      seguridad: 'Cero contacto; mantener amplitud uniforme de la roda.',
      diferenciacion_principiantes: 'Responder el coro con palmas constantes y entrar 25 s en Ginga.',
      diferenciacion_intermedios: 'Entrar con Ginga y Aú respetando el ritmo del coro.',
      diferenciacion_avanzados: 'Alternar rol de solista en coro y dialogar en el centro.',
      sugerencias_ia: 'Cuidar que el coro no acelere el pulso durante las entradas.',
      technical_movement_refs: ['Ginga', 'Aú'],
      tiempos_internos: mkSplit(dur),
      cancionero_reference: {
        song_title: 'Marinheiro só',
        rhythm: 'Corrido',
        audience_fit: 'infantil',
        lookup_hint: 'Buscar título en Cancionero GINGA',
      },
    };
  });

  return {
    // Deliberately send raw fase_tipo to confirm deterministic human-readable label mapping!
    fase: spec.fase_tipo,
    ejercicios: exercises,
  };
}

function assertErrorCode(plan, ctx, catalog, expectedCode, label) {
  const res = validateGeneratedPlan(plan, ctx, catalog);
  const codes = res.structuralValidation.errors.map((e) => e.code);
  assert(
    codes.includes(expectedCode),
    `[${label}] esperaba error '${expectedCode}' pero obtuvo [${codes.join(', ')}]`
  );
  console.log(`[ok] ${label} -> rechazado determinísticamente con ${expectedCode}`);
}

async function main() {
  const catalog = loadVerifiedCatalog();
  const resRepo = makeResourceRepo();
  const req = makeRichInfantilRequest();
  const ctx = await buildValidatedContext({
    request: req,
    actor: { actorId: 'local_dev_simulated_instructor', actorMode: 'local_dev_bypass' },
    catalog,
    resourceRepository: resRepo,
  });

  // Check 1: Context extracts requested Capoeira movements + simultaneous flag + reserves Técnica block + routes idea_res_02 to juegos (NOT roda_musicalidad)
  assert.deepStrictEqual(ctx.requestedTechnicalMovements, ['Ginga', 'Armada', 'Aú']);
  assert.strictEqual(ctx.simultaneousParticipationRequested, true);
  assert.strictEqual(ctx.temporalBlueprint.blocks.length, 5);
  assert.strictEqual(ctx.temporalBlueprint.blocks[1].fase_tipo, 'tecnica');
  assert(ctx.temporalBlueprint.blocks[1].duracion_min >= 14, 'Debe reservar espacio efectivo para Técnica y progresiones');
  const blk2Slots = ctx.temporalBlueprint.blocks.find((b) => b.block_id === 'blk_2')?.exercise_slots || [];
  const blk3Slots = ctx.temporalBlueprint.blocks.find((b) => b.block_id === 'blk_3')?.exercise_slots || [];
  const blk5Slots = ctx.temporalBlueprint.blocks.find((b) => b.block_id === 'blk_5')?.exercise_slots || [];
  assert(
    blk3Slots.some((s) => s.assigned_resource_ids.includes('idea_res_02')),
    'Recurso de juego idea_res_02 debe asignarse al bloque de Juegos blk_3, NO a Técnica ni a Roda'
  );
  assert(
    !blk2Slots.some((s) => s.assigned_resource_ids.includes('idea_res_02')) &&
      !blk5Slots.some((s) => s.assigned_resource_ids.includes('idea_res_02')),
    'Coincidencia superficial de la palabra pandeiro en notes NO debe mover idea_res_02 a blk_5 ni quitar espacio a blk_2 técnica'
  );
  for (const b of ctx.temporalBlueprint.blocks) {
    for (const s of b.exercise_slots) {
      if (s.duracion_min >= 4) {
        assert.strictEqual(s.min_internal_stages, 2);
        assert(Array.isArray(s.suggested_stage_minutes) && s.suggested_stage_minutes.length >= 2);
        assert.strictEqual(
          s.suggested_stage_minutes.reduce((a, x) => a + x, 0),
          s.duracion_min
        );
      }
    }
  }
  console.log('[ok] Extracción Ginga/Armada/Aú, reserva Técnica 5 bloques, routing idea_res_02 -> blk_3 y etapas previas verificados');

  // Check 2: Happy modular pass builds human-readable block titles, clean observaciones_profesor, aiSuggestions, and passes all 10 criteria
  const provider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsed = JSON.parse(opts.body);
      const m = parsed.messages[1].content.match(/"block_position":"(\d+)\/(\d+)"/);
      const spec = ctx.temporalBlueprint.blocks[Number(m[1]) - 1];
      return {
        ok: true,
        status: 200,
        json: async () => ({
          choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(buildGoodDraftForBlock(spec)) } }],
          usage: { prompt_tokens: 950, completion_tokens: 800 },
        }),
      };
    },
  });

  const okRes = await generateClassPlanV2({
    request: req,
    authContext: {},
    deps: {
      catalog,
      quotaStore: new InMemoryAtomicQuotaStore(),
      resourceRepository: resRepo,
      provider,
    },
    serverOverrides: {
      providerMode: 'openai',
      realProviderEnabled: true,
      allowLocalDevSimulatedBypass: true,
      primaryModel: 'gpt-4o-mini',
    },
  });

  assert.strictEqual(okRes.validation_report.structural.passed, true);
  assert.strictEqual(okRes.plan.bloques[0].fase, 'Calentamiento');
  assert.strictEqual(okRes.plan.bloques[1].fase, 'Técnica y progresiones');
  assert.strictEqual(okRes.plan.bloques[2].fase, 'Juegos de capoeira');
  assert.strictEqual(okRes.plan.bloques[3].fase, 'Acrobacias y movimientos de suelo');
  assert.strictEqual(okRes.plan.bloques[4].fase, 'Roda y musicalidad');
  assert.strictEqual(okRes.plan.bloques[0].block_id, 'blk_1');
  assert.strictEqual(okRes.plan.bloques[0].fase_tipo, 'calentamiento');
  // IA suggestions separated cleanly from teacher observations
  assert(okRes.plan.bloques[0].ejercicios[0].sugerencias_ia.length > 10);
  assert.strictEqual(okRes.plan.bloques[0].ejercicios[0].observaciones_profesor, '');
  assert(okRes.plan.bloques[1].ejercicios[0].technical_movement_refs.includes('Armada'));
  assert.strictEqual(okRes.plan.bloques[1].ejercicios[0].curriculum_movement_ids.length, 0);
  console.log('[ok] Clase modular especializada completa: 5 bloques con Técnica dedicada, separación IA vs profesor y 0 FIU adulto en Infantil');

  // Negative regression matrix covering every gap observed in PED-04C2-D human review:
  const basePlan = JSON.parse(JSON.stringify(okRes.plan));

  // Neg 1: Generic physical-education game ("Juego de las Estatuas")
  const pGeneric = JSON.parse(JSON.stringify(basePlan));
  pGeneric.bloques[0].ejercicios[0].nombre = 'Juego de las Estatuas';
  assertErrorCode(pGeneric, ctx, catalog, 'GENERIC_NON_CAPOEIRA_EXERCISE', 'Neg1_Juego_Generico_EF');

  // Neg 2: Missing requested technical movement ("Armada")
  const pMissingMov = JSON.parse(JSON.stringify(basePlan));
  for (const b of pMissingMov.bloques) {
    for (const e of b.ejercicios) {
      e.nombre = e.nombre.replace(/Armada/gi, 'Patada circular');
      e.detalle = e.detalle.replace(/Armada/gi, 'patada circular');
      e.diferenciacion_principiantes = e.diferenciacion_principiantes.replace(/Armada/gi, 'giro');
      e.diferenciacion_intermedios = e.diferenciacion_intermedios.replace(/Armada/gi, 'patada');
      e.diferenciacion_avanzados = e.diferenciacion_avanzados.replace(/Armada/gi, 'patada');
      e.technical_movement_refs = (e.technical_movement_refs || []).filter((t) => !/armada/i.test(t));
    }
  }
  assertErrorCode(pMissingMov, ctx, catalog, 'MISSING_REQUESTED_MOVEMENT_COVERAGE', 'Neg2_Movimiento_Solicitado_Omitido');

  // Neg 3: Eliminations or queues when simultaneous participation requested
  const pElim = JSON.parse(JSON.stringify(basePlan));
  pElim.bloques[1].ejercicios[0].detalle += ' Si falla alguien, queda eliminado del juego.';
  assertErrorCode(pElim, ctx, catalog, 'ELIMINATION_OR_QUEUE_WHEN_SIMULTANEOUS_REQUESTED', 'Neg3a_Eliminacion');

  const pTurnos = JSON.parse(JSON.stringify(basePlan));
  pTurnos.bloques[1].ejercicios[0].organizacion = 'Turnos';
  assertErrorCode(pTurnos, ctx, catalog, 'ELIMINATION_OR_QUEUE_WHEN_SIMULTANEOUS_REQUESTED', 'Neg3b_Organizacion_Turnos');

  // Neg 4: Free-prose organization instead of structured mode
  const pFreeOrg = JSON.parse(JSON.stringify(basePlan));
  pFreeOrg.bloques[0].ejercicios[0].organizacion =
    'Un solo instructor supervisa todo el salón mientras los niños se mueven por estaciones libres.';
  assertErrorCode(pFreeOrg, ctx, catalog, 'UNSTRUCTURED_ORGANIZATION_PROSE', 'Neg4_Organizacion_Prosa_Libre');

  // Neg 5: Undeclared chairs or unconfirmed pandeiro without palms/voice fallback
  const pChairs = JSON.parse(JSON.stringify(basePlan));
  pChairs.bloques[1].ejercicios[0].detalle += ' Coloca sillas en círculo para los niños.';
  assertErrorCode(pChairs, ctx, catalog, 'UNDECLARED_MATERIAL_OR_INSTRUMENT_IN_PROSE', 'Neg5a_Sillas_No_Declaradas');

  const pPandeiroNoAlt = JSON.parse(JSON.stringify(basePlan));
  pPandeiroNoAlt.bloques[0].ejercicios[0].detalle =
    'Objetivo: activar Ginga. Preparación: círculo en el espacio. Reglas y señales: cambiar al toque del pandeiro. Rondas y rotación: 3 rondas activas.';
  assertErrorCode(
    pPandeiroNoAlt,
    ctx,
    catalog,
    'UNDECLARED_MATERIAL_OR_INSTRUMENT_IN_PROSE',
    'Neg5b_Instrumento_Sin_Alternativa'
  );

  // Neg 6: Forward roll / voltereta on unconfirmed floor
  const pRoll = JSON.parse(JSON.stringify(basePlan));
  pRoll.bloques[3].ejercicios[1].nombre = 'Rodar como una bola';
  pRoll.bloques[3].ejercicios[1].detalle = 'Los alumnos practican rodar como una bola por el salón.';
  assertErrorCode(pRoll, ctx, catalog, 'UNSAFE_ROLL_OR_TUMBLE_ON_UNCONFIRMED_FLOOR', 'Neg6_Rodada_Sin_Colchonetas');

  // Neg 7: Trivial single-stage internal timing for >= 4 min exercise
  const pTrivialTime = JSON.parse(JSON.stringify(basePlan));
  pTrivialTime.bloques[0].ejercicios[0].tiempos_internos = [{ etapa: 'Juego', minutos: 6 }];
  assertErrorCode(pTrivialTime, ctx, catalog, 'TRIVIAL_INTERNAL_TIMINGS', 'Neg7_Tiempos_Internos_Triviales');

  // Neg 8: Non-executable musicality (only song mention, no vocal/rhythm/group execution + exact missing dims reported)
  const pShallowMusic = JSON.parse(JSON.stringify(basePlan));
  pShallowMusic.bloques[4].ejercicios[0].nombre = 'Escuchar música al cierre';
  pShallowMusic.bloques[4].ejercicios[0].detalle = 'Los niños escuchan la grabación de Marinheiro só sentados.';
  pShallowMusic.bloques[4].ejercicios[0].sugerencias_ia = 'Mantener calma.';
  const shallowVal = validateGeneratedPlan(pShallowMusic, ctx, catalog);
  const musicErr = shallowVal.structuralValidation.errors.find((e) => e.code === 'NON_EXECUTABLE_MUSICALITY');
  assert(musicErr, '[Neg8_Musicalidad_No_Ejecutable] debía fallar con NON_EXECUTABLE_MUSICALITY');
  assert(
    musicErr.message.includes('canto/coro responsorial') &&
      musicErr.message.includes('palmas/pulso rítmico') &&
      musicErr.message.includes('práctica grupal/roda en círculo'),
    `Mensaje debe diagnosticar las 3 dimensiones faltantes exactas, obtuvo: ${musicErr.message}`
  );
  console.log('[ok] Neg8_Musicalidad_No_Ejecutable -> rechazado con diagnóstico exacto de dimensiones faltantes');

  // Reg 9: Reproduce Attempt 7/8 exact residual errors (multiple TRIVIAL_INTERNAL_TIMINGS + NON_EXECUTABLE_MUSICALITY)
  // AND verify targeted repair prompts + anti-regression guard for valid sibling exercise
  const repairPromptCaptures = [];
  const attemptCounts78 = {};
  const reg78Provider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsed = JSON.parse(opts.body);
      const userMsg = parsed.messages[1].content;
      const m = userMsg.match(/"block_position":"(\d+)\/(\d+)"/);
      const spec = ctx.temporalBlueprint.blocks[Number(m[1]) - 1];
      const isRepair = userMsg.includes('REPARA SOLO ESTE BLOQUE');
      attemptCounts78[spec.block_id] = (attemptCounts78[spec.block_id] || 0) + 1;
      if (isRepair) {
        repairPromptCaptures.push({ blockId: spec.block_id, userMsg });
      }
      const draft = buildGoodDraftForBlock(spec);

      if (attemptCounts78[spec.block_id] === 1) {
        // First wave reproduces exact 7/8 residual errors:
        // - blk_2: ex_1 trivial timing (1 stage), ex_2 stays 100% VALID!
        // - blk_5: NON_EXECUTABLE_MUSICALITY (mentions palmas + rueda/círculo, misses vocal responsorial coro)
        if (spec.block_id === 'blk_2') {
          draft.ejercicios[0].tiempos_internos = [{ etapa: 'Práctica', minutos: spec.exercise_slots[0].duracion_min }];
        }
        if (spec.block_id === 'blk_5') {
          draft.ejercicios[0].nombre = 'Círculo de palmas de cierre';
          draft.ejercicios[0].detalle =
            'Objetivo: cerrar la sesión. Preparación: círculo amplio en el salón manteniendo palmas suaves al pulso mientras rotan parejas en Ginga y Aú.';
        }
      } else if (spec.block_id === 'blk_2') {
        // Simulate repair fixing ex_1's TRIVIAL_INTERNAL_TIMINGS, while accidentally breaking valid sibling ex_2!
        draft.ejercicios[1].nombre = 'Juego de las Estatuas';
        draft.ejercicios[1].seguridad = '';
      }

      return {
        ok: true,
        status: 200,
        json: async () => ({
          choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(draft) } }],
          usage: { prompt_tokens: 950, completion_tokens: 800 },
        }),
      };
    },
  });

  const reg78Res = await generateClassPlanV2({
    request: makeRichInfantilRequest({ request_id: 'req_ped04c2e_reg78' }),
    authContext: {},
    deps: {
      catalog,
      quotaStore: new InMemoryAtomicQuotaStore(),
      resourceRepository: resRepo,
      provider: reg78Provider,
    },
    serverOverrides: {
      providerMode: 'openai',
      realProviderEnabled: true,
      allowLocalDevSimulatedBypass: true,
      primaryModel: 'gpt-4o-mini',
    },
  });

  assert.strictEqual(reg78Res.validation_report.structural.passed, true);
  assert.deepStrictEqual(reg78Res.generation_meta.repaired_block_ids, ['blk_2', 'blk_5']);
  assert(
    reg78Res.generation_meta.deterministic_fixes_applied.includes('preserve_valid_exercise:blk_2_ex_2'),
    'Anti-regression guard must restore previously valid sibling blk_2_ex_2 when repair regresses it'
  );
  const blk2Prompt = repairPromptCaptures.find((c) => c.blockId === 'blk_2')?.userMsg || '';
  const blk5Prompt = repairPromptCaptures.find((c) => c.blockId === 'blk_5')?.userMsg || '';
  assert(blk2Prompt.includes('TRIVIAL_INTERNAL_TIMINGS') && blk2Prompt.includes('suggested_stage_minutes'));
  assert(blk2Prompt.includes('ANTI-REGRESIÓN'));
  assert(blk5Prompt.includes('NON_EXECUTABLE_MUSICALITY') && blk5Prompt.includes('canto/coro responsorial'));
  console.log('[ok] Regresión intento 7/8: TRIVIAL_INTERNAL_TIMINGS + NON_EXECUTABLE_MUSICALITY + anti-regresión reparados y verificados');

  console.log('ALL_PED04C2E_PEDAGOGICAL_QUALITY_TESTS_PASSED');
}

main().catch((err) => {
  console.error('FAIL test_planner_v2_pedagogical_quality_ped04c2e:', err);
  process.exitCode = 1;
});

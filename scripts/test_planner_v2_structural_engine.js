#!/usr/bin/env node
'use strict';

/**
 * Comprehensive structural verification & regression suite (`PED-04C2-D`):
 * - T1: Reproduces exact `scratch/last_planner_v2_failure.json` errors (`INVALID_BLOCKS_COUNT`,
 *   `MISSING_INTERNAL_TIMING_BREAKDOWN`, `BLOCKS_DURATION_SUM_MISMATCH`) offline.
 * - T2: Verifies flexible temporal blueprints & generation across 45/60/75/90 min,
 *   multiple focuses, Infantil multilevel (5-11), Adultos FIU, and required resources.
 * - T3: Verifies Level 1 bounded arithmetic reconciliation fixes minor arithmetic drift
 *   WITHOUT a second LLM call (`repair_attempts_used === 0`), while never fabricating missing blocks
 *   or weakening pedagogical/safety/resource/differentiation checks.
 * - T4: Verifies Flutter `toPlannerV2RequestMap()` wire contract end-to-end against local server.
 */

const assert = require('assert');
const {
  generateClassPlanV2,
  loadVerifiedCatalog,
  OpenAiStructuredProvider,
  InMemoryAtomicQuotaStore,
  AtomicPilotBudgetGuard,
} = require('../functions/planner_v2');
const { buildFlexibleTemporalBlueprint } = require('../functions/planner_v2/temporal_planner');
const { normalizeOpenAiWirePlan } = require('../functions/planner_v2/response_schema');
const { validateGeneratedPlan } = require('../functions/planner_v2/plan_validator');
const { buildValidatedContext } = require('../functions/planner_v2/context_builder');
const { buildPilotScenarios, buildPilotResourceRepository } = require('./run_planner_v2_real_pilot');
const { createPlannerV2LocalServer } = require('./planner_v2_local_server');

function makeCompleteExerciseFromSlot({
  exercise_id,
  nombre,
  tipo_actividad = 'juego_dinamico',
  duracion_min,
  linked_resource_ids = [],
  curriculum_movement_ids = [],
  video_reference_note = null,
  cancionero_reference = null,
}) {
  const half = Math.max(1, Math.floor(duracion_min / 2));
  const rest = Math.max(1, duracion_min - half);
  const resNotes = {};
  for (const r of linked_resource_ids) {
    resNotes[r] = 'Aplicar según guía del profesor.';
  }
  const hasRes = linked_resource_ids.length > 0;
  const hasMov = curriculum_movement_ids.length > 0;
  let content_origin = 'ai_complementary_proposal';
  let source_origins = ['ai_complementary_proposal'];
  let activity_authoring = 'ai_complementary_proposal';
  if (hasRes && hasMov) {
    content_origin = 'teacher_resource';
    source_origins = ['teacher_resource', 'official_fiu_curriculum'];
    activity_authoring = 'teacher_resource_with_official_fiu_movements';
  } else if (hasRes) {
    content_origin = 'teacher_resource';
    source_origins = ['teacher_resource'];
    activity_authoring = 'teacher_resource';
  } else if (hasMov) {
    content_origin = 'official_fiu_curriculum';
    source_origins = ['official_fiu_curriculum', 'ai_designed_activity'];
    activity_authoring = 'ai_exercise_from_official_fiu';
  }

  return {
    exercise_id,
    nombre,
    tipo_actividad,
    detalle:
      'Preparación: formación simultánea en el área despejada. Reglas: rondas dinámicas con señal sonora y rotación continua sin colas.',
    duracion_min,
    organizacion: 'Todos simultáneamente',
    supervision_instructors_needed: 1,
    materiales: [],
    seguridad: 'Mantener distancia visible entre participantes sin contactos ni saltos bruscos.',
    diferenciacion_principiantes: 'Ritmo pausado cuidando apoyo y postura base.',
    diferenciacion_intermedios: 'Transiciones continuas manteniendo mirada al frente.',
    diferenciacion_avanzados: 'Cambios de ritmo y altura controlando retorno estable.',
    observaciones_profesor: 'Progresión adaptada por nivel.',
    content_origin,
    source_origins,
    activity_authoring,
    curriculum_movement_ids,
    linked_resource_ids,
    resource_usage_notes: Object.entries(resNotes).map(([resource_id, note]) => ({ resource_id, note })),
    tiempos_internos:
      duracion_min >= 2
        ? [
            { etapa: 'preparación y regla visual', minutos: half },
            { etapa: 'rondas dinámicas y rotación', minutos: rest },
          ]
        : [{ etapa: 'ejecución continua', minutos: duracion_min }],
    cancionero_reference,
    video_reference_note,
  };
}

function buildBlueprintCompliantWirePlan(context) {
  const bp = context.temporalBlueprint;
  const reqRes = context.selectedResources || [];
  const reqMov = context.selectedMovements || [];
  let resAttached = false;

  const bloques = bp.blocks.map((b, bi) => {
    const ejercicios = b.exercise_slots.map((slot, ei) => {
      const attachAllRes = !resAttached && bi === 1 && ei === 0 && reqRes.length > 0;
      if (attachAllRes) resAttached = true;
      const attachMovs = bi === 1 && ei === 0 && context.curriculumScope === 'adulto_fiu' ? reqMov.map((m) => m.movement_id) : [];
      const hasExtVid = attachAllRes && reqRes.some((r) => r.has_external_video);
      const isRoda = b.fase_tipo === 'roda_musicalidad' || b.fase_tipo === 'musicalidad';
      return makeCompleteExerciseFromSlot({
        exercise_id: slot.exercise_id,
        nombre: attachAllRes ? reqRes.map((r) => r.title).join(' + ') : `${b.role_hint} (${ei + 1})`,
        tipo_actividad: isRoda
          ? 'musicalidad_roda'
          : (b.fase_tipo === 'acrobacias_suelo' ? 'progresion_suelo' : 'juego_dinamico'),
        duracion_min: slot.duracion_min,
        linked_resource_ids: attachAllRes ? reqRes.map((r) => r.resource_id) : [],
        curriculum_movement_ids: attachMovs,
        video_reference_note: hasExtVid
          ? 'Recurso con video externo integrado según notas escritas (no se inspecciona video visualmente).'
          : null,
        cancionero_reference: isRoda
          ? {
              song_title: context.audienceType === 'infantil' ? 'Marinheiro só' : 'Paraná ê',
              rhythm: 'São Bento Grande',
              audience_fit: context.audienceType === 'infantil' ? 'infantil' : 'adultos',
              cantiga_id: null,
              lookup_hint: 'Cancionero tradicional',
            }
          : null,
      });
    });
    return {
      block_id: b.block_id,
      fase: b.role_hint,
      fase_tipo: b.fase_tipo,
      duracion_min: b.duracion_min,
      ejercicios,
    };
  });

  return {
    titulo: `Clase ${context.audienceType} ${context.durationMin}m`,
    duracion_total: context.durationMin,
    nivel: context.audienceType === 'infantil' ? 'Infantil' : (context.audienceType === 'mixto' ? 'Mixto' : 'Adultos'),
    audience_type: context.audienceType,
    curriculum_scope: context.curriculumScope,
    enfoque: context.focusLabel,
    objetivo: context.objectives[0] || 'Objetivos de sesión',
    objetivos: context.objectives,
    bloques,
    consejos_instructor: 'Observar espacio, ritmo del grupo y rotaciones continuas sin filas.',
    continuity_applied_note: context.continuityContext ? 'Se retoman dificultades previas en progresiones.' : '',
  };
}

async function testT1ReproduceFailureAndVerifyBlueprintRepair() {
  const catalog = loadVerifiedCatalog();
  const scenarios = buildPilotScenarios();
  const resourceRepository = buildPilotResourceRepository();
  const actor = { actorId: 't1', actorMode: 'custom_claims' };
  const req = {
    ...scenarios[1].request,
    request_id: 't1_repro_failure',
  };
  const ctx = await buildValidatedContext({ request: req, actor, catalog, resourceRepository });

  // Exact reproduction of the 3 real observed errors:
  // 1 block of 10 min, ejercicio_1 (5 min) without timing breakdown, sum 10 != 60
  const brokenResponse = {
    titulo: 'Clase Infantil Incompleta',
    duracion_total: 60,
    nivel: 'Infantil',
    audience_type: 'infantil',
    curriculum_scope: 'infantil_fiu_pending',
    enfoque: 'Técnica · Juegos',
    objetivo: 'Ginga y juegos',
    objetivos: ['Ginga y juegos'],
    bloques: [
      {
        block_id: 'bloque_1',
        fase: 'Calentamiento',
        fase_tipo: 'calentamiento',
        duracion_min: 10,
        ejercicios: [
          {
            exercise_id: 'ejercicio_1',
            nombre: 'Juego sin desglose',
            tipo_actividad: 'juego_dinamico',
            detalle: 'Preparación: en círculo jugando ginga con reglas y rotaciones constantes.',
            duracion_min: 5,
            organizacion: 'Todos simultáneamente',
            supervision_instructors_needed: 1,
            materiales: [],
            seguridad: 'Mantener distancia segura entre participantes.',
            diferenciacion_principiantes: 'Ginga básica pausada.',
            diferenciacion_intermedios: 'Ginga con esquiva simple.',
            diferenciacion_avanzados: 'Ginga con cambio rápido de dirección.',
            observaciones_profesor: '',
            content_origin: 'ai_complementary_proposal',
            source_origins: ['ai_complementary_proposal'],
            activity_authoring: 'ai_complementary_proposal',
            curriculum_movement_ids: [],
            linked_resource_ids: [],
            resource_usage_notes: {},
            tiempos_internos: [],
            cancionero_reference: null,
            video_reference_note: null,
          },
          {
            exercise_id: 'ejercicio_2',
            nombre: 'Desplazamiento simple',
            tipo_actividad: 'ejercicio_tecnico',
            detalle: 'Preparación: en línea realizando ginga lateral con rotaciones en 5 min total.',
            duracion_min: 5,
            organizacion: 'Todos simultáneamente',
            supervision_instructors_needed: 1,
            materiales: [],
            seguridad: 'Cuidar espacio alrededor.',
            diferenciacion_principiantes: 'Pasos cortos.',
            diferenciacion_intermedios: 'Pasos fluidos.',
            diferenciacion_avanzados: 'Cambios de plano.',
            observaciones_profesor: '',
            content_origin: 'ai_complementary_proposal',
            source_origins: ['ai_complementary_proposal'],
            activity_authoring: 'ai_complementary_proposal',
            curriculum_movement_ids: [],
            linked_resource_ids: [],
            resource_usage_notes: {},
            tiempos_internos: [{ etapa: 'ginga continua', minutos: 5 }],
            cancionero_reference: null,
            video_reference_note: null,
          },
        ],
      },
    ],
    consejos_instructor: 'Cuidar ritmo.',
    continuity_applied_note: '',
  };

  const valBroken = validateGeneratedPlan(normalizeOpenAiWirePlan(brokenResponse), ctx, catalog);
  const brokenCodes = new Set(valBroken.structuralValidation.errors.map((e) => e.code));
  assert(brokenCodes.has('INVALID_BLOCKS_COUNT'));
  assert(brokenCodes.has('MISSING_INTERNAL_TIMING_BREAKDOWN'));
  assert(brokenCodes.has('BLOCKS_DURATION_SUM_MISMATCH'));

  // Orchestrator must NOT stretch a 1-block broken draft; it sends full temporal_blueprint + anti-anchoring repair
  const goodWirePlan = buildBlueprintCompliantWirePlan(ctx);
  let callNum = 0;
  let capturedRepairPrompt = '';
  const mockFetch = async (_url, init) => {
    const body = JSON.parse(init.body);
    callNum += 1;
    if (callNum === 2) capturedRepairPrompt = body.messages[1].content;
    return {
      ok: true,
      status: 200,
      async json() {
        return {
          choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(callNum === 1 ? brokenResponse : goodWirePlan) } }],
          usage: { prompt_tokens: 2400, completion_tokens: 2200 },
        };
      },
    };
  };

  const resp = await generateClassPlanV2({
    request: req,
    authContext: { uid: 't1', token: { instructor: true } },
    deps: {
      catalog,
      provider: new OpenAiStructuredProvider({ apiKey: 'mock_key', fetchImpl: mockFetch }),
      quotaStore: new InMemoryAtomicQuotaStore(),
      budgetGuard: new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 }),
      resourceRepository,
    },
    serverOverrides: { providerMode: 'openai', realProviderEnabled: true, primaryModel: 'gpt-4o-mini', useModularGeneration: false },
  });

  assert.strictEqual(callNum, 2);
  assert(capturedRepairPrompt.includes('temporal_blueprint') && capturedRepairPrompt.includes('DESCARTA el conteo incompleto previo'));
  assert.strictEqual(resp.validation_report.structural.passed, true);
  assert.strictEqual(resp.plan.duracion_total, 60);
  console.log('[PASS] T1_reproduced_observed_errors_and_verified_blueprint_repair');
}

async function testT2FlexibleDurationsAndFocuses() {
  const catalog = loadVerifiedCatalog();
  const resourceRepository = buildPilotResourceRepository();
  const baseCases = [
    {
      label: 'Infantil_45m_sin_roda',
      duration: 45,
      audience: 'infantil',
      scope: 'infantil_fiu_pending',
      focuses: ['Técnica', 'Juegos'],
      includeRoda: false,
      res: [],
    },
    {
      label: 'Infantil_60m_multinivel_recursos',
      duration: 60,
      audience: 'infantil',
      scope: 'infantil_fiu_pending',
      focuses: ['Técnica', 'Juegos', 'Acrobacias'],
      includeRoda: true,
      res: [{ resource_id: 'pilot_res_infantil_juego', priority: 'required' }, { resource_id: 'pilot_res_video_au', priority: 'required' }],
    },
    {
      label: 'Musicalidad_75m_flexible',
      duration: 75,
      audience: 'adultos',
      scope: 'none_manual',
      focuses: ['Musicalidad', 'Roda'],
      includeRoda: true,
      res: [],
    },
    {
      label: 'Adultos_90m_FIU_multifoco',
      duration: 90,
      audience: 'adultos',
      scope: 'adulto_fiu',
      focuses: ['Técnica', 'Juegos', 'Musicalidad', 'Roda'],
      includeRoda: true,
      res: [{ resource_id: 'pilot_res_adulto_drill', priority: 'required' }],
      movs: [{ movement_id: 'queixada', priority: 'required' }, { movement_id: 'esquiva_lateral', priority: 'required' }],
    },
  ];

  const seenBlockCounts = new Set();
  for (const c of baseCases) {
    const req = {
      contract_version: '2.1.0',
      request_id: `t2_${c.label}`,
      creation_mode: 'avanzada',
      group_context: {
        source: 'real_class',
        group_label: c.label,
        audience_type: c.audience,
        age_min: c.audience === 'infantil' ? 5 : 16,
        age_max: c.audience === 'infantil' ? 11 : 40,
        estimated_participants: 10,
        experience_distribution: { principiantes: 5, intermedios: 3, avanzados: 2, manually_confirmed: true },
      },
      curriculum_context: { scope: c.scope, ...(c.scope === 'adulto_fiu' ? { target_corda_index: 2 } : {}) },
      space_context: { space_size: 'mediano', floor_type: 'tatami', available_mats: true, instructors_available: 1 },
      session_config: {
        duration_min: c.duration,
        focuses: c.focuses,
        objectives: ['Objetivo de prueba flexible'],
        include_musicality_roda: c.includeRoda,
        allow_ai_complementary_proposals: true,
        free_instructions: 'Mantener flujo dinámico sin filas.',
      },
      selected_movements: c.movs || [],
      selected_resources: c.res,
    };

    const res = await generateClassPlanV2({
      request: req,
      authContext: { uid: 't2', token: { instructor: true } },
      deps: { catalog, resourceRepository },
    });

    assert.strictEqual(res.plan.duracion_total, c.duration);
    assert.strictEqual(res.validation_report.structural.passed, true);
    const blkSum = res.plan.bloques.reduce((acc, b) => acc + b.duracion_min, 0);
    assert.strictEqual(blkSum, c.duration);
    seenBlockCounts.add(res.plan.bloques.length);

    // Also verify blueprint invariants directly
    const ctx = await buildValidatedContext({
      request: req,
      actor: { actorId: 't2', actorMode: 'custom_claims' },
      catalog,
      resourceRepository,
    });
    const bp = buildFlexibleTemporalBlueprint(ctx);
    assert.strictEqual(bp.total_duration_min, c.duration);
    assert.strictEqual(bp.blocks.reduce((a, b) => a + b.duracion_min, 0), c.duration);
    for (const b of bp.blocks) {
      assert.strictEqual(b.exercise_slots.reduce((a, s) => a + s.duracion_min, 0), b.duracion_min);
    }
  }

  assert(seenBlockCounts.size >= 2, 'La estructura debe ser flexible en número de bloques (no plantilla rígida única).');
  console.log('[PASS] T2_flexible_45_60_75_90m_infantil_multilevel_and_resources');
}

async function testT3Level1ArithmeticReconciliationZeroExtraLlmCalls() {
  const catalog = loadVerifiedCatalog();
  const scenarios = buildPilotScenarios();
  const resourceRepository = buildPilotResourceRepository();
  const ctx = await buildValidatedContext({
    request: { ...scenarios[1].request, request_id: 't3_lvl1_arith' },
    actor: { actorId: 't3', actorMode: 'custom_claims' },
    catalog,
    resourceRepository,
  });

  // Produce compliant 4-block wire plan, then introduce realistic minor GPT arithmetic drift:
  // block 0 exercises sum to 11 instead of 12, block 3 sum is 10 instead of 12 (total 58 vs 60),
  // plus exercise tiempos_internos sums to 5 while exercise duracion_min is 6.
  const minorDriftWire = buildBlueprintCompliantWirePlan(ctx);
  const lastIdx = minorDriftWire.bloques.length - 1;
  minorDriftWire.bloques[0].ejercicios[0].duracion_min = Math.max(1, minorDriftWire.bloques[0].ejercicios[0].duracion_min - 1);
  minorDriftWire.bloques[lastIdx].duracion_min = Math.max(2, minorDriftWire.bloques[lastIdx].duracion_min - 2);
  minorDriftWire.bloques[lastIdx].ejercicios[0].duracion_min = minorDriftWire.bloques[lastIdx].duracion_min;
  minorDriftWire.bloques[lastIdx].ejercicios[0].tiempos_internos = [
    { etapa: 'coro inicial', minutos: 2 },
    { etapa: 'roda guiada', minutos: 3 },
  ];

  // Make minor internal timing drift within 35% threshold
  minorDriftWire.bloques[1].ejercicios[0].tiempos_internos = [
    { etapa: 'preparación', minutos: 2 },
    { etapa: 'rondas', minutos: Math.max(1, minorDriftWire.bloques[1].ejercicios[0].duracion_min - 3) },
  ];
  // Reset last block timings accurately
  const lastDur = minorDriftWire.bloques[lastIdx].duracion_min;
  minorDriftWire.bloques[lastIdx].ejercicios[0].tiempos_internos = [
    { etapa: 'coro', minutos: 2 },
    { etapa: 'roda', minutos: Math.max(1, lastDur - 2) },
  ];

  let calls = 0;
  const mockFetch = async () => {
    calls += 1;
    return {
      ok: true,
      status: 200,
      async json() {
        return {
          choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(minorDriftWire) } }],
          usage: { prompt_tokens: 2100, completion_tokens: 2000 },
        };
      },
    };
  };

  const res = await generateClassPlanV2({
    request: { ...scenarios[1].request, request_id: 't3_lvl1_arith' },
    authContext: { uid: 't3', token: { instructor: true } },
    deps: {
      catalog,
      provider: new OpenAiStructuredProvider({ apiKey: 'mock_key', fetchImpl: mockFetch }),
      quotaStore: new InMemoryAtomicQuotaStore(),
      budgetGuard: new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 }),
      resourceRepository,
    },
    serverOverrides: { providerMode: 'openai', realProviderEnabled: true, primaryModel: 'gpt-4o-mini', useModularGeneration: false },
  });

  // Zero second LLM calls used!
  assert.strictEqual(calls, 1);
  assert.strictEqual(res.generation_meta.repair_attempts_used, 0);
  assert.strictEqual(res.plan.bloques.reduce((a, b) => a + b.duracion_min, 0), 60);
  assert.strictEqual(res.validation_report.structural.passed, true);
  assert(
    res.generation_meta.deterministic_fixes_applied.some((f) => f.startsWith('reconcile_')),
    'Debe registrar trazabilidad de la reconciliación aritmética Nivel 1.'
  );
  console.log('[PASS] T3_level1_arithmetic_reconciliation_zero_extra_llm_calls');
}

async function testT4FlutterPayloadContractEndToEnd() {
  const srv = createPlannerV2LocalServer({ host: '127.0.0.1' });
  await new Promise((resolve) => srv.listen(0, '127.0.0.1', resolve));
  const port = srv.address().port;
  try {
    // Exact payload shape emitted by Dart `ClassPlanDraftRequest.toPlannerV2RequestMap()`
    const flutterWirePayload = {
      request: {
        contract_version: '2.1.0',
        request_id: 'req_flutter_kids_adv_thu',
        creation_mode: 'avanzada',
        group_context: {
          source: 'real_class',
          clase_id: 'clase_kids_mj_1800',
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
        curriculum_context: { scope: 'infantil_fiu_pending' },
        space_context: {
          space_size: 'mediano',
          floor_type: 'tatami',
          available_mats: true,
          instructors_available: 1,
        },
        session_config: {
          duration_min: 60,
          focus: 'Técnica · Juegos',
          focuses: ['Técnica', 'Juegos'],
          objectives: ['Mejorar fluidez en Ginga, Cocorinha y desplazamientos seguros'],
          materials: ['Pandeiro', 'Conos'],
          include_musicality_roda: true,
          free_instructions: 'Clase dinámica infantil sin pausas largas ni colas.',
          allow_ai_complementary_proposals: true,
        },
        selected_movements: [],
        selected_resources: [
          {
            resource_id: 'idea_res_02',
            priority: 'required',
            usage_note: 'Usar en bloque central.',
          },
        ],
      },
      preview_resources_catalog: [
        {
          resource_id: 'idea_res_02',
          title: 'Juego espejo de Ginga y Cocorinha',
          type: 'juego',
          media_kind: 'nota',
          category: 'Juegos',
          notes: '3 rondas cambiando liderazgo al sonido del pandeiro.',
          has_external_video: false,
        },
      ],
    };

    const resp = await fetch(`http://127.0.0.1:${port}/api/planner-v2/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(flutterWirePayload),
    });
    assert.strictEqual(resp.status, 200);
    const json = await resp.json();
    assert.strictEqual(json.status, 'ok');
    assert.strictEqual(json.plan.duracion_total, 60);
    assert(json.plan.bloques.length >= 3);
    assert(json.plan.bloques.every((b) => b.ejercicios.every((e) => Array.isArray(e.tiempos_internos) && e.tiempos_internos.length > 0)));
    console.log('[PASS] T4_flutter_payload_contract_end_to_end');
  } finally {
    await new Promise((resolve) => srv.close(resolve));
  }
}

async function main() {
  await testT1ReproduceFailureAndVerifyBlueprintRepair();
  await testT2FlexibleDurationsAndFocuses();
  await testT3Level1ArithmeticReconciliationZeroExtraLlmCalls();
  await testT4FlutterPayloadContractEndToEnd();
  console.log('ALL STRUCTURAL ENGINE & REGRESSION CHECKS PASSED (4/4).');
}

main().catch((err) => {
  console.error('FAIL test_planner_v2_structural_engine:', err);
  process.exitCode = 1;
});

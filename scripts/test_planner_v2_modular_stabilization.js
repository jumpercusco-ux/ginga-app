#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  generateClassPlanV2,
  loadVerifiedCatalog,
  InMemoryAtomicQuotaStore,
  AtomicPilotBudgetGuard,
  OpenAiStructuredProvider,
  PlannerV2Error,
} = require('../functions/planner_v2');
const { buildValidatedContext } = require('../functions/planner_v2/context_builder');
const { buildPlannerPrompts, buildSingleBlockPrompts } = require('../functions/planner_v2/prompt_builder');
const {
  OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA,
  OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA,
} = require('../functions/planner_v2/response_schema');

function buildProfessorInfantilAdvancedRequest(requestId = 'req_infantil_adv_repro') {
  return {
    request_id: requestId,
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
      floor_type: 'desconocido',
      instructors_available: 1,
    },
    session_config: {
      duration_min: 60,
      focuses: ['Técnicas', 'Juegos', 'Acrobacias', 'Musicalidad'],
      objectives: ['Coordinar ginga básica y esquiva lúdica por señales'],
      include_musicality_roda: true,
      allow_ai_complementary_proposals: true,
      free_instructions: 'Mantener ritmo dinámico y rotaciones fluidas sin filas.',
    },
    selected_movements: [],
    selected_resources: [
      {
        resource_id: 'idea_res_02',
        title: 'Juego espejo de esquivas por señales',
        type: 'juego',
        category: 'Juegos',
        notes: 'Trabajo por parejas a distancia segura cambiando esquiva al sonido del pandeiro.',
        usage_note: 'Aplicar como dinámica principal de reacción visual y sonora.',
        has_external_video: false,
        priority: 'required',
      },
    ],
  };
}

function buildSlimBlockOpenAiBody(blockSpec, { audienceType = 'infantil', injectBananeira = false, latencyDelayMs = 0 } = {}) {
  const slots = blockSpec.exercise_slots || [];
  const exercises = slots.map((slot, idx) => {
    const isMusic = blockSpec.fase_tipo === 'musicalidad' || blockSpec.fase_tipo === 'roda_musicalidad';
    const isGame = blockSpec.fase_tipo === 'juegos' || blockSpec.fase_tipo === 'calentamiento' || idx === 0;
    const dur = slot.duracion_min;
    const half = Math.max(1, Math.floor(dur / 2));
    const rem = Math.max(1, dur - half);
    const hasRes = (slot.assigned_resource_ids || []).length > 0;
    const nombre = injectBananeira && idx === 0
      ? 'Bananeira asistida contra pared'
      : isMusic
        ? 'Roda cantada y palmas por pulso'
        : hasRes
          ? 'Juego espejo de esquivas por señales'
          : isGame
            ? `Dinámica cooperativa de ginga ${blockSpec.block_id}_${idx + 1}`
            : `Control corporal bajo en suelo (${blockSpec.block_id}_${idx + 1})`;

    return {
      nombre,
      tipo_actividad: isMusic
        ? 'musicalidad_roda'
        : blockSpec.fase_tipo === 'acrobacias_suelo'
          ? 'progresion_suelo'
          : isGame
            ? 'juego_dinamico'
            : 'ejercicio_tecnico',
      detalle: isMusic
        ? 'Objetivo: integrar canto responsorial, palmas y roda dialogada. Preparación: círculo amplio en el área de práctica; al pulso de las palmas (alternativa si no hay pandeiro), inician coro y entran parejas en rondas de 45 segundos rotando sin espera.'
        : 'Objetivo: mejorar esquiva y ginga continua. Preparación: ubicados en parejas o círculo amplio con distancia segura; reglas claras con señales de palmas o pandeiro (si hay disponible); rondas activas con rotación simultánea de todo el grupo.',
      organizacion: 'Todos simultáneamente',
      materiales: [],
      seguridad: 'Mantener al menos 1.5 metros libres y detener movimiento ante señal.',
      diferenciacion_principiantes: 'Ginga alta lenta y esquiva lateral pausada con apoyo visual.',
      diferenciacion_intermedios: 'Encadenar ginga con esquiva al primer pulso sin perder balance.',
      diferenciacion_avanzados: 'Cambios de dirección fluidos y rolê bajo controlado entre señales.',
      sugerencias_ia: 'Corregir postura de guardia alta y fomentar mirada al frente.',
      technical_movement_refs: ['Ginga', 'Esquiva lateral', 'Cocorinha', 'Rolê'],
      tiempos_internos:
        dur >= 2 && half + rem === dur && dur > 1
          ? [
              { etapa: 'preparación y señales', minutos: half },
              { etapa: 'rondas y rotación activa', minutos: rem },
            ]
          : [{ etapa: 'ejecución continua', minutos: dur }],
      cancionero_reference: blockSpec.include_cancionero
        ? {
            song_title: audienceType === 'infantil' ? 'Marinheiro só' : 'Paraná ê',
            rhythm: audienceType === 'infantil' ? 'Corrido' : 'Benguela',
            audience_fit: audienceType === 'infantil' ? 'infantil' : 'adultos',
            lookup_hint: 'Buscar título en Cancionero GINGA',
          }
        : null,
    };
  });

  return {
    choices: [
      {
        finish_reason: 'stop',
        message: {
          content: JSON.stringify({
            fase: `Bloque ${blockSpec.block_id}: ${blockSpec.fase_tipo}`,
            ejercicios: exercises,
          }),
        },
      },
    ],
    usage: {
      prompt_tokens: 790,
      completion_tokens: 460 + (latencyDelayMs > 0 ? 10 : 0),
    },
  };
}

function makeFakeResourceRepo() {
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
      if (ids.includes('res_video_01')) {
        m.set('res_video_01', {
          resourceId: 'res_video_01',
          ownerId: 'local_dev_simulated_instructor',
          shared: true,
          title: 'Secuencia Queixada con desplazamiento',
          type: 'video',
          mediaKind: 'video',
          category: 'Técnica',
          notes: 'Entrada en diagonal cuidando guardia alta.',
          url: 'https://local-preview-video.invalid/vid1',
        });
      }
      return m;
    },
  };
}

async function main() {
  const catalog = loadVerifiedCatalog();
  const resRepo = makeFakeResourceRepo();
  const actorAuth = {};

  // 1. Quantitative prompt & schema reduction check on exact Infantil Advanced repro
  const reqInfantil = buildProfessorInfantilAdvancedRequest();
  const ctx = await buildValidatedContext({
    request: reqInfantil,
    actor: { actorId: 'local_dev_simulated_instructor', actorMode: 'local_dev_bypass' },
    catalog,
    resourceRepository: resRepo,
  });

  const monoPrompt = buildPlannerPrompts(ctx);
  const block0Prompt = buildSingleBlockPrompts(ctx, ctx.temporalBlueprint.blocks[0], {
    blockIndex: 0,
    totalBlocks: ctx.temporalBlueprint.blocks_count,
  });
  const monoSchemaLen = JSON.stringify(OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA).length;
  const slimSchemaLen = JSON.stringify(OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA).length;

  console.log('[metric] Monolithic input est tokens:', monoPrompt.estimatedInputTokens, '| schema chars:', monoSchemaLen);
  console.log('[metric] Modular block-0 input est tokens:', block0Prompt.estimatedInputTokens, '| slim schema chars:', slimSchemaLen);

  assert(block0Prompt.estimatedInputTokens < 1200, 'Per-block input tokens must stay < 1200');
  assert(block0Prompt.estimatedInputTokens < monoPrompt.estimatedInputTokens * 0.45, 'Must shrink per-call input >55%');
  assert(slimSchemaLen < 2000 && slimSchemaLen < monoSchemaLen * 0.6, 'Slim block schema must be <2000 chars');

  // Verify deterministic blueprint assigned required resource idea_res_02 with 0 adult FIU movements
  const assignedResources = ctx.temporalBlueprint.blocks.flatMap((b) =>
    b.exercise_slots.flatMap((s) => s.assigned_resource_ids)
  );
  const assignedMovements = ctx.temporalBlueprint.blocks.flatMap((b) =>
    b.exercise_slots.flatMap((s) => s.assigned_movement_ids)
  );
  assert(assignedResources.includes('idea_res_02'), 'Required resource idea_res_02 must be pre-assigned in blueprint');
  assert.strictEqual(assignedMovements.length, 0, 'Infantil blueprint must never assign FIU adult movements');

  // 2. Modular happy path with simulated parallel latencies (140ms per call, concurrency=2 across 4 blocks)
  const callLog = [];
  const tempState1 = path.join(os.tmpdir(), `ginga_mod_test_${Date.now()}_1.json`);
  const guard1 = new AtomicPilotBudgetGuard({
    maxBudgetUsd: 0.10,
    maxGenerations: 4,
    stateFilePath: tempState1,
  });

  const happyProvider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsedBody = JSON.parse(opts.body);
      const userMsg = parsedBody.messages[1].content;
      const match = userMsg.match(/"block_position":"(\d+)\/(\d+)"/);
      const blkIdx = Number(match[1]) - 1;
      const spec = ctx.temporalBlueprint.blocks[blkIdx];
      callLog.push(spec.block_id);
      await new Promise((r) => setTimeout(r, 140));
      return {
        ok: true,
        status: 200,
        json: async () => buildSlimBlockOpenAiBody(spec, { audienceType: 'infantil', latencyDelayMs: 140 }),
      };
    },
  });

  const progressEvents = [];
  const t0 = Date.now();
  const happyRes = await generateClassPlanV2({
    request: reqInfantil,
    authContext: actorAuth,
    deps: {
      catalog,
      quotaStore: new InMemoryAtomicQuotaStore(),
      budgetGuard: guard1,
      resourceRepository: resRepo,
      provider: happyProvider,
      onProgress: (ev) => progressEvents.push(ev),
    },
    serverOverrides: {
      providerMode: 'openai',
      realProviderEnabled: true,
      allowLocalDevSimulatedBypass: true,
      primaryModel: 'gpt-4o-mini',
      blockConcurrency: 2,
    },
  });
  const wallMs = Date.now() - t0;

  assert.strictEqual(happyRes.status, 'ok');
  assert.strictEqual(happyRes.generation_meta.generation_strategy, 'modular_block_v2');
  assert.strictEqual(happyRes.generation_meta.repair_attempts_used, 0);
  assert.strictEqual(happyRes.generation_meta.llm_calls_made, 5);
  assert.strictEqual(happyRes.plan.duracion_total, 60);
  assert.strictEqual(happyRes.plan.bloques.length, 5);
  assert.strictEqual(happyRes.validation_report.structural.passed, true);
  assert(happyRes.validation_report.structural.required_resources_covered);
  assert(happyRes.validation_report.structural.curriculum_track_respected);
  assert(happyRes.validation_report.pedagogical_heuristic.score_total >= 90);
  assert(wallMs < 620, `Expected 3-wave parallel latency < 620ms (sequential would be ~700ms), got ${wallMs}ms`);
  assert(progressEvents.some((e) => e.stage === 'generating_blocks'), 'Must emit block generation progress');
  assert(progressEvents.some((e) => e.stage === 'validating'), 'Must emit validation progress');
  assert.strictEqual(guard1.getSnapshot().completed_generations, 1);
  assert.strictEqual(guard1.getSnapshot().total_llm_calls, 5);
  assert(guard1.getSnapshot().spent_usd > 0 && guard1.getSnapshot().spent_usd < 0.01);
  console.log(`[ok] Happy modular Infantil repro: calls=${happyRes.generation_meta.llm_calls_made}, cost=$${happyRes.cost_telemetry.estimated_cost_usd}, wall=${wallMs}ms, heuristic=${happyRes.validation_report.pedagogical_heuristic.score_total}/100`);

  // 3. Partial single-block failure (blk_4 acrobacias_suelo injects Bananeira without mats) -> ONLY blk_4 is repaired!
  const callsPerBlock = [];
  let blk4Calls = 0;
  const repairProvider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsedBody = JSON.parse(opts.body);
      const userMsg = parsedBody.messages[1].content;
      const match = userMsg.match(/"block_position":"(\d+)\/(\d+)"/);
      const blkIdx = Number(match[1]) - 1;
      const spec = ctx.temporalBlueprint.blocks[blkIdx];
      const isRepair = userMsg.includes('REPARA SOLO ESTE BLOQUE');
      callsPerBlock.push({ blockId: spec.block_id, isRepair });

      if (spec.block_id === 'blk_4') {
        blk4Calls += 1;
        return {
          ok: true,
          status: 200,
          json: async () =>
            buildSlimBlockOpenAiBody(spec, {
              audienceType: 'infantil',
              injectBananeira: blk4Calls === 1,
            }),
        };
      }
      return {
        ok: true,
        status: 200,
        json: async () => buildSlimBlockOpenAiBody(spec, { audienceType: 'infantil' }),
      };
    },
  });

  const repairRes = await generateClassPlanV2({
    request: buildProfessorInfantilAdvancedRequest('req_infantil_repair_blk4'),
    authContext: actorAuth,
    deps: {
      catalog,
      quotaStore: new InMemoryAtomicQuotaStore(),
      budgetGuard: guard1,
      resourceRepository: resRepo,
      provider: repairProvider,
    },
    serverOverrides: {
      providerMode: 'openai',
      realProviderEnabled: true,
      allowLocalDevSimulatedBypass: true,
      primaryModel: 'gpt-4o-mini',
    },
  });

  assert.strictEqual(repairRes.generation_meta.repair_attempts_used, 1);
  assert.deepStrictEqual(repairRes.generation_meta.repaired_block_ids, ['blk_4']);
  assert.strictEqual(repairRes.generation_meta.llm_calls_made, 6);
  assert.strictEqual(
    callsPerBlock.filter((c) => c.isRepair).length,
    1,
    'Must run ONLY 1 repair call'
  );
  assert.strictEqual(
    callsPerBlock.find((c) => c.isRepair).blockId,
    'blk_4',
    'Must repair ONLY blk_4 without regenerating blk_1, blk_2, blk_3, blk_5'
  );
  console.log('[ok] Targeted single-block repair passed: repaired ONLY blk_4 (calls=6, repairs=1)');

  // 4. Timeout on Wave 2 (blk_4) settles EXACT partial usage cleanly
  const timeoutProvider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsedBody = JSON.parse(opts.body);
      const userMsg = parsedBody.messages[1].content;
      const match = userMsg.match(/"block_position":"(\d+)\/(\d+)"/);
      const blkIdx = Number(match[1]) - 1;
      const spec = ctx.temporalBlueprint.blocks[blkIdx];
      if (spec.block_id === 'blk_4') {
        const abortErr = new Error('The operation was aborted due to timeout');
        abortErr.name = 'AbortError';
        throw abortErr;
      }
      return {
        ok: true,
        status: 200,
        json: async () => buildSlimBlockOpenAiBody(spec, { audienceType: 'infantil' }),
      };
    },
  });

  let caughtTimeout = null;
  try {
    await generateClassPlanV2({
      request: buildProfessorInfantilAdvancedRequest('req_infantil_timeout_blk4'),
      authContext: actorAuth,
      deps: {
        catalog,
        quotaStore: new InMemoryAtomicQuotaStore(),
        budgetGuard: guard1,
        resourceRepository: resRepo,
        provider: timeoutProvider,
      },
      serverOverrides: {
        providerMode: 'openai',
        realProviderEnabled: true,
        allowLocalDevSimulatedBypass: true,
        primaryModel: 'gpt-4o-mini',
        blockTimeoutMs: 500,
      },
    });
  } catch (err) {
    caughtTimeout = err;
  }

  assert(caughtTimeout instanceof PlannerV2Error);
  assert.strictEqual(caughtTimeout.code, 'PROVIDER_TIMEOUT');
  assert.strictEqual(caughtTimeout.details.failed_block_id, 'blk_4');
  assert(caughtTimeout.details.partial_usage.callsMade >= 2, 'Wave 1 completed calls must be settled');
  assert.strictEqual(guard1.getSnapshot().completed_generations, 3);
  console.log(`[ok] Partial wave timeout settled cleanly: failed=${caughtTimeout.details.failed_block_id}, completed_gens=${guard1.getSnapshot().completed_generations}`);

  // 5. Monolithic repair timeout bugfix verification (repairs=1 reported instead of 0)
  const monoTimeoutRepairProvider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsedBody = JSON.parse(opts.body);
      const userMsg = parsedBody.messages[1].content;
      if (userMsg.includes('CORRECCIÓN OBLIGATORIA')) {
        const abortErr = new Error('timeout');
        abortErr.name = 'AbortError';
        throw abortErr;
      }
      return {
        ok: true,
        status: 200,
        json: async () => ({
          choices: [
            {
              finish_reason: 'stop',
              message: {
                content: JSON.stringify({
                  titulo: 'Incomplete Draft',
                  duracion_total: 60,
                  nivel: 'Infantil',
                  audience_type: 'infantil',
                  curriculum_scope: 'infantil_fiu_pending',
                  enfoque: 'Juegos',
                  objetivo: 'Objetivo breve',
                  objetivos: ['Objetivo breve'],
                  bloques: [],
                  consejos_instructor: 'Consejos',
                  continuity_applied_note: 'Nota',
                }),
              },
            },
          ],
          usage: { prompt_tokens: 3400, completion_tokens: 450 },
        }),
      };
    },
  });

  let monoRepairErr = null;
  try {
    await generateClassPlanV2({
      request: buildProfessorInfantilAdvancedRequest('req_mono_bugfix_check'),
      authContext: actorAuth,
      deps: {
        catalog,
        quotaStore: new InMemoryAtomicQuotaStore(),
        budgetGuard: guard1,
        resourceRepository: resRepo,
        provider: monoTimeoutRepairProvider,
      },
      serverOverrides: {
        providerMode: 'openai',
        realProviderEnabled: true,
        allowLocalDevSimulatedBypass: true,
        primaryModel: 'gpt-4o-mini',
        useModularGeneration: false,
      },
    });
  } catch (err) {
    monoRepairErr = err;
  }
  assert(monoRepairErr instanceof PlannerV2Error);
  assert.strictEqual(monoRepairErr.code, 'PROVIDER_TIMEOUT');
  assert.strictEqual(monoRepairErr.details.repair_attempts_used, 1, 'Bugfix: repair_attempts_used MUST be 1');
  console.log('[ok] Monolithic repair-timeout reporting bugfix verified (repair_attempts_used=1)');

  // 6. Preserved live budget file guard enforcement (must NEVER reset or surpass 4/4 without explicit authorization)
  const tempStatePreserved = path.join(os.tmpdir(), `ginga_preserved_${Date.now()}.json`);
  fs.writeFileSync(
    tempStatePreserved,
    JSON.stringify({
      max_budget_usd: 0.1,
      spent_usd: 0.00713,
      completed_generations: 4,
      max_generations: 4,
      total_llm_calls: 6,
    })
  );
  const preservedGuard = new AtomicPilotBudgetGuard({
    maxBudgetUsd: 0.10,
    maxGenerations: 4,
    stateFilePath: tempStatePreserved,
  });
  await assert.rejects(
    () =>
      generateClassPlanV2({
        request: buildProfessorInfantilAdvancedRequest('req_blocked_4_of_4'),
        authContext: actorAuth,
        deps: {
          catalog,
          quotaStore: new InMemoryAtomicQuotaStore(),
          budgetGuard: preservedGuard,
          resourceRepository: resRepo,
          provider: happyProvider,
        },
        serverOverrides: {
          providerMode: 'openai',
          realProviderEnabled: true,
          allowLocalDevSimulatedBypass: true,
          primaryModel: 'gpt-4o-mini',
        },
      }),
    (err) => err instanceof PlannerV2Error && err.code === 'PILOT_BUDGET_EXCEEDED'
  );
  console.log('[ok] Preserved 4/4 budget guard strictly blocks extra calls without authorization');

  // 7. Adulto FIU modular flow with required movement + video resource honesty
  const adultReq = {
    request_id: 'req_adult_fiu_modular',
    creation_mode: 'avanzada',
    group_context: {
      group_label: 'Adultos M/J 19:00',
      audience_type: 'adultos',
      age_min: 17,
      age_max: 42,
      estimated_participants: 12,
      experience_distribution: { principiantes: 4, intermedios: 6, avanzados: 2, manually_confirmed: true },
    },
    curriculum_context: {
      scope: 'adulto_fiu',
      target_corda_index: 1,
    },
    space_context: {
      space_size: 'amplio',
      floor_type: 'madera',
      available_mats: false,
      instructors_available: 1,
    },
    session_config: {
      duration_min: 60,
      focuses: ['Técnica', 'Musicalidad'],
      materials: ['Berimbau', 'Pandeiro'],
      include_musicality_roda: true,
      allow_ai_complementary_proposals: true,
    },
    selected_movements: [
      { movement_id: 'queixada', priority: 'required' },
      { movement_id: 'esquiva_lateral', priority: 'required' },
    ],
    selected_resources: [
      {
        resource_id: 'res_video_01',
        title: 'Secuencia Queixada con desplazamiento',
        type: 'video',
        category: 'Técnica',
        notes: 'Entrada en diagonal cuidando guardia alta.',
        usage_note: 'Usar en la fase técnica central.',
        has_external_video: true,
        priority: 'required',
      },
    ],
  };

  const adultCtx = await buildValidatedContext({
    request: adultReq,
    actor: { actorId: 'local_dev_simulated_instructor', actorMode: 'local_dev_bypass' },
    catalog,
    resourceRepository: resRepo,
  });
  const adultProvider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsedBody = JSON.parse(opts.body);
      const userMsg = parsedBody.messages[1].content;
      const match = userMsg.match(/"block_position":"(\d+)\/(\d+)"/);
      const blkIdx = Number(match[1]) - 1;
      const spec = adultCtx.temporalBlueprint.blocks[blkIdx];
      return {
        ok: true,
        status: 200,
        json: async () => buildSlimBlockOpenAiBody(spec, { audienceType: 'adultos' }),
      };
    },
  });

  const adultRes = await generateClassPlanV2({
    request: adultReq,
    authContext: actorAuth,
    deps: {
      catalog,
      quotaStore: new InMemoryAtomicQuotaStore(),
      resourceRepository: resRepo,
      provider: adultProvider,
    },
    serverOverrides: {
      providerMode: 'openai',
      realProviderEnabled: true,
      allowLocalDevSimulatedBypass: true,
      primaryModel: 'gpt-4o-mini',
    },
  });
  assert.strictEqual(adultRes.validation_report.structural.passed, true);
  assert(adultRes.validation_report.structural.required_movements_covered);
  assert(adultRes.validation_report.structural.required_resources_covered);
  assert(adultRes.generation_meta.origin_breakdown.teacher_resource >= 1);
  const videoEx = adultRes.plan.bloques
    .flatMap((b) => b.ejercicios)
    .find((e) => e.linked_resource_ids.includes('res_video_01'));
  assert(videoEx && /no inspecciona/i.test(videoEx.video_reference_note));
  console.log('[ok] Adulto FIU modular + video honesty + precedence passed');

  // 8. Multi-block subset repair in 1 parallel pass (blk_1 + blk_4 fail; blk_2, blk_3, blk_5 untouched)
  // AND Spanish natural game wording accepted vs vague game rejected
  const subsetRepairCalls = [];
  const blockAttemptCounts = {};
  const subsetRepairProvider = new OpenAiStructuredProvider({
    apiKey: 'dummy_test_key_offline',
    fetchImpl: async (_url, opts) => {
      const parsedBody = JSON.parse(opts.body);
      const userMsg = parsedBody.messages[1].content;
      const match = userMsg.match(/"block_position":"(\d+)\/(\d+)"/);
      const blkIdx = Number(match[1]) - 1;
      const spec = ctx.temporalBlueprint.blocks[blkIdx];
      const isRepair = userMsg.includes('REPARA SOLO ESTE BLOQUE');
      subsetRepairCalls.push({ blockId: spec.block_id, isRepair });
      blockAttemptCounts[spec.block_id] = (blockAttemptCounts[spec.block_id] || 0) + 1;

      const bodyObj = buildSlimBlockOpenAiBody(spec, { audienceType: 'infantil' });
      const parsedContent = JSON.parse(bodyObj.choices[0].message.content);
      if ((spec.block_id === 'blk_1' || spec.block_id === 'blk_4') && blockAttemptCounts[spec.block_id] === 1) {
        // Vague game fails GAME_MISSING_EXECUTABLE_RULES
        parsedContent.ejercicios[0].tipo_actividad = 'juego_dinamico';
        parsedContent.ejercicios[0].detalle = 'Jugar libremente por la sala.';
      } else if (spec.block_id !== 'blk_5') {
        // Natural Spanish game structure (setup + cue + turns >= 75 chars, without literal stem "regla") passes
        parsedContent.ejercicios[0].tipo_actividad = 'juego_dinamico';
        parsedContent.ejercicios[0].detalle =
          'Ubicados en círculo amplio en parejas manteniendo distancia segura; al toque de palmas (o berimbau si está disponible) practican Ginga, cambian de lado y alternan turno cada 45 segundos en rondas.';
      }
      bodyObj.choices[0].message.content = JSON.stringify(parsedContent);
      return { ok: true, status: 200, json: async () => bodyObj };
    },
  });

  const subsetRes = await generateClassPlanV2({
    request: buildProfessorInfantilAdvancedRequest('req_subset_repair_01'),
    authContext: actorAuth,
    deps: {
      catalog,
      quotaStore: new InMemoryAtomicQuotaStore(),
      resourceRepository: resRepo,
      provider: subsetRepairProvider,
    },
    serverOverrides: {
      providerMode: 'openai',
      realProviderEnabled: true,
      allowLocalDevSimulatedBypass: true,
      primaryModel: 'gpt-4o-mini',
    },
  });
  assert.strictEqual(subsetRes.validation_report.structural.passed, true);
  assert.strictEqual(subsetRes.generation_meta.repair_attempts_used, 1);
  assert.deepStrictEqual(subsetRes.generation_meta.repaired_block_ids, ['blk_1', 'blk_4']);
  assert.strictEqual(subsetRes.generation_meta.llm_calls_made, 7);
  assert.deepStrictEqual(
    subsetRepairCalls.filter((c) => c.isRepair).map((c) => c.blockId),
    ['blk_1', 'blk_4']
  );
  console.log('[ok] Multi-block subset repair in 1 pass + natural Spanish game rules verified');

  // 9. Keyword-only gaming check (long vague sentence with ONLY "rondas" must FAIL 3-dimension game validator)
  const keywordOnlyGuardPlan = JSON.parse(JSON.stringify(subsetRes.plan));
  keywordOnlyGuardPlan.bloques[0].ejercicios[0].tipo_actividad = 'juego_dinamico';
  keywordOnlyGuardPlan.bloques[0].ejercicios[0].detalle =
    'Los niños hacen rondas divertidas practicando ginga libremente por todo el salón de clases con mucha alegría y entusiasmo. ' +
    'Tiempos internos (Ejecución 6 min = total: 6 min).';
  const { validateGeneratedPlan } = require('../functions/planner_v2/plan_validator');
  const keywordVal = validateGeneratedPlan(keywordOnlyGuardPlan, ctx, catalog);
  assert(
    keywordVal.structuralValidation.errors.some((e) => e.code === 'GAME_MISSING_EXECUTABLE_RULES'),
    'Must reject game lacking spatial setup & rules/cues even if long and containing "rondas"'
  );

  // 10. Multi-block budget worst-case reservation covers ALL initial blocks + ALL repaired blocks simultaneously (2000 out tokens)
  const singleRepairCost = guard1.estimateWorstCaseGenerationUsd({
    model: 'gpt-4o-mini',
    estimatedInputTokens: 950,
    blockMaxOutputTokens: 2000,
    blocksCount: 5,
    mode: 'modular',
    maxRepairAttempts: 0,
  });
  const multiRepairWorst = guard1.estimateWorstCaseGenerationUsd({
    model: 'gpt-4o-mini',
    estimatedInputTokens: 950,
    blockMaxOutputTokens: 2000,
    blocksCount: 5,
    mode: 'modular',
    maxRepairAttempts: 1,
  });
  assert(
    multiRepairWorst > singleRepairCost * 2,
    `Multi-block modular budget worst-case (${multiRepairWorst}) must reserve initial 5 blocks + 5 simultaneous repaired blocks`
  );
  console.log(`[ok] 3-dimension executable game validator & multi-block budget worst-case ($${multiRepairWorst}) verified`);

  // Cleanup temp files
  [tempState1, tempStatePreserved].forEach((p) => {
    if (fs.existsSync(p)) fs.unlinkSync(p);
  });

  console.log('ALL_MODULAR_STABILIZATION_TESTS_PASSED');
}

main().catch((err) => {
  console.error('FAIL:', err);
  process.exitCode = 1;
});

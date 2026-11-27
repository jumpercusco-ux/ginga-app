#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');
const {
  generateClassPlanV2,
  loadVerifiedCatalog,
  AtomicPilotBudgetGuard,
  OpenAiStructuredProvider,
  listAccessibleOpenAiModels,
  SimulatedPlannerProvider,
  InMemoryAtomicQuotaStore,
  PlannerV2Error,
} = require('../functions/planner_v2');
const {
  OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA,
  normalizeOpenAiWirePlan,
} = require('../functions/planner_v2/response_schema');
const {
  buildPilotScenarios,
  buildPilotResourceRepository,
  buildScenarioEvaluationReport,
  runDryRunPilotCheck,
  runAuthorizedPaidPilot,
} = require('./run_planner_v2_real_pilot');

async function testBudgetGuardConcurrencyAndExactSettlement() {
  // Exact ceiling: USD 0.10, max 4 generations, considering concurrent bursts + repairs
  const guard = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 });
  const worst = guard.estimateWorstCaseGenerationUsd({
    model: 'gpt-4.1-mini',
    estimatedInputTokens: 2500,
    maxOutputTokens: 4500,
    maxRepairAttempts: 1,
  });
  // primary = 2500*0.4/1e6 + 4500*1.6/1e6 = 0.001 + 0.0072 = 0.0082
  // repair = 7000*0.4/1e6 + 4500*1.6/1e6 = 0.0028 + 0.0072 = 0.0100
  // total = 0.0182
  assert(worst > 0.015 && worst < 0.025, `Worst case fuera de rango esperado: ${worst}`);

  const results = await Promise.allSettled([
    guard.reserveGeneration({ requestId: 'c1', model: 'gpt-4.1-mini', estimatedInputTokens: 2500, maxOutputTokens: 4500 }),
    guard.reserveGeneration({ requestId: 'c2', model: 'gpt-4.1-mini', estimatedInputTokens: 2500, maxOutputTokens: 4500 }),
    guard.reserveGeneration({ requestId: 'c3', model: 'gpt-4.1-mini', estimatedInputTokens: 2500, maxOutputTokens: 4500 }),
    guard.reserveGeneration({ requestId: 'c4', model: 'gpt-4.1-mini', estimatedInputTokens: 2500, maxOutputTokens: 4500 }),
    guard.reserveGeneration({ requestId: 'c5', model: 'gpt-4.1-mini', estimatedInputTokens: 2500, maxOutputTokens: 4500 }),
  ]);

  const fulfilled = results.filter((r) => r.status === 'fulfilled');
  const rejected = results.filter((r) => r.status === 'rejected');
  assert.strictEqual(fulfilled.length, 4);
  assert.strictEqual(rejected.length, 1);
  assert.strictEqual(rejected[0].reason.code, 'PILOT_BUDGET_EXCEEDED');

  // Settle actual spend (< worst case) and verify exact remaining balance
  await guard.settleGeneration({ requestId: 'c1', actualCostUsd: 0.0045, actualCalls: 1, succeeded: true });
  const snap = guard.getSnapshot();
  assert.strictEqual(snap.completed_generations, 1);
  assert.strictEqual(snap.in_flight_generations, 3);
  assert.strictEqual(snap.spent_usd, 0.0045);

  // Also verify USD budget cap triggers even if maxGenerations is higher
  const tightGuard = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.03, maxGenerations: 10 });
  await tightGuard.reserveGeneration({ requestId: 't1', model: 'gpt-4.1-mini', estimatedInputTokens: 2500, maxOutputTokens: 4500 });
  let tightRejected = false;
  try {
    await tightGuard.reserveGeneration({ requestId: 't2', model: 'gpt-4.1-mini', estimatedInputTokens: 2500, maxOutputTokens: 4500 });
  } catch (e) {
    tightRejected = e instanceof PlannerV2Error && e.code === 'PILOT_BUDGET_EXCEEDED';
  }
  assert(tightRejected, 'Debe rechazar segunda reserva concurrente si el worst-case acumulado supera USD 0.03.');
  console.log('[PASS] 01_budget_guard_concurrency_and_usd_ceiling');
}

async function testOpenAiAdapterMockAndFailedRepairSettlement() {
  const catalog = loadVerifiedCatalog();
  const sim = new SimulatedPlannerProvider({ catalog });
  const scenarios = buildPilotScenarios();
  const resourceRepository = buildPilotResourceRepository();
  const quotaStore = new InMemoryAtomicQuotaStore();
  const budgetGuard = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 });

  // Use simulated output cleanly to build a mock HTTP 200 OpenAI JSON response (ZERO network calls!)
  const simResp = await generateClassPlanV2({
    request: scenarios[1].request,
    authContext: { uid: 'prof_test', token: { instructor: true } },
    deps: { catalog, resourceRepository },
  });

  const capturedBodies = [];
  const mockFetch = async (_url, init) => {
    capturedBodies.push(JSON.parse(init.body));
    return {
      ok: true,
      status: 200,
      async json() {
        return {
          choices: [
            {
              finish_reason: 'stop',
              message: { content: JSON.stringify(simResp.plan) },
            },
          ],
          usage: {
            prompt_tokens: 2100,
            completion_tokens: 1900,
          },
        };
      },
    };
  };

  // Disabled by default even with mockFetch
  const disabledProvider = new OpenAiStructuredProvider({ apiKey: 'dummy_not_used', fetchImpl: mockFetch });
  let disabledBlocked = false;
  try {
    await generateClassPlanV2({
      request: scenarios[1].request,
      authContext: { uid: 'prof_test', token: { instructor: true } },
      deps: { catalog, provider: disabledProvider, quotaStore, budgetGuard, resourceRepository },
      serverOverrides: { realProviderEnabled: false },
    });
  } catch (e) {
    disabledBlocked = e.code === 'REAL_PROVIDER_DISABLED';
  }
  assert(disabledBlocked, 'Debe rechazar OpenAI si realProviderEnabled != true.');

  // Enabled in local dev with injected mockFetch -> 0 live network calls
  const enabledProvider = new OpenAiStructuredProvider({ apiKey: 'dummy_local_mock', fetchImpl: mockFetch });
  const mockResp = await generateClassPlanV2({
    request: { ...scenarios[1].request, request_id: 'mock_openai_pilot_2' },
    authContext: { uid: 'prof_test', token: { instructor: true } },
    deps: { catalog, provider: enabledProvider, quotaStore, budgetGuard, resourceRepository },
    serverOverrides: { providerMode: 'openai', realProviderEnabled: true, useModularGeneration: false },
  });

  assert.strictEqual(capturedBodies.length, 1);
  assert.strictEqual(capturedBodies[0].model, 'gpt-4o-mini');
  assert.strictEqual(capturedBodies[0].response_format.type, 'json_schema');
  assert.strictEqual(mockResp.generation_meta.provider, 'openai');
  assert.strictEqual(mockResp.generation_meta.is_simulated, false);
  assert.strictEqual(mockResp.validation_report.real_llm_quality_status, 'pending_human_evaluation');
  assert(mockResp.cost_telemetry.pilot_budget.spent_usd > 0);

  // Verify failed repair after billable primary still accounts primary cost in budgetGuard
  const brokenPlan = JSON.parse(JSON.stringify(simResp.plan));
  brokenPlan.duracion_total = 999; // invalid duration forces repair
  const alwaysBrokenProvider = {
    name: 'openai',
    async generateStructured() {
      return {
        provider: 'openai',
        model: 'gpt-4.1-mini',
        isSimulated: false,
        rawPlan: brokenPlan,
        usage: { inputTokens: 2000, outputTokens: 1500, estimatedCostUsd: 0.0032, latencyMs: 10 },
      };
    },
  };
  let repairFailed = false;
  try {
    await generateClassPlanV2({
      request: { ...scenarios[2].request, request_id: 'mock_openai_broken_repair' },
      authContext: { uid: 'prof_test', token: { instructor: true } },
      deps: { catalog, provider: alwaysBrokenProvider, quotaStore, budgetGuard, resourceRepository },
      serverOverrides: { providerMode: 'openai', realProviderEnabled: true, useModularGeneration: false },
    });
  } catch (e) {
    repairFailed = e.code === 'VALIDATION_FAILED_AFTER_REPAIR';
  }
  assert(repairFailed);
  const afterSnap = budgetGuard.getSnapshot();
  assert.strictEqual(afterSnap.in_flight_generations, 0);
  assert.strictEqual(afterSnap.total_llm_calls, 3); // 1 from mockResp + 2 from broken initial+repair

  // Check evaluation report separates structural, heuristic, and human pending
  const evalReport = buildScenarioEvaluationReport(scenarios[1], mockResp);
  assert.strictEqual(evalReport.human_evaluation.status, 'pending');
  assert.strictEqual(evalReport.human_evaluation.dimensions.length, 12);
  assert.strictEqual(evalReport.structural_checks.uninspected_video_honesty_required, true);
  assert.strictEqual(evalReport.structural_checks.uninspected_video_honesty_note_present, true);

  console.log('[PASS] 02_openai_adapter_mock_and_repair_budget_accounting');
}

async function testPilotDryRunAndPaidAuthGate() {
  const dry = await runDryRunPilotCheck();
  assert.strictEqual(dry.mode, 'dry_run_zero_paid_calls');
  assert.strictEqual(dry.real_provider_default_enabled, false);
  assert.strictEqual(dry.primary_model, 'gpt-4o-mini');
  assert.strictEqual(dry.max_budget_usd, 0.10);
  assert.strictEqual(dry.max_generations, 4);
  assert.strictEqual(dry.scenarios.length, 4);
  assert(dry.worst_case_4_scenarios_with_all_repairs_usd <= 0.10, `Worst-case 4 scenarios USD ${dry.worst_case_4_scenarios_with_all_repairs_usd} excede USD 0.10`);

  let authGateBlocked = false;
  try {
    await runAuthorizedPaidPilot();
  } catch (e) {
    authGateBlocked = /PLANNER_V2_ALLOW_PAID_PILOT=YES/.test(e.message);
  }
  assert(authGateBlocked, 'runAuthorizedPaidPilot debe exigir PLANNER_V2_ALLOW_PAID_PILOT=YES.');
  console.log('[PASS] 03_pilot_dry_run_and_paid_authorization_gate');
}

function testOpenAiStrictSchemaCompliance() {
  const forbiddenKeywords = new Set(['minLength', 'maxLength', 'minItems', 'maxItems', 'minimum', 'maximum']);

  function walk(node, path) {
    if (!node || typeof node !== 'object') return;
    for (const kw of forbiddenKeywords) {
      assert(!Object.prototype.hasOwnProperty.call(node, kw), `Keyword prohibido en OpenAI strict schema en ${path}: ${kw}`);
    }
    if (Array.isArray(node.type) && node.type.includes('object')) {
      assert(!node.properties, `Nodo ${path} usa type nullable con properties directo en lugar de anyOf`);
    }
    if (node.type === 'object') {
      assert.strictEqual(node.additionalProperties, false, `Falta additionalProperties:false en ${path}`);
      const propKeys = Object.keys(node.properties || {});
      const req = new Set(node.required || []);
      for (const k of propKeys) {
        assert(req.has(k), `Falta '${k}' en required de ${path}`);
      }
    }
    if (node.properties) {
      for (const [k, v] of Object.entries(node.properties)) walk(v, `${path}.properties.${k}`);
    }
    if (node.items) walk(node.items, `${path}.items`);
    if (Array.isArray(node.anyOf)) node.anyOf.forEach((opt, i) => walk(opt, `${path}.anyOf[${i}]`));
  }

  walk(OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA.schema, 'root');
  const normalized = normalizeOpenAiWirePlan({
    bloques: [
      {
        ejercicios: [
          { resource_usage_notes: [{ resource_id: 'r1', note: 'usar al inicio' }] },
        ],
      },
    ],
  });
  assert.deepStrictEqual(normalized.bloques[0].ejercicios[0].resource_usage_notes, { r1: 'usar al inicio' });
  console.log('[PASS] 04_openai_strict_schema_and_wire_normalization');
}

async function testModelAccessDeniedFallbackAndProbe() {
  const probe = await listAccessibleOpenAiModels({
    apiKey: 'dummy_key_never_logged',
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      async json() {
        return { data: [{ id: 'gpt-4o-mini' }, { id: 'whisper-1' }] };
      },
    }),
  });
  assert.strictEqual(probe.checked, true);
  assert.deepStrictEqual(probe.accessibleCandidates, ['gpt-4o-mini']);
  assert.strictEqual(probe.recommendedPrimary, 'gpt-4o-mini');
  assert.strictEqual(probe.recommendedFallback, '');

  const catalog = loadVerifiedCatalog();
  const scenarios = buildPilotScenarios();
  const resourceRepository = buildPilotResourceRepository();
  const quotaStore = new InMemoryAtomicQuotaStore();
  const budgetGuard = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 });

  const simResp = await generateClassPlanV2({
    request: scenarios[0].request,
    authContext: { uid: 'prof_test', token: { instructor: true } },
    deps: { catalog, resourceRepository },
  });

  const attemptedModels = [];
  const fallbackFetch = async (_url, init) => {
    const body = JSON.parse(init.body);
    attemptedModels.push(body.model);
    if (body.model === 'gpt-4.1-mini') {
      return {
        ok: false,
        status: 403,
        async json() {
          return {
            error: {
              code: 'model_not_found',
              message: 'Project does not have access to model `gpt-4.1-mini`.',
            },
          };
        },
      };
    }
    return {
      ok: true,
      status: 200,
      async json() {
        return {
          choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(simResp.plan) } }],
          usage: { prompt_tokens: 2000, completion_tokens: 2000 },
        };
      },
    };
  };

  const fallbackProvider = new OpenAiStructuredProvider({ apiKey: 'dummy_key', fetchImpl: fallbackFetch });
  const resp = await generateClassPlanV2({
    request: { ...scenarios[0].request, request_id: 'fallback_403_test_01' },
    authContext: { uid: 'prof_test', token: { instructor: true } },
    deps: { catalog, provider: fallbackProvider, quotaStore, budgetGuard, resourceRepository },
    serverOverrides: {
      providerMode: 'openai',
      realProviderEnabled: true,
      primaryModel: 'gpt-4.1-mini',
      fallbackModel: 'gpt-4o-mini',
      useModularGeneration: false,
    },
  });

  assert.deepStrictEqual(attemptedModels, ['gpt-4.1-mini', 'gpt-4o-mini']);
  assert.strictEqual(resp.generation_meta.model, 'gpt-4o-mini');
  assert.strictEqual(resp.generation_meta.model_fallback_from, 'gpt-4.1-mini');
  assert(
    resp.generation_meta.transparency_notices.some((n) => /Fallback controlado/.test(n)),
    'Debe informar el fallback controlado en transparency_notices.'
  );
  // Exact gpt-4o-mini cost for 2000 in + 2000 out = 2000*0.15/1e6 + 2000*0.60/1e6 = 0.0015
  assert.strictEqual(resp.cost_telemetry.estimated_cost_usd, 0.0015);
  assert.strictEqual(resp.cost_telemetry.pilot_budget.spent_usd, 0.0015);
  assert.strictEqual(resp.cost_telemetry.pilot_budget.completed_generations, 1);
  console.log('[PASS] 05_model_access_denied_fallback_and_model_probe');
}

async function testInfantilAdvancedGpt4oMiniRegressionAndBudgetPersistence() {
  // 1. Strict schema enforces cantiga_id: { type: 'null' }
  const cantigaSchema =
    OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA.schema.properties.bloques.items.properties.ejercicios.items.properties
      .cancionero_reference.anyOf[0].properties.cantiga_id;
  assert.strictEqual(cantigaSchema.type, 'null');

  // 2. Persistent AtomicPilotBudgetGuard does NOT reset spent_usd across restarts
  const tmpStateFile = path.join(os.tmpdir(), `ginga_budget_test_${Date.now()}.json`);
  try {
    const guard1 = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4, stateFilePath: tmpStateFile });
    await guard1.reserveGeneration({ requestId: 'p1', model: 'gpt-4o-mini', estimatedInputTokens: 2000, maxOutputTokens: 4500 });
    await guard1.settleGeneration({ requestId: 'p1', actualCostUsd: 0.003131, actualCalls: 2, succeeded: false });

    const guard2 = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4, stateFilePath: tmpStateFile });
    const snap2 = guard2.getSnapshot();
    assert.strictEqual(snap2.spent_usd, 0.003131);
    assert.strictEqual(snap2.completed_generations, 1);
    assert.strictEqual(snap2.total_llm_calls, 2);
  } finally {
    if (fs.existsSync(tmpStateFile)) fs.unlinkSync(tmpStateFile);
  }

  // 3. Reproduces realistic GPT-4o-mini Infantil Advanced artifacts:
  //    Pass 1: has "Ninguno" in materiales (Level 1 strips cleanly), cantiga_id: "" (Level 1 normalizes to null),
  //    PLUS real errors (missing diferenciacion_avanzados + block duration mismatch -> triggers numbered Level 2 repair checklist)
  //    Pass 2: fixed cleanly and passes deterministic validation.
  const catalog = loadVerifiedCatalog();
  const scenarios = buildPilotScenarios();
  const resourceRepository = buildPilotResourceRepository();
  const quotaStore = new InMemoryAtomicQuotaStore();
  const budgetGuard = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 });

  const simResp = await generateClassPlanV2({
    request: scenarios[1].request,
    authContext: { uid: 'prof_test', token: { instructor: true } },
    deps: { catalog, resourceRepository },
  });

  const brokenDraft = JSON.parse(JSON.stringify(simResp.plan));
  brokenDraft.bloques[0].ejercicios[0].materiales = ['Ninguno'];
  brokenDraft.bloques[0].ejercicios[0].diferenciacion_avanzados = '';
  brokenDraft.bloques[0].duracion_min += 5; // triggers BLOCK_EXERCISES_DURATION_MISMATCH + BLOCKS_DURATION_SUM_MISMATCH
  brokenDraft.bloques[brokenDraft.bloques.length - 1].ejercicios[0].cancionero_reference = {
    song_title: 'Marinheiro só',
    rhythm: 'São Bento Grande',
    audience_fit: 'infantil',
    cantiga_id: '',
    lookup_hint: 'Buscar Marinheiro só',
  };

  const fixedDraft = JSON.parse(JSON.stringify(simResp.plan));
  fixedDraft.bloques[0].ejercicios[0].materiales = ['Sin materiales']; // also cleaned non-semantically at Level 1

  const repairUserPrompts = [];
  let callIndex = 0;
  const regFetch = async (_url, init) => {
    const body = JSON.parse(init.body);
    callIndex += 1;
    if (callIndex === 2) {
      repairUserPrompts.push(body.messages[1].content);
    }
    const chosen = callIndex === 1 ? brokenDraft : fixedDraft;
    return {
      ok: true,
      status: 200,
      async json() {
        return {
          choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(chosen) } }],
          usage: { prompt_tokens: 2400, completion_tokens: 1800 },
        };
      },
    };
  };

  const provider = new OpenAiStructuredProvider({ apiKey: 'dummy_key', fetchImpl: regFetch });
  const resp = await generateClassPlanV2({
    request: { ...scenarios[1].request, request_id: 'infantil_adv_reg_01' },
    authContext: { uid: 'prof_test', token: { instructor: true } },
    deps: { catalog, provider, quotaStore, budgetGuard, resourceRepository },
    serverOverrides: { providerMode: 'openai', realProviderEnabled: true, primaryModel: 'gpt-4o-mini', useModularGeneration: false },
  });

  assert.strictEqual(callIndex, 2);
  assert.strictEqual(resp.generation_meta.repair_attempts_used, 1);
  assert(
    resp.generation_meta.deterministic_fixes_applied.some((f) => f.startsWith('strip_empty_material_placeholders:')) &&
      resp.generation_meta.deterministic_fixes_applied.some((f) => f.startsWith('reconcile_block_header_duration:')),
    'Debe limpiar placeholders y reconciliar encabezado aritmético sin debilitar materiales no declarados.'
  );
  assert(
    repairUserPrompts[0].includes('CORRECCIÓN OBLIGATORIA DEL BORRADOR ANTERIOR') &&
      repairUserPrompts[0].includes('[MISSING_LEVEL_DIFFERENTIATION]'),
    'El prompt de reparación debe enumerar con precisión los códigos incumplidos tras Nivel 1.'
  );

  // Confirm real undeclared material (e.g. 'Conos' when materialsKnown=true) is STILL rejected strictly
  const declaredMatCtxReq = {
    ...scenarios[1].request,
    request_id: 'infantil_adv_undeclared_mat_02',
    session_config: {
      ...scenarios[1].request.session_config,
      materials: ['Pandeiro'],
    },
  };
  const undeclaredPlan = JSON.parse(JSON.stringify(simResp.plan));
  undeclaredPlan.bloques[0].ejercicios[0].materiales = ['Conos'];
  const undeclaredProvider = {
    name: 'openai',
    async generateStructured() {
      return {
        provider: 'openai',
        model: 'gpt-4o-mini',
        isSimulated: false,
        rawPlan: undeclaredPlan,
        usage: { inputTokens: 1000, outputTokens: 1000, estimatedCostUsd: 0.00075, latencyMs: 10 },
      };
    },
  };
  let undeclaredErrCode = '';
  try {
    await generateClassPlanV2({
      request: declaredMatCtxReq,
      authContext: { uid: 'prof_test', token: { instructor: true } },
      deps: { catalog, provider: undeclaredProvider, quotaStore, budgetGuard, resourceRepository },
      serverOverrides: { providerMode: 'openai', realProviderEnabled: true, primaryModel: 'gpt-4o-mini', useModularGeneration: false },
    });
  } catch (e) {
    undeclaredErrCode = e.details?.errors?.[0]?.code || e.code;
  }
  assert.strictEqual(undeclaredErrCode, 'UNDECLARED_MATERIAL_USED');

  console.log('[PASS] 06_infantil_advanced_gpt4o_mini_regression_and_budget_persistence');
}

async function main() {
  await testBudgetGuardConcurrencyAndExactSettlement();
  await testOpenAiAdapterMockAndFailedRepairSettlement();
  await testPilotDryRunAndPaidAuthGate();
  testOpenAiStrictSchemaCompliance();
  await testModelAccessDeniedFallbackAndProbe();
  await testInfantilAdvancedGpt4oMiniRegressionAndBudgetPersistence();
  console.log('ALL PLANNER V2 PILOT & BUDGET TESTS PASSED (6/6).');
}

main().catch((err) => {
  console.error('FAIL test_planner_v2_pilot_and_budget:', err);
  process.exitCode = 1;
});

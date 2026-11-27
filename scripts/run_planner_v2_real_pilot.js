#!/usr/bin/env node
'use strict';

/**
 * Controlled Real OpenAI Pilot Runner & Pedagogical Evaluation Matrix (`PED-04C2-D`).
 *
 * SAFETY BY DEFAULT:
 * - Default (`--dry-run`): makes ZERO network / OpenAI calls. Validates all 4 pilot request payloads,
 *   computes worst-case and realistic token/USD bounds under `AtomicPilotBudgetGuard` ($0.10 cap),
 *   and reports credential presence (boolean only, never prints values).
 * - Paid execution (`--authorize-paid-pilot`): requires explicit CLI flag `--authorize-paid-pilot`,
 *   env `PLANNER_V2_ALLOW_PAID_PILOT=YES`, and server OpenAI API key (`PLANNER_V2_OPENAI_API_KEY` or `OPENAI_API_KEY`).
 * - Never treats offline simulator output as evidence of real LLM quality.
 */

const fs = require('fs');
const path = require('path');
const {
  generateClassPlanV2,
  getServerConfig,
  resolveServerOpenAiApiKey,
  hasServerOpenAiCredentials,
  loadVerifiedCatalog,
  listAccessibleOpenAiModels,
  AtomicPilotBudgetGuard,
  InMemoryAtomicQuotaStore,
} = require('../functions/planner_v2');
const { resolveMaxOutputTokens, estimateCostUsd } = require('../functions/planner_v2/config');
const { buildValidatedContext } = require('../functions/planner_v2/context_builder');
const { buildPlannerPrompts } = require('../functions/planner_v2/prompt_builder');

const PILOT_EVALUATION_DIMENSIONS = [
  { id: 'structural_validation', label: '1. Validación estructural', kind: 'deterministic' },
  { id: 'exact_duration', label: '2. Duración exacta', kind: 'deterministic' },
  { id: 'internal_timing_coherence', label: '3. Coherencia de los tiempos internos', kind: 'deterministic_and_human' },
  { id: 'real_capoeira_terminology', label: '4. Nombres técnicos reales de capoeira', kind: 'human' },
  { id: 'sufficient_exercise_detail', label: '5. Ejercicios suficientemente detallados', kind: 'human' },
  { id: 'games_rules_prep_rounds', label: '6. Juegos con reglas, preparación y rondas', kind: 'human' },
  { id: 'level_differentiation', label: '7. Diferenciación efectiva por experiencia', kind: 'human' },
  { id: 'age_space_instructor_safety', label: '8. Seguridad según edad, espacio e instructores', kind: 'deterministic_and_human' },
  { id: 'faithful_resource_integration', label: '9. Integración fiel de recursos seleccionados', kind: 'deterministic_and_human' },
  { id: 'pedagogical_continuity', label: '10. Continuidad pedagógica', kind: 'human' },
  { id: 'no_false_curriculum_attribution', label: '11. Ausencia de atribuciones curriculares falsas', kind: 'deterministic' },
  { id: 'uninspected_video_honesty', label: '12. Honestidad sobre videos no inspeccionados', kind: 'deterministic_and_human' },
];

const PILOT_PREVIEW_RESOURCES = [
  {
    resource_id: 'pilot_res_infantil_juego',
    ownerId: 'local_dev_simulated_instructor',
    shared: true,
    title: 'Juego de esquiva con cuerdas en parejas',
    type: 'juego',
    mediaKind: 'nota',
    category: 'Juegos',
    notes: 'Reglas claras: dos cuerdas paralelas a 2 m, 3 rondas de 90 s rotando parejas sin eliminados.',
    url: '',
  },
  {
    resource_id: 'pilot_res_video_au',
    ownerId: 'local_dev_simulated_instructor',
    shared: true,
    title: 'Progresión Aú con banco bajo',
    type: 'video',
    mediaKind: 'video',
    category: 'Acrobacias',
    notes: 'Video corto de apoyo lateral con manos firmes; solo progresión lateral baja, sin invertidas mantenidas.',
    url: 'https://local-preview-video.invalid/au-banco-bajo',
  },
  {
    resource_id: 'pilot_res_adulto_drill',
    ownerId: 'local_dev_simulated_instructor',
    shared: true,
    title: 'Drill esquiva en parejas sin pausa',
    type: 'video',
    mediaKind: 'video',
    category: 'Técnica Marcial',
    notes: 'Trabajo continuo alternando ataque circular controlado y defensa baja.',
    url: 'https://local-preview-video.invalid/drill-esquiva',
  },
];

function buildPilotScenarios() {
  return [
    {
      id: 'pilot_01_infantil_multinivel',
      title: 'Piloto 1: Infantil 5–11 años multinivel',
      request: {
        contract_version: '2.1.0',
        request_id: 'pilot_01_infantil_multinivel',
        creation_mode: 'rápida',
        group_context: {
          source: 'real_class',
          group_label: 'Infantil Multinivel 5–11 años',
          audience_type: 'infantil',
          age_min: 5,
          age_max: 11,
          estimated_participants: 10,
          experience_distribution: {
            principiantes: 5,
            intermedios: 3,
            avanzados: 2,
            manually_confirmed: true,
          },
        },
        curriculum_context: { scope: 'infantil_fiu_pending' },
        space_context: { space_size: 'desconocido', floor_type: 'desconocido', instructors_available: 1 },
        session_config: {
          duration_min: 60,
          focuses: ['Técnica', 'Juegos', 'Musicalidad'],
          objectives: ['Afianzar Ginga continua y esquiva lúdica sin tiempos muertos'],
          include_musicality_roda: true,
          allow_ai_complementary_proposals: true,
          free_instructions:
            'Grupo mixto en niveles de 5 a 11 años. Sin colchonetas confirmadas: priorizar desplazamientos seguros y participación simultánea.',
        },
        selected_movements: [],
        selected_resources: [],
      },
    },
    {
      id: 'pilot_02_infantil_movimientos_y_recursos',
      title: 'Piloto 2: Infantil con movimientos específicos y recursos del profesor',
      request: {
        contract_version: '2.1.0',
        request_id: 'pilot_02_infantil_movimientos_y_recursos',
        creation_mode: 'avanzada',
        group_context: {
          source: 'real_class',
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
          focuses: ['Técnica', 'Juegos', 'Acrobacias'],
          objectives: ['Conectar Ginga, Cocorinha y Armada básica con Aú lateral bajo'],
          include_musicality_roda: true,
          allow_ai_complementary_proposals: true,
          free_instructions:
            'Trabajar Ginga, Cocorinha, Armada controlada y Aú lateral bajo en grupos breves antes de combinar en parejas. No programar Bananeira ni Ponte.',
        },
        selected_movements: [],
        selected_resources: [
          {
            resource_id: 'pilot_res_infantil_juego',
            priority: 'required',
            usage_note: 'Usar en bloque de juegos con explicación previa y 3 rondas cronometradas.',
          },
          {
            resource_id: 'pilot_res_video_au',
            priority: 'required',
            usage_note: 'Usar solo la progresión lateral baja en parejas.',
          },
        ],
      },
    },
    {
      id: 'pilot_03_adultos_fiu_continuidad',
      title: 'Piloto 3: Adultos con currículo FIU y continuidad',
      request: {
        contract_version: '2.1.0',
        request_id: 'pilot_03_adultos_fiu_continuidad',
        creation_mode: 'avanzada',
        group_context: {
          source: 'real_class',
          group_label: 'Adultos M/J 19:00',
          audience_type: 'adultos',
          age_min: 16,
          age_max: 40,
          estimated_participants: 12,
          experience_distribution: {
            principiantes: 5,
            intermedios: 5,
            avanzados: 2,
            manually_confirmed: true,
          },
        },
        curriculum_context: { scope: 'adulto_fiu', target_corda_index: 2 },
        space_context: {
          space_size: 'mediano',
          floor_type: 'tatami',
          available_mats: true,
          instructors_available: 1,
        },
        session_config: {
          duration_min: 60,
          focuses: ['Técnica', 'Secuencias', 'Roda'],
          objectives: ['Integrar Queixada y Esquiva lateral en secuencia fluida con entrada a la roda'],
          materials: ['Berimbau', 'Pandeiro'],
          include_musicality_roda: true,
          allow_ai_complementary_proposals: true,
          free_instructions: 'Progresión progresiva por niveles antes de secuencia en parejas.',
        },
        selected_movements: [
          { movement_id: 'queixada', priority: 'required' },
          { movement_id: 'esquiva_lateral', priority: 'required' },
          { movement_id: 'role', priority: 'optional' },
        ],
        selected_resources: [
          {
            resource_id: 'pilot_res_adulto_drill',
            priority: 'required',
            usage_note: 'Usarlo como puente previo a la secuencia en parejas.',
          },
        ],
        continuity_context: {
          group_label: 'Adultos M/J 19:00',
          exercises_done: ['Ginga con Cocorinha', 'Armada en desplazamiento'],
          exercises_skipped: ['Sequência armada-queixada continua'],
          movements_practiced: ['Cocorinha', 'Armada', 'Rolê'],
          difficulties: ['Mantener base estable al salir de la esquiva hacia rolê'],
          teacher_observations: ['Buena energía grupal; falta consolidar mirada constante en defensa'],
          content_to_reinforce: ['Salida limpia desde Esquiva lateral hacia Rolê antes de contraataque'],
          next_class_proposal: 'Retomar Esquiva lateral -> Rolê con entrada progresiva a Queixada',
        },
      },
    },
    {
      id: 'pilot_04_adultos_enfoque_especializado',
      title: 'Piloto 4: Adultos con enfoque especializado (Musicalidad y Roda)',
      request: {
        contract_version: '2.1.0',
        request_id: 'pilot_04_adultos_enfoque_especializado',
        creation_mode: 'avanzada',
        group_context: {
          source: 'real_class',
          group_label: 'Adultos Especializado · Musicalidad y Roda',
          audience_type: 'adultos',
          age_min: 18,
          age_max: 45,
          estimated_participants: 14,
          experience_distribution: {
            principiantes: 4,
            intermedios: 6,
            avanzados: 4,
            manually_confirmed: true,
          },
        },
        curriculum_context: { scope: 'none_manual' },
        space_context: {
          space_size: 'amplio',
          floor_type: 'madera',
          available_mats: false,
          instructors_available: 1,
        },
        session_config: {
          duration_min: 75,
          focuses: ['Musicalidad', 'Roda'],
          objectives: ['Sincronizar toque de Angola/São Bento Pequeno con canto corrido y diálogo en roda'],
          materials: ['Berimbau', 'Pandeiro', 'Atabaque', 'Agogô'],
          include_musicality_roda: true,
          allow_ai_complementary_proposals: true,
          free_instructions:
            'Sesión especializada de música, canto coral y roda dialogada sin acrobacias aéreas sobre piso de madera.',
        },
        selected_movements: [],
        selected_resources: [],
      },
    },
  ];
}

function buildPilotResourceRepository() {
  const map = new Map(PILOT_PREVIEW_RESOURCES.map((r) => [r.resource_id, r]));
  return {
    async getResourcesByIds(ids) {
      const out = new Map();
      for (const id of ids) {
        if (map.has(id)) out.set(id, map.get(id));
      }
      return out;
    },
  };
}

function buildScenarioEvaluationReport(scenario, response) {
  const structural = response.validation_report.structural;
  const heuristic = response.validation_report.pedagogical_heuristic;
  const hasExternalVideoInput = (scenario.request.selected_resources || []).some((sel) => {
    const res = PILOT_PREVIEW_RESOURCES.find((r) => r.resource_id === sel.resource_id);
    return Boolean(res && res.url);
  });
  const planJsonText = JSON.stringify(response.plan);

  return {
    scenario_id: scenario.id,
    title: scenario.title,
    provider: response.generation_meta.provider,
    model: response.generation_meta.model,
    is_simulated: response.generation_meta.is_simulated,
    simulator_evidence_valid_for_real_llm: false,
    structural_checks: {
      structural_passed: structural.passed,
      exact_duration_passed: response.plan.duracion_total === scenario.request.session_config.duration_min,
      errors: structural.errors,
      warnings: structural.warnings,
      origin_breakdown: structural.origin_breakdown,
      no_false_curriculum_attribution_passed:
        scenario.request.group_context.audience_type !== 'infantil' ||
        structural.origin_breakdown.official_fiu_curriculum === 0,
      uninspected_video_honesty_required: hasExternalVideoInput,
      uninspected_video_honesty_note_present:
        !hasExternalVideoInput || /no inspecciona|notas escritas/i.test(planJsonText),
    },
    pedagogical_heuristic_offline_only: heuristic,
    human_evaluation: {
      status: 'pending',
      reviewer: null,
      notes: '',
      dimensions: PILOT_EVALUATION_DIMENSIONS.map((d) => ({
        id: d.id,
        label: d.label,
        kind: d.kind,
        score_1_to_5: null,
        comments: '',
      })),
    },
    usage: response.cost_telemetry,
    plan: response.plan,
  };
}

async function runDryRunPilotCheck() {
  const catalog = loadVerifiedCatalog();
  const serverConfig = getServerConfig();
  const budgetGuard = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 });
  const resourceRepository = buildPilotResourceRepository();
  const actor = { actorId: 'pilot_dry_run_actor', actorMode: 'local_dev_simulated_unauthenticated' };
  const scenarios = buildPilotScenarios();

  const summary = [];
  let totalWorstCaseUsd = 0;
  let totalExpectedUsd = 0;

  for (const s of scenarios) {
    const context = await buildValidatedContext({
      request: s.request,
      actor,
      catalog,
      resourceRepository,
    });
    const promptBundle = buildPlannerPrompts(context);
    const maxOutputTokens = resolveMaxOutputTokens(context.durationMin, serverConfig);
    const worstCaseUsd = budgetGuard.estimateWorstCaseGenerationUsd({
      model: serverConfig.primaryModel,
      estimatedInputTokens: promptBundle.estimatedInputTokens,
      maxOutputTokens,
      maxRepairAttempts: serverConfig.budget.maxRepairAttempts,
    });
    const expectedSinglePassUsd = estimateCostUsd(
      serverConfig.primaryModel,
      promptBundle.estimatedInputTokens,
      2600
    );
    totalWorstCaseUsd = Number((totalWorstCaseUsd + worstCaseUsd).toFixed(6));
    totalExpectedUsd = Number((totalExpectedUsd + expectedSinglePassUsd).toFixed(6));

    summary.push({
      scenario_id: s.id,
      duration_min: context.durationMin,
      estimated_input_tokens: promptBundle.estimatedInputTokens,
      max_output_tokens: maxOutputTokens,
      expected_single_pass_usd: expectedSinglePassUsd,
      worst_case_with_1_repair_usd: worstCaseUsd,
    });
  }

  return {
    mode: 'dry_run_zero_paid_calls',
    credentials_present: hasServerOpenAiCredentials(),
    real_provider_default_enabled: serverConfig.realProviderEnabled,
    primary_model: serverConfig.primaryModel,
    fallback_model: serverConfig.fallbackModel,
    max_budget_usd: budgetGuard.maxBudgetUsd,
    max_generations: budgetGuard.maxGenerations,
    max_repair_attempts_per_generation: serverConfig.budget.maxRepairAttempts,
    max_total_llm_calls: budgetGuard.maxGenerations * (1 + serverConfig.budget.maxRepairAttempts),
    expected_4_scenarios_single_pass_usd: totalExpectedUsd,
    worst_case_4_scenarios_with_all_repairs_usd: totalWorstCaseUsd,
    scenarios: summary,
  };
}

async function runAuthorizedPaidPilot({ outDir = path.join(__dirname, '..', 'scratch') } = {}) {
  if (process.env.PLANNER_V2_ALLOW_PAID_PILOT !== 'YES') {
    throw new Error(
      'Bloqueo de seguridad: para ejecutar llamadas pagadas del piloto debes definir PLANNER_V2_ALLOW_PAID_PILOT=YES además de --authorize-paid-pilot.'
    );
  }
  if (!hasServerOpenAiCredentials()) {
    throw new Error(
      'Faltan credenciales OpenAI en servidor (PLANNER_V2_OPENAI_API_KEY o OPENAI_API_KEY).'
    );
  }

  const catalog = loadVerifiedCatalog();
  const baseConfig = getServerConfig();
  const probe = await listAccessibleOpenAiModels({ apiKey: resolveServerOpenAiApiKey() });
  const activePrimaryModel =
    probe.checked && probe.accessibleCandidates.length > 0
      ? probe.recommendedPrimary
      : baseConfig.primaryModel;
  const activeFallbackModel =
    probe.checked && probe.accessibleCandidates.length > 1 ? probe.recommendedFallback : baseConfig.fallbackModel;

  const quotaStore = new InMemoryAtomicQuotaStore();
  const budgetGuard = new AtomicPilotBudgetGuard({ maxBudgetUsd: 0.10, maxGenerations: 4 });
  const resourceRepository = buildPilotResourceRepository();
  const scenarios = buildPilotScenarios();

  const results = [];
  for (const s of scenarios) {
    const response = await generateClassPlanV2({
      request: s.request,
      authContext: {},
      deps: {
        catalog,
        quotaStore,
        budgetGuard,
        resourceRepository,
      },
      serverOverrides: {
        providerMode: 'openai',
        realProviderEnabled: true,
        allowLocalDevSimulatedBypass: true,
        primaryModel: activePrimaryModel,
        fallbackModel: activeFallbackModel,
      },
    });
    results.push(buildScenarioEvaluationReport(s, response));
  }

  const report = {
    generated_at: new Date().toISOString(),
    provider: 'openai',
    model: results[0]?.model || activePrimaryModel,
    accessible_candidate_models: probe.accessibleCandidates,
    pilot_budget: budgetGuard.getSnapshot(),
    structural_passed_count: results.filter((r) => r.structural_checks.structural_passed).length,
    human_evaluation_pending_count: results.length,
    results,
  };

  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const jsonPath = path.join(outDir, 'pilot_ped04c2d_report.json');
  fs.writeFileSync(jsonPath, JSON.stringify(report, null, 2));

  const mdLines = [
    '# Reporte del Piloto Real GINGA Planner V2 (`PED-04C2-D`)',
    '',
    `- Fecha: ${report.generated_at}`,
    `- Modelo: \`${report.model}\``,
    `- Gasto real acumulado: USD ${report.pilot_budget.spent_usd} / USD ${report.pilot_budget.max_budget_usd}`,
    `- Generaciones completadas: ${report.pilot_budget.completed_generations} / ${report.pilot_budget.max_generations}`,
    `- Llamadas LLM totales (incl. reparaciones): ${report.pilot_budget.total_llm_calls}`,
    `- Validación estructural determinista: ${report.structural_passed_count}/${results.length} PASS`,
    `- Evaluación pedagógica humana: **PENDIENTE DE REVISIÓN POR EL PROPIETARIO**`,
    '',
    ...results.map(
      (r) =>
        `## ${r.title}\n- Título generado: ${r.plan.titulo}\n- Duración: ${r.plan.duracion_total} min\n- Estructural: ${r.structural_checks.structural_passed ? 'PASS' : 'FAIL'}\n- Heurístico automático (no humano): ${r.pedagogical_heuristic_offline_only.score_total}/100\n- Costo estimado: USD ${r.usage.estimated_cost_usd} (${r.usage.input_tokens} in / ${r.usage.output_tokens} out)\n`
    ),
  ];
  const mdPath = path.join(outDir, 'pilot_ped04c2d_review.md');
  fs.writeFileSync(mdPath, mdLines.join('\n'));

  return { report, jsonPath, mdPath };
}

async function main() {
  const args = process.argv.slice(2);
  const authorizePaid = args.includes('--authorize-paid-pilot');
  if (!authorizePaid) {
    const dry = await runDryRunPilotCheck();
    console.log(JSON.stringify(dry, null, 2));
    return;
  }
  const { report, jsonPath, mdPath } = await runAuthorizedPaidPilot();
  console.log(
    `PILOT COMPLETE: ${report.structural_passed_count}/4 structural PASS, spent=USD ${report.pilot_budget.spent_usd}, json=${jsonPath}, md=${mdPath}`
  );
}

if (require.main === module) {
  main().catch((err) => {
    console.error('PILOT ERROR:', err.message);
    process.exitCode = 1;
  });
}

module.exports = {
  PILOT_EVALUATION_DIMENSIONS,
  PILOT_PREVIEW_RESOURCES,
  buildPilotScenarios,
  buildPilotResourceRepository,
  buildScenarioEvaluationReport,
  runDryRunPilotCheck,
  runAuthorizedPaidPilot,
};

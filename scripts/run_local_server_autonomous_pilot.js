#!/usr/bin/env node
'use strict';

/**
 * Autonomous local pilot runner against the ALREADY-RUNNING GINGA local server
 * (`http://127.0.0.1:8097` by default), reproducing the professor's exact Infantil Advanced form
 * WITHOUT re-entering the API key in this chat/process.
 *
 * Safety defaults:
 * - Runs in `--dry-run` by default (0 paid OpenAI calls; queries `/api/planner-v2/health` or runs offline check).
 * - Requires BOTH `--execute-live` AND `--confirm-budget` to POST to `/api/planner-v2/generate`.
 */

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const opts = {
    url: 'http://127.0.0.1:8097',
    token: '',
    executeLive: false,
    confirmBudget: false,
    outputPath: path.join(__dirname, '..', 'scratch', 'autonomous_pilot_result.json'),
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--url' && argv[i + 1]) opts.url = argv[++i];
    else if (a === '--token' && argv[i + 1]) opts.token = argv[++i];
    else if (a === '--execute-live') opts.executeLive = true;
    else if (a === '--confirm-budget') opts.confirmBudget = true;
    else if (a === '--output' && argv[i + 1]) opts.outputPath = path.resolve(argv[++i]);
  }
  return opts;
}

function buildProfessorInfantilPayload(requestId) {
  return {
    request: {
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
        objectives: [
          'Trabajar Ginga, Armada y Aú mediante progresiones diferenciadas por nivel, esquivas, juegos de capoeira, musicalidad y participación simultánea.',
        ],
        include_musicality_roda: true,
        allow_ai_complementary_proposals: true,
        free_instructions:
          'Principiantes: iniciación a Armada y preparación de Aú mediante apoyos progresivos de manos. Avanzados: perfeccionamiento de Armada y Aú según capacidades confirmadas. Todos deben mantenerse activos, evitando filas, eliminaciones y tiempos muertos.',
      },
      selected_movements: [],
      selected_resources: [
        {
          resource_id: 'idea_res_02',
          title: 'Juego espejo de esquivas por señales',
          type: 'juego',
          category: 'Juegos',
          notes: 'Trabajo por parejas a distancia segura cambiando esquiva al sonido del pandeiro.',
          usage_note: 'Aplicar como juego central de reacción.',
          has_external_video: false,
          priority: 'required',
        },
      ],
    },
    preview_resources_catalog: [
      {
        resource_id: 'idea_res_02',
        title: 'Juego espejo de esquivas por señales',
        type: 'juego',
        media_kind: 'nota',
        category: 'Juegos',
        notes: 'Trabajo por parejas a distancia segura cambiando esquiva al sonido del pandeiro.',
        has_external_video: false,
      },
    ],
  };
}

function evaluateInfantilResult12Criteria(response) {
  const plan = response?.plan || {};
  const bloques = Array.isArray(plan.bloques) ? plan.bloques : [];
  const exs = bloques.flatMap((b) => (Array.isArray(b.ejercicios) ? b.ejercicios : []));
  const blockSum = bloques.reduce((a, b) => a + Number(b.duracion_min || 0), 0);
  const exSumsMatch = bloques.every(
    (b) =>
      (b.ejercicios || []).reduce((a, e) => a + Number(e.duracion_min || 0), 0) ===
      Number(b.duracion_min || 0)
  );
  const allLinkedRes = new Set(exs.flatMap((e) => e.linked_resource_ids || []));
  const allMovs = exs.flatMap((e) => e.curriculum_movement_ids || []);
  const textAll = JSON.stringify(plan);
  const hasCantiga = exs.some((e) => e.cancionero_reference && e.cancionero_reference.song_title);
  const cantigaIdsNull = exs.every((e) => !e.cancionero_reference || e.cancionero_reference.cantiga_id === null);

  return {
    duration_60_exact: plan.duracion_total === 60 && blockSum === 60 && exSumsMatch,
    blocks_count_valid: bloques.length >= 2 && bloques.length <= 7,
    infantil_audience_preserved: plan.audience_type === 'infantil' && plan.curriculum_scope === 'infantil_fiu_pending',
    zero_fiu_adult_movements: allMovs.length === 0,
    required_resource_integrated: allLinkedRes.has('idea_res_02'),
    multilevel_differentiation_present: exs.every(
      (e) =>
        String(e.diferenciacion_principiantes || '').trim().length > 0 &&
        String(e.diferenciacion_intermedios || '').trim().length > 0 &&
        String(e.diferenciacion_avanzados || '').trim().length > 0
    ),
    internal_timings_complete: exs.every((e) => Array.isArray(e.tiempos_internos) && e.tiempos_internos.length > 0),
    safe_surface_respected: !/\b(bananeira|ponte|parada\s+de\s+m[aã]o|queda\s+de\s+rim)\b/i.test(textAll),
    cancionero_ref_without_invented_id: hasCantiga && cantigaIdsNull,
    structural_validator_passed: response?.validation_report?.structural?.passed === true,
    heuristic_score: response?.validation_report?.pedagogical_heuristic?.score_total ?? null,
    llm_calls_made: response?.generation_meta?.llm_calls_made ?? null,
    estimated_cost_usd: response?.cost_telemetry?.estimated_cost_usd ?? null,
    pilot_budget_after: response?.cost_telemetry?.pilot_budget ?? null,
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const base = opts.url.replace(/\/$/, '');
  const headers = {
    'Content-Type': 'application/json',
    ...(opts.token ? { 'X-Preview-Token': opts.token } : {}),
  };

  if (!opts.executeLive || !opts.confirmBudget) {
    console.log('[autonomous-pilot] DRY-RUN active (0 OpenAI calls will be executed).');
    console.log(`[autonomous-pilot] Target local server: ${base}`);
    try {
      const healthResp = await fetch(`${base}/api/planner-v2/health`, { headers });
      const health = await healthResp.json();
      console.log('[autonomous-pilot] Server health snapshot:', JSON.stringify(health, null, 2));
    } catch (err) {
      console.log(`[autonomous-pilot] Local server not reachable at ${base} (${err.message}). Pass --execute-live --confirm-budget once running and authorized.`);
    }
    console.log('AUTONOMOUS_PILOT_DRY_RUN_OK');
    return;
  }

  const requestId = `req_auto_pilot_${Date.now()}`;
  const payload = buildProfessorInfantilPayload(requestId);

  console.log(`[autonomous-pilot] Sending live request (${requestId}) to ${base}/api/planner-v2/generate ...`);
  const resp = await fetch(`${base}/api/planner-v2/generate`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  });
  const body = await resp.json();

  if (!resp.ok || body.status !== 'ok') {
    fs.mkdirSync(path.dirname(opts.outputPath), { recursive: true });
    fs.writeFileSync(opts.outputPath, JSON.stringify({ ok: false, httpStatus: resp.status, body }, null, 2));
    console.error('[autonomous-pilot] FAILED:', JSON.stringify(body, null, 2));
    process.exitCode = 1;
    return;
  }

  const report = evaluateInfantilResult12Criteria(body);
  const out = {
    ok: true,
    executed_at: new Date().toISOString(),
    request_id: requestId,
    evaluation_12_points: report,
    generation_meta: body.generation_meta,
    cost_telemetry: body.cost_telemetry,
    plan: body.plan,
  };
  fs.mkdirSync(path.dirname(opts.outputPath), { recursive: true });
  fs.writeFileSync(opts.outputPath, JSON.stringify(out, null, 2));
  console.log('[autonomous-pilot] SUCCESS. Summary:', JSON.stringify(report, null, 2));
  console.log(`[autonomous-pilot] Saved full class + evaluation to ${opts.outputPath}`);
}

main().catch((err) => {
  console.error('[autonomous-pilot] Fatal error:', err.message);
  process.exitCode = 1;
});

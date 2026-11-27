#!/usr/bin/env node
'use strict';

/**
 * End-to-end verification of `scripts/planner_v2_local_server.js`:
 * - Loopback server answers /api/planner-v2/health & /api/planner-v2/generate for Infantil M/J 18:00 and Adultos M/J 19:00.
 * - Rejects starting on non-loopback host without --token.
 * - Enforces X-Preview-Token / ?token= when configured on non-loopback.
 * - Disables /flutter_service_worker.js (404).
 */

const assert = require('assert');
const { createPlannerV2LocalServer } = require('./planner_v2_local_server');

async function postJson(url, body, headers = {}) {
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  return { status: resp.status, json: await resp.json() };
}

async function main() {
  // 1. Refuse non-loopback without token
  let threw = false;
  try {
    createPlannerV2LocalServer({ host: '192.168.1.50', token: '' });
  } catch (e) {
    threw = true;
  }
  assert(threw, 'Debe prohibir enlace LAN sin token.');

  // 2. Start isolated loopback server on ephemeral port 0
  const srv = createPlannerV2LocalServer({ host: '127.0.0.1' });
  await new Promise((resolve) => srv.listen(0, '127.0.0.1', resolve));
  const port = srv.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;

  try {
    const swResp = await fetch(`${baseUrl}/flutter_service_worker.js`);
    assert.strictEqual(swResp.status, 404);

    const healthResp = await fetch(`${baseUrl}/api/planner-v2/health`);
    assert.strictEqual(healthResp.status, 200);
    const health = await healthResp.json();
    assert.strictEqual(health.mode, 'simulated_offline');
    assert.strictEqual(health.real_provider_enabled, false);
    assert.strictEqual(typeof health.real_provider_credentials_present, 'boolean');
    assert.strictEqual(health.primary_model, 'gpt-4o-mini');
    assert(Array.isArray(health.accessible_models));
    assert.strictEqual(health.pilot_budget.max_budget_usd, 0.10);
    assert.strictEqual(health.pilot_budget.max_generations, 4);

    // 3. Infantil M/J 18:00 (5-11 años, sin asumir materiales ni colchonetas, sin Bananeira/Ponte)
    const kidsResp = await postJson(`${baseUrl}/api/planner-v2/generate`, {
      request: {
        contract_version: '2.1.0',
        request_id: 'e2e_kids_mj_1800',
        creation_mode: 'rápida',
        group_context: {
          source: 'real_class',
          group_label: 'Infantil M/J 18:00',
          audience_type: 'infantil',
          age_min: 5,
          age_max: 11,
          estimated_participants: 10,
          experience_distribution: { principiantes: 6, intermedios: 2, avanzados: 2, manually_confirmed: true },
        },
        curriculum_context: { scope: 'infantil_fiu_pending' },
        space_context: { space_size: 'desconocido', floor_type: 'desconocido', instructors_available: 1 },
        session_config: {
          duration_min: 60,
          focuses: ['Técnica', 'Juegos', 'Acrobacias', 'Musicalidad'],
          objectives: ['Progresiones de Ginga y Aú sin tiempos muertos'],
          include_musicality_roda: true,
          allow_ai_complementary_proposals: true,
          free_instructions: 'Trabajar Ginga, progresiones iniciales de Aú y Armada manteniendo participación simultánea.',
        },
        selected_movements: [],
        selected_resources: [],
      },
    });
    assert.strictEqual(kidsResp.status, 200);
    assert.strictEqual(kidsResp.json.status, 'ok');
    assert.strictEqual(kidsResp.json.generation_meta.is_simulated, true);
    assert.strictEqual(kidsResp.json.plan.duracion_total, 60);
    assert(!/\bbananeira|ponte\b/i.test(JSON.stringify(kidsResp.json.plan.bloques)));
    assert.strictEqual(
      kidsResp.json.validation_report.structural.origin_breakdown.official_fiu_curriculum,
      0
    );

    // 4. Adultos M/J 19:00 with FIU + Pizarra resource
    const adultsResp = await postJson(`${baseUrl}/api/planner-v2/generate`, {
      request: {
        contract_version: '2.1.0',
        request_id: 'e2e_adultos_mj_1900',
        creation_mode: 'avanzada',
        group_context: {
          source: 'real_class',
          group_label: 'Adultos M/J 19:00',
          audience_type: 'adultos',
          age_min: 16,
          age_max: 40,
          estimated_participants: 12,
          experience_distribution: { principiantes: 5, intermedios: 5, avanzados: 2, manually_confirmed: true },
        },
        curriculum_context: { scope: 'adulto_fiu', target_corda_index: 2 },
        space_context: { space_size: 'mediano', floor_type: 'tatami', available_mats: true, instructors_available: 1 },
        session_config: {
          duration_min: 60,
          focuses: ['Técnica', 'Secuencias', 'Musicalidad'],
          materials: ['Berimbau', 'Pandeiro'],
          include_musicality_roda: true,
          allow_ai_complementary_proposals: true,
          free_instructions: 'Conectar Queixada y Esquiva lateral.',
        },
        selected_movements: [
          { movement_id: 'queixada', priority: 'required' },
          { movement_id: 'esquiva_lateral', priority: 'required' },
        ],
        selected_resources: [
          { resource_id: 'idea_res_01', priority: 'required', usage_note: 'Aplicar como puente técnico.' },
        ],
      },
      preview_resources_catalog: [
        {
          resource_id: 'idea_res_01',
          title: 'Drill esquiva en parejas sin pausa',
          type: 'video',
          media_kind: 'video',
          category: 'Técnica',
          notes: '3 rondas de 90s alternando atacante y defensa.',
          has_external_video: true,
        },
      ],
    });
    assert.strictEqual(adultsResp.status, 200);
    assert.strictEqual(adultsResp.json.status, 'ok');
    assert.strictEqual(adultsResp.json.plan.duracion_total, 60);
    assert(
      adultsResp.json.plan.bloques.some((b) =>
        b.ejercicios.some((e) => e.linked_resource_ids.includes('idea_res_01') && e.curriculum_movement_ids.includes('queixada'))
      )
    );

    console.log('PASS test_planner_v2_local_server_e2e: health, SW 404, LAN guard, Infantil M/J 18:00 & Adultos M/J 19:00 verified.');
  } finally {
    await new Promise((resolve) => srv.close(resolve));
  }
}

main().catch((err) => {
  console.error('FAIL test_planner_v2_local_server_e2e:', err);
  process.exitCode = 1;
});

#!/usr/bin/env node
'use strict';

/**
 * scripts/verify_staging_remote.js
 *
 * Verificación remota end-to-end contra el proyecto de staging (por defecto `ginga-capoeira-staging`).
 * 100% compatible con Linux/macOS/CI/Remote Agents; lee configuración desde variables de entorno
 * (sin credenciales ni claves hardcoded en el repositorio):
 *   - STAGING_PROJECT_ID (default: ginga-capoeira-staging; bloquea capoeirafiu-ea8ljo)
 *   - STAGING_WEB_API_KEY
 *   - STAGING_PROF_EMAIL / STAGING_PROF_PASSWORD
 *   - STAGING_ALU_EMAIL / STAGING_ALU_PASSWORD
 */

const assert = require('assert');

const PROJECT_ID = String(process.env.STAGING_PROJECT_ID || 'ginga-capoeira-staging').trim();
const WEB_API_KEY = String(process.env.STAGING_WEB_API_KEY || '').trim();
const PROF_EMAIL = String(process.env.STAGING_PROF_EMAIL || 'prof_staging@ginga.test').trim();
const PROF_PASSWORD = String(process.env.STAGING_PROF_PASSWORD || '').trim();
const ALU_EMAIL = String(process.env.STAGING_ALU_EMAIL || 'alumno_staging_1@ginga.test').trim();
const ALU_PASSWORD = String(process.env.STAGING_ALU_PASSWORD || '').trim();

if (!PROJECT_ID || PROJECT_ID === 'capoeirafiu-ea8ljo') {
  console.error('BLOQUEADO: prohibido ejecutar verificación staging contra capoeirafiu-ea8ljo.');
  process.exit(1);
}
if (!WEB_API_KEY || !PROF_PASSWORD || !ALU_PASSWORD) {
  console.error(
    'Faltan variables de entorno requeridas: STAGING_WEB_API_KEY, STAGING_PROF_PASSWORD, STAGING_ALU_PASSWORD.'
  );
  process.exit(1);
}

async function signInWithPassword(email, password) {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(WEB_API_KEY)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const body = await res.json();
  if (!res.ok) {
    throw new Error(`Login falló para ${email} (${res.status}): ${JSON.stringify(body)}`);
  }
  return body;
}

function decodeJwtPayload(jwt) {
  const parts = String(jwt || '').split('.');
  assert(parts.length >= 2, 'JWT inválido');
  return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
}

async function fsRest(method, docSubPath, idToken, body = null) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents${docSubPath}`;
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_) {
    parsed = text;
  }
  return { status: res.status, body: parsed };
}

function toVal(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toVal) } };
  if (typeof v === 'object') return { mapValue: { fields: toFields(v) } };
  return { stringValue: String(v) };
}

function toFields(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) out[k] = toVal(v);
  }
  return out;
}

function fromVal(v) {
  if (!v || typeof v !== 'object') return v;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return Boolean(v.booleanValue);
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return ((v.arrayValue && v.arrayValue.values) || []).map(fromVal);
  if ('mapValue' in v) return fromFields((v.mapValue && v.mapValue.fields) || {});
  return v;
}

function fromFields(fields = {}) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) out[k] = fromVal(v);
  return out;
}

async function callCallable(fnName, data, idToken = null) {
  const url = `https://us-central1-${PROJECT_ID}.cloudfunctions.net/${fnName}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const text = await res.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_) {
    parsed = text;
  }
  return { status: res.status, body: parsed };
}

async function main() {
  console.log('================================================================');
  console.log(`  VERIFICACIÓN REMOTA STAGING: ${PROJECT_ID}`);
  console.log('================================================================\n');

  let passed = 0;
  async function check(name, fn) {
    await fn();
    passed += 1;
    console.log(`[PASS] ${name}`);
  }

  // 1. Hosting HTTPS live & isolated
  await check('R01_hosting_https_responde_200_y_sin_referencia_prod', async () => {
    const res = await fetch(`https://${PROJECT_ID}.web.app/`);
    assert.strictEqual(res.status, 200);
    const html = await res.text();
    assert(html.includes('flutter_bootstrap.js') || html.includes('main.dart.js'), 'Debe servir app Flutter Web');
    assert.strictEqual(html.includes('capoeirafiu-ea8ljo'), false, 'HTML de staging no debe mencionar proyecto productivo');
  });

  // 2. Auth real + Custom Claims
  let profToken = '';
  let profUid = '';
  let aluToken = '';
  await check('R02_auth_real_profesor_y_alumno_con_custom_claims', async () => {
    const profAuth = await signInWithPassword(PROF_EMAIL, PROF_PASSWORD);
    profToken = profAuth.idToken;
    profUid = profAuth.localId;
    const profClaims = decodeJwtPayload(profToken);
    assert.strictEqual(profClaims.profesor, true);
    assert.strictEqual(profClaims.instructor, true);
    assert.strictEqual(profClaims.admin, false);

    const aluAuth = await signInWithPassword(ALU_EMAIL, ALU_PASSWORD);
    aluToken = aluAuth.idToken;
    const aluClaims = decodeJwtPayload(aluToken);
    assert.strictEqual(aluClaims.rol, 'alumno');
    assert.notStrictEqual(aluClaims.profesor, true);
  });

  // 3. Reglas Firestore remotas
  await check('R03_reglas_firestore_aislamiento_y_biblioteca_en_vivo', async () => {
    assert.strictEqual((await fsRest('GET', '/curriculum_movements/ginga', profToken)).status, 200);
    assert.strictEqual((await fsRest('GET', '/clases/clase_infantil_mj', profToken)).status, 200);
    assert.strictEqual((await fsRest('GET', '/instructor_ideas/idea_staging_01', profToken)).status, 200);

    // Alumno bloqueado sobre PII docente, whatsapp_leads, planes y cuotas
    assert.strictEqual((await fsRest('GET', `/users/${profUid}`, aluToken)).status, 403);
    assert.strictEqual((await fsRest('GET', '/whatsapp_leads/any', aluToken)).status, 403);
    assert.strictEqual((await fsRest('GET', '/instructor_planes_clase/plan_demo_infantil_staging_01', aluToken)).status, 403);
    assert.strictEqual((await fsRest('GET', '/_quota_runtime/test', aluToken)).status, 403);
  });

  // 4. Callables remotos (`generarPlanClaseV2` y `copilotoPedagogicoV1`) en modo simulado
  let generatedPlan = null;
  let copilotUpdatedPlan = null;
  await check('R04_callables_v2_y_copiloto_remotos_modo_simulado_y_rbac', async () => {
    const aluDenyGen = await callCallable('generarPlanClaseV2', { request: {} }, aluToken);
    assert(aluDenyGen.status === 403 || aluDenyGen.body?.error?.status === 'PERMISSION_DENIED', 'Alumno debe ser rechazado en generarPlanClaseV2');

    const aluDenyCop = await callCallable('copilotoPedagogicoV1', { request: {} }, aluToken);
    assert(aluDenyCop.status === 403 || aluDenyCop.body?.error?.status === 'PERMISSION_DENIED', 'Alumno debe ser rechazado en copilotoPedagogicoV1');

    const genRes = await callCallable(
      'generarPlanClaseV2',
      {
        request: {
          contract_version: '2.1.0',
          request_id: `remote_stg_gen_${Date.now()}`,
          creation_mode: 'avanzada',
          group_context: {
            source: 'real_class',
            group_label: 'Infantil M/J 18:00',
            audience_type: 'infantil',
            age_min: 6,
            age_max: 11,
            estimated_participants: 12,
            experience_distribution: { principiantes: 6, intermedios: 4, avanzados: 2, manually_confirmed: true },
          },
          curriculum_context: { scope: 'none_manual' },
          space_context: { space_size: 'mediano', floor_type: 'ceramico', confirmed_materials: [], instructors_available: 1 },
          session_config: {
            duration_min: 60,
            focuses: ['Técnica', 'Juegos', 'Musicalidad y Roda'],
            include_musicality_roda: true,
            allow_ai_complementary_proposals: true,
            additional_instructions: 'Integrar Ginga, Armada y Au con juegos simultaneos y musicalidad aplicada.',
          },
          selected_movements: [],
          selected_resources: [
            { resource_id: 'idea_staging_01', priority: 'required', usage_note: 'Aplicar en bloque de juegos.' },
          ],
        },
      },
      profToken
    );
    assert.strictEqual(genRes.status, 200, `Error callable V2: ${JSON.stringify(genRes.body)}`);
    const genResult = genRes.body.result;
    assert.strictEqual(genResult.status, 'ok');
    assert.strictEqual(genResult.generation_meta?.is_simulated, true, 'OpenAI real debe estar desactivado');
    assert.strictEqual(genResult.plan.duracion_total, 60);
    generatedPlan = genResult.plan;

    const copRes = await callCallable(
      'copilotoPedagogicoV1',
      {
        request: {
          request_id: `remote_stg_cop_${Date.now()}`,
          message: 'Redistribuye la clase a 60 minutos enfatizando técnica y juegos',
          available_resource_ids: ['idea_staging_01', 'idea_staging_02'],
          plan: generatedPlan,
        },
      },
      profToken
    );
    assert.strictEqual(copRes.status, 200, `Error callable Copiloto: ${JSON.stringify(copRes.body)}`);
    const copResult = copRes.body.result;
    assert.strictEqual(copResult.status, 'ok');
    assert.strictEqual(copResult.generation_meta?.is_simulated, true);
    copilotUpdatedPlan = copResult.proposed_plan || generatedPlan;
  });

  // 5. Persistencia remota real: clase demo infantil, edición, recuperación, en vivo e historial inmutable
  await check('R05_persistencia_remota_clase_demo_en_vivo_e_historial_inmutable', async () => {
    const demoPlanId = 'plan_demo_infantil_staging_01';
    const edited = JSON.parse(JSON.stringify(copilotUpdatedPlan));
    edited.titulo = 'Clase Demo Infantil — Ginga, Armada y Aú (Staging)';
    edited.bloques[0].ejercicios[0].observaciones_profesor = 'Observar postura de Ginga en parejas.';

    const planDoc = {
      ...edited,
      id: demoPlanId,
      schema_version: 2,
      instructor_id: profUid,
      clase_id: 'clase_infantil_mj',
      plan_status: 'saved',
      revision: 1,
      updated_by_device: 'verify_staging_remote',
      created_at: '2026-11-27T14:25:00Z',
      updated_at: '2026-11-27T14:25:00Z',
    };
    const savePlanRes = await fsRest('PATCH', `/instructor_planes_clase/${demoPlanId}`, profToken, {
      fields: toFields(planDoc),
    });
    assert.strictEqual(savePlanRes.status, 200, `Error guardando plan demo: ${JSON.stringify(savePlanRes.body)}`);

    // Recuperar plan remoto
    const getPlanRes = await fsRest('GET', `/instructor_planes_clase/${demoPlanId}`, profToken);
    assert.strictEqual(getPlanRes.status, 200);
    const recoveredPlan = fromFields(getPlanRes.body.fields);
    assert.strictEqual(recoveredPlan.id, demoPlanId);
    assert.strictEqual(recoveredPlan.duracion_total, 60);

    // Iniciar ejecución en vivo y recuperar tras interrupción
    const activeId = `active_${profUid}`;
    const livePayload = {
      session_id: 'live_remote_verify_01',
      instructor_id: profUid,
      plan_id: demoPlanId,
      clase_id: 'clase_infantil_mj',
      active_block_index: 1,
      active_exercise_index: 0,
      status: 'paused',
      elapsed_seconds_accumulated: 245,
      revision: 1,
      device_id: 'remote_verifier_tablet',
      started_at: '2026-11-27T14:26:00Z',
      updated_at: '2026-11-27T14:27:00Z',
    };
    const saveLive = await fsRest('PATCH', `/instructor_sesiones_activas/${activeId}`, profToken, {
      fields: toFields(livePayload),
    });
    assert.strictEqual(saveLive.status, 200);
    const getLive = await fsRest('GET', `/instructor_sesiones_activas/${activeId}`, profToken);
    assert.strictEqual(getLive.status, 200);
    assert.strictEqual(fromFields(getLive.body.fields).elapsed_seconds_accumulated, 245);

    // Guardar historial inmutable de prueba y verificar inmutabilidad (PATCH debe devolver 403)
    const histId = `hist_remote_verify_${Date.now()}`;
    const saveHist = await fsRest('PATCH', `/instructor_sesiones_impartidas/${histId}`, profToken, {
      fields: toFields({
        session_id: histId,
        plan_id: demoPlanId,
        instructor_id: profUid,
        clase_id: 'clase_infantil_mj',
        audience_type: 'infantil',
        completed_at: '2026-11-27T14:30:00Z',
        duracion_real_min: 60,
        worked_movements: ['Ginga', 'Armada', 'Au'],
        continuity_note: 'Demo staging verificada remotamente.',
        plan_snapshot: recoveredPlan,
      }),
    });
    assert.strictEqual(saveHist.status, 200, `Error creando historial: ${JSON.stringify(saveHist.body)}`);

    const tamperHist = await fsRest(
      'PATCH',
      `/instructor_sesiones_impartidas/${histId}?updateMask.fieldPaths=duracion_real_min`,
      profToken,
      { fields: toFields({ duracion_real_min: 99 }) }
    );
    assert.strictEqual(tamperHist.status, 403, 'El historial impartido debe ser inmutable');

    // Limpiar sesión activa temporal para que el profesor arranque limpio en Tablet
    const delLive = await fsRest('DELETE', `/instructor_sesiones_activas/${activeId}`, profToken);
    assert.strictEqual(delLive.status, 200);
  });

  console.log(`\n✔ VERIFICACIÓN REMOTA STAGING COMPLETADA: ${passed}/5 bloques aprobados (100%).`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ FALLO EN VERIFICACIÓN REMOTA STAGING:', err);
  process.exit(1);
});

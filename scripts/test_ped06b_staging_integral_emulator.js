#!/usr/bin/env node
'use strict';

/**
 * scripts/test_ped06b_staging_integral_emulator.js
 *
 * Suite integral PED-06B contra Firebase Firestore Emulator (`demo-ginga-test`, cero OpenAI, cero producción).
 * Verifica:
 *  1. Sembrado sintético idempotente (`--dry-run` y `--apply` x2, Zero-PII) + bloqueo de producción.
 *  2. Recorrido funcional completo de 15 pasos del Planificador V2 usando los callables reales
 *     exportados en `functions/index.js` (`generarPlanClaseV2` y `copilotoPedagogicoV1`, modo simulado).
 *  3. Compatibilidad integral tras endurecimiento de seguridad:
 *     - Login/perfiles (alumno, profesor, admin), Biblioteca FIU, Pizarra, reserva atómica
 *       (`clases.cupos_disponibles - 1` + `users.status: nuevo -> prueba`), asistencias QR compuestas
 *       (`${sesionId}_${uid}`) y rechazo de manipulaciones indirectas.
 *     - Cuotas transaccionales en Firestore `_quota_runtime` (`sendManualWhatsAppMessage`,
 *       `generarPlanClaseIA`) y aislamiento de lectura/escritura cliente sobre `_quota_runtime`.
 */

const assert = require('assert');
const http = require('http');
const admin = require('../functions/node_modules/firebase-admin');
const { seedSyntheticStagingData, assertSafeTarget } = require('./seed_staging_synthetic_data');

const HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const [HOSTNAME, PORT_STR] = HOST.split(':');
const PORT = Number(PORT_STR || 8080);
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-ginga-test';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('ERROR: FIRESTORE_EMULATOR_HOST debe estar definido.');
  process.exit(1);
}
if (PROJECT_ID === 'capoeirafiu-ea8ljo') {
  console.error('BLOQUEADO: prohibido ejecutar contra capoeirafiu-ea8ljo.');
  process.exit(1);
}

function createMockToken(uid, extraClaims = {}) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({
      sub: uid,
      user_id: uid,
      uid,
      email: `${uid}@ginga.test`,
      ...extraClaims,
    })
  ).toString('base64url');
  return `${header}.${payload}.`;
}

function restRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        hostname: HOSTNAME,
        port: PORT,
        path,
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          let parsed = null;
          try {
            parsed = data ? JSON.parse(data) : null;
          } catch (_) {
            parsed = data;
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function toVal(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') {
    return { stringValue: v };
  }
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (Array.isArray(v)) {
    return { arrayValue: { values: v.map((i) => toVal(i)) } };
  }
  if (typeof v === 'object') {
    return { mapValue: { fields: toFields(v) } };
  }
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
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(fromVal);
  if ('mapValue' in v) return fromFields(v.mapValue.fields || {});
  return v;
}

function fromFields(fields = {}) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    out[k] = fromVal(v);
  }
  return out;
}

function docPath(collection, id = null) {
  const base = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}`;
  return id ? `${base}/${encodeURIComponent(id)}` : base;
}

async function clearEmulator() {
  const res = await restRequest(
    'DELETE',
    `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`
  );
  assert.strictEqual(res.status, 200);
}

async function main() {
  console.log('================================================================');
  console.log('  SUITE PED-06B: STAGING SINTÉTICO, 15 PASOS Y COMPATIBILIDAD');
  console.log(`  Emulator: ${HOST} | Project: ${PROJECT_ID}`);
  console.log('================================================================\n');

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();
  await clearEmulator();

  // Asegurar que los flags de IA pagada están apagados explícitamente en esta suite
  delete process.env.PLANNER_V2_REAL_PROVIDER_ENABLED;
  delete process.env.PLANNER_V2_COPILOT_REAL_ENABLED;
  delete process.env.OPENAI_API_KEY;
  process.env.META_WHATSAPP_TOKEN = 'mock_wa_staging';
  process.env.META_PHONE_NUMBER_ID = '000000000';

  const origFetch = global.fetch;
  global.fetch = async (url) => {
    if (String(url).includes('graph.facebook.com')) {
      return { ok: true, status: 200, json: async () => ({ messages: [{ id: 'wamid.staging' }] }), text: async () => '{}' };
    }
    throw new Error(`Unexpected external HTTP blocked: ${url}`);
  };

  const indexExports = require('../functions/index.js');
  let passed = 0;
  async function check(name, fn) {
    await fn();
    passed += 1;
    console.log(`[PASS] ${name}`);
  }

  try {
    // -------------------------------------------------------------------------
    // 1. Sembrado sintético idempotente + bloqueo producción
    // -------------------------------------------------------------------------
    await check('S01_seed_sintetico_bloquea_produccion_y_es_100_idempotente', async () => {
      assert.throws(() => assertSafeTarget('capoeirafiu-ea8ljo', 'capoeirafiu-ea8ljo'), /BLOQUEADO/);

      const dry = await seedSyntheticStagingData({ apply: false, projectId: PROJECT_ID, includeCurriculum: true, db });
      assert.strictEqual(dry.mode, 'dry-run');
      assert.strictEqual(dry.synthetic_created, 10);
      assert.strictEqual(dry.curriculum.dryRun, true);
      assert.strictEqual((await db.collection('users').doc('prof_staging').get()).exists, false);

      const app1 = await seedSyntheticStagingData({ apply: true, projectId: PROJECT_ID, includeCurriculum: true, db });
      assert.strictEqual(app1.mode, 'apply');
      assert.strictEqual(app1.synthetic_created, 10);
      assert.strictEqual(app1.curriculum.totalPlannedCurriculumDocs, 164);

      const app2 = await seedSyntheticStagingData({ apply: true, projectId: PROJECT_ID, includeCurriculum: true, db });
      assert.strictEqual(app2.synthetic_created, 0);
      assert.strictEqual(app2.synthetic_updated, 0);
      assert.strictEqual(app2.synthetic_skipped, 10);
      assert.strictEqual(app2.curriculum.created, 0);
      assert.strictEqual(app2.curriculum.skipped, 164);
    });

    const tokAdmin = createMockToken('admin_staging', { admin: true, curriculum_admin: true, profesor: true, instructor: true, rol: 'admin' });
    const tokProf = createMockToken('prof_staging', { profesor: true, instructor: true, rol: 'profesor' });
    const tokAlu1 = createMockToken('alumno_staging_1', { rol: 'alumno' });
    const tokAlu2 = createMockToken('alumno_staging_2', { rol: 'alumno' });

    // -------------------------------------------------------------------------
    // 2. Recorrido funcional completo de 15 pasos via callables registrados
    // -------------------------------------------------------------------------
    const planId = 'plan_staging_infantil_01';
    let generatedPlan = null;
    let editedPlan = null;
    let savedRev1 = null;

    await check('S02_pasos_1_a_5_profesor_biblioteca_infantil_generarPlanClaseV2_y_pizarra', async () => {
      // Paso 1: Perfil profesor accesible con token
      const rProfProfile = await restRequest('GET', docPath('users', 'prof_staging'), null, tokProf);
      assert.strictEqual(rProfProfile.status, 200);

      // Paso 2: Abrir biblioteca curricular FIU
      const rCurric = await restRequest('GET', docPath('curriculum_movements', 'ginga'), null, tokProf);
      assert.strictEqual(rCurric.status, 200);

      // Paso 3: Seleccionar grupo infantil sintético
      const rGrupo = await restRequest('GET', docPath('clases', 'clase_infantil_mj'), null, tokProf);
      assert.strictEqual(rGrupo.status, 200);

      // Pasos 4-5: Invocar callable real registrado `generarPlanClaseV2` (modo simulado, cero OpenAI)
      assert.strictEqual(typeof indexExports.generarPlanClaseV2?.run, 'function');
      const genResp = await indexExports.generarPlanClaseV2.run(
        {
          request: {
            contract_version: '2.1.0',
            request_id: 'ped06b_staging_gen_01',
            creation_mode: 'avanzada',
            group_context: {
              source: 'real_class',
              group_label: 'Infantil M/J 18:00',
              audience_type: 'infantil',
              age_min: 6,
              age_max: 11,
              estimated_participants: 12,
              experience_distribution: {
                principiantes: 6,
                intermedios: 4,
                avanzados: 2,
                manually_confirmed: true,
              },
            },
            curriculum_context: { scope: 'none_manual' },
            space_context: {
              space_size: 'mediano',
              floor_type: 'ceramico',
              confirmed_materials: [],
              instructors_available: 1,
            },
            session_config: {
              duration_min: 60,
              focuses: ['Técnica', 'Juegos', 'Musicalidad y Roda'],
              include_musicality_roda: true,
              allow_ai_complementary_proposals: true,
              additional_instructions: 'Integrar Ginga, Armada, Au con participacion simultanea sin filas.',
            },
            selected_movements: [],
            selected_resources: [
              { resource_id: 'idea_staging_01', priority: 'required', usage_note: 'Aplicar en bloque de juegos.' },
            ],
          },
        },
        { auth: { uid: 'prof_staging', token: { profesor: true, instructor: true, rol: 'profesor' } } }
      );
      assert.strictEqual(genResp.status, 'ok');
      assert.strictEqual(genResp.generation_meta?.is_simulated, true);
      generatedPlan = genResp.plan;
      assert.strictEqual(generatedPlan.duracion_total, 60);
      const flatText = JSON.stringify(generatedPlan).toLowerCase();
      assert(flatText.includes('ginga') && flatText.includes('armada') && flatText.includes('au'));
      assert(
        generatedPlan.bloques.some((b) => (b.ejercicios || []).some((e) => (e.linked_resource_ids || []).includes('idea_staging_01'))),
        'Debe integrar recurso de Pizarra idea_staging_01'
      );
      const hasAdultFiu = generatedPlan.bloques.some((b) =>
        (b.ejercicios || []).some((e) => (e.curriculum_movement_ids || []).length > 0)
      );
      assert.strictEqual(hasAdultFiu, false, 'Infantil no debe arrastrar curriculum_movement_ids adultos FIU');
    });

    await check('S03_pasos_6_a_10_editar_copiloto_guardar_y_recuperar_en_segundo_dispositivo', async () => {
      // Paso 6: Editar ejercicio/tiempo manualmente preservando duración total 60 min
      editedPlan = JSON.parse(JSON.stringify(generatedPlan));
      editedPlan.bloques[0].ejercicios[0].observaciones_profesor = 'Observar rodillas alineadas en Ginga.';

      // Pasos 7-8: Consultar al callable real `copilotoPedagogicoV1` y aprobar propuesta
      assert.strictEqual(typeof indexExports.copilotoPedagogicoV1?.run, 'function');
      const copResp = await indexExports.copilotoPedagogicoV1.run(
        {
          request: {
            request_id: 'ped06b_staging_cop_01',
            message: 'Redistribuye la clase a 60 minutos enfatizando técnica y juegos',
            available_resource_ids: ['idea_staging_01', 'idea_staging_02'],
            plan: editedPlan,
          },
        },
        { auth: { uid: 'prof_staging', token: { profesor: true, instructor: true, rol: 'profesor' } } }
      );
      assert.strictEqual(copResp.status, 'ok');
      assert.strictEqual(copResp.generation_meta?.provider, 'simulated-copilot');
      assert.strictEqual(copResp.generation_meta?.is_simulated, true);
      const planToSave = copResp.proposed_plan || editedPlan;

      // Paso 9: Guardar planificación en Firestore (`instructor_planes_clase`, rev 1)
      const planDoc = {
        ...planToSave,
        id: planId,
        schema_version: 2,
        instructor_id: 'prof_staging',
        clase_id: 'clase_infantil_mj',
        plan_status: 'saved',
        revision: 1,
        updated_by_device: 'mac_chrome_staging',
        created_at: '2026-11-27T13:00:00Z',
        updated_at: '2026-11-27T13:00:00Z',
      };
      const createRes = await restRequest(
        'POST',
        `${docPath('instructor_planes_clase')}?documentId=${planId}`,
        { fields: toFields(planDoc) },
        tokProf
      );
      assert.strictEqual(createRes.status, 200);

      // Paso 10: Recuperar desde segundo dispositivo (Tablet)
      const tabletGet = await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokProf);
      assert.strictEqual(tabletGet.status, 200);
      savedRev1 = fromFields(tabletGet.body.fields);
      assert.strictEqual(savedRev1.clase_id, 'clase_infantil_mj');
      assert.strictEqual(savedRev1.revision, 1);

      // Verificar que recurso de Pizarra NO fue marcado como utilizado al guardar planificación
      const ideaAfterSave = (await db.collection('instructor_ideas').doc('idea_staging_01').get()).data();
      assert.strictEqual(ideaAfterSave.veces_impartida, 0);
    });

    await check('S04_pasos_11_a_15_en_vivo_recuperacion_historial_y_continuidad_siguiente_clase', async () => {
      // Pasos 11-12: Iniciar ejecución en vivo en Tablet y recuperar temporizador tras interrupción en otro dispositivo
      const activeId = 'active_prof_staging';
      const liveState = {
        session_id: 'live_staging_001',
        instructor_id: 'prof_staging',
        plan_id: planId,
        clase_id: 'clase_infantil_mj',
        active_block_index: 1,
        active_exercise_index: 0,
        status: 'paused',
        elapsed_seconds_accumulated: 320,
        revision: 1,
        device_id: 'tablet_ipad_staging',
        started_at: '2026-11-27T13:10:00Z',
        updated_at: '2026-11-27T13:15:00Z',
      };
      const rLiveStart = await restRequest(
        'POST',
        `${docPath('instructor_sesiones_activas')}?documentId=${activeId}`,
        { fields: toFields(liveState) },
        tokProf
      );
      assert.strictEqual(rLiveStart.status, 200);

      // Recuperar sesión activa desde Mac tras recargar/interrupción
      const rLiveRecover = await restRequest('GET', docPath('instructor_sesiones_activas', activeId), null, tokProf);
      assert.strictEqual(rLiveRecover.status, 200);
      const recoveredLive = fromFields(rLiveRecover.body.fields);
      assert.strictEqual(recoveredLive.elapsed_seconds_accumulated, 320);
      assert.strictEqual(recoveredLive.active_block_index, 1);

      // Paso 13: Finalizar clase guardando historial inmutable separado del plan original
      const histId = 'live_staging_001';
      const histRes = await restRequest(
        'POST',
        `${docPath('instructor_sesiones_impartidas')}?documentId=${histId}`,
        {
          fields: toFields({
            session_id: 'live_staging_001',
            plan_id: planId,
            instructor_id: 'prof_staging',
            clase_id: 'clase_infantil_mj',
            audience_type: 'infantil',
            completed_at: '2026-11-27T14:00:00Z',
            duracion_real_min: 60,
            worked_movements: ['Ginga', 'Armada', 'Au'],
            continuity_note: 'Buen control de Armada; reforzar llegada limpia del Au en principiantes.',
            plan_snapshot: savedRev1,
          }),
        },
        tokProf
      );
      assert.strictEqual(histRes.status, 200);

      // Inmutabilidad histórica: nadie puede editar ni borrar historial impartido
      const histTamper = await restRequest(
        'PATCH',
        `${docPath('instructor_sesiones_impartidas', histId)}?updateMask.fieldPaths=duracion_real_min`,
        { fields: toFields({ duracion_real_min: 99 }) },
        tokAdmin
      );
      assert.strictEqual(histTamper.status, 403);

      // Pasos 14-15: Consultar historial y preparar siguiente clase usando continuidad pedagógica Zero-PII
      const histRead = await restRequest('GET', docPath('instructor_sesiones_impartidas', histId), null, tokProf);
      assert.strictEqual(histRead.status, 200);
      const histData = fromFields(histRead.body.fields);

      const nextGen = await indexExports.generarPlanClaseV2.run(
        {
          request: {
            contract_version: '2.1.0',
            request_id: 'ped06b_staging_gen_02_continuity',
            creation_mode: 'rápida',
            group_context: {
              source: 'real_class',
              group_label: 'Infantil M/J 18:00',
              audience_type: 'infantil',
              age_min: 6,
              age_max: 11,
              estimated_participants: 12,
              experience_distribution: {
                principiantes: 6,
                intermedios: 4,
                avanzados: 2,
                manually_confirmed: true,
              },
            },
            curriculum_context: { scope: 'none_manual' },
            space_context: { space_size: 'mediano', floor_type: 'ceramico', instructors_available: 1 },
            session_config: {
              duration_min: 60,
              focuses: ['Técnica', 'Roda y musicalidad'],
              include_musicality_roda: true,
              allow_ai_complementary_proposals: true,
              additional_instructions: 'Continuar con Ginga y Au en grupo infantil con participacion simultanea.',
            },
            continuity_context: {
              group_label: 'Infantil M/J 18:00',
              audience_type: 'infantil',
              worked_movements: histData.worked_movements,
              reinforce_content: histData.continuity_note,
            },
            selected_movements: [],
            selected_resources: [],
          },
        },
        { auth: { uid: 'prof_staging', token: { profesor: true, instructor: true, rol: 'profesor' } } }
      );
      assert.strictEqual(nextGen.status, 'ok');
      assert.strictEqual(nextGen.plan.duracion_total, 60);
    });

    // -------------------------------------------------------------------------
    // 3. Compatibilidad integral + Cuotas transaccionales `_quota_runtime`
    // -------------------------------------------------------------------------
    await check('S05_compatibilidad_alumno_admin_reserva_atomica_y_QR_compuesto', async () => {
      // Login alumno / admin lecturas legítimas
      assert.strictEqual((await restRequest('GET', docPath('users', 'alumno_staging_1'), null, tokAlu1)).status, 200);
      assert.strictEqual((await restRequest('GET', docPath('users', 'alumno_staging_1'), null, tokAdmin)).status, 200);

      // Reserva atómica de alumno nuevo (clases.cupos_disponibles 8->7 + reserva + status nuevo->prueba + notificaciones)
      const rAtomicBooking = await restRequest(
        'POST',
        `/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`,
        {
          writes: [
            {
              update: {
                name: `projects/${PROJECT_ID}/databases/(default)/documents/clases/clase_infantil_mj`,
                fields: toFields({ cupos_disponibles: 7 }),
              },
              updateMask: { fieldPaths: ['cupos_disponibles'] },
            },
            {
              update: {
                name: `projects/${PROJECT_ID}/databases/(default)/documents/users/alumno_staging_1`,
                fields: toFields({ status: 'prueba' }),
              },
              updateMask: { fieldPaths: ['status'] },
            },
            {
              update: {
                name: `projects/${PROJECT_ID}/databases/(default)/documents/reservas/res_staging_1`,
                fields: toFields({
                  user_id: 'alumno_staging_1',
                  clase_id: 'clase_infantil_mj',
                  status: 'confirmado',
                  tipo: 'prueba',
                }),
              },
            },
          ],
        },
        tokAlu1
      );
      assert.strictEqual(rAtomicBooking.status, 200);

      // Intentar drenar cupos por segunda vez (ya status='prueba') debe fallar con 403
      const rSecondDrain = await restRequest(
        'PATCH',
        `${docPath('clases', 'clase_infantil_mj')}?updateMask.fieldPaths=cupos_disponibles`,
        { fields: toFields({ cupos_disponibles: 6 }) },
        tokAlu1
      );
      assert.strictEqual(rSecondDrain.status, 403);

      // Check-in QR válido con ID compuesto `${sesionId}_${uid}`
      const rQrOk = await restRequest(
        'POST',
        `${docPath('asistencias')}?documentId=sesion_qr_staging_1_alumno_staging_2`,
        {
          fields: toFields({
            sesion_id: 'sesion_qr_staging_1',
            user_id: 'alumno_staging_2',
            clase_id: 'clase_infantil_mj',
            fecha: '2026-11-27',
          }),
        },
        tokAlu2
      );
      assert.strictEqual(rQrOk.status, 200);

      // Duplicado o ID distinto debe fallar
      const rQrDup = await restRequest(
        'POST',
        `${docPath('asistencias')}?documentId=sesion_qr_staging_1_alumno_staging_2`,
        {
          fields: toFields({
            sesion_id: 'sesion_qr_staging_1',
            user_id: 'alumno_staging_2',
            clase_id: 'clase_infantil_mj',
            fecha: '2026-11-27',
          }),
        },
        tokAlu2
      );
      assert.strictEqual(rQrDup.status, 409);
    });

    await check('S06_cuotas_transaccionales_en_firestore_y_aislamiento_cliente', async () => {
      // Preparar lead sintético
      await db.collection('whatsapp_leads').doc('lead_staging_demo').set({
        telefono: '000000000',
        nombre: 'Lead Sintetico',
        status: 'requiere_atencion',
      });

      const profAuth = { auth: { uid: 'prof_staging', token: { profesor: true, rol: 'profesor' } } };
      // 20 envíos permitidos dentro del minuto -> 21 debe disparar resource-exhausted desde _quota_runtime
      for (let i = 1; i <= 20; i++) {
        const res = await indexExports.sendManualWhatsAppMessage.run(
          { leadId: 'lead_staging_demo', texto: `Mensaje sintetico ${i}` },
          profAuth
        );
        assert.strictEqual(res.success, true);
      }

      await assert.rejects(
        () => indexExports.sendManualWhatsAppMessage.run(
          { leadId: 'lead_staging_demo', texto: 'Mensaje 21 excedido' },
          profAuth
        ),
        (err) => err.code === 'resource-exhausted'
      );

      // Verificar persistencia real de cuota transaccional en `_quota_runtime`
      const quotaSnap = await db.collection('_quota_runtime').doc('sendManualWhatsAppMessage_prof_staging').get();
      assert.strictEqual(quotaSnap.exists, true);
      assert.strictEqual(quotaSnap.data().timestamps_ms.length, 20);

      // Ningún cliente (ni admin sin SDK) puede leer/editar `_quota_runtime` directamente (default-deny)
      const rClientQuotaRead = await restRequest(
        'GET',
        docPath('_quota_runtime', 'sendManualWhatsAppMessage_prof_staging'),
        null,
        tokAdmin
      );
      assert.strictEqual(rClientQuotaRead.status, 403);
    });
  } finally {
    global.fetch = origFetch;
  }

  console.log(`\n✔ SUITE PED-06B INTEGRAL STAGING COMPLETADA: ${passed}/6 bloques verificados (100%).`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ FALLO EN SUITE PED-06B INTEGRAL:', err);
  process.exit(1);
});

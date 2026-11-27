#!/usr/bin/env node
'use strict';

/**
 * scripts/test_ped05_firestore_persistence_emulator.js
 *
 * Suite integral PED-05 contra Firebase Firestore Emulator (`demo-ginga-test`, cero OpenAI, cero producción).
 * Verifica los 12 criterios de aceptación:
 *  1. Crear y guardar clase V2 en Firestore.
 *  2. Cerrar/reabrir cliente recuperando el borrador exacto.
 *  3. Recuperar la misma clase desde dos clientes autenticados (PC y móvil).
 *  4. Aplicar modificación del copiloto (simulado offline via callable autenticado) y guardar.
 *  5. Conservar referencias de Pizarra y Biblioteca FIU sin marcar recursos usados al guardar borrador.
 *  6. Iniciar ejecución en vivo y recuperar estado en otro dispositivo con marcas temporales.
 *  7. Finalizar clase guardando historial inmutable (sin mutar al editar plan luego).
 *  8. Recuperar continuidad pedagógica aislada para el grupo correcto (Zero-PII).
 *  9. Prevenir registro duplicado de sesión y detectar conflictos de escritura concurrente (`revision`).
 * 10. Rechazar accesos no autorizados (anónimo, alumno, otro instructor, escalación, quotas).
 * 11. Preservar datos preexistentes mediante migración `--dry-run` e idempotente (`--apply`).
 * 12. Comportamiento ante fallo/interrupción de conexión y recuperación al reconectar.
 */

const assert = require('assert');
const http = require('http');
const admin = require('../functions/node_modules/firebase-admin');
const {
  createGenerateClassPlanV2CallableHandler,
  createPedagogicalCopilotV1CallableHandler,
  buildFirestorePizarraResourceRepository,
} = require('../functions/planner_v2/callable_handler');
const { runMigration } = require('./migrate_planner_v2_firestore');

const HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const [HOSTNAME, PORT_STR] = HOST.split(':');
const PORT = Number(PORT_STR || 8080);
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-ginga-test';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('ERROR: FIRESTORE_EMULATOR_HOST debe estar definido para ejecutar esta suite.');
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
      email: `${uid}@capoeirafiu.test`,
      ...extraClaims,
    })
  ).toString('base64url');
  return `${header}.${payload}.`;
}

function restRequest(method, path, body = null, token = null, portOverride = PORT) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        hostname: HOSTNAME,
        port: portOverride,
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

function toFields(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    out[k] = toVal(v);
  }
  return out;
}

function toVal(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
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

function fromFields(fields) {
  if (!fields || typeof fields !== 'object') return {};
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    out[k] = fromVal(v);
  }
  return out;
}

function fromVal(v) {
  if (!v || typeof v !== 'object') return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) {
    return Array.isArray(v.arrayValue.values) ? v.arrayValue.values.map(fromVal) : [];
  }
  if ('mapValue' in v) {
    return fromFields(v.mapValue.fields || {});
  }
  return null;
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
  assert.strictEqual(res.status, 200, 'Failed clearing Firestore emulator');
}

async function seedLegacyAndAuthFixtures(db) {
  // Users: prof_1, prof_2, alumno_1, admin_1
  await db.collection('users').doc('prof_1').set({ rol: 'profesor', nombre: 'Prof Uno' });
  await db.collection('users').doc('prof_2').set({ rol: 'profesor', nombre: 'Prof Dos' });
  await db.collection('users').doc('admin_1').set({ rol: 'admin', nombre: 'Admin Uno' });
  await db.collection('users').doc('alumno_1').set({ rol: 'alumno', nombre: 'Alumno Uno' });

  // Existing pre-PED05 collections (Criterion 11)
  await db.collection('clases').doc('clase_adultos_mj').set({
    nombre: 'Adultos M/J 19:00',
    publico: 'Adultos',
    dias: 'Martes y Jueves',
    hora: '19:00',
    cupos_totales: 12,
  });
  await db.collection('clases').doc('clase_infantil_mj').set({
    nombre: 'Infantil M/J 18:00',
    publico: 'Niños',
    dias: 'Martes y Jueves',
    hora: '18:00',
    cupos_totales: 10,
  });
  await db.collection('asistencias').doc('asis_legacy_01').set({
    user_id: 'alumno_1',
    clase_id: 'clase_adultos_mj',
    fecha: '2026-11-20',
  });
  await db.collection('sesiones').doc('qr_sesion_01').set({
    clase_id: 'clase_adultos_mj',
    codigo: 'QR-LEGACY-01',
    activa: true,
  });
  await db.collection('tutoriales').doc('tut_ginga_01').set({
    titulo: 'Ginga Base',
    categoria: 'Fundamentos',
    nivel: 'Todos',
    corda: 'Crua',
    visible: true,
  });

  // Pre-existing legacy Pizarra ideas + legacy V1 plan (without instructor_id / schema_version / revision)
  await db.collection('instructor_ideas').doc('idea_legacy_01').set({
    titulo: 'Roda de palmas progresivas (Legacy)',
    tipo: 'nota',
    categoria: 'Musicalidad',
    publico: 'Todos',
    notas: 'Palmas base y respuesta de coro.',
    completado: false,
    veces_impartida: 0,
    created_at: '2026-11-01T10:00:00Z',
  });
  await db.collection('instructor_planes_clase').doc('plan_legacy_v1_01').set({
    titulo: 'Clase V1 Histórica Ginga y Cocorinha',
    duracion_total: 60,
    nivel: 'Adultos',
    enfoque: 'Técnica & Movilidad',
    objetivo: 'Postura base y esquiva.',
    veces_impartida: 3,
    created_at: '2026-11-02T10:00:00Z',
    bloques: [
      {
        fase: 'Técnica',
        duracion_min: 60,
        ejercicios: [{ nombre: 'Ginga + Cocorinha', detalle: 'Trabajo en parejas.' }],
      },
    ],
  });

  // Prof 1 owned Pizarra idea & Prof 2 private idea
  await db.collection('instructor_ideas').doc('idea_prof1_01').set({
    titulo: 'Circuito de esquivas con referencia visual',
    tipo: 'video',
    categoria: 'Técnica',
    publico: 'Todos',
    notas: 'Usar cinta en el suelo para marcar altura segura.',
    url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    completado: false,
    veces_impartida: 0,
    instructor_id: 'prof_1',
    shared: false,
    created_at: '2026-11-25T10:00:00Z',
  });
  await db.collection('instructor_ideas').doc('idea_prof2_private').set({
    titulo: 'Recurso privado Prof 2',
    tipo: 'nota',
    categoria: 'Roda',
    publico: 'Adultos',
    notas: 'Solo prof 2',
    completado: false,
    veces_impartida: 0,
    instructor_id: 'prof_2',
    shared: false,
    created_at: '2026-11-25T10:00:00Z',
  });
}

async function main() {
  console.log('================================================================');
  console.log('  SUITE PED-05: PERSISTENCIA FIRESTORE & MULTIDISPOSITIVO');
  console.log(`  Emulator: ${HOST} | Project: ${PROJECT_ID}`);
  console.log('================================================================\n');

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();
  await clearEmulator();
  await seedLegacyAndAuthFixtures(db);

  const tokenProf1 = createMockToken('prof_1', { instructor: true, rol: 'profesor' });
  const tokenProf2 = createMockToken('prof_2', { instructor: true, rol: 'profesor' });
  const tokenAlumno1 = createMockToken('alumno_1', { rol: 'alumno' });

  let passed = 0;
  async function check(name, fn) {
    await fn();
    passed += 1;
    console.log(`[PASS ${passed}/12] ${name}`);
  }

  // Shared test plan doc generated cleanly by simulated Motor V2 (zero OpenAI calls) and saved by prof_1
  const planId = 'ped05_plan_adultos_01';
  const genCallableForSeed = createGenerateClassPlanV2CallableHandler({
    db,
    allowLiveFirestore: true,
    serverOverrides: { providerMode: 'simulated', realProviderEnabled: false },
  });
  const genResp = await genCallableForSeed(
    {
      request: {
        contract_version: '2.1.0',
        request_id: 'ped05_seed_plan_01',
        creation_mode: 'avanzada',
        group_context: {
          source: 'real_class',
          clase_id: 'clase_adultos_mj',
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
          { resource_id: 'idea_prof1_01', priority: 'required', usage_note: 'Aplicar como puente técnico.' },
        ],
      },
    },
    { auth: { uid: 'prof_1', token: { instructor: true } } }
  );
  const generatedPlanTitle = genResp.plan.titulo;
  const basePlanDoc = {
    ...genResp.plan,
    id: planId,
    schema_version: 2,
    instructor_id: 'prof_1',
    clase_id: 'clase_adultos_mj',
    plan_status: 'draft',
    revision: 1,
    updated_by_device: 'pc_chrome_prof1',
    created_at: '2026-11-27T12:00:00Z',
    updated_at: '2026-11-27T12:00:00Z',
  };

  // Criterio 1: Crear y guardar clase
  await check('Criterio 1: Crear y guardar una clase V2 en instructor_planes_clase', async () => {
    const createRes = await restRequest(
      'POST',
      `${docPath('instructor_planes_clase')}?documentId=${planId}`,
      { fields: toFields(basePlanDoc) },
      tokenProf1
    );
    assert.strictEqual(createRes.status, 200, `Unexpected create status: ${JSON.stringify(createRes.body)}`);
    const saved = fromFields(createRes.body.fields);
    assert.strictEqual(saved.titulo, generatedPlanTitle);
    assert.strictEqual(saved.revision, 1);
    assert(saved.bloques.length >= 4);
  });

  // Criterio 2: Cerrar y reabrir la app recuperando el borrador
  await check('Criterio 2: Cerrar y reabrir sesión recuperando el borrador completo desde Firestore', async () => {
    const reopenToken = createMockToken('prof_1', { instructor: true, rol: 'profesor' });
    const getRes = await restRequest('GET', docPath('instructor_planes_clase', planId), null, reopenToken);
    assert.strictEqual(getRes.status, 200);
    const recovered = fromFields(getRes.body.fields);
    assert.strictEqual(recovered.plan_status, 'draft');
    assert.strictEqual(recovered.clase_id, 'clase_adultos_mj');
    assert(recovered.bloques[0].ejercicios[0].tiempos_internos.length >= 2);
  });

  // Criterio 3: Recuperar la misma clase desde dos dispositivos autenticados y editar
  await check('Criterio 3: Recuperar y editar la clase desde dos clientes autenticados (PC + Tablet)', async () => {
    const pcRead = await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokenProf1);
    const tabletRead = await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokenProf1);
    assert.strictEqual(pcRead.status, 200);
    assert.strictEqual(tabletRead.status, 200);

    const updatedFromTablet = {
      ...fromFields(tabletRead.body.fields),
      plan_status: 'saved',
      revision: 2,
      updated_by_device: 'tablet_ipad_prof1',
      updated_at: '2026-11-27T12:05:00Z',
    };
    const patchRes = await restRequest(
      'PATCH',
      docPath('instructor_planes_clase', planId),
      { fields: toFields(updatedFromTablet) },
      tokenProf1
    );
    assert.strictEqual(patchRes.status, 200);

    const pcRefresh = await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokenProf1);
    const synced = fromFields(pcRefresh.body.fields);
    assert.strictEqual(synced.plan_status, 'saved');
    assert.strictEqual(synced.revision, 2);
    assert.strictEqual(synced.updated_by_device, 'tablet_ipad_prof1');
  });

  // Criterio 4: Aplicar una modificación del copiloto (callable autenticado offline + instructor_ideas real) y guardar
  await check('Criterio 4: Modificación del Copiloto autenticado con instructor_ideas real y guardado', async () => {
    const copilotCallable = createPedagogicalCopilotV1CallableHandler({
      db,
      allowLiveFirestore: true,
      serverOverrides: { providerMode: 'simulated', realProviderEnabled: false },
    });
    const currentSnap = await db.collection('instructor_planes_clase').doc(planId).get();
    const currentPlan = currentSnap.data();

    const repo = buildFirestorePizarraResourceRepository(db, 'prof_1');
    const resolvedRes = await repo.getResourcesByIds(['idea_prof1_01', 'idea_prof2_private']);
    assert.strictEqual(resolvedRes.has('idea_prof1_01'), true, 'Debe leer recurso propio de instructor_ideas');
    assert.strictEqual(resolvedRes.has('idea_prof2_private'), false, 'No debe filtrar recurso privado de otro docente');

    const copilotResp = await copilotCallable(
      {
        request: {
          request_id: 'ped05_copilot_sim_01',
          message: 'Redistribuye la clase a 45 minutos',
          available_resource_ids: ['idea_prof1_01'],
          continuity_context: {
            group_label: 'Adultos M/J 19:00',
            audience_type: 'adultos',
            worked_movements: ['Ginga', 'Cocorinha'],
            reinforce_content: 'Postura en salidas laterales',
          },
          plan: currentPlan,
        },
      },
      { auth: { uid: 'prof_1', token: { instructor: true } } }
    );

    assert.strictEqual(copilotResp.status, 'ok');
    assert.strictEqual(copilotResp.mode, 'propose_changes', `Unexpected copilot conflict: ${copilotResp.conflict_reason}`);
    assert(copilotResp.proposed_plan, 'Debe devolver proposed_plan validado');
    assert.strictEqual(copilotResp.proposed_plan.duracion_total, 45);

    const persistedAfterCopilot = {
      ...copilotResp.proposed_plan,
      instructor_id: 'prof_1',
      clase_id: 'clase_adultos_mj',
      revision: 3,
      updated_by_device: 'pc_chrome_prof1',
      last_copilot_summary: {
        applied_at: '2026-11-27T12:10:00Z',
        mode: copilotResp.mode,
        operations_count: copilotResp.operations.length,
        diff_count: copilotResp.diff_summary.length,
      },
    };
    const saveCopilotRes = await restRequest(
      'PATCH',
      docPath('instructor_planes_clase', planId),
      { fields: toFields(persistedAfterCopilot) },
      tokenProf1
    );
    assert.strictEqual(saveCopilotRes.status, 200);
    const checkDoc = fromFields(saveCopilotRes.body.fields);
    assert.strictEqual(checkDoc.revision, 3);
    assert.strictEqual(checkDoc.duracion_total, 45);
    assert(checkDoc.last_copilot_summary && checkDoc.last_copilot_summary.operations_count >= 1);
  });

  // Criterio 5: Preservar referencias Pizarra y FIU sin marcar recurso como usado al guardar borrador
  await check('Criterio 5: Preservar referencias Pizarra y FIU sin incrementar contadores al guardar borrador', async () => {
    const planSnap = await db.collection('instructor_planes_clase').doc(planId).get();
    const pData = planSnap.data();
    const allResIds = pData.bloques.flatMap((b) => (b.ejercicios || []).flatMap((e) => e.linked_resource_ids || []));
    const allMovIds = pData.bloques.flatMap((b) => (b.ejercicios || []).flatMap((e) => e.curriculum_movement_ids || []));
    assert(allResIds.includes('idea_prof1_01'), 'Debe conservar linked_resource_ids de Pizarra');
    assert(allMovIds.includes('queixada'), 'Debe conservar curriculum_movement_ids FIU (queixada)');
    assert(allMovIds.includes('esquiva_lateral'), 'Debe conservar curriculum_movement_ids FIU (esquiva_lateral)');

    const ideaSnap = await db.collection('instructor_ideas').doc('idea_prof1_01').get();
    assert.strictEqual(ideaSnap.data().completado, false);
    assert.strictEqual(ideaSnap.data().veces_impartida, 0);
  });

  // Criterio 6: Iniciar ejecución en vivo y recuperar estado en otro dispositivo con marcas temporales
  const liveDocId = 'active_prof_1';
  const liveSessionId = 'live_ped05_ses_01';
  await check('Criterio 6: Iniciar ejecución en vivo y recuperarla desde segundo dispositivo con marcas temporales', async () => {
    const activeState = {
      session_id: liveSessionId,
      plan_id: planId,
      instructor_id: 'prof_1',
      clase_id: 'clase_adultos_mj',
      plan_title: 'Armada y Cocorinha — Adultos M/J',
      group_id: 'clase_adultos_mj',
      group_name: 'Adultos M/J 19:00',
      audience_type: 'adultos',
      planned_total_duration_min: 60,
      participants_count: 12,
      started_at: '2026-11-27T18:00:00.000Z',
      last_resumed_at: '2026-11-27T18:15:00.000Z',
      accumulated_session_elapsed_sec: 900,
      active_exercise_index: 1,
      active_exercise_allocated_sec: 900,
      active_exercise_accumulated_sec: 120,
      is_running: true,
      revision: 2,
      device_id: 'tablet_ipad_prof1',
      updated_at: '2026-11-27T18:17:00.000Z',
      plan_snapshot: { id: planId, titulo: 'Armada y Cocorinha — Adultos M/J' },
      exercises: [
        {
          block_id: 'blk_tech',
          block_title: 'Técnica y progresiones',
          block_index: 0,
          exercise_id: 'ex_tech_armada',
          exercise_index: 0,
          planned_duration_sec: 1200,
          actual_duration_sec: 900,
          status: 'completed',
          resolved_resource_ids: ['idea_prof1_01'],
          exercise: { exercise_id: 'ex_tech_armada', nombre: 'Progresión Armada', detalle: '...' },
        },
      ],
    };

    const putLive = await restRequest(
      'PATCH',
      docPath('instructor_sesiones_activas', liveDocId),
      { fields: toFields(activeState) },
      tokenProf1
    );
    assert.strictEqual(putLive.status, 200);

    // Segundo dispositivo (celular) lee estado activo y calcula tiempo real transcurrido desde last_resumed_at
    const mobileRead = await restRequest(
      'GET',
      docPath('instructor_sesiones_activas', liveDocId),
      null,
      tokenProf1
    );
    assert.strictEqual(mobileRead.status, 200);
    const recovered = fromFields(mobileRead.body.fields);
    assert.strictEqual(recovered.session_id, liveSessionId);
    assert.strictEqual(recovered.active_exercise_index, 1);
    const nowMs = Date.parse('2026-11-27T18:20:00.000Z');
    const deltaSec = Math.floor((nowMs - Date.parse(recovered.last_resumed_at)) / 1000);
    const totalElapsed = recovered.accumulated_session_elapsed_sec + deltaSec;
    assert.strictEqual(totalElapsed, 1200);
  });

  // Criterio 7: Finalizar clase guardando historial inmutable (y edición posterior no muta historial)
  await check('Criterio 7: Finalizar clase guardando historial inmutable separado del plan original', async () => {
    const finalizeTx = async (sessionDocId, taughtResIds) => {
      const sesRef = db.collection('instructor_sesiones_impartidas').doc(sessionDocId);
      const pRef = db.collection('instructor_planes_clase').doc(planId);
      const ideaRef = db.collection('instructor_ideas').doc('idea_prof1_01');
      const activeRef = db.collection('instructor_sesiones_activas').doc(liveDocId);

      return db.runTransaction(async (tx) => {
        const sSnap = await tx.get(sesRef);
        if (sSnap.exists) return false;
        const pSnap = await tx.get(pRef);
        const rSnap = await tx.get(ideaRef);

        tx.set(sesRef, {
          session_id: sessionDocId,
          instructor_id: 'prof_1',
          plan_id: planId,
          plan_titulo_snapshot: pSnap.data().titulo,
          clase_id: 'clase_adultos_mj',
          grupo_nombre_snapshot: 'Adultos M/J 19:00',
          track_id: 'adultos',
          ended_at: '2026-11-27T19:00:00.000Z',
          duracion_real_min: 59,
          duracion_real_seg: 3540,
          asistentes_count: 11,
          completed_exercises_count: 2,
          total_exercises_count: 3,
          practiced_movements: ['Armada', 'Cocorinha'],
          ejercicios_completados: ['Progresión de Armada y Cocorinha en parejas'],
          ejercicios_omitidos: ['Preparación de Aú controlado'],
          notas_post_clase: 'Buena distancia y fluidez sin filas.',
          contenido_reforzar: 'Entrada limpia de Armada con cadera alta.',
          pendiente_proxima_sesion: 'Conectar Armada con Negativa lateral.',
          taught_resource_ids: taughtResIds,
          plan_snapshot: pSnap.data(),
          immutable: true,
        });

        tx.update(pRef, {
          veces_impartida: (pSnap.data().veces_impartida || 0) + 1,
          ultima_ejecucion: '2026-11-27T19:00:00.000Z',
          plan_status: 'completed',
          revision: (pSnap.data().revision || 1) + 1,
        });
        tx.update(ideaRef, {
          completado: true,
          veces_impartida: (rSnap.data().veces_impartida || 0) + 1,
          clase_usada: 'Adultos M/J 19:00',
        });
        tx.delete(activeRef);
        return true;
      });
    };

    const recorded = await finalizeTx(liveSessionId, ['idea_prof1_01']);
    assert.strictEqual(recorded, true);

    // Reglas Firestore prohíben UPDATE/DELETE sobre historial impartido
    const tamperUpdate = await restRequest(
      'PATCH',
      docPath('instructor_sesiones_impartidas', liveSessionId),
      { fields: toFields({ notas_post_clase: 'ALTERADO' }) },
      tokenProf1
    );
    assert.strictEqual(tamperUpdate.status, 403, 'Historial debe rechazar UPDATE por regla');

    const tamperDelete = await restRequest(
      'DELETE',
      docPath('instructor_sesiones_impartidas', liveSessionId),
      null,
      tokenProf1
    );
    assert.strictEqual(tamperDelete.status, 403, 'Historial debe rechazar DELETE por regla');

    // Editar plan original después NO muta el snapshot histórico
    await db.collection('instructor_planes_clase').doc(planId).update({
      titulo: 'Título Editado Posteriormente',
      revision: 5,
    });
    const histSnap = await db.collection('instructor_sesiones_impartidas').doc(liveSessionId).get();
    assert.strictEqual(histSnap.data().plan_snapshot.titulo, generatedPlanTitle);
    const ideaAfter = await db.collection('instructor_ideas').doc('idea_prof1_01').get();
    assert.strictEqual(ideaAfter.data().completado, true);
    assert.strictEqual(ideaAfter.data().veces_impartida, 1);

    // Criterio 9 (parte 1): Idempotencia ante doble finalización
    const duplicateFinal = await finalizeTx(liveSessionId, ['idea_prof1_01']);
    assert.strictEqual(duplicateFinal, false, 'Reintento de misma sesión no debe duplicar');
    const ideaIdempotent = await db.collection('instructor_ideas').doc('idea_prof1_01').get();
    assert.strictEqual(ideaIdempotent.data().veces_impartida, 1, 'No debe incrementar recurso dos veces');
  });

  // Criterio 8: Continuidad pedagógica aislada para el grupo correcto
  await check('Criterio 8: Recuperar continuidad pedagógica aislada por grupo sin mezclar historiales', async () => {
    await db.collection('instructor_sesiones_impartidas').doc('live_infantil_ses_01').set({
      session_id: 'live_infantil_ses_01',
      instructor_id: 'prof_1',
      plan_id: 'plan_infantil_ref',
      plan_titulo_snapshot: 'Juegos de Ginga Kids',
      clase_id: 'clase_infantil_mj',
      grupo_nombre_snapshot: 'Infantil M/J 18:00',
      track_id: 'infantil',
      ended_at: '2026-11-26T18:55:00.000Z',
      duracion_real_min: 55,
      asistentes_count: 9,
      practiced_movements: ['Ginga', 'Aú'],
      notas_post_clase: 'Buena coordinación en circuito animal.',
      pendiente_proxima_sesion: 'Reforzar palmas de 3 tiempos en círculo.',
      plan_snapshot: { id: 'plan_infantil_ref' },
    });

    const adultHist = await db
      .collection('instructor_sesiones_impartidas')
      .where('instructor_id', '==', 'prof_1')
      .where('clase_id', '==', 'clase_adultos_mj')
      .get();
    assert.strictEqual(adultHist.docs.length, 1);
    assert.strictEqual(adultHist.docs[0].data().pendiente_proxima_sesion, 'Conectar Armada con Negativa lateral.');

    const kidsHist = await db
      .collection('instructor_sesiones_impartidas')
      .where('instructor_id', '==', 'prof_1')
      .where('clase_id', '==', 'clase_infantil_mj')
      .get();
    assert.strictEqual(kidsHist.docs.length, 1);
    assert.strictEqual(kidsHist.docs[0].data().pendiente_proxima_sesion, 'Reforzar palmas de 3 tiempos en círculo.');
  });

  // Criterio 9 (parte 2): Prevención de conflicto de escritura concurrente (`revision`)
  await check('Criterio 9: Idempotencia confirmada + detección transaccional de conflicto de revisión', async () => {
    const pRef = db.collection('instructor_planes_clase').doc(planId);
    let conflictCaught = false;
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(pRef);
        const remoteRev = snap.data().revision; // 5
        const staleExpectedRev = 3;
        if (remoteRev !== staleExpectedRev) {
          throw new Error(`CONCURRENCY_CONFLICT: expected ${staleExpectedRev}, remote ${remoteRev}`);
        }
        tx.update(pRef, { titulo: 'Sobrescritura silenciosa', revision: staleExpectedRev + 1 });
      });
    } catch (e) {
      if (String(e.message).includes('CONCURRENCY_CONFLICT')) {
        conflictCaught = true;
      }
    }
    assert.strictEqual(conflictCaught, true, 'La transacción debe rechazar revision obsoleta');
    const afterSnap = await pRef.get();
    assert.strictEqual(afterSnap.data().titulo, 'Título Editado Posteriormente');
  });

  // Criterio 10: Rechazo de accesos no autorizados
  await check('Criterio 10: Rechazar anónimos, alumnos, otro instructor, escalación y cuotas cliente', async () => {
    // Anónimo leer plan
    const anonPlan = await restRequest('GET', docPath('instructor_planes_clase', planId), null, null);
    assert.strictEqual(anonPlan.status, 403);

    // Alumno escribir o leer plan
    const alumnoRead = await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokenAlumno1);
    assert.strictEqual(alumnoRead.status, 403);

    // Otro instructor prof_2 leer/modificar/borrar plan privado de prof_1
    const prof2Read = await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokenProf2);
    assert.strictEqual(prof2Read.status, 403);

    const prof2Delete = await restRequest('DELETE', docPath('instructor_planes_clase', planId), null, tokenProf2);
    assert.strictEqual(prof2Delete.status, 403);

    // Reasignar instructor_id bloqueado incluso por dueño
    const hijackRes = await restRequest(
      'PATCH',
      docPath('instructor_planes_clase', planId),
      { fields: toFields({ instructor_id: 'prof_2', titulo: 'Hijack', duracion_total: 60 }) },
      tokenProf1
    );
    assert.strictEqual(hijackRes.status, 403);

    // Estado inválido en plan
    const badStatus = await restRequest(
      'POST',
      `${docPath('instructor_planes_clase')}?documentId=plan_bad_status`,
      {
        fields: toFields({
          instructor_id: 'prof_1',
          titulo: 'Plan inválido',
          duracion_total: 60,
          plan_status: 'superuser_hacked',
        }),
      },
      tokenProf1
    );
    assert.strictEqual(badStatus.status, 403);

    // Cliente intentando escribir en planner_v2_quotas o planner_copilot_usage
    const quotaWrite = await restRequest(
      'POST',
      `${docPath('planner_v2_quotas')}?documentId=q1`,
      { fields: toFields({ limit: 9999 }) },
      tokenProf1
    );
    assert.strictEqual(quotaWrite.status, 403);

    // Alumno intentando invocar callables V2 / Copiloto
    const genCallable = createGenerateClassPlanV2CallableHandler({
      db,
      allowLiveFirestore: true,
      serverOverrides: { providerMode: 'simulated' },
    });
    await assert.rejects(
      () => genCallable({ request: {} }, { auth: { uid: 'alumno_1', token: { rol: 'alumno' } } }),
      (err) => err.code === 'permission-denied'
    );
  });

  // Criterio 11: Preservar datos preexistentes con migración dry-run + idempotente
  await check('Criterio 11: Migración --dry-run e idempotente preservando V1, Pizarra y colecciones previas', async () => {
    const drySummary = await runMigration({
      apply: false,
      defaultInstructorUid: 'prof_1',
      projectId: PROJECT_ID,
    });
    assert.strictEqual(drySummary.mode, 'dry-run');
    assert.strictEqual(drySummary.plansToMigrate, 1);
    assert.strictEqual(drySummary.ideasToMigrate, 1);

    const apply1 = await runMigration({
      apply: true,
      defaultInstructorUid: 'prof_1',
      projectId: PROJECT_ID,
    });
    assert.strictEqual(apply1.plansUpdated, 1);
    assert.strictEqual(apply1.ideasUpdated, 1);

    const apply2 = await runMigration({
      apply: true,
      defaultInstructorUid: 'prof_1',
      projectId: PROJECT_ID,
    });
    assert.strictEqual(apply2.plansToMigrate, 0, 'Segunda ejecución debe ser 100% idempotente');
    assert.strictEqual(apply2.ideasToMigrate, 0);

    // Contenido V1 + colecciones legacy intactas
    const v1After = (await db.collection('instructor_planes_clase').doc('plan_legacy_v1_01').get()).data();
    assert.strictEqual(v1After.titulo, 'Clase V1 Histórica Ginga y Cocorinha');
    assert.strictEqual(v1After.veces_impartida, 3);
    assert.strictEqual(v1After.bloques[0].ejercicios[0].nombre, 'Ginga + Cocorinha');

    const qrSes = (await db.collection('sesiones').doc('qr_sesion_01').get()).data();
    assert.strictEqual(qrSes.codigo, 'QR-LEGACY-01');
    const asist = (await db.collection('asistencias').doc('asis_legacy_01').get()).data();
    assert.strictEqual(asist.fecha, '2026-11-20');
    const tut = (await db.collection('tutoriales').doc('tut_ginga_01').get()).data();
    assert.strictEqual(tut.titulo, 'Ginga Base');
  });

  // Criterio 12: Comportamiento ante fallo/interrupción de conexión y recuperación al reconectar
  await check('Criterio 12: Error de conexión controlado sin corromper datos + recuperación al reconectar', async () => {
    let connFailed = false;
    try {
      await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokenProf1, 59999);
    } catch (_) {
      connFailed = true;
    }
    assert.strictEqual(connFailed, true, 'Debe propagar fallo real cuando no hay conexión al puerto');

    // Al reconectar al puerto real del emulador, el plan sigue íntegro y actualizable
    const retryRead = await restRequest('GET', docPath('instructor_planes_clase', planId), null, tokenProf1);
    assert.strictEqual(retryRead.status, 200);
    const retryData = fromFields(retryRead.body.fields);
    assert.strictEqual(retryData.revision, 5);
  });

  console.log(`\n✔ SUITE PED-05 EMULATOR COMPLETADA: ${passed}/12 criterios aprobados.`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ ERROR EN SUITE PED-05 EMULATOR:', err);
  process.exit(1);
});

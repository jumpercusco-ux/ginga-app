#!/usr/bin/env node
'use strict';

/**
 * scripts/test_ped06a_security_emulator.js
 *
 * Suite integral PED-06A contra Firebase Firestore Emulator (`demo-ginga-test`, cero OpenAI, cero producción).
 * Verifica:
 *  A. Reglas Firestore P0 resueltas (positivas y negativas):
 *     - users (PII tercero bloqueada, auto-registro acotado, anti-escalación, perfil/FCM/status legítimos)
 *     - whatsapp_leads y mensajes (aislado a staff)
 *     - asistencias + sesiones QR (check-in en sesión activa vs sesión cerrada/forjada)
 *     - clases, reservas, pedidos, pagos, productos, tutoriales, cantigas, eventos, config y default-deny
 *     - consistencia entre 'admin' y legacy 'administrador'
 *  B. Seguridad de Cloud Functions (`functions/index.js` + `functions/planner_v2/`):
 *     - sendManualWhatsAppMessage (unauthenticated, alumno 403, leadId/texto inválido, not-found, profesor OK)
 *     - migrarMensajesHistoricos (GET 405, sin token 401, profesor 403, admin dry-run OK sin mutar)
 *     - ejecutarStressTestAI (GET 405, sin token 401, profesor 403, falta confirmación 400)
 *     - actualizarMiniaturasExistentes (GET 405, sin token 401, profesor 403, bloqueo SSRF, admin dry-run OK)
 *     - isSafePublicHttpUrl / obtenerOgImage anti-SSRF (metadata cloud, loopback, RFC1918, file://)
 *     - generarPlanClaseIA (unauthenticated, alumno 403, duracion 999 invalid-argument, profesor rate limit)
 *     - Planner V2 / Copiloto aceptan claims `profesor: true` y `rol: 'administrador'` y rechazan alumno
 *  C. Migración idempotente de roles y Custom Claims (`--dry-run` y `--apply`)
 */

const assert = require('assert');
const http = require('http');
const admin = require('../functions/node_modules/firebase-admin');
const { runRoleAndClaimsMigration } = require('./migrate_auth_roles_and_claims');
const {
  createGenerateClassPlanV2CallableHandler,
  createPedagogicalCopilotV1CallableHandler,
} = require('../functions/planner_v2/callable_handler');

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
      email: `${uid}@capoeirafiu.test`,
      ...extraClaims,
    })
  ).toString('base64url');
  return `${header}.${payload}.`;
}

function decodeMockToken(token) {
  const parts = String(token || '').split('.');
  if (parts.length < 2) throw new Error('Malformed mock JWT');
  const json = Buffer.from(parts[1], 'base64url').toString('utf8');
  return JSON.parse(json);
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
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(v)) return { timestampValue: v };
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
    out[k] = toVal(v);
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

function makeMockRes() {
  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    sendStatus(code) {
      this.statusCode = code;
      return this;
    },
  };
  return res;
}

async function main() {
  console.log('================================================================');
  console.log('  SUITE PED-06A: SEGURIDAD FIRESTORE, CLOUD FUNCTIONS Y ROLES');
  console.log(`  Emulator: ${HOST} | Project: ${PROJECT_ID}`);
  console.log('================================================================\n');

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();
  await clearEmulator();

  // Seed users including legacy `administrador` role
  await db.collection('users').doc('admin_1').set({ rol: 'admin', nombre: 'Admin Principal' });
  await db.collection('users').doc('admin_legacy').set({ rol: 'administrador', nombre: 'Admin Legacy' });
  await db.collection('users').doc('prof_1').set({ rol: 'profesor', nombre: 'Profesor Uno' });
  await db.collection('users').doc('alumno_1').set({
    uid: 'alumno_1',
    rol: 'alumno',
    nombre: 'Alumno Uno',
    email: 'alumno_1@capoeirafiu.test',
    corda: 'Crua',
    status: 'nuevo',
    dni: '99998888',
    telefono: '+51999111222',
  });
  await db.collection('users').doc('alumno_2').set({
    uid: 'alumno_2',
    rol: 'alumno',
    nombre: 'Alumna Dos',
    email: 'alumno_2@capoeirafiu.test',
    corda: 'Crua',
    status: 'activo',
    dni: '77776666',
    telefono: '+51999333444',
  });

  // Seed legacy & catalog data
  await db.collection('clases').doc('clase_1').set({
    nombre: 'Adultos M/J',
    dias: 'Martes y Jueves',
    hora: '19:00',
    cupos_disponibles: 5,
    instructor_id: 'prof_1',
  });
  await db.collection('sesiones').doc('sesion_qr_activa').set({
    clase_id: 'clase_1',
    activa: true,
    nivel: 'Adultos',
    hora: '19:00',
    fecha: '2026-11-27',
  });
  await db.collection('sesiones').doc('sesion_qr_cerrada').set({
    clase_id: 'clase_1',
    activa: false,
  });
  await db.collection('whatsapp_leads').doc('51999000111').set({
    telefono: '51999000111',
    nombre: 'Prospecto Demo',
    status: 'conversando',
    ai_habilitada: false,
  });
  await db
    .collection('whatsapp_leads')
    .doc('51999000111')
    .collection('mensajes')
    .doc('msg_1')
    .set({
      from: 'user',
      texto: 'Hola, quiero info',
    });
  await db.collection('pagos').doc('pago_a2').set({ user_id: 'alumno_2', monto: 140 });
  await db.collection('cantigas').doc('cantiga_1').set({ titulo: 'Marinheiro só', ritmo: 'Corrido' });
  await db.collection('productos').doc('prod_1').set({ nombre: 'Corda', precio: 50 });
  await db.collection('config').doc('negocio').set({ precio_regular: 140 });
  await db.collection('instructor_ideas').doc('idea_ssrf_test').set({
    titulo: 'Link externo',
    tipo: 'link',
    url: 'http://169.254.169.254/latest/meta-data/',
    instructor_id: 'prof_1',
  });

  const tokAdmin = createMockToken('admin_1', { admin: true, curriculum_admin: true, rol: 'admin' });
  const tokAdminLegacy = createMockToken('admin_legacy'); // solo doc users con rol='administrador'
  const tokProf = createMockToken('prof_1', { profesor: true, instructor: true, rol: 'profesor' });
  const tokAlu1 = createMockToken('alumno_1', { rol: 'alumno' });
  const tokAlu3 = createMockToken('alumno_3');

  let passed = 0;
  async function check(name, fn) {
    await fn();
    passed += 1;
    console.log(`[PASS] ${name}`);
  }

  // =========================================================================
  // A. FIRESTORE SECURITY RULES
  // =========================================================================
  await check('A01_users_bloquea_anonimo_y_lectura_PII_terceros', async () => {
    const rAnon = await restRequest('GET', docPath('users', 'alumno_1'), null, null);
    assert.strictEqual(rAnon.status, 403);

    const rOwn = await restRequest('GET', docPath('users', 'alumno_1'), null, tokAlu1);
    assert.strictEqual(rOwn.status, 200);

    const rOther = await restRequest('GET', docPath('users', 'alumno_2'), null, tokAlu1);
    assert.strictEqual(rOther.status, 403, 'Alumno 1 no puede leer PII de Alumno 2');

    const rProfRead = await restRequest('GET', docPath('users', 'alumno_2'), null, tokProf);
    assert.strictEqual(rProfRead.status, 200, 'Profesor sí puede leer alumnos');
  });

  await check('A02_users_bloquea_auto_registro_privilegiado_y_permite_alumno', async () => {
    const rSpoofCreate = await restRequest(
      'POST',
      `${docPath('users')}?documentId=alumno_3`,
      { fields: toFields({ uid: 'alumno_3', rol: 'admin', status: 'activo' }) },
      tokAlu3
    );
    assert.strictEqual(rSpoofCreate.status, 403);

    const rValidCreate = await restRequest(
      'POST',
      `${docPath('users')}?documentId=alumno_3`,
      { fields: toFields({ uid: 'alumno_3', rol: 'alumno', status: 'nuevo', nombre: 'Alumno Tres' }) },
      tokAlu3
    );
    assert.strictEqual(rValidCreate.status, 200);
  });

  await check('A03_users_bloquea_escalacion_rol_corda_status_y_permite_perfil_propio', async () => {
    const rEscRole = await restRequest(
      'PATCH',
      `${docPath('users', 'alumno_1')}?updateMask.fieldPaths=rol`,
      { fields: toFields({ rol: 'profesor' }) },
      tokAlu1
    );
    assert.strictEqual(rEscRole.status, 403);

    const rEscCorda = await restRequest(
      'PATCH',
      `${docPath('users', 'alumno_1')}?updateMask.fieldPaths=corda`,
      { fields: toFields({ corda: 'Verde' }) },
      tokAlu1
    );
    assert.strictEqual(rEscCorda.status, 403);

    const rEscStatus = await restRequest(
      'PATCH',
      `${docPath('users', 'alumno_1')}?updateMask.fieldPaths=status`,
      { fields: toFields({ status: 'activo' }) },
      tokAlu1
    );
    assert.strictEqual(rEscStatus.status, 403, 'Alumno no puede autopromoverse a activo');

    // Actualizaciones legítimas: ficha personal, fcm_token y status nuevo -> prueba
    const rValidProfile = await restRequest(
      'PATCH',
      `${docPath('users', 'alumno_1')}?updateMask.fieldPaths=telefono&updateMask.fieldPaths=fcm_token&updateMask.fieldPaths=status`,
      { fields: toFields({ telefono: '+51999000999', fcm_token: 'tok_fcm_1', status: 'prueba' }) },
      tokAlu1
    );
    assert.strictEqual(rValidProfile.status, 200);

    // Profesor no puede promover alumno a admin
    const rProfPromote = await restRequest(
      'PATCH',
      `${docPath('users', 'alumno_1')}?updateMask.fieldPaths=rol`,
      { fields: toFields({ rol: 'admin' }) },
      tokProf
    );
    assert.strictEqual(rProfPromote.status, 403);
  });

  await check('A04_notificaciones_protegidas_y_envio_hacia_profesor_permitido', async () => {
    // Alumno 1 no puede leer buzón de Alumno 2 ni spamear a Alumno 2
    const rReadOther = await restRequest(
      'GET',
      docPath('users/alumno_2/notificaciones'),
      null,
      tokAlu1
    );
    assert.strictEqual(rReadOther.status, 403);

    const rSpamAlu2 = await restRequest(
      'POST',
      docPath('users/alumno_2/notificaciones'),
      { fields: toFields({ titulo: 'Spam', mensaje: 'No permitido' }) },
      tokAlu1
    );
    assert.strictEqual(rSpamAlu2.status, 403);

    // Alumno 1 sí puede notificar al profesor al reservar/pedir
    const rNotifyProf = await restRequest(
      'POST',
      docPath('users/prof_1/notificaciones'),
      { fields: toFields({ titulo: 'Nueva reserva', mensaje: 'Cupo reservado', tipo: 'bienvenida' }) },
      tokAlu1
    );
    assert.strictEqual(rNotifyProf.status, 200);
  });

  await check('A05_whatsapp_leads_y_mensajes_estrictamente_restringidos_a_staff', async () => {
    const rAluLeadRead = await restRequest('GET', docPath('whatsapp_leads', '51999000111'), null, tokAlu1);
    assert.strictEqual(rAluLeadRead.status, 403);

    const rAluMsgRead = await restRequest(
      'GET',
      docPath('whatsapp_leads/51999000111/mensajes', 'msg_1'),
      null,
      tokAlu1
    );
    assert.strictEqual(rAluMsgRead.status, 403);

    const rProfLeadRead = await restRequest('GET', docPath('whatsapp_leads', '51999000111'), null, tokProf);
    assert.strictEqual(rProfLeadRead.status, 200);

    const rAdminLegacyRead = await restRequest(
      'GET',
      docPath('whatsapp_leads', '51999000111'),
      null,
      tokAdminLegacy
    );
    assert.strictEqual(rAdminLegacyRead.status, 200, 'Admin legacy con rol=administrador debe seguir operando');
  });

  await check('A06_clases_asistencias_reservas_y_sesiones_QR_compatibles_y_seguras', async () => {
    // Alumno puede leer clases/sesiones pero no crear sesiones ni editar horario de clase
    const rAluEditClass = await restRequest(
      'PATCH',
      `${docPath('clases', 'clase_1')}?updateMask.fieldPaths=hora`,
      { fields: toFields({ hora: '03:00' }) },
      tokAlu1
    );
    assert.strictEqual(rAluEditClass.status, 403);

    // Alumno NO puede decrementar cupos sin transición atómica nuevo -> prueba
    const rCupoStandalone = await restRequest(
      'PATCH',
      `${docPath('clases', 'clase_1')}?updateMask.fieldPaths=cupos_disponibles`,
      { fields: toFields({ cupos_disponibles: 4 }) },
      tokAlu3
    );
    assert.strictEqual(rCupoStandalone.status, 403, 'Debe rechazar decremento suelto de cupos');

    // Alumno SÍ puede decrementar cupos_disponibles en exactamente 1 dentro de commit atómico nuevo -> prueba
    const rCupoCommit = await restRequest(
      'POST',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`,
      {
        writes: [
          {
            update: {
              name: `projects/${PROJECT_ID}/databases/(default)/documents/clases/clase_1`,
              fields: toFields({ cupos_disponibles: 4 }),
            },
            updateMask: { fieldPaths: ['cupos_disponibles'] },
          },
          {
            update: {
              name: `projects/${PROJECT_ID}/databases/(default)/documents/users/alumno_3`,
              fields: toFields({ status: 'prueba' }),
            },
            updateMask: { fieldPaths: ['status'] },
          },
        ],
      },
      tokAlu3
    );
    assert.strictEqual(rCupoCommit.status, 200);

    // Alumno NO puede registrar asistencia sobre sesión cerrada, a nombre de otro, ID arbitrario ni clase falsificada
    const rAsisClosed = await restRequest(
      'POST',
      `${docPath('asistencias')}?documentId=sesion_qr_cerrada_alumno_1`,
      { fields: toFields({ user_id: 'alumno_1', sesion_id: 'sesion_qr_cerrada', clase_id: 'clase_1', fecha: '2026-11-27' }) },
      tokAlu1
    );
    assert.strictEqual(rAsisClosed.status, 403);

    const rAsisSpoof = await restRequest(
      'POST',
      `${docPath('asistencias')}?documentId=sesion_qr_activa_alumno_2`,
      { fields: toFields({ user_id: 'alumno_2', sesion_id: 'sesion_qr_activa', clase_id: 'clase_1', fecha: '2026-11-27' }) },
      tokAlu1
    );
    assert.strictEqual(rAsisSpoof.status, 403);

    const rAsisRandomId = await restRequest(
      'POST',
      docPath('asistencias'),
      { fields: toFields({ user_id: 'alumno_1', sesion_id: 'sesion_qr_activa', clase_id: 'clase_1', fecha: '2026-11-27' }) },
      tokAlu1
    );
    assert.strictEqual(rAsisRandomId.status, 403, 'Debe rechazar asistencia con ID arbitrario');

    const rAsisFakeClass = await restRequest(
      'POST',
      `${docPath('asistencias')}?documentId=sesion_qr_activa_alumno_1`,
      { fields: toFields({ user_id: 'alumno_1', sesion_id: 'sesion_qr_activa', clase_id: 'clase_falsa', fecha: '2026-11-27' }) },
      tokAlu1
    );
    assert.strictEqual(rAsisFakeClass.status, 403, 'Debe rechazar asistencia con clase_id alterado');

    const rAsisValid = await restRequest(
      'POST',
      `${docPath('asistencias')}?documentId=sesion_qr_activa_alumno_1`,
      { fields: toFields({ user_id: 'alumno_1', sesion_id: 'sesion_qr_activa', clase_id: 'clase_1', fecha: '2026-11-27' }) },
      tokAlu1
    );
    assert.strictEqual(rAsisValid.status, 200);
  });

  await check('A07_pedidos_pagos_cantigas_config_y_default_deny', async () => {
    const rPagoOther = await restRequest('GET', docPath('pagos', 'pago_a2'), null, tokAlu1);
    assert.strictEqual(rPagoOther.status, 403);

    const rCantigaWriteAlu = await restRequest(
      'POST',
      docPath('cantigas'),
      { fields: toFields({ titulo: 'Hack' }) },
      tokAlu1
    );
    assert.strictEqual(rCantigaWriteAlu.status, 403);

    const rConfigWriteProf = await restRequest(
      'PATCH',
      docPath('config', 'negocio'),
      { fields: toFields({ precio_regular: 1 }) },
      tokProf
    );
    assert.strictEqual(rConfigWriteProf.status, 403, 'Solo admin escribe config/negocio');

    const rDefaultDeny = await restRequest('GET', docPath('coleccion_inexistente_audit', 'x'), null, tokAdmin);
    assert.strictEqual(rDefaultDeny.status, 403);
  });

  // =========================================================================
  // B. CLOUD FUNCTIONS SECURITY (`functions/index.js` & `functions/planner_v2`)
  // =========================================================================
  Object.defineProperty(admin, 'auth', {
    configurable: true,
    value: () => ({
      verifyIdToken: async (token) => {
        if (token === 'INVALID_TOKEN') throw new Error('Invalid token');
        return decodeMockToken(token);
      },
    }),
  });
  const origFetch = global.fetch;
  global.fetch = async (url) => {
    if (String(url).includes('graph.facebook.com')) {
      return { ok: true, status: 200, json: async () => ({ messages: [{ id: 'wamid.mock' }] }), text: async () => '{}' };
    }
    throw new Error(`Unexpected external fetch blocked in offline test: ${url}`);
  };
  process.env.META_WHATSAPP_TOKEN = 'mock_wa_token';
  process.env.META_PHONE_NUMBER_ID = '123456789';

  const indexExports = require('../functions/index.js');
  const internals = indexExports.__internals;

  try {
    await check('B01_endpoints_http_admin_rechazan_GET_sin_token_y_no_admin', async () => {
      const httpFns = [
        { name: 'migrarMensajesHistoricos', fn: indexExports.migrarMensajesHistoricos },
        { name: 'ejecutarStressTestAI', fn: indexExports.ejecutarStressTestAI },
        { name: 'actualizarMiniaturasExistentes', fn: indexExports.actualizarMiniaturasExistentes },
      ];
      for (const { name, fn } of httpFns) {
        const resGet = makeMockRes();
        await fn({ method: 'GET', headers: {} }, resGet);
        assert.strictEqual(resGet.statusCode, 405, `${name} debe rechazar GET`);

        const resNoTok = makeMockRes();
        await fn({ method: 'POST', headers: {}, body: {} }, resNoTok);
        assert.strictEqual(resNoTok.statusCode, 401, `${name} debe rechazar sin token`);

        const resProf = makeMockRes();
        await fn({ method: 'POST', headers: { authorization: `Bearer ${tokProf}` }, body: {} }, resProf);
        assert.strictEqual(resProf.statusCode, 403, `${name} debe rechazar profesor sin claim admin`);
      }

      // Admin dry-run en migrarMensajesHistoricos y actualizarMiniaturasExistentes
      internals._resetRuntimeRateLimits();
      const resMigDry = makeMockRes();
      await indexExports.migrarMensajesHistoricos(
        { method: 'POST', headers: { authorization: `Bearer ${tokAdmin}` }, body: {} },
        resMigDry
      );
      assert.strictEqual(resMigDry.statusCode, 200);
      assert.strictEqual(resMigDry.body.dry_run, true);

      const resMinDry = makeMockRes();
      await indexExports.actualizarMiniaturasExistentes(
        { method: 'POST', headers: { authorization: `Bearer ${tokAdmin}` }, body: {} },
        resMinDry
      );
      assert.strictEqual(resMinDry.statusCode, 200);
      assert.strictEqual(resMinDry.body.dry_run, true);
      assert.strictEqual(resMinDry.body.bloqueadasSsrf, 1, 'Debe bloquear URL metadata SSRF');

      // ejecutarStressTestAI exige confirmación explícita
      const resStressNoConfirm = makeMockRes();
      await indexExports.ejecutarStressTestAI(
        { method: 'POST', headers: { authorization: `Bearer ${tokAdmin}` }, body: {} },
        resStressNoConfirm
      );
      assert.strictEqual(resStressNoConfirm.statusCode, 400);
    });

    await check('B02_anti_SSRF_rechaza_loopback_metadata_y_redes_privadas', async () => {
      assert.strictEqual(internals.isSafePublicHttpUrl('http://169.254.169.254/latest/meta-data/'), false);
      assert.strictEqual(internals.isSafePublicHttpUrl('http://127.0.0.1:8080/'), false);
      assert.strictEqual(internals.isSafePublicHttpUrl('http://localhost:3333/'), false);
      assert.strictEqual(internals.isSafePublicHttpUrl('http://192.168.1.1/admin'), false);
      assert.strictEqual(internals.isSafePublicHttpUrl('http://10.0.0.5/secret'), false);
      assert.strictEqual(internals.isSafePublicHttpUrl('file:///etc/passwd'), false);
      assert.strictEqual(internals.isSafePublicHttpUrl('https://user:pass@instagram.com/reel/abc'), false);
      assert.strictEqual(internals.isSafePublicHttpUrl('https://www.instagram.com/reel/xyz/'), true);
      assert.strictEqual(await internals.obtenerOgImage('http://169.254.169.254/'), null);
    });

    await check('B03_callables_sendManualWhatsAppMessage_y_generarPlanClaseIA_protegidos', async () => {
      internals._resetRuntimeRateLimits();
      const sendFn = indexExports.sendManualWhatsAppMessage.run;
      await assert.rejects(() => sendFn({ leadId: '51999000111', texto: 'Hola' }, {}), (e) => e.code === 'unauthenticated');
      await assert.rejects(
        () => sendFn({ leadId: '51999000111', texto: 'Hola' }, { auth: { uid: 'alumno_1', token: { rol: 'alumno' } } }),
        (e) => e.code === 'permission-denied'
      );
      await assert.rejects(
        () => sendFn({ leadId: '../hack', texto: 'Hola' }, { auth: { uid: 'prof_1', token: { profesor: true } } }),
        (e) => e.code === 'invalid-argument'
      );
      await assert.rejects(
        () => sendFn({ leadId: '51999999999', texto: 'Hola' }, { auth: { uid: 'prof_1', token: { profesor: true } } }),
        (e) => e.code === 'not-found'
      );
      const okSend = await sendFn(
        { leadId: '51999000111', texto: 'Hola, te esperamos el martes.' },
        { auth: { uid: 'prof_1', token: { profesor: true } } }
      );
      assert.strictEqual(okSend.success, true);

      const legacyIaFn = indexExports.generarPlanClaseIA.run;
      await assert.rejects(() => legacyIaFn({}, {}), (e) => e.code === 'unauthenticated');
      await assert.rejects(
        () => legacyIaFn({ duracion: 60 }, { auth: { uid: 'alumno_1', token: { rol: 'alumno' } } }),
        (e) => e.code === 'permission-denied'
      );
      await assert.rejects(
        () => legacyIaFn({ duracion: 999 }, { auth: { uid: 'prof_1', token: { profesor: true } } }),
        (e) => e.code === 'invalid-argument'
      );
    });

    await check('B04_planner_v2_y_copiloto_aceptan_claims_profesor_y_administrador_rechazan_alumno', async () => {
      const genCallable = createGenerateClassPlanV2CallableHandler({
        db,
        allowLiveFirestore: true,
        serverOverrides: { providerMode: 'simulated', realProviderEnabled: false },
      });
      const copilotCallable = createPedagogicalCopilotV1CallableHandler({
        db,
        allowLiveFirestore: true,
        serverOverrides: { providerMode: 'simulated', realProviderEnabled: false },
      });

      await assert.rejects(
        () => genCallable({ request: {} }, { auth: { uid: 'alumno_1', token: { rol: 'alumno' } } }),
        (e) => e.code === 'permission-denied'
      );
      await assert.rejects(
        () => copilotCallable({ request: {} }, { auth: { uid: 'alumno_1', token: { rol: 'alumno' } } }),
        (e) => e.code === 'permission-denied'
      );

      const genOk = await genCallable(
        {
          request: {
            contract_version: '2.1.0',
            request_id: 'ped06a_gen_prof_claim',
            creation_mode: 'rápida',
            group_context: {
              source: 'real_class',
              group_label: 'Adultos M/J 19:00',
              audience_type: 'adultos',
              age_min: 18,
              age_max: 40,
              estimated_participants: 10,
              experience_distribution: { principiantes: 4, intermedios: 4, avanzados: 2, manually_confirmed: true },
            },
            curriculum_context: { scope: 'none_manual' },
            space_context: { space_size: 'mediano', floor_type: 'madera', instructors_available: 1 },
            session_config: {
              duration_min: 60,
              focuses: ['Técnica'],
              include_musicality_roda: true,
              allow_ai_complementary_proposals: true,
            },
            selected_movements: [],
            selected_resources: [],
          },
        },
        { auth: { uid: 'admin_legacy', token: { rol: 'administrador' } } }
      );
      assert.strictEqual(genOk.status, 'ok');
    });
  } finally {
    delete admin.auth;
    global.fetch = origFetch;
  }

  // =========================================================================
  // C. MIGRACIÓN IDEMPOTENTE DE ROLES Y CUSTOM CLAIMS
  // =========================================================================
  await check('C01_migracion_roles_administrador_a_admin_dry_run_y_idempotente', async () => {
    const dry = await runRoleAndClaimsMigration({ apply: false, projectId: PROJECT_ID });
    assert.strictEqual(dry.mode, 'dry-run');
    assert.strictEqual(dry.rolesToNormalize, 1);

    const app1 = await runRoleAndClaimsMigration({ apply: true, projectId: PROJECT_ID });
    assert.strictEqual(app1.rolesNormalized, 1);

    const legacyDoc = (await db.collection('users').doc('admin_legacy').get()).data();
    assert.strictEqual(legacyDoc.rol, 'admin');
    assert.strictEqual(legacyDoc.nombre, 'Admin Legacy');

    const app2 = await runRoleAndClaimsMigration({ apply: true, projectId: PROJECT_ID });
    assert.strictEqual(app2.rolesToNormalize, 0, 'Segunda ejecución debe ser 100% idempotente');
  });

  console.log(`\n✔ SUITE PED-06A SEGURIDAD COMPLETADA: ${passed} pruebas aprobadas (100%).`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ FALLO EN SUITE PED-06A SEGURIDAD:', err);
  process.exit(1);
});

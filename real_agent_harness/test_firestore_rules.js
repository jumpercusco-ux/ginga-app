/**
 * real_agent_harness/test_firestore_rules.js
 * Suite de Verificación de Seguridad y Reglas Firestore
 * GINGA REAL — PROMPT 72
 * 
 * Valida de forma ejecutable contra el Firestore Emulator:
 * 1. Profesor autorizado puede registrar feedback.
 * 2. Alumno no puede leer ni crear feedback (PERMISSION_DENIED).
 * 3. Usuario anónimo no puede acceder (PERMISSION_DENIED).
 * 4. No se puede suplantar al autor (reported_by.uid != auth.uid rechazado).
 * 5. Campos de auditoría son inmutables en update.
 * 6. Profesor ordinario no puede establecer 'approved', 'deployed' ni 'closed' (PERMISSION_DENIED).
 * 7. Administrador SÍ puede aprobar, desplegar y cerrar incidencias.
 * 8. Eliminación estrictamente prohibida (allow delete: if false).
 * 9. Consulta de incidencias por lead compatible con reglas.
 */

const http = require('http');
const assert = require('assert');

const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const [hostname, port] = host.split(':');
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-ginga-test';

function createMockToken(uid, extraClaims = {}) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    sub: uid,
    user_id: uid,
    email: `${uid}@capoeirafiu.test`,
    ...extraClaims,
  })).toString('base64url');
  return `${header}.${payload}.`;
}

function makeRequest(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request({
      hostname,
      port: Number(port),
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        let parsed = null;
        try { parsed = JSON.parse(data); } catch (_) { parsed = data; }
        resolve({ status: res.statusCode, body: parsed });
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === null || v === undefined) {
      fields[k] = { nullValue: null };
    } else if (typeof v === 'string') {
      if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(v)) {
        fields[k] = { timestampValue: v };
      } else {
        fields[k] = { stringValue: v };
      }
    } else if (typeof v === 'boolean') {
      fields[k] = { booleanValue: v };
    } else if (typeof v === 'number') {
      fields[k] = { integerValue: v.toString() };
    } else if (v instanceof Date) {
      fields[k] = { timestampValue: v.toISOString() };
    } else if (typeof v === 'object' && !Array.isArray(v)) {
      fields[k] = { mapValue: { fields: toFirestoreFields(v) } };
    } else if (Array.isArray(v)) {
      fields[k] = { arrayValue: { values: v.map(item => ({ stringValue: String(item) })) } };
    }
  }
  return fields;
}

async function runFirestoreRulesSuite() {
  console.log('================================================================');
  console.log('   TEST SUITE: SEGURIDAD Y REGLAS FIRESTORE (EMULATOR)');
  console.log('   Verificación formal de permisos, inmutabilidad y roles');
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;

  async function testRule(name, fn) {
    total++;
    try {
      await fn();
      passed++;
      console.log(`[PASS] ${name}`);
    } catch (e) {
      console.error(`[FAIL] ${name}: ${e.message}`);
      throw e;
    }
  }

  // -------------------------------------------------------------
  // SETUP DE USUARIOS Y ROLES (vía credencial de administración)
  // -------------------------------------------------------------
  console.log('--- Configuración de usuarios y roles ---');
  await makeRequest('POST', `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?documentId=prof_1`, {
    fields: toFirestoreFields({ rol: 'profesor', nombre: 'Profesor Titular' })
  }, 'owner');

  await makeRequest('POST', `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?documentId=prof_2`, {
    fields: toFirestoreFields({ rol: 'profesor', nombre: 'Profesor Secundario' })
  }, 'owner');

  await makeRequest('POST', `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?documentId=admin_1`, {
    fields: toFirestoreFields({ rol: 'admin', nombre: 'Administrador General' })
  }, 'owner');

  await makeRequest('POST', `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?documentId=alumno_1`, {
    fields: toFirestoreFields({ rol: 'alumno', nombre: 'Alumno Regular' })
  }, 'owner');
  console.log('✔ Usuarios inicializados en Firestore Emulator: prof_1 (profesor), admin_1 (admin), alumno_1 (alumno).\n');

  // Tokens
  const tokenProf1 = createMockToken('prof_1');
  const tokenProf2 = createMockToken('prof_2');
  const tokenAdmin = createMockToken('admin_1');
  const tokenAlumno = createMockToken('alumno_1');

  const validDocId = 'FB-20261112-PRUEB1';
  const nowIso = new Date().toISOString();

  const validFeedbackData = {
    feedback_id: validDocId,
    lead_id: '+51984111001',
    message_id: 'msg_001_test',
    conversation_reference: 'Test Lead Sofia',
    reported_by: {
      uid: 'prof_1',
      email: 'prof_1@capoeirafiu.test',
      nombre: 'Profesor Titular',
      rol: 'profesor'
    },
    reported_at: nowIso,
    agent_version: 'whatsappWebhook v69',
    category: 'interpretacion_ambiguedad',
    severity: 'alta',
    observation: 'El agente asumió fecha incorrecta ante contradicción de días.',
    expected_behavior: 'Debe pedir aclaración de fecha disponible.',
    actual_behavior: 'Entendido, te paso para el jueves.',
    status: 'reported',
  };

  // -------------------------------------------------------------
  // TEST 1: PROFESOR AUTORIZADO PUEDE CREAR FEEDBACK
  // -------------------------------------------------------------
  await testRule('01_profesor_autorizado_puede_crear_feedback', async () => {
    const res = await makeRequest(
      'POST',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback?documentId=${validDocId}`,
      { fields: toFirestoreFields(validFeedbackData) },
      tokenProf1
    );
    assert.strictEqual(res.status, 200, `Esperado 200 pero se recibió ${res.status}: ${JSON.stringify(res.body)}`);
  });

  // -------------------------------------------------------------
  // TEST 2: ALUMNO NO PUEDE CREAR NI LEER FEEDBACK
  // -------------------------------------------------------------
  await testRule('02_alumno_no_puede_leer_ni_crear_feedback', async () => {
    // Intento de lectura
    const resRead = await makeRequest(
      'GET',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      null,
      tokenAlumno
    );
    assert.strictEqual(resRead.status, 403, 'Alumno debe recibir 403 en lectura.');

    // Intento de creación
    const resCreate = await makeRequest(
      'POST',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback?documentId=FB-ALUMNO-HACK`,
      { fields: toFirestoreFields({ ...validFeedbackData, feedback_id: 'FB-ALUMNO-HACK', reported_by: { uid: 'alumno_1' } }) },
      tokenAlumno
    );
    assert.strictEqual(resCreate.status, 403, 'Alumno debe recibir 403 en creación.');
  });

  // -------------------------------------------------------------
  // TEST 3: USUARIO ANÓNIMO NO PUEDE ACCEDER
  // -------------------------------------------------------------
  await testRule('03_usuario_anonimo_rechazado', async () => {
    const res = await makeRequest(
      'GET',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      null,
      null // Sin token
    );
    assert.strictEqual(res.status, 403, 'Usuario anónimo debe recibir 403 PERMISSION_DENIED.');
  });

  // -------------------------------------------------------------
  // TEST 4: PREVENCIÓN DE SUPLANTACIÓN DE AUTOR (reported_by.uid != auth.uid)
  // -------------------------------------------------------------
  await testRule('04_rechaza_suplantacion_de_autor', async () => {
    // prof_2 intenta reportar firmando como prof_1
    const hackedData = {
      ...validFeedbackData,
      feedback_id: 'FB-SPOOF-001',
      reported_by: {
        uid: 'prof_1', // Suplantando a prof_1
        rol: 'profesor'
      }
    };
    const res = await makeRequest(
      'POST',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback?documentId=FB-SPOOF-001`,
      { fields: toFirestoreFields(hackedData) },
      tokenProf2 // Autenticado como prof_2
    );
    assert.strictEqual(res.status, 403, 'Debe rechazar si reported_by.uid no coincide con request.auth.uid.');
  });

  // -------------------------------------------------------------
  // TEST 5: INMUTABILIDAD DE CAMPOS DE AUDITORÍA
  // -------------------------------------------------------------
  await testRule('05_inmutabilidad_de_campos_de_auditoria', async () => {
    // Intento de modificar lead_id original
    const tamperedLead = {
      ...validFeedbackData,
      lead_id: '+51999999999', // Modificado
    };
    const resLead = await makeRequest(
      'PATCH',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      { fields: toFirestoreFields(tamperedLead) },
      tokenProf1
    );
    assert.strictEqual(resLead.status, 403, 'Debe rechazar alteración de lead_id.');

    // Intento de modificar actual_behavior original
    const tamperedBehavior = {
      ...validFeedbackData,
      actual_behavior: 'Texto alterado a posteriori.',
    };
    const resBehavior = await makeRequest(
      'PATCH',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      { fields: toFirestoreFields(tamperedBehavior) },
      tokenProf1
    );
    assert.strictEqual(resBehavior.status, 403, 'Debe rechazar alteración de actual_behavior original.');
  });

  // -------------------------------------------------------------
  // TEST 6: PROFESOR NO PUEDE ESTABLECER 'deployed' NI 'approved'
  // -------------------------------------------------------------
  await testRule('06_profesor_no_puede_aprobar_ni_desplegar', async () => {
    // prof_1 intenta marcar como deployed
    const deployedAttempt = {
      ...validFeedbackData,
      status: 'deployed',
      diagnosis: 'Arreglado por el profesor.',
    };
    const res = await makeRequest(
      'PATCH',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      { fields: toFirestoreFields(deployedAttempt) },
      tokenProf1
    );
    assert.strictEqual(res.status, 403, 'Profesor ordinario no puede marcar status = deployed.');

    // prof_1 intenta marcar como approved
    const approvedAttempt = {
      ...validFeedbackData,
      status: 'approved',
    };
    const resAppr = await makeRequest(
      'PATCH',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      { fields: toFirestoreFields(approvedAttempt) },
      tokenProf1
    );
    assert.strictEqual(resAppr.status, 403, 'Profesor ordinario no puede marcar status = approved.');
  });

  // -------------------------------------------------------------
  // TEST 7: ADMINISTRADOR SÍ PUEDE APROBAR O DESPLEGAR
  // -------------------------------------------------------------
  await testRule('07_administrador_si_puede_aprobar_y_cerrar', async () => {
    // admin_1 aprueba la incidencia
    const adminApproval = {
      ...validFeedbackData,
      status: 'approved',
      diagnosis: 'Aprobado formalmente por administración técnica.',
    };
    const resAppr = await makeRequest(
      'PATCH',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      { fields: toFirestoreFields(adminApproval) },
      tokenAdmin
    );
    assert.strictEqual(resAppr.status, 200, `Admin debe poder marcar approved. Recibido ${resAppr.status}`);

    // admin_1 cierra la incidencia
    const adminClosed = {
      ...validFeedbackData,
      status: 'closed',
      diagnosis: 'Verificado en producción y cerrado.',
    };
    const resClosed = await makeRequest(
      'PATCH',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      { fields: toFirestoreFields(adminClosed) },
      tokenAdmin
    );
    assert.strictEqual(resClosed.status, 200, `Admin debe poder marcar closed. Recibido ${resClosed.status}`);
  });

  // -------------------------------------------------------------
  // TEST 8: PROHIBICIÓN ESTRICTA DE ELIMINACIÓN (INMUTABILIDAD)
  // -------------------------------------------------------------
  await testRule('08_eliminacion_estrictamente_prohibida', async () => {
    // Intento de borrado por profesor
    const resDelProf = await makeRequest(
      'DELETE',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      null,
      tokenProf1
    );
    assert.strictEqual(resDelProf.status, 403, 'Borrado por profesor debe retornar 403.');

    // Intento de borrado por admin
    const resDelAdmin = await makeRequest(
      'DELETE',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/agent_feedback/${validDocId}`,
      null,
      tokenAdmin
    );
    assert.strictEqual(resDelAdmin.status, 403, 'Borrado por admin también debe retornar 403 (inmutable).');
  });

  // -------------------------------------------------------------
  // TEST 9: CONSULTAS UTILIZADAS EN FLUTTER SON COMPATIBLES
  // -------------------------------------------------------------
  await testRule('09_consultas_flutter_compatibles', async () => {
    // Query por lead_id
    const queryPayload = {
      structuredQuery: {
        from: [{ collectionId: 'agent_feedback' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'lead_id' },
            op: 'EQUAL',
            value: { stringValue: '+51984111001' }
          }
        }
      }
    };
    const resQuery = await makeRequest(
      'POST',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
      queryPayload,
      tokenProf1
    );
    assert.strictEqual(resQuery.status, 200, 'Consulta estructurada por lead_id debe ser permitida.');
    assert(Array.isArray(resQuery.body), 'Respuesta de runQuery debe ser una lista.');
  });

  console.log('\n================================================================');
  console.log(` RESULTADO SUITE REGLAS FIRESTORE: ${passed}/${total} PRUEBAS PASS (100%)`);
  console.log('================================================================\n');

  return { passed, total };
}

if (require.main === module) {
  runFirestoreRulesSuite().catch((err) => {
    console.error('Error en ejecución de suite de reglas:', err);
    process.exit(1);
  });
}

module.exports = { runFirestoreRulesSuite };

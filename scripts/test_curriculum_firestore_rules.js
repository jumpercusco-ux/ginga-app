#!/usr/bin/env node
'use strict';

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

function makeRequest(method, reqPath, body, token) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request({
      hostname,
      port: Number(port),
      path: reqPath,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
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

function toFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === null || v === undefined) fields[k] = { nullValue: null };
    else if (typeof v === 'string') fields[k] = { stringValue: v };
    else if (typeof v === 'boolean') fields[k] = { booleanValue: v };
    else if (typeof v === 'number') fields[k] = { integerValue: String(v) };
    else if (Array.isArray(v)) fields[k] = { arrayValue: { values: v.map((i) => ({ stringValue: String(i) })) } };
    else if (typeof v === 'object') fields[k] = { mapValue: { fields: toFields(v) } };
  }
  return fields;
}

async function runCurriculumRulesSuite() {
  console.log('================================================================');
  console.log('   TEST SUITE: REGLAS FIRESTORE CURRICULARES (EMULATOR)');
  console.log('================================================================\n');

  const base = `/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

  await makeRequest('PATCH', `${base}/users/curr_admin_1`, {
    fields: toFields({ rol: 'admin', nombre: 'Admin Curricular' }),
  }, 'owner');
  await makeRequest('PATCH', `${base}/users/curr_prof_1`, {
    fields: toFields({ rol: 'profesor', nombre: 'Profesor FIU' }),
  }, 'owner');
  await makeRequest('PATCH', `${base}/users/curr_alumno_1`, {
    fields: toFields({ rol: 'alumno', nombre: 'Alumno FIU' }),
  }, 'owner');
  await makeRequest('PATCH', `${base}/users/curr_spoof_admin`, {
    fields: toFields({ rol: 'admin', nombre: 'Usuario con rol autoasignado' }),
  }, 'owner');

  const tokenAdmin = createMockToken('curr_admin_1', { admin: true });
  const tokenProf = createMockToken('curr_prof_1');
  const tokenAlumno = createMockToken('curr_alumno_1');
  const tokenSpoofAdmin = createMockToken('curr_spoof_admin');

  let passed = 0;
  let total = 0;
  async function testRule(name, fn) {
    total++;
    await fn();
    passed++;
    console.log(`[PASS] ${name}`);
  }

  const validMovement = {
    movement_id: 'bencao',
    canonical_name: 'Benção',
    category_id: 'golpe_de_ataque',
    review_status: 'approved',
    is_ambiguous: false,
    ai_planner_eligible: true,
  };

  await testRule('01_admin_puede_escribir_curriculum_movements_y_cordas', async () => {
    const resMov = await makeRequest(
      'PATCH',
      `${base}/curriculum_movements/bencao`,
      { fields: toFields(validMovement) },
      tokenAdmin
    );
    assert.strictEqual(resMov.status, 200, `Admin debe escribir movement (200), recibido ${resMov.status}`);

    const resCorda = await makeRequest(
      'PATCH',
      `${base}/curriculum_cordas/adulto_corda_01`,
      {
        fields: toFields({
          corda_id: 'adulto_corda_01',
          track_id: 'adulto',
          index: 1,
          nombre_manual: 'Corda Crua',
        }),
      },
      tokenAdmin
    );
    assert.strictEqual(resCorda.status, 200, `Admin debe escribir corda (200), recibido ${resCorda.status}`);
  });

  await testRule('02_alumno_y_profesor_pueden_leer_colecciones_curriculares', async () => {
    const rAlumno = await makeRequest('GET', `${base}/curriculum_movements/bencao`, null, tokenAlumno);
    assert.strictEqual(rAlumno.status, 200);
    const rProf = await makeRequest('GET', `${base}/curriculum_cordas/adulto_corda_01`, null, tokenProf);
    assert.strictEqual(rProf.status, 200);
  });

  await testRule('03_usuario_anonimo_rechazado_en_lectura_curricular', async () => {
    const rAnon = await makeRequest('GET', `${base}/curriculum_movements/bencao`, null, null);
    assert.strictEqual(rAnon.status, 403);
  });

  await testRule('04_alumno_y_profesor_rechazados_en_escritura_curricular', async () => {
    const rAlumnoWrite = await makeRequest(
      'PATCH',
      `${base}/curriculum_movements/bencao`,
      { fields: toFields(validMovement) },
      tokenAlumno
    );
    assert.strictEqual(rAlumnoWrite.status, 403);

    const rProfWrite = await makeRequest(
      'PATCH',
      `${base}/curriculum_movements/bencao`,
      { fields: toFields(validMovement) },
      tokenProf
    );
    assert.strictEqual(rProfWrite.status, 403, 'Solo admin debe poder escribir currículo');
  });

  await testRule('05_borrado_curricular_bloqueado_incluso_para_admin', async () => {
    const rDel = await makeRequest('DELETE', `${base}/curriculum_movements/bencao`, null, tokenAdmin);
    assert.strictEqual(rDel.status, 403);
  });

  await testRule('06_permisos_existentes_de_tutoriales_permanecen_intactos', async () => {
    // Profesor puede escribir en /tutoriales (comportamiento existente preservado)
    const rProfCreate = await makeRequest(
      'PATCH',
      `${base}/tutoriales/tut_perm_test`,
      { fields: toFields({ titulo: 'Ginga', corda: '' }) },
      tokenProf
    );
    assert.strictEqual(rProfCreate.status, 200);

    // Alumno puede leer /tutoriales pero NO escribir
    const rAlumnoRead = await makeRequest('GET', `${base}/tutoriales/tut_perm_test`, null, tokenAlumno);
    assert.strictEqual(rAlumnoRead.status, 200);

    const rAlumnoWrite = await makeRequest(
      'PATCH',
      `${base}/tutoriales/tut_perm_test`,
      { fields: toFields({ titulo: 'Hack' }) },
      tokenAlumno
    );
    assert.strictEqual(rAlumnoWrite.status, 403);
  });

  await testRule('07_auto_elevacion_en_users_rol_admin_sin_claim_es_rechazada', async () => {
    const rSpoofWrite = await makeRequest(
      'PATCH',
      `${base}/curriculum_movements/bencao`,
      { fields: toFields(validMovement) },
      tokenSpoofAdmin
    );
    assert.strictEqual(
      rSpoofWrite.status,
      403,
      'Usuario con users/{uid}.rol=admin pero sin custom claim firmado debe ser rechazado (403).'
    );
  });

  console.log(`\nRESULTADO REGLAS CURRICULARES: ${passed}/${total} PRUEBAS PASS (100%)\n`);
}

if (require.main === module) {
  runCurriculumRulesSuite().catch((err) => {
    console.error('FAIL en reglas curriculares:', err);
    process.exit(1);
  });
}

module.exports = { runCurriculumRulesSuite };

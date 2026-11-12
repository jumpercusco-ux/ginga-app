/**
 * scripts/smoke_test_feedback_v1.js
 * GINGA REAL — PROMPT 76
 * Smoke test controlado post-despliegue de Feedback V1 en Firestore productivo.
 */

const https = require('https');
const { execSync } = require('child_process');
const assert = require('assert');

const projectId = 'capoeirafiu-ea8ljo';
const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();

function firestoreRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path,
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        let parsed = null;
        try { parsed = JSON.parse(data); } catch (_) { parsed = data; }
        resolve({ status: res.statusCode, data: parsed });
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

function fromFirestoreFields(fields = {}) {
  const res = {};
  for (const [k, v] of Object.entries(fields)) {
    if ('stringValue' in v) res[k] = v.stringValue;
    else if ('timestampValue' in v) res[k] = v.timestampValue;
    else if ('integerValue' in v) res[k] = parseInt(v.integerValue, 10);
    else if ('booleanValue' in v) res[k] = v.booleanValue;
    else if ('mapValue' in v) res[k] = fromFirestoreFields(v.mapValue.fields);
    else if ('nullValue' in v) res[k] = null;
    else res[k] = v;
  }
  return res;
}

async function runSmokeTest() {
  console.log('================================================================');
  console.log('   GINGA REAL — PROMPT 76: SMOKE TEST CONTROLADO FEEDBACK V1');
  console.log('   Proyecto: capoeirafiu-ea8ljo');
  console.log('================================================================\n');

  const leadId = '51900075008';
  const messageId = '5USjRNbgQyb5C7eOEw9R';
  const instructorUid = 'JGqDCSsPDBae4VLmtke9hKIYufh1';
  const reservaId = '6DDDPoEp87hB9tz1M2AH';

  // 1. Snapshot previo de integridad
  console.log('1. Verificando estado PREVIO de lead y reserva TEST...');
  const leadResPre = await firestoreRequest('GET', `/v1/projects/${projectId}/databases/(default)/documents/whatsapp_leads/${leadId}`);
  assert.strictEqual(leadResPre.status, 200, 'Lead TEST debe existir');
  const leadUpdateTimePre = leadResPre.data.updateTime;
  const leadFieldsPre = fromFirestoreFields(leadResPre.data.fields);
  console.log(`   ✓ Lead TEST 51900075008 encontrado: nombre="${leadFieldsPre.nombre}", status="${leadFieldsPre.status}"`);
  console.log(`   ✓ Lead updateTime previo: ${leadUpdateTimePre}`);

  const msgResPre = await firestoreRequest('GET', `/v1/projects/${projectId}/databases/(default)/documents/whatsapp_leads/${leadId}/mensajes/${messageId}`);
  assert.strictEqual(msgResPre.status, 200, 'Mensaje AI TEST debe existir');
  const msgUpdateTimePre = msgResPre.data.updateTime;
  console.log(`   ✓ Mensaje AI ${messageId} verificado, updateTime previo: ${msgUpdateTimePre}`);

  const resResPre = await firestoreRequest('GET', `/v1/projects/${projectId}/databases/(default)/documents/reservas/${reservaId}`);
  assert.strictEqual(resResPre.status, 200, 'Reserva TEST debe existir');
  const resUpdateTimePre = resResPre.data.updateTime;
  console.log(`   ✓ Reserva TEST ${reservaId} verificada, updateTime previo: ${resUpdateTimePre}\n`);

  // 2. Generar feedback ID determinista y trazable
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const feedbackId = `FB-${yyyy}${mm}${dd}-SMK01`;

  console.log(`2. Creando documento de incidencia en agent_feedback (${feedbackId})...`);
  const feedbackPayload = {
    feedback_id: feedbackId,
    lead_id: leadId,
    message_id: messageId,
    conversation_reference: 'Conversación TEST Javier / Jumper AI Lab',
    reported_by: {
      uid: instructorUid,
      nombre: 'Enrique P',
      email: 'jumpercusco@gmail.com',
      rol: 'profesor'
    },
    reported_at: d.toISOString(),
    agent_version: 'whatsappWebhook v69',
    category: 'reserva_reprogramacion',
    severity: 'baja',
    observation: '[SMOKE TEST PROMPT 76] Verificación controlada de creación de feedback post-despliegue.',
    expected_behavior: 'El sistema debe registrar la incidencia sin mutar datos de la conversación ni de la reserva.',
    actual_behavior: '¡Genial! He reservado la clase de prueba para Javier el martes 17 de noviembre de 2026 de 6:00 a 7:00 p.m...',
    status: 'reported'
  };

  const createRes = await firestoreRequest(
    'PATCH',
    `/v1/projects/${projectId}/databases/(default)/documents/agent_feedback/${feedbackId}`,
    { fields: toFirestoreFields(feedbackPayload) }
  );

  assert.strictEqual(createRes.status, 200, `Creación de feedback debe retornar 200, recibido: ${createRes.status}`);
  console.log(`   ✓ Documento creado exitosamente en agent_feedback/${feedbackId}`);
  console.log(`   ✓ createTime: ${createRes.data.createTime}\n`);

  // 3. Verificación de lectura y esquema
  console.log('3. Verificando lectura y esquema del documento agent_feedback...');
  const getFeedbackRes = await firestoreRequest('GET', `/v1/projects/${projectId}/databases/(default)/documents/agent_feedback/${feedbackId}`);
  assert.strictEqual(getFeedbackRes.status, 200, 'Debe poder leer el documento creado');
  const readFields = fromFirestoreFields(getFeedbackRes.data.fields);

  assert.strictEqual(readFields.feedback_id, feedbackId, 'feedback_id coincide');
  assert.strictEqual(readFields.lead_id, leadId, 'lead_id coincide');
  assert.strictEqual(readFields.message_id, messageId, 'message_id coincide');
  assert.strictEqual(readFields.reported_by.uid, instructorUid, 'reported_by.uid coincide');
  assert.strictEqual(readFields.status, 'reported', 'status es reported');
  assert.strictEqual(readFields.category, 'reserva_reprogramacion', 'category coincide');
  assert.strictEqual(readFields.severity, 'baja', 'severity coincide');
  assert(readFields.reported_at, 'reported_at tiene timestamp válido');
  console.log(`   ✓ ID verificado: ${readFields.feedback_id}`);
  console.log(`   ✓ Lead ID verificado: ${readFields.lead_id}`);
  console.log(`   ✓ Message ID verificado: ${readFields.message_id}`);
  console.log(`   ✓ Instructor UID verificado: ${readFields.reported_by.uid} (${readFields.reported_by.nombre})`);
  console.log(`   ✓ Status verificado: ${readFields.status}`);
  console.log(`   ✓ Timestamp verificado: ${readFields.reported_at}\n`);

  // 4. Verificación de query con índices compuestos
  console.log('4. Verificando consultas con índices compuestos recién desplegados...');
  const queryBody = {
    structuredQuery: {
      from: [{ collectionId: 'agent_feedback' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'lead_id' },
          op: 'EQUAL',
          value: { stringValue: leadId }
        }
      },
      orderBy: [{
        field: { fieldPath: 'reported_at' },
        direction: 'DESCENDING'
      }],
      limit: 10
    }
  };

  const queryRes = await firestoreRequest('POST', `/v1/projects/${projectId}/databases/(default)/documents:runQuery`, queryBody);
  assert.strictEqual(queryRes.status, 200, `Query indexada debe responder 200, recibido: ${queryRes.status}`);
  const foundDocs = (queryRes.data || []).filter(item => item.document);
  console.log(`   ✓ Consulta por lead_id + reported_at DESC ejecutada exitosamente con índice compuesto.`);
  console.log(`   ✓ Documentos encontrados en la consulta: ${foundDocs.length}\n`);

  // 5. Verificación de NO MUTACIÓN de conversación ni reservas
  console.log('5. Verificando integridad y NO MUTACIÓN de la conversación y reserva TEST...');
  const leadResPost = await firestoreRequest('GET', `/v1/projects/${projectId}/databases/(default)/documents/whatsapp_leads/${leadId}`);
  assert.strictEqual(leadResPost.status, 200);
  const leadUpdateTimePost = leadResPost.data.updateTime;
  assert.strictEqual(leadUpdateTimePost, leadUpdateTimePre, 'El lead NO debe haber sido alterado');
  console.log(`   ✓ whatsapp_leads/${leadId} updateTime INTACTO: ${leadUpdateTimePost}`);

  const msgResPost = await firestoreRequest('GET', `/v1/projects/${projectId}/databases/(default)/documents/whatsapp_leads/${leadId}/mensajes/${messageId}`);
  assert.strictEqual(msgResPost.status, 200);
  const msgUpdateTimePost = msgResPost.data.updateTime;
  assert.strictEqual(msgUpdateTimePost, msgUpdateTimePre, 'El mensaje NO debe haber sido alterado');
  console.log(`   ✓ mensaje/${messageId} updateTime INTACTO: ${msgUpdateTimePost}`);

  const resResPost = await firestoreRequest('GET', `/v1/projects/${projectId}/databases/(default)/documents/reservas/${reservaId}`);
  assert.strictEqual(resResPost.status, 200);
  const resUpdateTimePost = resResPost.data.updateTime;
  assert.strictEqual(resUpdateTimePost, resUpdateTimePre, 'La reserva NO debe haber sido alterada');
  console.log(`   ✓ reservas/${reservaId} updateTime INTACTO: ${resUpdateTimePost}\n`);

  console.log('================================================================');
  console.log('   SMOKE TEST COMPLETADO CON ÉXITO (PASS)');
  console.log(`   Incidencia creada: ${feedbackId}`);
  console.log('================================================================');
}

runSmokeTest().catch(err => {
  console.error('ERROR EN SMOKE TEST:', err);
  process.exit(1);
});


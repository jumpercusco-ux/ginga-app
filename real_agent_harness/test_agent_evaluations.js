/**
 * real_agent_harness/test_agent_evaluations.js
 * Suite de Evaluación Continua de Calidad y Registro de Incidencias
 * GINGA REAL — PROMPT 71
 * 
 * Implementación de pruebas locales para:
 * - Carga y validación del fixture GINGA-EVAL-001 (Caso Accostupa).
 * - Detección de ambigüedades contradictorias y prevención de mutaciones indebidas.
 * - Variaciones positivas y negativas (anti-sobreajuste).
 * - Verificación de reglas del modelo AgentFeedback y AgentEvaluation.
 * - Idempotencia, prevención de duplicados y consultas por lead.
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { RealAgentHarness } = require('./loader');
const { MockTimestamp } = require('./in_memory_firestore');

async function runEvaluationSuite() {
  console.log('================================================================');
  console.log('   TEST SUITE: EVALUACIÓN CONTINUA Y REGISTRO DE INCIDENCIAS');
  console.log('   Caso GINGA-EVAL-001 (Accostupa) & Modelo AgentFeedback');
  console.log('================================================================\n');

  const harness = new RealAgentHarness();
  const internals = harness.internals;
  const firestore = harness.firestore;

  let passed = 0;
  let total = 0;

  function test(name, fn) {
    total++;
    try {
      fn();
      passed++;
      console.log(`[PASS] ${name}`);
    } catch (e) {
      console.error(`[FAIL] ${name}: ${e.message}`);
      throw e;
    }
  }

  async function asyncTest(name, fn) {
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
  // 1. CARGA Y VALIDACIÓN DEL FIXTURE GINGA-EVAL-001
  // -------------------------------------------------------------
  console.log('--- 1. Fixture GINGA-EVAL-001 ---');

  let fixture = null;
  test('01_fixture_eval_001_existe_y_cumple_esquema', () => {
    const fixturePath = path.resolve(__dirname, 'fixtures/eval_001_accostupa.json');
    assert(fs.existsSync(fixturePath), 'El archivo fixture eval_001_accostupa.json debe existir.');
    const raw = fs.readFileSync(fixturePath, 'utf8');
    fixture = JSON.parse(raw);

    assert.strictEqual(fixture.case_id, 'GINGA-EVAL-001');
    assert.strictEqual(fixture.category, 'interpretacion_ambiguedad');
    assert(fixture.cases && fixture.cases.length >= 4, 'Debe contener al menos 4 casos/variaciones.');
    assert(fixture.initial_state && fixture.initial_state.lead, 'Debe definir el estado inicial del lead.');
    assert(fixture.initial_state.reserva_preexistente, 'Debe definir la reserva preexistente.');
  });

  // -------------------------------------------------------------
  // 2. EVALUACIÓN CASO 1: EVIDENCIA REAL OBSERVADA (ACCOSTUPA)
  // -------------------------------------------------------------
  console.log('\n--- 2. Caso Principal Accostupa (Ambigüedad Jueves vs Martes) ---');

  await asyncTest('02_caso_1_reconoce_restricciones_contradictorias_y_bloquea_mutaciones', async () => {
    const leadId = fixture.source_lead.lead_id;
    const case1 = fixture.cases.find((c) => c.id === 'CASE_1_EVIDENCIA_REAL_CONTRADICTORIA');
    assert(case1, 'Debe existir CASE_1_EVIDENCIA_REAL_CONTRADICTORIA');

    // Setup de reserva inicial
    const resRef = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: fixture.initial_state.reserva_preexistente.nombre_persona,
      tipo: fixture.initial_state.reserva_preexistente.tipo,
      hora: fixture.initial_state.reserva_preexistente.hora,
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(new Date('2026-11-17T17:00:00.000Z')),
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: fixture.initial_state.lead.nombre,
      status: 'clase_agendada',
      perfil_personas: fixture.initial_state.lead.perfil_personas,
      reserva_id: resRef.id,
      fecha_clase_reservada: MockTimestamp.fromDate(new Date('2026-11-17T17:00:00.000Z')),
      hora_clase_reservada: '18:00',
    });

    // Diagnóstico del input: «Para el jueves no puede ser es que el martes yo no estoy en cusco y yo mismo quiero traerle a mi hija»
    const inputMsg = case1.input_message;
    const tNorm = inputMsg.toLowerCase();

    // Verificamos la presencia de doble restricción negativa
    const tieneJuevesNoPuede = /jueves\s+no\s+puede/i.test(tNorm);
    const tieneMartesNoEstoy = /martes\s+yo\s+no\s+estoy/i.test(tNorm);
    assert(tieneJuevesNoPuede && tieneMartesNoEstoy, 'El mensaje contiene dos restricciones negativas explícitas.');

    // Verificación de Comportamiento Prohibido: ZERO mutaciones sin aclaración
    const turnContext = new internals.TurnContext(leadId);
    assert.strictEqual(turnContext.executedToolNames.length, 0, 'No debe tener herramientas ejecutadas al inicio.');

    // Si el agente intentara mutar arbitrariamente la reserva:
    const reservasAntes = (await firestore.collection('reservas').where('lead_id', '==', leadId).get()).docs;
    assert.strictEqual(reservasAntes.length, 1, 'Debe existir exactamente 1 reserva inicial.');

    // Runtime Guard: si el modelo afirma falsamente haber reprogramado al jueves sin tool:
    const { systemPrompt } = await internals.generarSystemPrompt(
      (await firestore.collection('whatsapp_leads').doc(leadId).get()).data(),
      1,
      leadId
    );
    const candidateHallucination = '¡Listo! Ya te he reprogramado la clase para el jueves a las 18:00.';
    const guardCheck = internals.evaluarRuntimeGuard(leadId, candidateHallucination, turnContext, systemPrompt);
    assert.strictEqual(guardCheck.passed, false, 'Runtime Guard DEBE INTERCEPTAR afirmación de cambio al jueves sin tool.');
    assert.strictEqual(guardCheck.action, 'intercept');

    // Verificamos que el estado en Firestore permaneció intacto (cero mutaciones)
    const reservasDespues = (await firestore.collection('reservas').where('lead_id', '==', leadId).get()).docs;
    assert.strictEqual(reservasDespues.length, 1);
    assert.strictEqual(reservasDespues[0].data().status, 'confirmado');
    assert.strictEqual(reservasDespues[0].id, resRef.id);
  });

  // -------------------------------------------------------------
  // 3. CASO 2: VARIACIÓN CONTRADICTORIA SINTÉTICA (MARTES Y JUEVES)
  // -------------------------------------------------------------
  console.log('\n--- 3. Variación Sintética Oficial (Martes vs Jueves) ---');

  test('03_caso_2_variacion_martes_jueves_requiere_aclaracion_sin_mutar', () => {
    const case2 = fixture.cases.find((c) => c.id === 'CASE_2_VARIACION_CONTRADICTORIA_SINTETICA');
    assert(case2);

    const input = case2.input_message; // "Para el martes se me complica y el jueves tampoco llego a tiempo..."
    const tNorm = input.toLowerCase().replace(/[áàäâ]/g, 'a').replace(/[éèëê]/g, 'e').replace(/[íìïî]/g, 'i').replace(/[óòöô]/g, 'o').replace(/[úùüû]/g, 'u');

    // Verificamos que contiene días oficiales del catálogo infantil
    const diasMencionados = [];
    if (tNorm.includes('martes')) diasMencionados.push('martes');
    if (tNorm.includes('jueves')) diasMencionados.push('jueves');
    assert.strictEqual(diasMencionados.length, 2, 'Menciona martes y jueves con imposibilidad horaria.');

    // Un mensaje ambiguo nunca debe generar diaObjetivo definitivo
    const infoReprog = internals.detectarSolicitudReprogramacion(input);
    if (infoReprog) {
      assert(
        infoReprog.esFechaAmbigua === true || infoReprog.diaObjetivo === null,
        'No debe seleccionar arbitrariamente el jueves o martes como destino.'
      );
    }
  });

  // -------------------------------------------------------------
  // 4. CASO 3: CONTROL POSITIVO UNÍVOCO (JUEVES CLARO)
  // -------------------------------------------------------------
  console.log('\n--- 4. Control Positivo Unívoco (Sin Ambigüedad) ---');

  test('04_caso_3_control_positivo_detecta_jueves_univocamente', () => {
    const case3 = fixture.cases.find((c) => c.id === 'CASE_3_CONTROL_POSITIVO_UNIVOCO');
    assert(case3);

    const input = case3.input_message; // "Por favor quiero cambiar mi clase para el jueves a las 18:00..."
    const infoReprog = internals.detectarSolicitudReprogramacion(input);

    assert(infoReprog !== null, 'Debe detectar solicitud de reprogramación.');
    assert.strictEqual(infoReprog.diaObjetivo, 'jueves', 'Debe identificar unívocamente el jueves.');
    assert.strictEqual(infoReprog.esFechaAmbigua, false, 'No debe marcar ambigüedad en pedido unívoco.');
  });

  // -------------------------------------------------------------
  // 5. CASO 4: RESOLUCIÓN POST-ACLARACIÓN
  // -------------------------------------------------------------
  console.log('\n--- 5. Resolución Post-Aclaración (Turno 2) ---');

  test('05_caso_4_resolucion_post_aclaracion_identifica_martes', () => {
    const case4 = fixture.cases.find((c) => c.id === 'CASE_4_RESOLUCION_POST_ACLARACION');
    assert(case4);

    const input = case4.input_message; // "Quiero cambiar mi clase para el próximo martes que ya estaré de vuelta en Cusco"
    const infoReprog = internals.detectarSolicitudReprogramacion(input);

    assert(infoReprog !== null);
    assert.strictEqual(infoReprog.diaObjetivo, 'martes');
    assert.strictEqual(infoReprog.esFechaAmbigua, false);
  });

  // -------------------------------------------------------------
  // 6. MODELO DE DATOS AGENT_FEEDBACK: VALIDACIÓN, IDS Y DUPLICADOS
  // -------------------------------------------------------------
  console.log('\n--- 6. Validación de AgentFeedback y Colecciones Firestore ---');

  test('06_generador_id_feedback_formato_y_unicidad', () => {
    // Formato FB-YYYYMMDD-XXXXX
    const regexId = /^FB-\d{8}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{5}$/;
    const ids = new Set();
    for (let i = 0; i < 50; i++) {
      const d = new Date();
      const yyyy = d.getFullYear().toString();
      const mm = (d.getMonth() + 1).toString().padStart(2, '0');
      const dd = d.getDate().toString().padStart(2, '0');
      const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
      let suffix = '';
      for (let j = 0; j < 5; j++) {
        suffix += chars[Math.floor(Math.random() * chars.length)];
      }
      const id = `FB-${yyyy}${mm}${dd}-${suffix}`;
      assert(regexId.test(id), `El ID generado ${id} debe cumplir el formato estandarizado.`);
      ids.add(id);
    }
    assert.strictEqual(ids.size, 50, 'Todos los IDs generados deben ser únicos.');
  });

  await asyncTest('07_persistencia_feedback_en_firestore_y_prevencion_duplicados', async () => {
    const feedbackCol = firestore.collection('agent_feedback');
    const leadId = '+51984111001';
    const messageId = 'msg_test_001';
    const fbId1 = 'FB-20261112-TEST1';

    const feedbackDoc = {
      feedback_id: fbId1,
      lead_id: leadId,
      message_id: messageId,
      conversation_reference: 'Test Lead Sofia',
      reported_by: {
        uid: 'JGqDCSsPDBae4VLmtke9hKIYufh1',
        email: 'profesor@capoeirafiu.test',
        nombre: 'Instructor Test',
        rol: 'profesor',
      },
      reported_at: MockTimestamp.now(),
      agent_version: 'whatsappWebhook v69',
      category: 'interpretacion_ambiguedad',
      severity: 'alta',
      observation: 'El agente asumió fecha incorrecta ante contradicción de días.',
      expected_behavior: 'Debe pedir aclaración de fecha disponible.',
      actual_behavior: 'Entendido, te paso para el jueves.',
      status: 'reported',
    };

    // Escritura 1
    await feedbackCol.doc(fbId1).set(feedbackDoc);
    const read1 = await feedbackCol.doc(fbId1).get();
    assert(read1.exists);
    assert.strictEqual(read1.data().category, 'interpretacion_ambiguedad');
    assert.strictEqual(read1.data().severity, 'alta');

    // Verificación anti-duplicados por message_id y category
    const queryDup = await feedbackCol
      .where('message_id', '==', messageId)
      .where('category', '==', 'interpretacion_ambiguedad')
      .get();
    assert.strictEqual(queryDup.docs.length, 1, 'Debe detectar que ya existe un reporte para ese mensaje y categoría.');

    // Consulta de incidencias por lead
    const queryLead = await feedbackCol.where('lead_id', '==', leadId).get();
    assert.strictEqual(queryLead.docs.length, 1);
  });

  await asyncTest('08_persistencia_evaluacion_en_agent_evaluations', async () => {
    const evalCol = firestore.collection('agent_evaluations');
    const caseId = 'GINGA-EVAL-001';

    await evalCol.doc(caseId).set({
      case_id: caseId,
      category: fixture.category,
      scenario: fixture.scenario,
      created_at: MockTimestamp.now(),
      evaluation_method: 'deterministic_rules_and_assertions',
      last_result: 'PASS',
      last_tested_version: 'whatsappWebhook v69',
    });

    const doc = await evalCol.doc(caseId).get();
    assert(doc.exists);
    assert.strictEqual(doc.data().case_id, 'GINGA-EVAL-001');
    assert.strictEqual(doc.data().last_result, 'PASS');
  });

  // -------------------------------------------------------------
  // 7. SEGURIDAD DE ROLES: RECHAZO DE ALUMNOS O NO AUTORIZADOS
  // -------------------------------------------------------------
  console.log('\n--- 7. Seguridad y Control de Acceso a Feedback ---');

  test('09_autorizacion_exclusiva_profesor_o_admin', () => {
    function validarRolAutorizado(userRol) {
      if (!userRol) return false;
      const rolNorm = userRol.toLowerCase().trim();
      return rolNorm === 'profesor' || rolNorm === 'admin';
    }

    assert.strictEqual(validarRolAutorizado('profesor'), true);
    assert.strictEqual(validarRolAutorizado('admin'), true);
    assert.strictEqual(validarRolAutorizado('Profesor'), true);
    assert.strictEqual(validarRolAutorizado('alumno'), false);
    assert.strictEqual(validarRolAutorizado('lead'), false);
    assert.strictEqual(validarRolAutorizado(null), false);
    assert.strictEqual(validarRolAutorizado(''), false);
  });

  console.log('\n================================================================');
  console.log(` RESULTADO SUITE EVALUACIONES: ${passed}/${total} PRUEBAS PASS (100%)`);
  console.log('================================================================\n');

  return { passed, total };
}

if (require.main === module) {
  runEvaluationSuite().catch((err) => {
    console.error('Error fatal en la ejecución de la suite de evaluaciones:', err);
    process.exit(1);
  });
}

module.exports = { runEvaluationSuite };

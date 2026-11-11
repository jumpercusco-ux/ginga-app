/**
 * real_agent_harness/test_qa_regressions.js
 * Suite de Regresiones Específicas para los Casos 2, 9 y 11 del QA Conversacional.
 * Ejecución 100% offline y determinista con el backend real en memoria.
 */

const assert = require('assert');
const { RealAgentHarness } = require('./loader');
const { MockTimestamp } = require('./in_memory_firestore');

async function runRegressionSuite() {
  console.log('================================================================');
  console.log('   TEST SUITE: REGRESIONES QA CONVERSACIONAL (CASOS 2, 4, 9 Y 11)');
  console.log('   Validación determinista y offline sobre backend real');
  console.log('================================================================\n');

  const harness = new RealAgentHarness();
  const internals = harness.internals;
  const firestore = harness.firestore;
  const {
    evaluarRuntimeGuard,
    detectarSolicitudExplicitaAtencionHumana,
    detectarSolicitudCancelacion,
    preguntarIA,
    generarSystemPrompt,
    TurnContext,
  } = internals;

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
  // REGRESIÓN CASO 2: RECORDATORIO DE RESERVA VIGENTE
  // -------------------------------------------------------------
  console.log('--- CASO 2: Recordatorio de Reserva Vigente vs. Falsa Mutación ---');

  const systemPromptConReservaDaniela = `Eres el instructor de Capoeira.
[RESERVAS CONFIRMADAS VIGENTES DE ESTE LEAD]:
Este lead YA TIENE una clase de prueba confirmada en el sistema. NO es un lead nuevo:
- Asistente: Daniela Perez | Nivel: Clase regular | Fecha: sábado 14 de noviembre a las 18:00 (ID de reserva: res_daniela_123).
REGLAS OBLIGATORIAS:
3. Si la persona consulta sobre su cita, reconoce su reserva con calidez.`;

  test('01_caso2_reconoce_primer_nombre_y_fecha_valida', () => {
    // Respuesta típica que causó el falso positivo (usaba primer nombre "Daniela" y fecha "sábado 14")
    const candidateText = '¡Hola, Daniela! Tu clase de prueba está confirmada para el sábado 14 de noviembre a las 18:00 hrs en Calle Hospital 840, segundo piso.';
    const turnContext = new TurnContext('+51984111002');
    const evaluation = evaluarRuntimeGuard('+51984111002', candidateText, turnContext, systemPromptConReservaDaniela);

    assert.strictEqual(evaluation.passed, true, 'Debe permitir el recordatorio legítimo de Daniela.');
    assert.strictEqual(evaluation.action, 'allow');
    assert.strictEqual(evaluation.intercepted_claims.length, 0);
  });

  test('02_caso2_intercepta_si_afirma_fecha_discrepante', () => {
    // Si Daniela tiene reserva para sábado 14, pero el modelo afirma jueves 12: DEBE INTERCEPTAR
    const candidateText = '¡Hola, Daniela! Tu clase de prueba está confirmada para el jueves 12 de noviembre a las 18:00 hrs.';
    const turnContext = new TurnContext('+51984111002');
    const evaluation = evaluarRuntimeGuard('+51984111002', candidateText, turnContext, systemPromptConReservaDaniela);

    assert.strictEqual(evaluation.passed, false, 'Debe interceptar si la fecha afirmada contradice la confirmada.');
    assert.strictEqual(evaluation.action, 'intercept');
    assert(evaluation.intercepted_claims.includes('booking'), 'Debe incluir reclamo de booking no respaldado.');
  });

  test('03_caso2_anti_regresion_lead_sin_reservas_sigue_protegido', () => {
    // Si el lead NO tiene reservas previas y el modelo afirma confirmación sin tool: DEBE INTERCEPTAR
    const systemPromptSinReservas = 'Eres el instructor de Capoeira.';
    const candidateText = '¡Hola, Camila! Tu clase de prueba está confirmada para el jueves 12 de noviembre.';
    const turnContext = new TurnContext('+51984111001');
    const evaluation = evaluarRuntimeGuard('+51984111001', candidateText, turnContext, systemPromptSinReservas);

    assert.strictEqual(evaluation.passed, false, 'Lead sin reserva no puede recibir confirmación sin tool.');
    assert.strictEqual(evaluation.action, 'intercept');
  });

  test('04_caso2_intercepta_si_afirma_nueva_accion_sin_tool', () => {
    // Si tiene reserva pero el modelo afirma que ACABA de crear una NUEVA en este turno sin tool
    const candidateText = '¡Listo Daniela! Te acabo de agendar una nueva clase de prueba para el sábado 14.';
    const turnContext = new TurnContext('+51984111002');
    const evaluation = evaluarRuntimeGuard('+51984111002', candidateText, turnContext, systemPromptConReservaDaniela);

    assert.strictEqual(evaluation.passed, false, 'No debe permitir afirmar nueva acción sin tool.');
  });

  // -------------------------------------------------------------
  // REGRESIÓN CASO 9: SOLICITUD DE CANCELACIÓN
  // -------------------------------------------------------------
  console.log('\n--- CASO 9: Detección y Derivación de Cancelación ---');

  test('05_caso9_detector_cancelacion_positivos', () => {
    assert(detectarSolicitudCancelacion('Hola, no voy a poder ir a mi clase reservada de mañana. Por favor cancelen mi cupo.'));
    assert(detectarSolicitudCancelacion('quiero cancelar mi reserva'));
    assert(detectarSolicitudCancelacion('por favor cancelen mi clase'));
    assert(detectarSolicitudCancelacion('no voy a poder asistir, anulen mi cupo por favor'));
  });

  test('06_caso9_detector_cancelacion_no_confunde_con_reprogramacion', () => {
    // Si el usuario pide reprogramar a otra fecha, NO es cancelación definitiva
    assert.strictEqual(detectarSolicitudCancelacion('No puedo ir hoy, reprograma mi clase para el jueves'), false);
    assert.strictEqual(detectarSolicitudCancelacion('Tuve un inconveniente, cambien mi reserva para el martes'), false);
  });

  await asyncTest('07_caso9_escalacion_determinista_cancelacion_en_preguntarIA', async () => {
    const leadId = '+51984111009';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mariana Soto',
      status: 'clase_agendada',
    });

    const historial = [
      { role: 'user', content: 'Hola, no voy a poder ir a mi clase reservada de mañana. Por favor cancelen mi cupo.' }
    ];

    // Interceptar temporalmente llamarOpenAI para simular respuesta sin tool (lo que ocurrió en QA real)
    const originalLlamar = harness.openai.complete;
    harness.openai.complete = async () => ({
      role: 'assistant',
      content: '¡Hola Mariana! Lamento saber que no podrás asistir a tu clase de mañana. Tomo nota de tu aviso.',
      tool_calls: [],
    });

    const toolsEjecutadas = [];
    const respuesta = await preguntarIA(leadId, 'Prompt de prueba', historial, (c) => toolsEjecutadas.push(c.name));

    // Restaurar mock
    harness.openai.complete = originalLlamar;

    // Debe haberse ejecutado marcar_seguimiento_humano deterministamente
    assert(toolsEjecutadas.includes('marcar_seguimiento_humano'), 'Debe ejecutar marcar_seguimiento_humano deterministamente.');
    
    // Firestore debe tener status requiere_atencion
    const doc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    assert.strictEqual(doc.data().status, 'requiere_atencion');
    assert(doc.data().motivo_seguimiento.includes('cancelación'));
  });

  // -------------------------------------------------------------
  // REGRESIÓN CASO 11: ATENCIÓN HUMANA EXPLÍCITA
  // -------------------------------------------------------------
  console.log('\n--- CASO 11: Solicitud Explícita de Atención Humana ---');

  test('08_caso11_detector_atencion_humana_positivos', () => {
    assert(detectarSolicitudExplicitaAtencionHumana('Hola, por favor quiero hablar con una persona.'));
    assert(detectarSolicitudExplicitaAtencionHumana('quiero hablar con un humano'));
    assert(detectarSolicitudExplicitaAtencionHumana('pásame con el profesor'));
    assert(detectarSolicitudExplicitaAtencionHumana('necesito hablar con un asesor'));
    assert(detectarSolicitudExplicitaAtencionHumana('atención humana por favor'));
  });

  test('09_caso11_detector_anti_falsos_positivos_preguntas_informativas', () => {
    // Preguntas informativas legítimas que contienen la palabra "persona" NO deben activar derivación forzada
    assert.strictEqual(detectarSolicitudExplicitaAtencionHumana('¿Cuántas personas van a la clase de prueba?'), false);
    assert.strictEqual(detectarSolicitudExplicitaAtencionHumana('¿El precio de S/140 es por persona o en total?'), false);
    assert.strictEqual(detectarSolicitudExplicitaAtencionHumana('¿La promo es para dos personas?'), false);
  });

  await asyncTest('10_caso11_escalacion_determinista_atencion_humana_en_preguntarIA', async () => {
    const leadId = '+51984111011';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Roberto Carlos',
      status: 'conversando',
    });

    const historial = [
      { role: 'user', content: 'Hola, por favor quiero hablar con una persona.' }
    ];

    // Interceptar temporalmente llamarOpenAI para simular respuesta evasiva sin tool (lo que ocurrió en QA real)
    const originalLlamar = harness.openai.complete;
    harness.openai.complete = async () => ({
      role: 'assistant',
      content: '¡Hola! Estoy aquí para ayudarte con cualquier consulta que tengas sobre Capoeira en Ginga Cusco.',
      tool_calls: [],
    });

    const toolsEjecutadas = [];
    const respuesta = await preguntarIA(leadId, 'Prompt de prueba', historial, (c) => toolsEjecutadas.push(c.name));

    // Restaurar mock
    harness.openai.complete = originalLlamar;

    // Debe haberse ejecutado marcar_seguimiento_humano deterministamente
    assert(toolsEjecutadas.includes('marcar_seguimiento_humano'), 'Debe ejecutar marcar_seguimiento_humano.');
    
    // Firestore debe tener status requiere_atencion
    const doc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    assert.strictEqual(doc.data().status, 'requiere_atencion');
    assert(doc.data().motivo_seguimiento.includes('hablar con una persona'));

    // La respuesta devuelta debe confirmar la derivación al instructor
    assert(/instructor|profesor|equipo|asesor/i.test(respuesta), 'La respuesta debe asegurar que un instructor lo contactará.');
  });

  // -------------------------------------------------------------
  // VALIDACIONES FOCALIZADAS ADICIONALES (PRE-QA LIVE 2)
  // -------------------------------------------------------------
  console.log('\n--- VALIDACIONES FOCALIZADAS: Tests Negativos, Persistencia y No-Duplicación ---');

  test('11_negativo_como_funcionan_cancelaciones_es_informativo', () => {
    assert.strictEqual(
      detectarSolicitudCancelacion('¿Cómo funcionan las cancelaciones?'),
      false,
      'Pregunta informativa sobre cancelaciones no debe considerarse solicitud de cancelación.'
    );
    assert.strictEqual(
      detectarSolicitudCancelacion('¿Cuál es la política de cancelación?'),
      false,
      'Pregunta sobre política de cancelación no debe activar cancelación.'
    );
  });

  test('12_positivo_quiero_cancelar_mi_reserva_es_derivacion', () => {
    assert.strictEqual(
      detectarSolicitudCancelacion('Quiero cancelar mi reserva'),
      true,
      'Solicitud directa debe reconocerse como cancelación.'
    );
    assert.strictEqual(
      detectarSolicitudCancelacion('Por favor cancelen mi cupo'),
      true,
      'Petición de cancelar cupo debe ser detectada.'
    );
  });

  test('13_negativo_quien_es_el_profesor_es_informativo', () => {
    assert.strictEqual(
      detectarSolicitudExplicitaAtencionHumana('¿Quién es el profesor?'),
      false,
      'Pregunta sobre identidad del profesor es informativa, no atención humana.'
    );
    assert.strictEqual(
      detectarSolicitudExplicitaAtencionHumana('¿Cómo se llama el profesor de la clase?'),
      false,
      'Pregunta sobre el nombre del profesor es informativa.'
    );
  });

  test('14_positivo_quiero_hablar_con_un_profesor_es_derivacion', () => {
    assert.strictEqual(
      detectarSolicitudExplicitaAtencionHumana('Quiero hablar con un profesor'),
      true,
      'Petición de hablar con un profesor debe ser derivada.'
    );
    assert.strictEqual(
      detectarSolicitudExplicitaAtencionHumana('Necesito comunicarme con un asesor'),
      true,
      'Petición de asesor debe ser derivada.'
    );
  });

  test('15_nunca_afirma_cancelada_intercepta_afirmacion_falsa', () => {
    // Si el texto afirma que la reserva "ha sido cancelada" pero solo se registró human_escalation:
    const turnContext = new TurnContext('+51984111015');
    turnContext.recordToolExecution({
      tool_name: 'marcar_seguimiento_humano',
      operation: 'human_escalation',
      status: 'success',
      reason_code: 'OK',
      mutation_committed: true,
      details: { motivo: 'Solicitud de cancelación' },
    });

    const candidateText = '¡Listo! Tu reserva ha sido cancelada exitosamente del sistema.';
    const evaluation = evaluarRuntimeGuard('+51984111015', candidateText, turnContext, 'Prompt base');

    assert.strictEqual(evaluation.passed, false, 'Runtime Guard debe interceptar afirmación de cancelación sin tool de cancelación.');
    assert.strictEqual(evaluation.action, 'intercept');
    assert(evaluation.intercepted_claims.includes('cancellation'), 'Debe incluir reclamo de cancelación.');
    assert(evaluation.safeFallbackText.includes('asesor te responderá'), 'Fallback debe derivar a asesor sin prometer cancelación consumada.');
  });

  await asyncTest('16_falla_persistencia_no_promete_intervencion_humana', async () => {
    const leadId = '+51984111016';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Test Lead',
      status: 'conversando',
    });

    const leadRefSample = firestore.collection('whatsapp_leads').doc(leadId);
    const DocumentRefClass = leadRefSample.constructor;
    const origProtoUpdate = DocumentRefClass.prototype.update;

    DocumentRefClass.prototype.update = async function (data, ...args) {
      if (this.id === leadId && data?.status === 'requiere_atencion') {
        throw new Error('Firestore write timeout simulado');
      }
      return origProtoUpdate.apply(this, [data, ...args]);
    };

    harness.openai.setResponder(async () => ({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'Hola, ¿en qué te puedo ayudar?',
          },
        },
      ],
    }));

    const historial = [
      { role: 'user', content: 'Quiero hablar con una persona' }
    ];

    let respuesta;
    try {
      respuesta = await preguntarIA(leadId, 'Prompt base', historial);
    } finally {
      DocumentRefClass.prototype.update = origProtoUpdate;
    }

    // Si falló la persistencia, NUNCA debe decir "Ya le avisé al instructor"
    assert(respuesta, 'Debe devolver una respuesta de fallback.');
    assert(!/ya le avise al instructor/i.test(respuesta), 'No debe prometer intervención si falló la base de datos.');
    assert(/inconveniente técnico|escríbenos en unos minutos|te contactaremos/i.test(respuesta), 'Debe entregar fallback técnico seguro.');
  });

  await asyncTest('17_no_duplica_si_el_llm_ya_ejecuto_marcar_seguimiento', async () => {
    const leadId = '+51984111017';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Ernesto',
      status: 'conversando',
    });

    const historial = [
      { role: 'user', content: 'Quiero hablar con un profesor' }
    ];

    let round = 0;
    harness.openai.setResponder(async () => {
      if (round === 0) {
        round++;
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: null,
                tool_calls: [
                  {
                    id: 'call_esc_1',
                    type: 'function',
                    function: {
                      name: 'marcar_seguimiento_humano',
                      arguments: JSON.stringify({ motivo: 'Solicita hablar con un profesor' }),
                    },
                  },
                ],
              },
            },
          ],
        };
      }
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: 'He notificado al profesor para que te escriba pronto.',
            },
          },
        ],
      };
    });

    const toolsEjecutadas = [];
    await preguntarIA(leadId, 'Prompt base', historial, (c) => toolsEjecutadas.push(c.name));

    const conteoMarcado = toolsEjecutadas.filter((n) => n === 'marcar_seguimiento_humano').length;
    assert.strictEqual(conteoMarcado, 1, 'No debe duplicar la llamada si el LLM ya ejecutó marcar_seguimiento_humano.');
  });

  await asyncTest('18_reintento_mismo_mensaje_sin_duplicar_notificaciones', async () => {
    const leadId = '+51984111018';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Luciana',
      status: 'requiere_atencion',
      motivo_seguimiento: 'Escalación previa existente',
    });

    // Se asegura de que exista un profesor en /users
    await firestore.collection('users').doc('prof_test_1').set({
      nombre: 'Mestre FIU',
      rol: 'profesor',
    });

    // Conteo de notificaciones antes
    const notifsBefore = (await firestore.collection('users').doc('prof_test_1').collection('notificaciones').get()).docs.length;

    // Ejecutar marcar_seguimiento_humano para este lead que ya está en requiere_atencion
    const toolHumano = internals.AVAILABLE_TOOLS.find((t) => t.name === 'marcar_seguimiento_humano');
    const turnContext = new TurnContext(leadId);
    await toolHumano.handler(leadId, { motivo: 'Reintento del mismo mensaje' }, turnContext);

    // Conteo de notificaciones después
    const notifsAfter = (await firestore.collection('users').doc('prof_test_1').collection('notificaciones').get()).docs.length;

    assert.strictEqual(notifsAfter, notifsBefore, 'No debe duplicar notificaciones en reintentos cuando el lead ya está escalado.');
    const lastRecord = turnContext.toolRecords[turnContext.toolRecords.length - 1];
    assert.strictEqual(lastRecord.reason_code, 'ALREADY_ESCALATED', 'Debe registrar reason_code ALREADY_ESCALATED.');
  });

  // -------------------------------------------------------------
  // REGRESIÓN CASO 4: AGENDAR SEGUNDO HIJO (DOS HIJOS)
  // -------------------------------------------------------------
  console.log('--- CASO 4: Reserva de Segundo Hijo (Dos Hijos) y Flujo Familiar ---');

  await asyncTest('19_caso4_dos_hijos_peticion_completa_agenda_segundo_hijo_y_preserva_primero', async () => {
    const leadId = '+51984111019';
    const ahora = internals.obtenerFechaLimaAhora();
    const targetDate = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 3, 17, 0, 0);
    const targetTimestamp = MockTimestamp.fromDate(targetDate);

    // 1. Setup en Firestore: Mateo ya tiene reserva activa confirmada
    const resRefMateo = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Mateo',
      clase_id: 'clase_ninos',
      fecha_clase: targetTimestamp,
      hora: '17:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mamá Patricia',
      status: 'clase_agendada',
      perfil_personas: [{ nombre: 'Mateo', edad: 8 }], // Sin 'tipo' para verificar que no imprima undefined
      reservas_activas: {
        mateo: {
          reserva_id: resRefMateo.id,
          nombre_persona: 'Mateo',
          clase_id: 'clase_ninos',
          fecha_clase: targetTimestamp,
          hora: '17:00',
          status: 'confirmado',
        },
      },
    });

    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const leadData = leadDoc.data();

    // 2. Verificar que generarSystemPrompt incluye la Regla 7 y 7b y no imprime undefined
    const { systemPrompt } = await generarSystemPrompt(leadData, 1, leadId);
    assert(systemPrompt.includes('REGLAS OBLIGATORIAS ANTE ESTE LEAD CON RESERVA CONFIRMADA VIGENTE'), 'Debe incluir bloque de reservas vigentes');
    assert(systemPrompt.includes('7. Si el cliente solicita agendar o agregar a OTRA persona'), 'Debe incluir Regla 7 de familiares');
    assert(systemPrompt.includes('NO vuelvas a pedir el nombre ni la edad que ya te dio'), 'Regla 7b debe instruir no repreguntar');
    assert(!systemPrompt.includes('undefined'), 'No debe contener "undefined" en personas ya conocidas');
    assert(systemPrompt.includes('Mateo (persona, 8 años)'), 'Debe usar fallback limpio para tipo');

    // 3. Ejecución de herramientas: guardar_perfil_lead y reservar_clase_prueba para Sofia
    const turnContext = new TurnContext(leadId);
    const toolGuardar = internals.AVAILABLE_TOOLS.find((t) => t.name === 'guardar_perfil_lead');
    const toolReservar = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    await toolGuardar.handler(leadId, {
      personas: [{ nombre: 'Sofia', tipo: 'niño', edad: 5 }],
    }, turnContext);

    await toolReservar.handler(leadId, {
      nombre: 'Sofia',
      tipo: 'niño',
    }, turnContext);

    // 4. Evaluar que Runtime Guard aprueba la respuesta reconociendo a Mateo y confirmando a Sofia
    const candidateText = '¡Hola! Claro, la clase de Mateo sigue confirmada y ya registré a su hermanita Sofia para la misma clase de niños este jueves a las 17:00.';
    const evaluation = evaluarRuntimeGuard(leadId, candidateText, turnContext, systemPrompt);
    assert.strictEqual(evaluation.passed, true, 'Runtime Guard debe permitir confirmación válida de Sofia');
    assert.strictEqual(evaluation.action, 'allow');

    // 5. Verificar estado en Firestore: ambas reservas activas intactas
    const leadDocAfter = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDocAfter.data()?.reservas_activas || {};
    assert(activas.mateo, 'reservas_activas debe mantener a Mateo');
    assert(activas.sofia, 'reservas_activas debe contener a Sofia');
    assert.strictEqual(activas.mateo.reserva_id, resRefMateo.id, 'ID de Mateo debe ser el original');
    assert.strictEqual(activas.mateo.status, 'confirmado');
    assert.strictEqual(activas.sofia.status, 'confirmado');

    const mateoDoc = await firestore.collection('reservas').doc(resRefMateo.id).get();
    assert.strictEqual(mateoDoc.data()?.status, 'confirmado', 'Doc de reserva de Mateo debe mantenerse confirmado');

    const sofiaResDoc = await firestore.collection('reservas').doc(activas.sofia.reserva_id).get();
    assert.strictEqual(sofiaResDoc.data()?.nombre_persona, 'Sofia');
    assert.strictEqual(sofiaResDoc.data()?.status, 'confirmado');
  });

  await asyncTest('20_caso4_dos_hijos_peticion_incompleta_pide_aclaracion_sin_agendar', async () => {
    const leadId = '+51984111020';
    const ahora = internals.obtenerFechaLimaAhora();
    const targetDate = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 3, 17, 0, 0);
    const targetTimestamp = MockTimestamp.fromDate(targetDate);

    const resRefMateo = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Mateo',
      clase_id: 'clase_ninos',
      fecha_clase: targetTimestamp,
      hora: '17:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mamá Patricia',
      status: 'clase_agendada',
      perfil_personas: [{ nombre: 'Mateo', edad: 8 }],
      reservas_activas: {
        mateo: {
          reserva_id: resRefMateo.id,
          nombre_persona: 'Mateo',
          clase_id: 'clase_ninos',
          fecha_clase: targetTimestamp,
          hora: '17:00',
          status: 'confirmado',
        },
      },
    });

    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt } = await generarSystemPrompt(leadDoc.data(), 1, leadId);

    // Regla 7c: Si el cliente solicita agendar a un familiar pero NO indicó el nombre propio real o la edad
    assert(systemPrompt.includes('Si el cliente solicita agendar a un familiar pero NO indicó el nombre propio real o la edad'), 'Debe incluir Regla 7c');

    // El modelo responde pidiendo aclaración (nombre y edad) SIN ejecutar tools de reserva
    const turnContext = new TurnContext(leadId);
    const clarificationText = '¡Hola! Claro, la clase de Mateo ya está confirmada. ¿Cómo se llama tu otra hija y qué edad tiene para verificar su grupo y agendarla?';

    const evaluation = evaluarRuntimeGuard(leadId, clarificationText, turnContext, systemPrompt);
    assert.strictEqual(evaluation.passed, true, 'Debe permitir pedir aclaración legítima sin tools');
    assert.strictEqual(evaluation.action, 'allow');

    // Verificar que NO se crearon reservas nuevas en Firestore
    const allReservas = (await firestore.collection('reservas').where('lead_id', '==', leadId).get()).docs;
    assert.strictEqual(allReservas.length, 1, 'Solo debe existir la reserva original de Mateo');
    const leadDocAfter = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDocAfter.data()?.reservas_activas || {};
    assert.strictEqual(Object.keys(activas).length, 1, 'Solo debe haber 1 reserva activa');
    assert(activas.mateo && !activas.sofia, 'Solo debe estar Mateo');
  });

  await asyncTest('21_caso4_dos_hijos_multiturn_aclaracion_y_posterior_agendamiento', async () => {
    const leadId = '+51984111021';
    const ahora = internals.obtenerFechaLimaAhora();
    const targetDate = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 3, 17, 0, 0);
    const targetTimestamp = MockTimestamp.fromDate(targetDate);

    const resRefMateo = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Mateo',
      clase_id: 'clase_ninos',
      fecha_clase: targetTimestamp,
      hora: '17:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mamá Patricia',
      status: 'clase_agendada',
      perfil_personas: [{ nombre: 'Mateo', edad: 8 }],
      reservas_activas: {
        mateo: {
          reserva_id: resRefMateo.id,
          nombre_persona: 'Mateo',
          clase_id: 'clase_ninos',
          fecha_clase: targetTimestamp,
          hora: '17:00',
          status: 'confirmado',
        },
      },
    });

    // TURNO 1: Mensaje incompleto -> Aclaración
    const turn1Context = new TurnContext(leadId);
    const leadDoc1 = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt: promptTurn1 } = await generarSystemPrompt(leadDoc1.data(), 1, leadId);
    const replyTurn1 = '¡Hola! Claro, Mateo ya tiene su clase lista para este jueves a las 17:00. ¿Cómo se llama tu otra pequeña y qué edad tiene para agendarla?';
    const eval1 = evaluarRuntimeGuard(leadId, replyTurn1, turn1Context, promptTurn1);
    assert.strictEqual(eval1.passed, true, 'Turno 1 debe permitir la pregunta aclaratoria');

    // TURNO 2: El usuario proporciona los datos ("Se llama Sofia y tiene 5 años")
    const turn2Context = new TurnContext(leadId);
    const toolGuardar = internals.AVAILABLE_TOOLS.find((t) => t.name === 'guardar_perfil_lead');
    const toolReservar = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    await toolGuardar.handler(leadId, {
      personas: [{ nombre: 'Sofia', tipo: 'niño', edad: 5 }],
    }, turn2Context);

    await toolReservar.handler(leadId, {
      nombre: 'Sofia',
      tipo: 'niño',
    }, turn2Context);

    const leadDoc2 = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt: promptTurn2 } = await generarSystemPrompt(leadDoc2.data(), 3, leadId);

    const replyTurn2 = '¡Perfecto! Ya agendé a Sofia para la misma clase de niños de este jueves a las 17:00. Tanto Mateo como Sofia tienen su cupo asegurado.';
    const eval2 = evaluarRuntimeGuard(leadId, replyTurn2, turn2Context, promptTurn2);
    assert.strictEqual(eval2.passed, true, 'Turno 2 debe permitir confirmación tras recibir los datos');
    assert.strictEqual(eval2.action, 'allow');

    // Validar estado final en Firestore tras multi-turn
    const finalLeadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const activasFinal = finalLeadDoc.data()?.reservas_activas || {};
    assert(activasFinal.mateo, 'Mateo debe seguir activo');
    assert(activasFinal.sofia, 'Sofia debe estar activa');
    assert.strictEqual(activasFinal.mateo.reserva_id, resRefMateo.id);

    const reservasAll = (await firestore.collection('reservas').where('lead_id', '==', leadId).get()).docs;
    assert.strictEqual(reservasAll.length, 2, 'Deben existir exactamente 2 reservas para el lead');
  });

  console.log('\n================================================================');
  console.log(` RESULTADO REGRESIONES: ${passed}/${total} PRUEBAS PASS (100%)`);
  console.log('================================================================\n');
}

runRegressionSuite().catch((err) => {
  console.error('ERROR EN TEST SUITE REGRESIONES:', err);
  process.exit(1);
});

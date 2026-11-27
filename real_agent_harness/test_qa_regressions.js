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

  const harness = new RealAgentHarness({ fixedNowIso: '2026-11-18T10:00:00-05:00' });
  const internals = harness.internals;
  const firestore = harness.firestore;
  const {
    evaluarRuntimeGuard,
    detectarSolicitudExplicitaAtencionHumana,
    detectarSolicitudCancelacion,
    detectarSolicitudReprogramacion,
    resolverIdentidadPersona,
    reconciliarNombrePersona,
    calcularFechaProximoDia,
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

  // -------------------------------------------------------------
  // CASOS 1 Y 3: CONSISTENCIA DE OPERACIONES CRÍTICAS (RESERVAS Y REPROGRAMACIONES)
  // -------------------------------------------------------------
  console.log('--- CASOS 1 Y 3: Reconciliación de Identidad y Reprogramación Inequívoca ---');

  await asyncTest('22_caso1_reconciliacion_nombre_completo_y_pila_titular', async () => {
    const leadId = '+51984111022';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Camila Rivera',
      edad: 22,
      status: 'conversando',
    });

    const turnContext = new TurnContext(leadId);
    const toolGuardar = internals.AVAILABLE_TOOLS.find((t) => t.name === 'guardar_perfil_lead');
    const toolReservar = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    // Modelo extrae solo primer nombre "Camila"
    await toolGuardar.handler(leadId, {
      personas: [{ nombre: 'Camila', tipo: 'adulto', edad: 22 }],
    }, turnContext);

    // Reserva con nombre "Camila" o deducido
    await toolReservar.handler(leadId, {
      nombre: 'Camila',
      tipo: 'adulto',
    }, turnContext);

    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDoc.data()?.reservas_activas || {};

    // Reconciliación garantiza que se active bajo camila_rivera
    assert(activas.camila_rivera, 'reservas_activas debe contener camila_rivera tras reconciliación');
    assert.strictEqual(activas.camila_rivera.nombre_persona, 'Camila Rivera');

    // Verificar en colección /reservas
    const resSnap = await firestore.collection('reservas')
      .where('lead_id', '==', leadId)
      .where('status', '==', 'confirmado')
      .get();
    assert.strictEqual(resSnap.docs.length, 1, 'Debe existir 1 reserva confirmada');
    assert.strictEqual(resSnap.docs[0].data().nombre_persona, 'Camila Rivera');
  });

  test('23_normalizacion_variacion_acentos_y_tildes', () => {
    const leadData = { nombre: 'Matias Morales' };
    const perfil = [{ nombre: 'Matías Morales', edad: 8 }];

    const r1 = reconciliarNombrePersona('Matias', leadData, perfil);
    assert.strictEqual(r1, 'Matias Morales', 'Debe reconciliar prefijo Matias con Matias Morales');

    const r2 = reconciliarNombrePersona('Matías', leadData, perfil);
    assert.strictEqual(r2, 'Matias Morales', 'Debe reconciliar tilde Matías con titular');

    const d1 = detectarSolicitudReprogramacion('¿Puedo cambiar mi clase para el próximo martes?');
    assert.strictEqual(d1?.esReprogramacion, true);
    assert.strictEqual(d1?.diaObjetivo, 'martes');

    const d2 = detectarSolicitudReprogramacion('cambiar para el proximo martes');
    assert.strictEqual(d2?.esReprogramacion, true);
    assert.strictEqual(d2?.diaObjetivo, 'martes');
  });

  await asyncTest('24_caso3_reprogramacion_univoca_sin_repreguntar_nombre', async () => {
    const leadId = '+51984111024';
    const ahora = internals.obtenerFechaLimaAhora();
    const fechaOriginal = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);
    const originalTs = MockTimestamp.fromDate(fechaOriginal);

    const resRef = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Carlos Morales',
      clase_id: 'clase_adultos',
      fecha_clase: originalTs,
      hora: '18:00',
      status: 'confirmado',
      reprogramaciones: [],
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Carlos Morales',
      status: 'clase_agendada',
      reservas_activas: {
        carlos_morales: {
          reserva_id: resRef.id,
          nombre_persona: 'Carlos Morales',
          clase_id: 'clase_adultos',
          fecha_clase: originalTs,
          hora: '18:00',
          status: 'confirmado',
        },
      },
    });

    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt } = await generarSystemPrompt(leadDoc.data(), 1, leadId);

    // Regla 5a debe instruir que una sola reserva ya está 100% identificada
    assert(systemPrompt.includes('Si este lead tiene UNA SOLA reserva confirmada activa'), 'Debe incluir Regla 5a para reserva única');
    assert(systemPrompt.includes('NUNCA le vuelvas a preguntar el nombre ni a nombre de quién está la clase'), 'Debe prohibir repreguntar');

    // Modelo invoca reprogramar_reserva pasando solo primer nombre "Carlos" o nueva_fecha
    const turnContext = new TurnContext(leadId);
    const toolReprog = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const proximaFechaStr = calcularFechaProximoDia('martes', originalTs);

    const resResult = await toolReprog.handler(leadId, {
      nombre: 'Carlos',
      nueva_fecha: proximaFechaStr,
    }, turnContext);

    assert(resResult.includes('Reprogramación confirmada con éxito'), 'Debe confirmar reprogramación exitosa');

    // Verificar persistencia en Firestore
    const resDoc = await firestore.collection('reservas').doc(resRef.id).get();
    const resData = resDoc.data();
    assert(Array.isArray(resData.reprogramaciones) && resData.reprogramaciones.length === 1, 'Debe registrar auditoría');
    assert.strictEqual(resData.reprogramaciones[0].fecha_anterior.seconds, originalTs.seconds);

    const leadDocAfter = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const activasAfter = leadDocAfter.data()?.reservas_activas || {};
    assert(activasAfter.carlos_morales, 'reservas_activas debe mantener carlos_morales');
  });

  await asyncTest('25_caso3_reprogramacion_ambigua_dos_hijos_solicita_aclaracion', async () => {
    const leadId = '+51984111025';
    const ahora = internals.obtenerFechaLimaAhora();
    const targetDate = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 17, 0, 0);
    const targetTs = MockTimestamp.fromDate(targetDate);

    const resMateo = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Mateo',
      clase_id: 'clase_ninos',
      fecha_clase: targetTs,
      hora: '17:00',
      status: 'confirmado',
    });

    const resLucia = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Lucía',
      clase_id: 'clase_ninos',
      fecha_clase: targetTs,
      hora: '17:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mamá Patricia',
      status: 'clase_agendada',
      perfil_personas: [
        { nombre: 'Mateo', edad: 8 },
        { nombre: 'Lucía', edad: 6 },
      ],
      reservas_activas: {
        mateo: {
          reserva_id: resMateo.id,
          nombre_persona: 'Mateo',
          status: 'confirmado',
        },
        lucia: {
          reserva_id: resLucia.id,
          nombre_persona: 'Lucía',
          status: 'confirmado',
        },
      },
    });

    // Petición ambigua sin especificar alumno
    const turnContext = new TurnContext(leadId);
    const toolReprog = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const proximaFechaStr = calcularFechaProximoDia('martes');

    const resResult = await toolReprog.handler(leadId, {
      nueva_fecha: proximaFechaStr,
    }, turnContext);

    assert(
      resResult.includes('Hay varias reservas confirmadas activas para este número') ||
      resResult.includes('Hay varias personas registradas'),
      'Debe solicitar aclaración ante ambigüedad'
    );
    const rec = turnContext.toolRecords.find((r) => r.tool_name === 'reprogramar_reserva');
    assert.strictEqual(rec.status, 'clarification_required');
    assert.strictEqual(rec.mutation_committed, false);
  });

  test('26_negativo_detector_reprogramacion_preguntas_informativas', () => {
    // Preguntas informativas no deben ser detectadas como solicitud de reprogramación
    assert.strictEqual(detectarSolicitudReprogramacion('¿Cómo funcionan las reprogramaciones?'), null);
    assert.strictEqual(detectarSolicitudReprogramacion('¿Se puede cambiar de día si no puedo ir?'), null);
    assert.strictEqual(detectarSolicitudReprogramacion('¿Tiene algún costo reprogramar mi clase?'), null);
    assert.strictEqual(detectarSolicitudReprogramacion('¿Cuántas veces se puede reprogramar?'), null);
    assert.strictEqual(detectarSolicitudReprogramacion('Quiero una clase de capoeira'), null);
    assert.strictEqual(detectarSolicitudReprogramacion('Hola por favor quiero cancelar mi clase'), null);

    // Solicitudes efectivas sí deben ser detectadas
    const pos1 = detectarSolicitudReprogramacion('Hola, tuve un inconveniente y no podré ir este jueves. ¿Puedo cambiar mi clase para el próximo martes?');
    assert.strictEqual(pos1?.esReprogramacion, true);
    assert.strictEqual(pos1?.diaObjetivo, 'martes');

    const pos2 = detectarSolicitudReprogramacion('Quiero reprogramar mi reserva para este jueves');
    assert.strictEqual(pos2?.esReprogramacion, true);
    assert.strictEqual(pos2?.diaObjetivo, 'jueves');
  });

  await asyncTest('27_caso3_preguntarIA_reprogramacion_determinista_fallback', async () => {
    const leadId = '+51984111027';
    const ahora = internals.obtenerFechaLimaAhora();
    const fechaOriginal = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);
    const originalTs = MockTimestamp.fromDate(fechaOriginal);

    const resRef = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Carlos Morales',
      clase_id: 'clase_adultos',
      fecha_clase: originalTs,
      hora: '18:00',
      status: 'confirmado',
      reprogramaciones: [],
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Carlos Morales',
      status: 'clase_agendada',
      reservas_activas: {
        carlos_morales: {
          reserva_id: resRef.id,
          nombre_persona: 'Carlos Morales',
          clase_id: 'clase_adultos',
          fecha_clase: originalTs,
          hora: '18:00',
          status: 'confirmado',
        },
      },
    });

    // Simular que el modelo responde texto conversacional sin invocar tool
    harness.openai.setResponder(async () => ({
      choices: [
        {
          message: {
            role: 'assistant',
            content: '¡Hola! Claro, puedo ayudarte con eso. Solo necesito que me digas a nombre de quién es la clase.',
          },
        },
      ],
    }));

    const historial = [
      { role: 'user', content: 'Hola, tuve un inconveniente y no podré ir este jueves. ¿Puedo cambiar mi clase para el próximo martes?' }
    ];

    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt } = await generarSystemPrompt(leadDoc.data(), 1, leadId);

    const finalAnswer = await preguntarIA(leadId, systemPrompt, historial);

    // Debe resolver de forma determinista y confirmar la reprogramación
    assert(finalAnswer.includes('reprogramada con éxito') || finalAnswer.includes('martes'), 'Debe entregar confirmación segura de reprogramación');

    // Verificar en base de datos
    const resDoc = await firestore.collection('reservas').doc(resRef.id).get();
    assert.strictEqual(resDoc.data().reprogramaciones.length, 1, 'Debe haber persistido la reprogramación');

    harness.openai.reset();
  });

  // -------------------------------------------------------------
  // PRUEBAS DE REGRESIÓN NEGATIVAS: BLINDAJE DE IDENTIDAD, AUTORIZACIÓN E IDEMPOTENCIA
  // -------------------------------------------------------------
  console.log('--- BLINDAJE DE IDENTIDAD, AUTORIZACIÓN E IDEMPOTENCIA (TESTS 28-33) ---');

  await asyncTest('28_negativo_dos_personas_mismo_nombre_pila_bloquea_mutaciones', async () => {
    const leadId = '+51984111028';
    const perfilPersonas = [
      { nombre: 'Mateo Gómez', edad: 8, tipo: 'niño' },
      { nombre: 'Mateo Morales', edad: 10, tipo: 'niño' },
    ];
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Papá de los Mateos',
      perfil_personas: perfilPersonas,
      status: 'conversando',
    });

    // 1. Verificar que resolverIdentidadPersona marca ambigüedad estricta
    const resId = resolverIdentidadPersona('Mateo', { nombre: 'Papá' }, perfilPersonas);
    assert.strictEqual(resId.esAmbiguo, true, 'Debe marcar esAmbiguo: true ante dos Mateos');
    assert.strictEqual(resId.nombre, null);
    assert.strictEqual(reconciliarNombrePersona('Mateo', { nombre: 'Papá' }, perfilPersonas), null);

    // 2. Intentar reservar clase con nombre ambiguo "Mateo"
    const turnContext1 = new TurnContext(leadId);
    const toolReservar = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');
    const resBooking = await toolReservar.handler(leadId, { nombre: 'Mateo', tipo: 'niño' }, turnContext1);
    assert(resBooking.includes('Hay varias personas registradas'), 'Debe solicitar aclaración en reserva');
    const recBooking = turnContext1.toolRecords.find((r) => r.tool_name === 'reservar_clase_prueba');
    assert.strictEqual(recBooking.status, 'clarification_required');
    assert.strictEqual(recBooking.reason_code, 'AMBIGUOUS_NAME');
    assert.strictEqual(recBooking.mutation_committed, false);

    // Verificar que NO se creó ninguna reserva en Firestore
    const snapReservas = await firestore.collection('reservas').where('lead_id', '==', leadId).get();
    assert.strictEqual(snapReservas.docs.length, 0, 'No debe haber mutaciones en /reservas');

    // 3. Crear reservas individuales confirmadas para cada Mateo
    const ahora = internals.obtenerFechaLimaAhora();
    const f1 = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 17, 0, 0);
    const f2 = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 4, 17, 0, 0);
    const rMateo1 = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Mateo Gómez',
      clase_id: 'clase_ninos',
      fecha_clase: MockTimestamp.fromDate(f1),
      hora: '17:00',
      status: 'confirmado',
    });
    const rMateo2 = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Mateo Morales',
      clase_id: 'clase_ninos',
      fecha_clase: MockTimestamp.fromDate(f2),
      hora: '17:00',
      status: 'confirmado',
    });

    // 4. Intentar reprogramar usando solo "Mateo"
    const turnContext2 = new TurnContext(leadId);
    const toolReprog = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const proximaFechaStr = calcularFechaProximoDia('martes');
    const resReprog = await toolReprog.handler(leadId, { nombre: 'Mateo', nueva_fecha: proximaFechaStr }, turnContext2);
    assert(resReprog.includes('varias personas registradas') || resReprog.includes('coinciden'), 'Debe solicitar aclaración en reprogramación');
    const recReprog = turnContext2.toolRecords.find((r) => r.tool_name === 'reprogramar_reserva');
    assert.strictEqual(recReprog.status, 'clarification_required');
    assert.strictEqual(recReprog.reason_code, 'AMBIGUOUS_RESERVATION');
    assert.strictEqual(recReprog.mutation_committed, false);

    // Verificar que ambas reservas permanecen intactas en Firestore
    const docM1 = await firestore.collection('reservas').doc(rMateo1.id).get();
    const docM2 = await firestore.collection('reservas').doc(rMateo2.id).get();
    assert.strictEqual(docM1.data().reprogramaciones || undefined, undefined);
    assert.strictEqual(docM2.data().reprogramaciones || undefined, undefined);
  });

  await asyncTest('29_negativo_nombre_incompleto_no_atribuye_en_falso', async () => {
    const leadId = '+51984111029';
    const ahora = internals.obtenerFechaLimaAhora();
    const fechaClase = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);

    const resRef = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Juan Carlos Rivera',
      clase_id: 'clase_adultos',
      fecha_clase: MockTimestamp.fromDate(fechaClase),
      hora: '18:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Juan Carlos Rivera',
      status: 'clase_agendada',
      reservas_activas: {
        juan_carlos_rivera: {
          reserva_id: resRef.id,
          nombre_persona: 'Juan Carlos Rivera',
          status: 'confirmado',
        },
      },
    });

    // Petición nombrando "Carlos" (que es sufijo de "Juan Carlos", no prefijo ni correspondencia unívoca)
    const turnContext = new TurnContext(leadId);
    const toolReprog = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const proximaFechaStr = calcularFechaProximoDia('jueves');

    const resResult = await toolReprog.handler(leadId, {
      nombre: 'Carlos',
      nueva_fecha: proximaFechaStr,
    }, turnContext);

    assert(resResult.includes('No se encontró ninguna reserva para "Carlos"'), 'Debe rechazar atribución arbitraria de nombre parcial');
    const rec = turnContext.toolRecords.find((r) => r.tool_name === 'reprogramar_reserva');
    assert.strictEqual(rec.status, 'rejected');
    assert.strictEqual(rec.reason_code, 'PERSON_RESERVATION_NOT_FOUND');
    assert.strictEqual(rec.mutation_committed, false);

    // Verificar que la reserva de Juan Carlos no fue tocada
    const resDoc = await firestore.collection('reservas').doc(resRef.id).get();
    assert.strictEqual(resDoc.data().reprogramaciones || undefined, undefined);
  });

  await asyncTest('30_negativo_reserva_otro_lead_rechazo_estricto_autorizacion', async () => {
    const leadIdA = '+51984111030';
    const leadIdB = '+51984111099';
    const ahora = internals.obtenerFechaLimaAhora();
    const fechaOriginal = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);

    // Reserva perteneciente al Lead B
    const resRefB = await firestore.collection('reservas').add({
      lead_id: leadIdB,
      nombre_persona: 'Cliente B',
      clase_id: 'clase_adultos',
      fecha_clase: MockTimestamp.fromDate(fechaOriginal),
      hora: '18:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadIdA).set({
      telefono: leadIdA,
      nombre: 'Cliente A',
      status: 'conversando',
    });

    // Lead A intenta reprogramar la reserva del Lead B pasando su reserva_id
    const turnContext = new TurnContext(leadIdA);
    const toolReprog = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const proximaFechaStr = calcularFechaProximoDia('martes');

    const result = await toolReprog.handler(leadIdA, {
      reserva_id: resRefB.id,
      nueva_fecha: proximaFechaStr,
    }, turnContext);

    assert(result.includes('no pertenece a este número de teléfono'), 'Debe rechazar reserva no autorizada');
    const rec = turnContext.toolRecords.find((r) => r.tool_name === 'reprogramar_reserva');
    assert.strictEqual(rec.status, 'rejected');
    assert.strictEqual(rec.reason_code, 'UNAUTHORIZED_RESERVATION');
    assert.strictEqual(rec.mutation_committed, false);

    // También verificar rechazo en la función transaccional interna
    let errTx = null;
    try {
      await internals.reprogramarClasePruebaLead(leadIdA, resRefB.id, new Date(proximaFechaStr));
    } catch (e) {
      errTx = e;
    }
    assert(errTx && errTx.message.includes('UNAUTHORIZED_RESERVATION'), 'Transacción interna debe abortar con UNAUTHORIZED_RESERVATION');

    // Comprobar que en base de datos la reserva del Lead B permanece inalterada
    const resDocB = await firestore.collection('reservas').doc(resRefB.id).get();
    assert.strictEqual(resDocB.data().lead_id, leadIdB);
    assert.strictEqual(resDocB.data().reprogramaciones || undefined, undefined);
  });

  await asyncTest('31_negativo_reprogramacion_fecha_ambigua_no_dispara_fallback', async () => {
    const leadId = '+51984111031';
    const ahora = internals.obtenerFechaLimaAhora();
    const fechaOriginal = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);

    const resRef = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Pedro Díaz',
      clase_id: 'clase_adultos',
      fecha_clase: MockTimestamp.fromDate(fechaOriginal),
      hora: '18:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Pedro Díaz',
      status: 'clase_agendada',
      reservas_activas: {
        pedro_diaz: {
          reserva_id: resRef.id,
          nombre_persona: 'Pedro Díaz',
          status: 'confirmado',
        },
      },
    });

    // Mensaje ambiguo con dos días objetivo posibles ("martes o jueves")
    const textoAmbiguo = 'Quisiera cambiar mi clase para el martes o el jueves, ¿cuál tienen libre?';
    const info = detectarSolicitudReprogramacion(textoAmbiguo);
    assert.strictEqual(info?.esReprogramacion, true);
    assert.strictEqual(info?.diaObjetivo, null, 'diaObjetivo debe ser null ante ambigüedad');
    assert.strictEqual(info?.esFechaAmbigua, true, 'esFechaAmbigua debe ser true');

    // Modelo contesta pidiendo clarificar sin llamar tools
    harness.openai.setResponder(async () => ({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'Tenemos clases tanto el martes como el jueves a las 18:00. ¿Cuál de los dos días te queda mejor?',
          },
        },
      ],
    }));

    const historial = [{ role: 'user', content: textoAmbiguo }];
    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt } = await generarSystemPrompt(leadDoc.data(), 1, leadId);

    const finalAnswer = await preguntarIA(leadId, systemPrompt, historial);

    // El fallback determinista NO debe ejecutarse ni modificar la base de datos
    assert(!finalAnswer.includes('reprogramada con éxito'), 'No debe afirmar reprogramación exitosa ante fecha ambigua');

    const resDoc = await firestore.collection('reservas').doc(resRef.id).get();
    assert.strictEqual(resDoc.data().reprogramaciones || undefined, undefined, 'No debe haber mutaciones en /reservas');

    harness.openai.reset();
  });

  await asyncTest('32_negativo_reprogramacion_reserva_expirada_rechazo_estricto', async () => {
    const leadId = '+51984111032';
    const ahora = internals.obtenerFechaLimaAhora();
    // Fecha de hace 5 días (vencida)
    const fechaPasada = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() - 5, 18, 0, 0);

    const resRef = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Lucas Ramos',
      clase_id: 'clase_adultos',
      fecha_clase: MockTimestamp.fromDate(fechaPasada),
      hora: '18:00',
      status: 'confirmado',
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Lucas Ramos',
      status: 'clase_agendada',
      reservas_activas: {
        lucas_ramos: {
          reserva_id: resRef.id,
          nombre_persona: 'Lucas Ramos',
          status: 'confirmado',
        },
      },
    });

    const turnContext = new TurnContext(leadId);
    const toolReprog = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const proximaFechaStr = calcularFechaProximoDia('martes');

    const resResult = await toolReprog.handler(leadId, {
      nombre: 'Lucas Ramos',
      nueva_fecha: proximaFechaStr,
    }, turnContext);

    assert(resResult.includes('era para una fecha pasada') || resResult.includes('cita vencida'), 'Debe rechazar cita vencida');
    const rec = turnContext.toolRecords.find((r) => r.tool_name === 'reprogramar_reserva');
    assert.strictEqual(rec.status, 'rejected');
    assert.strictEqual(rec.reason_code, 'EXPIRED_DATE');
    assert.strictEqual(rec.mutation_committed, false);

    // Probar también que preguntarIA no dispara fallback determinista para reservas pasadas
    harness.openai.setResponder(async () => ({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'Hola, disculpa, tu clase ya pasó la semana pasada.',
          },
        },
      ],
    }));

    const historial = [{ role: 'user', content: 'No pude ir la semana pasada, ¿puedo cambiar mi clase para el próximo martes?' }];
    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt } = await generarSystemPrompt(leadDoc.data(), 1, leadId);

    const finalAnswer = await preguntarIA(leadId, systemPrompt, historial);
    assert(!finalAnswer.includes('reprogramada con éxito'), 'Fallback no debe auto-reprogramar citas pasadas');

    const resDoc = await firestore.collection('reservas').doc(resRef.id).get();
    assert.strictEqual(resDoc.data().reprogramaciones || undefined, undefined, '0 mutaciones para citas vencidas');

    harness.openai.reset();
  });

  await asyncTest('33_idempotencia_reintento_operacion_sin_duplicar_auditoria', async () => {
    const leadId = '+51984111033';
    const ahora = internals.obtenerFechaLimaAhora();
    const fechaOriginal = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);

    const resRef = await firestore.collection('reservas').add({
      lead_id: leadId,
      nombre_persona: 'Mariana Silva',
      clase_id: 'clase_adultos',
      fecha_clase: MockTimestamp.fromDate(fechaOriginal),
      hora: '18:00',
      status: 'confirmado',
      reprogramaciones: [],
    });

    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mariana Silva',
      status: 'clase_agendada',
      reservas_activas: {
        mariana_silva: {
          reserva_id: resRef.id,
          nombre_persona: 'Mariana Silva',
          status: 'confirmado',
        },
      },
    });

    const toolReprog = internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const proximaFechaStr = calcularFechaProximoDia('jueves');

    // Primer intento: reprogramación exitosa
    const turnContext1 = new TurnContext(leadId);
    const r1 = await toolReprog.handler(leadId, {
      nombre: 'Mariana Silva',
      nueva_fecha: proximaFechaStr,
    }, turnContext1);
    assert(r1.includes('Reprogramación confirmada con éxito'), 'Primer intento debe confirmar');
    const rec1 = turnContext1.toolRecords.find((r) => r.tool_name === 'reprogramar_reserva');
    assert.strictEqual(rec1.status, 'success');
    assert.strictEqual(rec1.reason_code, 'OK');

    const snap1 = await firestore.collection('reservas').doc(resRef.id).get();
    assert.strictEqual(snap1.data().reprogramaciones.length, 1, 'Debe haber exactamente 1 entrada de auditoría');

    // Segundo intento (reintento idéntico por duplicación de red o webhook)
    const turnContext2 = new TurnContext(leadId);
    const r2 = await toolReprog.handler(leadId, {
      nombre: 'Mariana Silva',
      nueva_fecha: proximaFechaStr,
    }, turnContext2);
    assert(r2.includes('ya se encuentra confirmada y programada exactamente'), 'Reintento debe reportar idempotencia');
    const rec2 = turnContext2.toolRecords.find((r) => r.tool_name === 'reprogramar_reserva');
    assert.strictEqual(rec2.status, 'success');
    assert.strictEqual(rec2.reason_code, 'ALREADY_SCHEDULED_ON_DATE');
    assert.strictEqual(rec2.mutation_committed, true);

    // Auditoría NO debe haberse duplicado
    const snap2 = await firestore.collection('reservas').doc(resRef.id).get();
    assert.strictEqual(snap2.data().reprogramaciones.length, 1, 'Idempotencia: auditoría debe seguir teniendo 1 sola entrada');

    // Tercer intento: llamada directa a reprogramarClasePruebaLead con la misma fecha
    const fechaDateTarget = internals.validarFechaSolicitada(proximaFechaStr, 'M, J');
    const txRes = await internals.reprogramarClasePruebaLead(leadId, resRef.id, fechaDateTarget);
    assert.strictEqual(txRes.ya_estaba_programada, true, 'Transacción interna debe retornar ya_estaba_programada');

    const snap3 = await firestore.collection('reservas').doc(resRef.id).get();
    assert.strictEqual(snap3.data().reprogramaciones.length, 1, 'Auditoría se mantiene intacta en 1');
  });

  console.log('\n================================================================');
  console.log(` RESULTADO REGRESIONES: ${passed}/${total} PRUEBAS PASS (100%)`);
  console.log('================================================================\n');
}

runRegressionSuite().catch((err) => {
  console.error('ERROR EN TEST SUITE REGRESIONES:', err);
  process.exit(1);
});

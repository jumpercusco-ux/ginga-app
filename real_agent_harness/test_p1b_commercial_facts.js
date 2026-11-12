/**
 * real_agent_harness/test_p1b_commercial_facts.js
 * Suite de Regresión P1B: Blindaje Determinista de Horarios y Edades de Catálogo
 * Cubre exhaustivamente los Casos A a J, Clases Activas y Preservación Transaccional (Prompt 60).
 */

const assert = require('assert');
const { RealAgentHarness } = require('./loader');
const { MockTimestamp } = require('./in_memory_firestore');

async function runCommercialFactsSuite() {
  console.log('================================================================');
  console.log('   TEST SUITE P1B: BLINDAJE DETERMINISTA DE HORARIOS Y EDADES');
  console.log('   Validación exhaustiva de Casos A a J y Preservación Transaccional');
  console.log('================================================================\n');

  const harness = new RealAgentHarness();
  const internals = harness.internals;
  const firestore = harness.firestore;

  const {
    evaluarRuntimeGuard,
    validarAfirmacionesComerciales,
    extraerCatalogoClasesOficiales,
    generarRespuestaComercialOficial,
    generarSystemPrompt,
    preguntarIA,
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

  // Catálogo oficial de Cusco (idéntico a Firestore productivo)
  const catalogoOficialCusco = [
    {
      nombre: 'Kids',
      dias: 'M, J',
      diasTexto: 'martes y jueves',
      hora: '18:00',
      hora_fin: '19:00',
      edad_min: 5,
      edad_max: 12,
      sinTopeSuperior: false,
      publico: 'niños',
      ubicacion: 'Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso (justo al costado de la Caja Arequipa).',
    },
    {
      nombre: 'Adultos',
      dias: 'M, J',
      diasTexto: 'martes y jueves',
      hora: '19:00',
      hora_fin: '20:00',
      edad_min: 13,
      edad_max: 99,
      sinTopeSuperior: true,
      publico: 'jovenes_adultos',
      ubicacion: 'Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso (justo al costado de la Caja Arequipa).',
    },
  ];

  // -------------------------------------------------------------
  // CASO A: "Los niños tienen clases de 5 a 6 pm" -> INTERCEPTAR
  // -------------------------------------------------------------
  test('Caso A: "Los niños tienen clases de 5 a 6 pm" -> interceptar', () => {
    const texto = 'Los niños tienen clases de 5 a 6 pm';
    const res = validarAfirmacionesComerciales(texto, catalogoOficialCusco);
    assert.strictEqual(res.valid, false, 'Debe interceptar horario no autorizado (17:00 / 5 pm)');
    assert.strictEqual(res.contradiction, true);
    assert.strictEqual(res.type, 'invalid_schedule_hour');
  });

  // -------------------------------------------------------------
  // CASO B: "No tenemos clases a las 5 pm; comenzamos a las 6 pm" -> PERMITIR
  // -------------------------------------------------------------
  test('Caso B: "No tenemos clases a las 5 pm; comenzamos a las 6 pm" -> permitir', () => {
    const texto = 'No tenemos clases a las 5 pm; comenzamos a las 6 pm';
    const res = validarAfirmacionesComerciales(texto, catalogoOficialCusco);
    assert.strictEqual(res.valid, true, 'Debe permitir negación de horario inexistente');
    assert.strictEqual(res.contradiction, false);
  });

  // -------------------------------------------------------------
  // CASO C: "¿Puedo ir a las 5 pm?" -> PERMITIR (no tratar pregunta del cliente como dato oficial)
  // -------------------------------------------------------------
  test('Caso C: "¿Puedo ir a las 5 pm?" -> permitir (no es afirmación oficial)', () => {
    const texto = '¿Puedo ir a las 5 pm?';
    const res = validarAfirmacionesComerciales(texto, catalogoOficialCusco);
    assert.strictEqual(res.valid, true, 'Pregunta no debe ser tratada como afirmación oficial de catálogo');
    assert.strictEqual(res.contradiction, false);
  });

  // -------------------------------------------------------------
  // CASO D: "Tengo un hijo de 4 años" -> PERMITIR (edad del hijo, no rango de academia)
  // -------------------------------------------------------------
  test('Caso D: "Tengo un hijo de 4 años" -> permitir (edad del cliente, no política de admisión)', () => {
    const texto = 'Tengo un hijo de 4 años y quisiera saber cómo son las clases.';
    const res = validarAfirmacionesComerciales(texto, catalogoOficialCusco);
    assert.strictEqual(res.valid, true, 'No debe confundir la edad del hijo con el rango de la academia');
    assert.strictEqual(res.contradiction, false);
  });

  // -------------------------------------------------------------
  // CASO E: "Aceptamos niños de 4 a 12 años" -> INTERCEPTAR
  // -------------------------------------------------------------
  test('Caso E: "Aceptamos niños de 4 a 12 años" -> interceptar (edad mínima 4 < 5)', () => {
    const texto = 'En Capoeira FIU aceptamos niños de 4 a 12 años.';
    const res = validarAfirmacionesComerciales(texto, catalogoOficialCusco);
    assert.strictEqual(res.valid, false, 'Debe interceptar edad mínima no autorizada');
    assert.strictEqual(res.contradiction, true);
    assert.strictEqual(res.type, 'invalid_kids_age_range');
  });

  // -------------------------------------------------------------
  // CASO F: "Niños 5 a 12 años, martes y jueves 6 a 7 pm" -> PERMITIR
  // -------------------------------------------------------------
  test('Caso F: "Niños 5 a 12 años, martes y jueves 6 a 7 pm" -> permitir', () => {
    const texto = 'Las clases para niños (5 a 12 años) son los martes y jueves de 6 a 7 pm.';
    const res = validarAfirmacionesComerciales(texto, catalogoOficialCusco);
    assert.strictEqual(res.valid, true, 'Debe permitir horario y rango válidos de catálogo');
    assert.strictEqual(res.contradiction, false);
  });

  // -------------------------------------------------------------
  // CASO G: "Los adultos tienen clases de 7 a 8 pm" -> PERMITIR
  // -------------------------------------------------------------
  test('Caso G: "Los adultos tienen clases de 7 a 8 pm" -> permitir', () => {
    const texto = 'Los adultos tienen clases de 7 a 8 pm los martes y jueves.';
    const res = validarAfirmacionesComerciales(texto, catalogoOficialCusco);
    assert.strictEqual(res.valid, true, 'Debe permitir horario de adultos de catálogo (19:00 a 20:00)');
    assert.strictEqual(res.contradiction, false);
  });

  // -------------------------------------------------------------
  // CASO H: Cambio dinámico de horario en fixture -> USAR NUEVOS VALORES
  // -------------------------------------------------------------
  test('Caso H: Cambio dinámico de horario en fixture -> usa nuevos valores dinámicamente', () => {
    const catalogoModificado = [
      {
        nombre: 'Infantil Nueva Sede',
        dias: 'L, X, V',
        diasTexto: 'lunes, miércoles y viernes',
        hora: '16:30',
        hora_fin: '17:30',
        edad_min: 7,
        edad_max: 11,
        sinTopeSuperior: false,
        publico: 'niños',
        ubicacion: 'Sede San Sebastián',
      },
    ];

    // Ahora 16:30 es válida dinámicamente
    const res1 = validarAfirmacionesComerciales('Las clases son a las 16:30 los lunes.', catalogoModificado);
    assert.strictEqual(res1.valid, true, '16:30 debe ser válida para el nuevo fixture');

    // 18:00 ahora es inválida para este nuevo fixture
    const res2 = validarAfirmacionesComerciales('Las clases son a las 18:00 los martes.', catalogoModificado);
    assert.strictEqual(res2.valid, false, '18:00 debe ser inválida si ya no está en el nuevo fixture');

    const repDinamica = generarRespuestaComercialOficial(catalogoModificado, 'Sede San Sebastián', '¿Tienen clases para niños?');
    assert(repDinamica.includes('lunes, miércoles y viernes de 16:30 a 17:30'));
    assert(repDinamica.includes('de 7 a 11 años'));
    assert(repDinamica.includes('Sede San Sebastián'));
  });

  // -------------------------------------------------------------
  // CASO I: Consulta informativa y reserva confirmada -> PRESERVAR FLUJO TRANSACCIONAL
  // -------------------------------------------------------------
  test('Caso I: Consulta informativa y reserva confirmada -> no romper flujo transaccional', () => {
    const leadId = '+51984222010';
    const turnContext = new TurnContext(leadId, null, catalogoOficialCusco, catalogoOficialCusco[0].ubicacion);

    // Simular que en este turno se confirmó exitosamente la reserva para Sofia
    turnContext.recordToolExecution({
      tool_name: 'reservar_clase_prueba',
      operation: 'booking',
      status: 'success',
      reason_code: 'OK',
      mutation_committed: true,
      persona_slug: 'sofia',
      fecha_confirmada: 'jueves 14 de noviembre',
      hora: '18:00',
      sede: 'Av. de la Cultura E-4, Urb. Magisterio',
    });

    // Caso I1: Respuesta mezcla reserva válida con información comercial válida
    const txtValido = '¡Listo! La clase de prueba de Sofia quedó confirmada para este jueves 14 de noviembre a las 18:00. Las clases de niños son los martes y jueves de 18:00 a 19:00.';
    const eval1 = evaluarRuntimeGuard(leadId, txtValido, turnContext);
    assert.strictEqual(eval1.passed, true, 'Debe permitir confirmación de reserva válida con horario válido');
    assert.strictEqual(eval1.action, 'allow');

    // Caso I2: Respuesta mezcla reserva válida con información comercial contradictoria (5 a 6 pm)
    const txtConContradiccion = '¡Listo! Tu clase quedó confirmada para el jueves 14 de noviembre a las 18:00. Recuerda que las clases de niños son de 5 a 6 pm.';
    const eval2 = evaluarRuntimeGuard(leadId, txtConContradiccion, turnContext);
    assert.strictEqual(eval2.passed, false);
    assert.strictEqual(eval2.action, 'intercept');

    // El fallback seguro DEBE preservar la confirmación de la reserva y NO borrarla
    assert(eval2.safeFallbackText.includes('quedó confirmada para el jueves 14 de noviembre'), 'Debe preservar confirmación transaccional');
    assert(eval2.safeFallbackText.includes('18:00 a 19:00'), 'Debe incluir horarios oficiales corregidos');
    assert(!eval2.safeFallbackText.includes('5 a 6 pm'), 'No debe incluir el horario erróneo');
  });

  // -------------------------------------------------------------
  // CASO J: Datos Firestore ausentes o consulta fallida -> NO INVENTAR INFORMACIÓN
  // -------------------------------------------------------------
  test('Caso J: Datos Firestore ausentes o consulta fallida -> no inventar información', () => {
    // 1. Catálogo vacío
    const repVacia = generarRespuestaComercialOficial([], null, '¿Qué horarios manejan?');
    assert(repVacia.includes('Por favor escríbenos tu consulta y con gusto el instructor te confirmará'));
    assert(!repVacia.includes('17:00'));
    assert(!repVacia.includes('18:00'));

    // 2. Catálogo null
    const repNull = generarRespuestaComercialOficial(null, null, '¿Qué edades tienen?');
    assert(repNull.includes('Por favor escríbenos tu consulta'));
  });

  // -------------------------------------------------------------
  // CASO 6: Solo clases regulares ACTIVAS (excluir inactivas o eventos especiales)
  // -------------------------------------------------------------
  await asyncTest('Caso 6: Solo clases regulares ACTIVAS en generarSystemPrompt', async () => {
    const leadId = '+51984222011';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Prueba Clases Activas',
      status: 'nuevo',
    });

    // Agregar clase regular inactiva
    await firestore.collection('clases').doc('clase_inactiva').set({
      nombre: 'Clase Desactivada',
      tipo: 'regular',
      activa: false,
      hora: '15:00',
      hora_fin: '16:00',
      dias: 'Lunes',
      edad_min: 5,
      edad_max: 10,
    });

    // Agregar evento especial (no regular)
    await firestore.collection('clases').doc('evento_especial').set({
      nombre: 'Taller Especial Fin de Semana',
      tipo: 'evento',
      activa: true,
      hora: '10:00',
      hora_fin: '12:00',
      dias: 'Domingo',
      edad_min: 5,
      edad_max: 50,
    });

    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt, catalogoClases } = await generarSystemPrompt(leadDoc.data(), 1, leadId);

    // Verificar que la clase inactiva NO está en el system prompt ni en catalogoClases
    assert(!systemPrompt.includes('Clase Desactivada'), 'No debe incluir clases inactivas (activa: false)');
    assert(!catalogoClases.some((c) => c.nombre === 'Clase Desactivada'), 'catalogoClases no debe contener clases inactivas');

    // Verificar que el evento especial NO está en el catálogo de clases regulares
    assert(!systemPrompt.includes('Taller Especial Fin de Semana'), 'No debe incluir eventos especiales (tipo != regular)');
    assert(!catalogoClases.some((c) => c.nombre === 'Taller Especial Fin de Semana'), 'catalogoClases no debe contener eventos especiales');
  });

  // -------------------------------------------------------------
  // CASO 7 & 8: Reutilización en turno y prevención de escalación en consulta pura
  // -------------------------------------------------------------
  await asyncTest('Caso 7 y 8: Reutilización de catálogo en turno y no escalación en consulta pura', async () => {
    const leadId = '+51984222012';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Valeria',
      status: 'nuevo',
    });

    const historial = [{ role: 'user', content: '¿Qué horarios manejan para niños?' }];

    // Configurar responder del mock de OpenAI para simular alucinación comercial del incidente
    harness.openai.setResponder(async () => ({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'Hola Valeria, tenemos clases para niños de 4 a 12 años de 5:00 a 6:00 pm.',
          },
        },
      ],
    }));

    try {
      const { systemPrompt, catalogoClases, ubicacionReal } = await generarSystemPrompt(
        (await firestore.collection('whatsapp_leads').doc(leadId).get()).data(),
        1,
        leadId
      );

      // Pasar los datos reutilizados a preguntarIA
      const respuesta = await preguntarIA(
        leadId,
        systemPrompt,
        historial,
        null,
        null,
        catalogoClases,
        ubicacionReal
      );

      // Debe entregar horarios oficiales
      assert(respuesta.includes('18:00 a 19:00'), 'Debe entregar 18:00 a 19:00');
      assert(!respuesta.includes('5:00 a 6:00 pm'), 'No debe contener horario inventado');

      // NO debe haber escalado a humano
      const leadDespues = (await firestore.collection('whatsapp_leads').doc(leadId).get()).data();
      assert.notStrictEqual(leadDespues.status, 'requiere_atencion', 'No debe escalar a humano por consulta informativa');
    } finally {
      harness.openai.reset();
    }
  });

  console.log('\n================================================================');
  console.log(` RESULTADO SUITE P1B: ${passed}/${total} PRUEBAS SUPERADAS (100%)`);
  console.log('================================================================\n');
}

if (require.main === module) {
  runCommercialFactsSuite().catch((err) => {
    console.error('Error fatal en Suite P1B:', err);
    process.exit(1);
  });
}

module.exports = { runCommercialFactsSuite };

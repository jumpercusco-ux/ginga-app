/**
 * real_agent_harness/test_p1b_commercial_facts.js
 * Suite de Regresión P1B: Blindaje Determinista de Horarios y Edades de Catálogo
 * Valida la interceptación, corrección dinámica y prevención de falsos positivos
 * según las especificaciones del Incidente P1 (Prompt 58/59).
 */

const assert = require('assert');
const { RealAgentHarness } = require('./loader');
const { MockTimestamp } = require('./in_memory_firestore');

async function runCommercialFactsSuite() {
  console.log('================================================================');
  console.log('   TEST SUITE P1B: BLINDAJE DETERMINISTA DE HORARIOS Y EDADES');
  console.log('   Ejecución 100% offline y determinista sobre backend real');
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

  // 1. Catálogo oficial representativo de Cusco (idéntico al de Firestore productivo)
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
  // TEST 1: Caso exacto del incidente de WhatsApp Real
  // -------------------------------------------------------------
  test('01_incidente_exacto_whatsapp_detectado_y_reemplazado', () => {
    const textoAlucinadoIncidente =
      'Sí, también tenemos clases para niños en Capoeira FIU Cusco. Los grupos para niños van desde los 4 hasta los 12 años, y las clases son los martes y jueves de 5:00 a 6:00 p.m. en la misma dirección: Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso (justo al costado de la Caja Arequipa). ¿Te gustaría agendar una clase de prueba gratuita para el niño este jueves 12 de noviembre de 2026?';

    const validacion = validarAfirmacionesComerciales(textoAlucinadoIncidente, catalogoOficialCusco);
    assert.strictEqual(validacion.valid, false, 'Debe invalidar horarios y edades no autorizados');
    assert.strictEqual(validacion.contradiction, true);

    const respuestaSegura = generarRespuestaComercialOficial(
      catalogoOficialCusco,
      catalogoOficialCusco[0].ubicacion,
      '¿Tienen clases para niños?'
    );

    assert(respuestaSegura.includes('18:00 a 19:00'), 'Debe contener el horario real de niños (18:00 a 19:00)');
    assert(respuestaSegura.includes('5 a 12 años'), 'Debe contener el rango de edad real (5 a 12 años)');
    assert(!respuestaSegura.includes('17:00'), 'No debe contener 17:00');
    assert(!respuestaSegura.includes('5:00'), 'No debe contener 5:00');
    assert(!respuestaSegura.includes('4 años'), 'No debe contener 4 años');
    assert(respuestaSegura.includes('Divergym'), 'Debe incluir dirección oficial');
  });

  // -------------------------------------------------------------
  // TEST 2: Variantes de horas y edades inválidas
  // -------------------------------------------------------------
  test('02_variantes_horas_y_edades_invalidas', () => {
    const casosInvalidos = [
      { texto: 'Las clases para niños son a las 17:00 hrs.', tipo: 'invalid_schedule_hour' },
      { texto: 'Entrenamos con los niños a las cinco de la tarde.', tipo: 'invalid_schedule_hour' },
      { texto: 'El horario de niños es de 5 a 6 pm los martes.', tipo: 'invalid_schedule_hour' },
      { texto: 'Tenemos clases de niños a las 5:00 pm.', tipo: 'invalid_schedule_hour' },
      { texto: 'Los grupos para niños son de 4 a 12 años.', tipo: 'invalid_kids_age_range' },
      { texto: 'Aceptamos niños desde los 4 años en adelante.', tipo: 'invalid_kids_min_age' },
      { texto: 'Tenemos cupos para chicos de 4-12 años.', tipo: 'invalid_kids_age_range' },
    ];

    for (const c of casosInvalidos) {
      const res = validarAfirmacionesComerciales(c.texto, catalogoOficialCusco);
      assert.strictEqual(res.valid, false, `Debe fallar para: "${c.texto}"`);
      assert.strictEqual(res.contradiction, true);
    }
  });

  // -------------------------------------------------------------
  // TEST 3: Generación según tipo de consulta (General, Niños, Adultos)
  // -------------------------------------------------------------
  test('03_generacion_respuesta_segun_tipo_consulta', () => {
    // Consulta niños
    const repNinos = generarRespuestaComercialOficial(catalogoOficialCusco, catalogoOficialCusco[0].ubicacion, '¿Tienen clases para mi hijo pequeño?');
    assert(repNinos.includes('clases para niños (de 5 a 12 años) los martes y jueves de 18:00 a 19:00'));
    assert(!repNinos.includes('Adultos:'));

    // Consulta adultos
    const repAdultos = generarRespuestaComercialOficial(catalogoOficialCusco, catalogoOficialCusco[0].ubicacion, '¿Qué horarios tienen para adultos?');
    assert(repAdultos.includes('clases para jóvenes y adultos (desde los 13 años) los martes y jueves de 19:00 a 20:00'));
    assert(!repAdultos.includes('clases para niños (de 5 a 12 años)'));

    // Consulta general
    const repGeneral = generarRespuestaComercialOficial(catalogoOficialCusco, catalogoOficialCusco[0].ubicacion, 'Hola, información de horarios por favor');
    assert(repGeneral.includes('Kids (de 5 a 12 años): martes y jueves de 18:00 a 19:00'));
    assert(repGeneral.includes('Adultos (desde los 13 años): martes y jueves de 19:00 a 20:00'));
  });

  // -------------------------------------------------------------
  // TEST 4: Adaptabilidad dinámica ante cambios en el catálogo
  // -------------------------------------------------------------
  test('04_adaptabilidad_dinamica_cambios_catalogo', () => {
    const catalogoNuevo = [
      {
        nombre: 'Infantil Especial',
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

    // Ahora 16:30 es válida, pero 18:00 ya no lo es para este nuevo catálogo
    const valNuevo = validarAfirmacionesComerciales('Las clases son a las 16:30 los lunes.', catalogoNuevo);
    assert.strictEqual(valNuevo.valid, true, '16:30 debe ser válida para catalogoNuevo');

    const valViejo = validarAfirmacionesComerciales('Las clases son a las 18:00 los martes.', catalogoNuevo);
    assert.strictEqual(valViejo.valid, false, '18:00 debe ser inválida si ya no está en el nuevo catálogo');

    const repDinamica = generarRespuestaComercialOficial(catalogoNuevo, 'Sede San Sebastián', '¿Tienen clases para niños?');
    assert(repDinamica.includes('lunes, miércoles y viernes de 16:30 a 17:30'));
    assert(repDinamica.includes('de 7 a 11 años'));
    assert(repDinamica.includes('Sede San Sebastián'));
  });

  // -------------------------------------------------------------
  // TEST 5: Prevención de falsos positivos
  // -------------------------------------------------------------
  test('05_prevencion_falsos_positivos', () => {
    const falsosPositivosPotenciales = [
      '¡Hola! La mensualidad regular es de S/140 por persona.',
      'Te esperamos el martes 17 de noviembre en nuestra sede.',
      'Como tu hijo tiene 4 años, le consultaré al profesor si puede ingresar.',
      'El número de WhatsApp termina en 1700.',
      'Tenemos más de 17 años de experiencia enseñando Capoeira en Cusco.',
    ];

    for (const txt of falsosPositivosPotenciales) {
      const res = validarAfirmacionesComerciales(txt, catalogoOficialCusco);
      assert.strictEqual(res.valid, true, `No debe dar falso positivo en: "${txt}"`);
    }
  });

  // -------------------------------------------------------------
  // TEST 6: Resiliencia ante falla de Firestore o catálogo vacío
  // -------------------------------------------------------------
  test('06_resiliencia_catalogo_vacio', () => {
    const repVacia = generarRespuestaComercialOficial([], null, '¿Qué horarios manejan?');
    assert(repVacia.includes('Por favor escríbenos tu consulta y con gusto el instructor te confirmará'));

    const repNull = generarRespuestaComercialOficial(null, null, '¿Tienen para niños?');
    assert(repNull.includes('Por favor escríbenos tu consulta'));
  });

  // -------------------------------------------------------------
  // TEST 7: Extracción de catálogo desde systemPrompt
  // -------------------------------------------------------------
  test('07_extraccion_catalogo_desde_system_prompt', () => {
    const mockSystemPrompt = `
Eres Ginga, asistente virtual de Capoeira FIU Cusco.

[CATÁLOGO OFICIAL DE CLASES Y HORARIOS REGULARES]
Usa ESTOS horarios y edades exactos para informar a los clientes. NUNCA inventes otros horarios ni edades diferentes:
- Grupo: Kids | Días: martes y jueves | Horario: 18:00 a 19:00 | Edades: 5 a 12 años (rango exacto)
- Grupo: Adultos | Días: martes y jueves | Horario: 19:00 a 20:00 | Edades: 13 años en adelante (sin tope)

DIRECCIÓN REAL (la única válida, cópiala tal cual, no la parafrasees ni cambies pisos/referencias): Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso
`;

    const catalogoExtraido = extraerCatalogoClasesOficiales(mockSystemPrompt);
    assert.strictEqual(catalogoExtraido.length, 2, 'Debe extraer 2 clases');

    const kids = catalogoExtraido.find((c) => c.nombre === 'Kids');
    assert.strictEqual(kids.hora, '18:00');
    assert.strictEqual(kids.hora_fin, '19:00');
    assert.strictEqual(kids.edad_min, 5);
    assert.strictEqual(kids.edad_max, 12);
    assert.strictEqual(kids.publico, 'niños');
    assert(kids.ubicacion.includes('Divergym'));

    const adultos = catalogoExtraido.find((c) => c.nombre === 'Adultos');
    assert.strictEqual(adultos.hora, '19:00');
    assert.strictEqual(adultos.hora_fin, '20:00');
    assert.strictEqual(adultos.edad_min, 13);
    assert.strictEqual(adultos.sinTopeSuperior, true);
  });

  // -------------------------------------------------------------
  // TEST 8: Runtime Guard intercepta y genera fallback sin escalar
  // -------------------------------------------------------------
  test('08_runtime_guard_intercepta_contradiccion_comercial_y_asigna_safe_fallback', () => {
    const leadId = '+51984222001';
    const turnContext = new TurnContext(leadId, null, catalogoOficialCusco, catalogoOficialCusco[0].ubicacion);

    const textoAlucinado = 'Tenemos clases para niños los martes y jueves de 5:00 a 6:00 p.m. de 4 a 12 años.';
    const evaluacion = evaluarRuntimeGuard(leadId, textoAlucinado, turnContext);

    assert.strictEqual(evaluacion.passed, false, 'Runtime Guard debe fallar ante contradicción comercial');
    assert.strictEqual(evaluacion.action, 'intercept');
    assert(evaluacion.intercepted_claims.includes('commercial_fact_contradiction'));
    assert(evaluacion.safeFallbackText.includes('18:00 a 19:00'), 'safeFallbackText debe contener 18:00 a 19:00');
    assert(evaluacion.safeFallbackText.includes('5 a 12 años'), 'safeFallbackText debe contener 5 a 12 años');
  });

  // -------------------------------------------------------------
  // TEST 9: preguntarIA no escala a humano ante contradicción comercial pura
  // -------------------------------------------------------------
  await asyncTest('09_preguntarIA_no_escala_a_humano_en_consulta_informativa', async () => {
    const leadId = '+51984222002';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Carlos',
      status: 'nuevo',
    });

    const historial = [{ role: 'user', content: '¿Qué horarios tienen para los pequeños?' }];
    const turnContext = new TurnContext(leadId, null, catalogoOficialCusco, catalogoOficialCusco[0].ubicacion);

    // Mockeamos llamarOpenAI mediante el responder del harness para simular que OpenAI respondió con alucinación de horarios
    const alucinacionLLM = 'Hola Carlos, para los niños tenemos clases de 4 a 12 años los martes de 5 a 6 pm.';
    harness.openai.setResponder(async () => ({
      choices: [
        {
          message: {
            role: 'assistant',
            content: alucinacionLLM,
          },
        },
      ],
    }));

    try {
      const systemPrompt = `[CATÁLOGO OFICIAL DE CLASES Y HORARIOS REGULARES]
- Grupo: Kids | Días: martes y jueves | Horario: 18:00 a 19:00 | Edades: 5 a 12 años (rango exacto)
DIRECCIÓN REAL: Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso`;

      const respuestaFinal = await preguntarIA(
        leadId,
        systemPrompt,
        historial,
        null,
        null,
        catalogoOficialCusco,
        catalogoOficialCusco[0].ubicacion
      );

      // 1. Debe haber sustituido la alucinación por la respuesta oficial
      assert(respuestaFinal.includes('18:00 a 19:00'), 'Debe entregar 18:00 a 19:00 al usuario');
      assert(!respuestaFinal.includes('5 a 6 pm'), 'No debe entregar 5 a 6 pm');

      // 2. El status del lead en Firestore NO debe haberse marcado como requiere_atencion
      const leadDocDespues = await firestore.collection('whatsapp_leads').doc(leadId).get();
      assert.notStrictEqual(
        leadDocDespues.data()?.status,
        'requiere_atencion',
        'No debe escalar a humano (Regla 20: no escalación innecesaria) en consultas informativas'
      );
    } finally {
      harness.openai.reset();
    }
  });

  // -------------------------------------------------------------
  // TEST 10: Inyección completa en generarSystemPrompt desde Firestore
  // -------------------------------------------------------------
  await asyncTest('10_generarSystemPrompt_inyecta_catalogo_completo_desde_firestore', async () => {
    const leadId = '+51984222003';
    await firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Luciana',
      status: 'nuevo',
    });

    const leadDoc = await firestore.collection('whatsapp_leads').doc(leadId).get();
    const { systemPrompt, catalogoClases, ubicacionReal } = await generarSystemPrompt(leadDoc.data(), 1, leadId);

    assert(systemPrompt.includes('[CATÁLOGO OFICIAL DE CLASES Y HORARIOS REGULARES]'), 'Debe incluir encabezado del catálogo');
    assert(systemPrompt.includes('Grupo: Capoeira Niños'), 'Debe incluir grupo de niños');
    assert(systemPrompt.includes('Grupo: Capoeira Jóvenes y Adultos'), 'Debe incluir grupo de adultos');
    assert(systemPrompt.includes('DIRECCIÓN REAL'), 'Debe incluir dirección real');

    assert(Array.isArray(catalogoClases) && catalogoClases.length >= 2, 'catalogoClases debe tener al menos 2 grupos');
    assert(Boolean(ubicacionReal), 'ubicacionReal debe estar poblada');
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

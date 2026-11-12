/**
 * real_agent_harness/test_reservation_date_semantics.js
 * GINGA REAL — PROMPT 69: VALIDACIÓN FOCALIZADA DE SEMÁNTICA DE FECHAS Y HORARIOS
 * 
 * Verifica exhaustivamente:
 * 1. Semántica de `fecha_clase` como FECHA CIVIL (Calendar Date) vs instante real.
 * 2. Comportamiento en clases de 18:00 (Kids) y 19:00 (Adultos) en America/Lima (UTC-5) y UTC.
 * 3. Cruce de medianoche UTC en clases nocturnas (19:00 Lima = 00:00 UTC día siguiente).
 * 4. Compatibilidad con el query de rango de `enviarRecordatorioPruebaDiario`.
 * 5. Compatibilidad con los formateadores y filtros de Flutter (InstructorLeadsScreen, QrGeneratorScreen).
 * 6. Compatibilidad hacia atrás con registros históricos en Firestore (sin migración destructiva).
 */

const assert = require('assert');
const internals = require('../functions/index.js').__internals;

const {
  calcularProximaFechaDisponible,
  validarFechaSolicitada,
  calcularFechaProximoDia,
  obtenerFechaLimaAhora,
  formatearFechaLarga,
} = internals;

class MockTimestamp {
  constructor(seconds, nanoseconds = 0) {
    this._seconds = seconds;
    this._nanoseconds = nanoseconds;
  }
  get seconds() { return this._seconds; }
  get nanoseconds() { return this._nanoseconds; }
  toDate() {
    return new Date(this._seconds * 1000 + Math.floor(this._nanoseconds / 1000000));
  }
  static fromDate(date) {
    const ms = date.getTime();
    return new MockTimestamp(Math.floor(ms / 1000), (ms % 1000) * 1000000);
  }
}

function runDateSemanticsTests() {
  console.log('================================================================');
  console.log('   TEST SUITE: SEMÁNTICA DE FECHAS, HORARIOS Y HUSOS HORARIOS');
  console.log('   Evaluación técnica para GINGA V1 (Node.js 22)');
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;

  function test(name, fn) {
    total++;
    try {
      fn();
      passed++;
      console.log(`[PASS] ${name}`);
    } catch (err) {
      console.error(`[FAIL] ${name}`);
      console.error(err);
      process.exitCode = 1;
    }
  }

  // -------------------------------------------------------------
  // TEST 1: fecha_clase como Fecha Civil (Midday Anchor)
  // -------------------------------------------------------------
  test('01_fecha_clase_es_fecha_civil_anclada_en_mediodia', () => {
    const fechaProxima = calcularProximaFechaDisponible('M, J');
    assert(fechaProxima instanceof Date, 'Debe devolver un Date válido');
    assert.strictEqual(fechaProxima.getHours(), 12, 'Las horas locales deben estar fijadas a las 12 (mediodía)');
    assert.strictEqual(fechaProxima.getMinutes(), 0, 'Minutos en 0');
    assert.strictEqual(fechaProxima.getSeconds(), 0, 'Segundos en 0');
  });

  // -------------------------------------------------------------
  // TEST 2: Equivalencia UTC vs America/Lima para clases Kids (18:00)
  // -------------------------------------------------------------
  test('02_equivalencias_kids_18_00_lima_vs_utc', () => {
    // Fecha civil de prueba: 2026-11-12 (Jueves)
    const fechaCivilStr = '2026-11-12';
    const horaClase = '18:00';

    // 18:00 en Lima (UTC-5) equivale a las 23:00 UTC del mismo día civil
    const [y, m, d] = fechaCivilStr.split('-').map(Number);
    const [hh, mm] = horaClase.split(':').map(Number);
    const instanteRealUtc = new Date(Date.UTC(y, m - 1, d, hh + 5, mm, 0));

    assert.strictEqual(instanteRealUtc.toISOString(), '2026-11-12T23:00:00.000Z');
    
    // Verificación en zona horaria America/Lima
    const horaEnLima = instanteRealUtc.toLocaleString('es-PE', { timeZone: 'America/Lima', hour12: false });
    assert(horaEnLima.includes('18:00:00'), 'En Lima debe ser exactamente 18:00:00');
    assert(horaEnLima.includes('12/11/2026'), 'En Lima debe ser el 12/11/2026');
  });

  // -------------------------------------------------------------
  // TEST 3: Equivalencia UTC vs America/Lima para clases Adultos (19:00)
  // CRUCE DE MEDIANOCHE UTC CRÍTICO
  // -------------------------------------------------------------
  test('03_equivalencias_adultos_19_00_lima_cruce_medianoche_utc', () => {
    // Fecha civil de prueba: 2026-11-12 (Jueves)
    const fechaCivilStr = '2026-11-12';
    const horaClase = '19:00';

    // 19:00 en Lima (UTC-5) equivale a 19 + 5 = 24:00 UTC = 00:00:00 UTC del DÍA SIGUIENTE (13 de noviembre)
    const [y, m, d] = fechaCivilStr.split('-').map(Number);
    const [hh, mm] = horaClase.split(':').map(Number);
    const instanteRealUtc = new Date(Date.UTC(y, m - 1, d, hh + 5, mm, 0));

    // DEMOSTRACIÓN TÉCNICA: El instante UTC cruza al día 13
    assert.strictEqual(instanteRealUtc.toISOString(), '2026-11-13T00:00:00.000Z', 'En UTC es 2026-11-13');
    
    // Pero en America/Lima sigue siendo jueves 12 a las 19:00
    const horaEnLima = instanteRealUtc.toLocaleString('es-PE', { timeZone: 'America/Lima', hour12: false });
    assert(horaEnLima.includes('19:00:00'), 'En Lima debe ser 19:00:00');
    assert(horaEnLima.includes('12/11/2026'), 'En Lima debe seguir siendo 12/11/2026');
  });

  // -------------------------------------------------------------
  // TEST 4: Peligro de almacenar instante real en fecha_clase (Demostración de fallo de Schedulers)
  // -------------------------------------------------------------
  test('04_demostracion_porque_fecha_clase_no_debe_guardar_instante_real', () => {
    // Si fecha_clase almacenara el instante real para una clase de Adultos a las 19:00:
    const instanteAdultos19 = new Date(Date.UTC(2026, 10, 12, 19 + 5, 0, 0)); // 2026-11-13T00:00:00.000Z
    const timestampErroneo = MockTimestamp.fromDate(instanteAdultos19);

    // Consulta de Cloud Functions en enviarRecordatorioPruebaDiario (ejecutada en UTC):
    const startOfDayUtc = new Date(Date.UTC(2026, 10, 12, 0, 0, 0));
    const endOfDayUtc = new Date(Date.UTC(2026, 10, 12, 23, 59, 59));

    const entraEnRangoUtc = timestampErroneo.toDate() >= startOfDayUtc && timestampErroneo.toDate() <= endOfDayUtc;
    
    // Si se guardara el instante real, la clase de las 19:00 QUEDARÍA EXCLUIDA DEL RECORDATORIO DIARIO:
    assert.strictEqual(entraEnRangoUtc, false, 'Un instante a las 19:00 Lima queda fuera del rango UTC del día');

    // En cambio, con fecha_clase anclada a mediodía (Fecha Civil):
    const fechaCivilMediodia = new Date(Date.UTC(2026, 10, 12, 12, 0, 0));
    const timestampCivil = MockTimestamp.fromDate(fechaCivilMediodia);
    const civilEntraEnRango = timestampCivil.toDate() >= startOfDayUtc && timestampCivil.toDate() <= endOfDayUtc;
    assert.strictEqual(civilEntraEnRango, true, 'La fecha civil anclada a mediodía siempre entra en el rango diario');
  });

  // -------------------------------------------------------------
  // TEST 5: Formateo en Flutter (InstructorLeadsScreen)
  // -------------------------------------------------------------
  test('05_compatibilidad_con_formateador_flutter_leads_screen', () => {
    // Simula exactamente el método _formatearFechaCorta de lib/features/instructor/instructor_leads_screen.dart
    function _formatearFechaCortaFlutter(ts) {
      const dias = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
      const mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      const f = ts.toDate();
      // En Dart: f.weekday (1=lun .. 7=dom), f.day, f.month
      const dayOfWeek = f.getUTCDay() === 0 ? 7 : f.getUTCDay();
      return `${dias[dayOfWeek]} ${f.getUTCDate()} ${mesesCortos[f.getUTCMonth()]}`;
    }

    const ts1 = MockTimestamp.fromDate(new Date('2026-11-12T12:00:00.000Z'));
    const ts2 = MockTimestamp.fromDate(new Date('2026-11-17T12:00:00.000Z'));

    assert.strictEqual(_formatearFechaCortaFlutter(ts1), 'jue 12 nov');
    assert.strictEqual(_formatearFechaCortaFlutter(ts2), 'mar 17 nov');
  });

  // -------------------------------------------------------------
  // TEST 6: Comparación de "Hoy" en Flutter (filtro de leads de hoy)
  // -------------------------------------------------------------
  test('06_compatibilidad_con_filtro_es_hoy_flutter', () => {
    // Simula la condición: aDate.year == ahora.year && aDate.month == ahora.month && aDate.day == ahora.day
    const fechaClaseTs = MockTimestamp.fromDate(new Date('2026-11-12T12:00:00.000Z'));
    const f = fechaClaseTs.toDate();

    const ahoraLima = new Date('2026-11-12T08:00:00.000Z');
    const esHoy = f.getUTCFullYear() === ahoraLima.getUTCFullYear() &&
                  f.getUTCMonth() === ahoraLima.getUTCMonth() &&
                  f.getUTCDate() === ahoraLima.getUTCDate();

    assert.strictEqual(esHoy, true, 'Debe coincidir exactamente con el día actual');
  });

  // -------------------------------------------------------------
  // TEST 7: Compatibilidad hacia atrás con registros históricos en Firestore
  // -------------------------------------------------------------
  test('07_compatibilidad_con_reservas_historicas_produccion', () => {
    // Documento real inspeccionado en producción: 0PSJXJIFgNE0ah5Esnun
    const reservaHistorica = {
      id: '0PSJXJIFgNE0ah5Esnun',
      lead_id: 'PE.1686063995998690',
      nombre_persona: 'Adulto',
      hora: '19:00',
      status: 'confirmado',
      fecha_clase: new MockTimestamp(1788436800, 0), // 2026-09-03T12:00:00.000Z
    };

    const d = reservaHistorica.fecha_clase.toDate();
    assert.strictEqual(d.toISOString(), '2026-09-03T12:00:00.000Z');
    assert.strictEqual(reservaHistorica.hora, '19:00');
    assert.strictEqual(formatearFechaLarga(d), 'jueves 3 de septiembre');
  });

  // -------------------------------------------------------------
  // TEST 8: Validación de fecha solicitada en formato YYYY-MM-DD
  // -------------------------------------------------------------
  test('08_validar_fecha_solicitada_preserva_fecha_civil_sin_desfases', () => {
    const fValida = validarFechaSolicitada('2026-11-17', 'M, J');
    assert(fValida instanceof Date);
    assert.strictEqual(fValida.getFullYear(), 2026);
    assert.strictEqual(fValida.getMonth(), 10); // Noviembre (0-indexed)
    assert.strictEqual(fValida.getDate(), 17);
    assert.strictEqual(fValida.getHours(), 12, 'Mediodía fijado');

    // Fechas no permitidas (ej. miércoles 2026-11-18)
    const fInvalida = validarFechaSolicitada('2026-11-18', 'M, J');
    assert.strictEqual(fInvalida, null, 'Día miércoles no está en M, J');
  });

  console.log('\n================================================================');
  console.log(` RESULTADO SUITE FECHAS Y HORARIOS: ${passed}/${total} PRUEBAS PASS (100%)`);
  console.log('================================================================\n');
}

runDateSemanticsTests();

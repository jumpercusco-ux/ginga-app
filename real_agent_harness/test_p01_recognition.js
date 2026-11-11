/**
 * Test Suite for P0.1: Reconocimiento de Reservas Confirmadas
 * Tests cases A through J in real_agent_harness without external calls.
 */

const { RealAgentHarness } = require('./loader');
const { MockTimestamp } = require('./in_memory_firestore');

async function runP01Tests() {
  const harness = new RealAgentHarness();
  const results = [];

  console.log('================================================================');
  console.log('   TEST SUITE P0.1: RECONOCIMIENTO DE RESERVAS CONFIRMADAS');
  console.log('================================================================\n');

  // Helper date generators in America/Lima
  const limaNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'America/Lima' }));
  const hoyStr = `${limaNow.getFullYear()}-${String(limaNow.getMonth() + 1).padStart(2, '0')}-${String(limaNow.getDate()).padStart(2, '0')}`;

  const manana = new Date(limaNow);
  manana.setDate(manana.getDate() + 1);

  const proxSemana = new Date(limaNow);
  proxSemana.setDate(proxSemana.getDate() + 7);

  const ayer = new Date(limaNow);
  ayer.setDate(ayer.getDate() - 1);

  const haceDosSemanas = new Date(limaNow);
  haceDosSemanas.setDate(haceDosSemanas.getDate() - 14);

  // A. Lead nuevo sin reservas
  {
    harness.reset();
    const leadId = '+51984000101';
    const res = await harness.dispatchMessage(leadId, 'Hola, quisiera información de capoeira');
    const hasReservationBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    results.push({
      caseId: 'A',
      name: 'Lead nuevo sin reservas',
      passed: !hasReservationBlock,
      detail: !hasReservationBlock
        ? 'Correcto: System prompt no incluye bloque de reservas.'
        : 'Error: Se inyectó bloque de reservas a un lead nuevo.',
    });
  }

  // B. Reserva futura confirmada
  {
    harness.reset();
    const leadId = '+51984000102';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Claudia',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });
    await harness.firestore.collection('reservas').doc('res_b').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola, ¿a qué hora es la clase?');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const hasName = res.systemPrompt.includes('Valentina');
    const hasHour = res.systemPrompt.includes('18:00');
    const passed = hasBlock && hasName && hasHour;
    results.push({
      caseId: 'B',
      name: 'Reserva futura confirmada',
      passed,
      detail: passed
        ? 'Correcto: El prompt inyecta la reserva futura de Valentina con fecha y hora.'
        : 'Fallo: El prompt no reconoció la reserva futura confirmada.',
    });
  }

  // C. Reserva para hoy (pendiente)
  {
    harness.reset();
    const leadId = '+51984000103';
    // Hora futura para hoy
    const horaClaseHoy = '23:59';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Rodrigo',
      status: 'reservado',
    });
    await harness.firestore.collection('reservas').doc('res_c').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      nivel: 'Iniciación Infantil',
      hora: horaClaseHoy,
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(limaNow),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola, ¿es hoy la clase?');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const mentionsHoy = res.systemPrompt.includes('HOY');
    const passed = hasBlock && mentionsHoy;
    results.push({
      caseId: 'C',
      name: 'Reserva para hoy pendiente',
      passed,
      detail: passed
        ? 'Correcto: El prompt reconoce que la reserva es para HOY.'
        : 'Fallo: No reconoció la reserva pendiente para hoy.',
    });
  }

  // D. Reserva cancelada
  {
    harness.reset();
    const leadId = '+51984000104';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Carla',
      status: 'perdido',
    });
    await harness.firestore.collection('reservas').doc('res_d').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'cancelado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const passed = !hasBlock;
    results.push({
      caseId: 'D',
      name: 'Reserva cancelada no se trata como confirmada',
      passed,
      detail: passed
        ? 'Correcto: La reserva cancelada no fue inyectada como confirmada vigente.'
        : 'Fallo: Una reserva cancelada fue tratada como vigente.',
    });
  }

  // E. Reserva pasada
  {
    harness.reset();
    const leadId = '+51984000105';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Luciano',
    });
    await harness.firestore.collection('reservas').doc('res_e').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(haceDosSemanas),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const passed = !hasBlock;
    results.push({
      caseId: 'E',
      name: 'Reserva pasada no se trata como confirmada vigente',
      passed,
      detail: passed
        ? 'Correcto: La fecha pasada fue descartada y no se inyectó como vigente.'
        : 'Fallo: Una reserva pasada fue tratada como vigente.',
    });
  }

  // F. Estado asistió
  {
    harness.reset();
    const leadId = '+51984000106';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Marcos',
    });
    await harness.firestore.collection('reservas').doc('res_f').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'asistio',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const passed = !hasBlock;
    results.push({
      caseId: 'F',
      name: 'Estado asistió no se inyecta como reserva pendiente',
      passed,
      detail: passed
        ? 'Correcto: Status asistio no se trata como reserva pendiente.'
        : 'Fallo: Reserva marcada como asistió fue tratada como pendiente.',
    });
  }

  // G. Estado no asistió
  {
    harness.reset();
    const leadId = '+51984000107';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Gabriel',
    });
    await harness.firestore.collection('reservas').doc('res_g').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'no_asistio',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const passed = !hasBlock;
    results.push({
      caseId: 'G',
      name: 'Estado no asistió no se inyecta como pendiente',
      passed,
      detail: passed
        ? 'Correcto: Status no_asistio no se trata como reserva confirmada vigente.'
        : 'Fallo: Status no_asistio fue inyectado como reserva confirmada.',
    });
  }

  // H. Familia con dos hijos
  {
    harness.reset();
    const leadId = '+51984000108';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Patricia',
      status: 'reservado',
      reserva_id: 'res_h_lucia', // Escalar solo tiene a Lucía
    });
    await harness.firestore.collection('reservas').doc('res_h_mateo').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'confirmado',
      tipo: 'prueba',
    });
    await harness.firestore.collection('reservas').doc('res_h_lucia').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Lucía',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola, ¿a qué hora van mis hijos?');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const hasMateo = res.systemPrompt.includes('Mateo');
    const hasLucia = res.systemPrompt.includes('Lucía');
    const passed = hasBlock && hasMateo && hasLucia;
    results.push({
      caseId: 'H',
      name: 'Familia con dos hijos reconoce ambas reservas',
      passed,
      detail: passed
        ? 'Correcto: Reconoció a Mateo y Lucía independientemente del escalar en el lead.'
        : 'Fallo: No reconoció a ambos hijos por separado.',
    });
  }

  // I. Error de consulta Firestore (fail-safe)
  {
    harness.reset();
    const leadId = '+51984000109';
    // Simular error en get() de reservas durante generarSystemPrompt
    const originalCollection = harness.firestore.collection.bind(harness.firestore);
    let throwOnce = true;
    harness.firestore.collection = (name) => {
      if (name === 'reservas' && throwOnce) {
        throwOnce = false;
        return {
          where: () => ({
            limit: () => ({
              get: async () => {
                throw new Error('Simulated Firestore Network Timeout');
              },
            }),
          }),
        };
      }
      return originalCollection(name);
    };

    let caughtError = false;
    let res = null;
    try {
      res = await harness.dispatchMessage(leadId, 'Hola');
    } catch (_) {
      caughtError = true;
    }

    harness.firestore.collection = originalCollection;

    const hasBlock = res?.systemPrompt?.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const passed = !caughtError && res && !hasBlock;
    results.push({
      caseId: 'I',
      name: 'Error de consulta Firestore maneja fail-safe sin caerse',
      passed,
      detail: passed
        ? 'Correcto: Ante error en Firestore, no crasheó y no inventó reservas confirmadas.'
        : 'Fallo: El error de Firestore no fue manejado de forma segura.',
    });
  }

  // J. No duplicación de preguntas de registro al contar con reserva válida
  {
    harness.reset();
    const leadId = '+51984000110';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Marisol',
      status: 'reservado',
    });
    await harness.firestore.collection('reservas').doc('res_j').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola, buenas tardes');
    const promptHasDirective =
      res.systemPrompt.includes('NUNCA le vuelvas a preguntar el nombre, edad ni datos de registro') &&
      res.systemPrompt.includes('NUNCA le ofrezcas agendar clase de prueba desde cero');
    const passed = promptHasDirective;
    results.push({
      caseId: 'J',
      name: 'Directivas contra duplicación de preguntas de registro',
      passed,
      detail: passed
        ? 'Correcto: El prompt prohíbe taxativamente volver a pedir nombre/edad u ofrecer agendar.'
        : 'Fallo: Faltan directivas explícitas contra la duplicación.',
    });
  }

  // K. Reserva de HOY que ya terminó (hora ya pasada)
  {
    harness.reset();
    const leadId = '+51984000111';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Renato',
      status: 'reservado',
    });
    // Clase fijada para las 06:00 de hoy (hora ya pasada respecto a la hora actual de Lima)
    await harness.firestore.collection('reservas').doc('res_k').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      nivel: 'Iniciación Infantil',
      hora: '06:00',
      fecha_clase: MockTimestamp.fromDate(limaNow),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola');
    const hasBlock = res.systemPrompt.includes('[RESERVAS CONFIRMADAS VIGENTES');
    const passed = !hasBlock;
    results.push({
      caseId: 'K',
      name: 'Reserva de hoy que ya terminó no se inyecta como vigente',
      passed,
      detail: passed
        ? 'Correcto: Clase de hoy con hora transcurrida no fue tratada como reserva pendiente.'
        : 'Fallo: Se trató como vigente una clase de hoy que ya había terminado.',
    });
  }

  // L. Directivas de no confirmar reprogramaciones falsas
  {
    harness.reset();
    const leadId = '+51984000112';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Daniela',
      status: 'reservado',
    });
    await harness.firestore.collection('reservas').doc('res_l').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Quiero cambiar la fecha de Mateo');
    const hasReprogWarning =
      res.systemPrompt.includes('NUNCA confirmes que el cambio ya está realizado de palabra') &&
      res.systemPrompt.includes('marcar_seguimiento_humano');
    const passed = hasReprogWarning;
    results.push({
      caseId: 'L',
      name: 'Protección contra confirmaciones falsas de reprogramación/cancelación',
      passed,
      detail: passed
        ? 'Correcto: El prompt prohíbe promesas falsas de reprogramación y exige derivar con marcar_seguimiento_humano.'
        : 'Fallo: Falta directiva de no confirmación falsa ante reprogramaciones.',
    });
  }

  // M. Neutralidad de género en el contexto
  {
    harness.reset();
    const leadId = '+51984000113';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Esteban',
      status: 'reservado',
    });
    await harness.firestore.collection('reservas').doc('res_m').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      fecha_clase: MockTimestamp.fromDate(proxSemana),
      status: 'confirmado',
      tipo: 'prueba',
    });

    const res = await harness.dispatchMessage(leadId, 'Hola');
    const hasNeutralDirective =
      res.systemPrompt.includes('Asistente: Mateo') &&
      res.systemPrompt.includes('sin asumir género por el nombre');
    const passed = hasNeutralDirective;
    results.push({
      caseId: 'M',
      name: 'Neutralidad de género en contexto y directivas',
      passed,
      detail: passed
        ? 'Correcto: Usa términos neutrales (Asistente, persona) y prohíbe inferir género por nombre.'
        : 'Fallo: Se encontraron términos no neutrales o inferencia de género.',
    });
  }

  // N. Advertencia fail-safe ante error en Firestore
  {
    harness.reset();
    const leadId = '+51984000114';
    const originalCollection = harness.firestore.collection.bind(harness.firestore);
    let throwOnce = true;
    harness.firestore.collection = (name) => {
      if (name === 'reservas' && throwOnce) {
        throwOnce = false;
        return {
          where: () => ({
            where: () => ({
              limit: () => ({
                get: async () => {
                  throw new Error('Simulated Database Unavailability');
                },
              }),
            }),
          }),
        };
      }
      return originalCollection(name);
    };

    const res = await harness.dispatchMessage(leadId, 'Hola');
    harness.firestore.collection = originalCollection;

    const hasFailSafeWarning =
      res.systemPrompt.includes('AVISO DE SEGURIDAD (ERROR DE LECTURA DE RESERVAS)') &&
      res.systemPrompt.includes('NO intentes crear una nueva reserva a ciegas') &&
      res.systemPrompt.includes('marcar_seguimiento_humano');
    const passed = hasFailSafeWarning;
    results.push({
      caseId: 'N',
      name: 'Aviso de seguridad y fail-safe explícito ante error de lectura',
      passed,
      detail: passed
        ? 'Correcto: Se inyectó advertencia que prohíbe reservas a ciegas y escala a seguimiento humano.'
        : 'Fallo: Falta advertencia fail-safe ante caída de lectura de base de datos.',
    });
  }

  console.log('----------------------------------------------------------------');
  results.forEach((r) => {
    const badge = r.passed ? '[PASS]' : '[FAIL]';
    console.log(`${badge} Caso ${r.caseId}: ${r.name}`);
    console.log(`       ${r.detail}`);
  });
  console.log('----------------------------------------------------------------');
  const allPassed = results.every((r) => r.passed);
  console.log(`Resultado Global: ${allPassed ? `TODAS LAS PRUEBAS PASARON (${results.length}/${results.length})` : 'HAY FALLOS'}\n`);

  return results;
}

if (require.main === module) {
  runP01Tests().catch(console.error);
}

module.exports = { runP01Tests };

/**
 * Comprehensive Test Suite for P0.2A: Reprogramación Segura e Integridad de Reservas
 * 
 * Verifies:
 * 1. Rescheduling Tuesday to Thursday
 * 2. Rescheduling Thursday to Tuesday
 * 3. Multi-child isolation (Valentina and Mateo)
 * 4. Non-existent reservation error handling
 * 5. Cancelled reservation handling (blocks rescheduling, allows new booking)
 * 6. Attended reservation commercial policy (blocks free class, escalates to human)
 * 7. No-show reservation commercial policy (blocks automated reschedule, escalates)
 * 8. Past/expired reservation handling
 * 9. Full class capacity check (cupos_disponibles <= 0)
 * 10. Invalid date handling (preserves original reservation, no false confirmation)
 * 11. Repeated rescheduling audit trail (multiple history entries)
 * 12. Concurrency & idempotency (optimistic lock in whatsapp_leads)
 * 13. Firestore write error fail-safe (prevents false confirmation)
 * 14. Hallucinated confirmation detection
 * 15. Multi-venue & legacy backward compatibility (missing sede_id)
 * 16. Multi-child profile merge in guardar_perfil_lead
 */

const { RealAgentHarness } = require('./loader');
const { MockTimestamp } = require('./in_memory_firestore');

async function runP02aTests() {
  const harness = new RealAgentHarness();
  const results = [];

  console.log('================================================================');
  console.log('   TEST SUITE P0.2A: REPROGRAMACIÓN SEGURA E INTEGRIDAD DE RESERVAS');
  console.log('   Ejecución 100% offline y aislada sobre lógica real del backend');
  console.log('================================================================\n');

  // Fechas de prueba futuras fijas en horario de clases (M, J)
  // 2026-11-17 es Martes, 2026-11-19 es Jueves, 2026-11-24 es Martes
  const fechaMartes1 = new Date('2026-11-17T18:00:00');
  const fechaJueves1 = new Date('2026-11-19T18:00:00');
  const fechaMartes2 = new Date('2026-11-24T18:00:00');

  // 1. Reprogramación de Martes a Jueves
  {
    harness.reset();
    const leadId = '+51984100001';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Valeria',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
      reserva_id: 'res_val_tue',
      clase_reservada_id: 'clase_ninos_regular',
      fecha_clase_reservada: MockTimestamp.fromDate(fechaMartes1),
      reservas_activas: {
        valentina: {
          reserva_id: 'res_val_tue',
          clase_id: 'clase_ninos_regular',
          nombre_persona: 'Valentina',
          fecha_clase: MockTimestamp.fromDate(fechaMartes1),
          status: 'confirmado',
          hora: '18:00',
        },
      },
    });

    await harness.firestore.collection('reservas').doc('res_val_tue').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      tipo: 'prueba',
      origen: 'whatsapp',
    });

    const res = await harness.dispatchMessage(
      leadId,
      'Hola, teníamos agendado para Valentina el martes pero no podemos ir, ¿podemos cambiar para el jueves 2026-11-19?'
    );

    const toolReprog = res.executedTools.find((t) => t.name === 'reprogramar_reserva');
    const reservaDoc = await harness.firestore.collection('reservas').doc('res_val_tue').get();
    const leadDoc = await harness.firestore.collection('whatsapp_leads').doc(leadId).get();

    const nuevaFechaRes = reservaDoc.data()?.fecha_clase?.toDate();
    const tieneAuditoria = Array.isArray(reservaDoc.data()?.reprogramaciones) && reservaDoc.data().reprogramaciones.length === 1;
    const leadActualizado = leadDoc.data()?.reservas_activas?.valentina?.fecha_clase?.toDate()?.toISOString() === nuevaFechaRes?.toISOString();

    const passed = Boolean(
      toolReprog &&
      reservaDoc.data()?.status === 'confirmado' &&
      nuevaFechaRes?.getDate() === 19 &&
      tieneAuditoria &&
      leadActualizado &&
      res.replyText.toLowerCase().includes('reprogram')
    );

    results.push({
      id: '01_martes_a_jueves',
      name: 'Reprogramación exitosa de Martes a Jueves',
      passed,
      detail: passed
        ? 'Correcto: Se ejecutó reprogramar_reserva, Firestore se actualizó a jueves, se guardó auditoría y el lead fue notificado.'
        : `Fallo: tool=${Boolean(toolReprog)}, fecha=${nuevaFechaRes}, auditoria=${tieneAuditoria}`,
    });
  }

  // 2. Reprogramación de Jueves a Martes siguiente
  {
    harness.reset();
    const leadId = '+51984100002';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Carlos',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Mateo', tipo: 'niño', edad: 8 }],
      reserva_id: 'res_mat_thu',
      clase_reservada_id: 'clase_ninos_regular',
      fecha_clase_reservada: MockTimestamp.fromDate(fechaJueves1),
    });

    await harness.firestore.collection('reservas').doc('res_mat_thu').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaJueves1),
      status: 'confirmado',
      tipo: 'prueba',
      origen: 'whatsapp',
    });

    const res = await harness.dispatchMessage(
      leadId,
      'Hola, por favor reprogramar a Mateo para el martes 2026-11-24'
    );

    const toolReprog = res.executedTools.find((t) => t.name === 'reprogramar_reserva');
    const reservaDoc = await harness.firestore.collection('reservas').doc('res_mat_thu').get();
    const nuevaFechaRes = reservaDoc.data()?.fecha_clase?.toDate();

    const passed = Boolean(toolReprog && nuevaFechaRes?.getDate() === 24);
    results.push({
      id: '02_jueves_a_martes',
      name: 'Reprogramación exitosa de Jueves a Martes siguiente',
      passed,
      detail: passed
        ? 'Correcto: Se reprogramó de Jueves a Martes 24 en Firestore de manera verificada.'
        : `Fallo: tool=${Boolean(toolReprog)}, fecha=${nuevaFechaRes}`,
    });
  }

  // 3. Familia con dos hijos (Multi-child isolation)
  {
    harness.reset();
    const leadId = '+51984100003';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Luciana',
      status: 'reservado',
      perfil_personas: [
        { nombre: 'Valentina', tipo: 'niño', edad: 9 },
        { nombre: 'Mateo', tipo: 'niño', edad: 11 },
      ],
      reservas_activas: {
        valentina: {
          reserva_id: 'res_fam_val',
          nombre_persona: 'Valentina',
          fecha_clase: MockTimestamp.fromDate(fechaMartes1),
          status: 'confirmado',
        },
        mateo: {
          reserva_id: 'res_fam_mat',
          nombre_persona: 'Mateo',
          fecha_clase: MockTimestamp.fromDate(fechaMartes1),
          status: 'confirmado',
        },
      },
    });

    await harness.firestore.collection('reservas').doc('res_fam_val').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      hora: '18:00',
    });

    await harness.firestore.collection('reservas').doc('res_fam_mat').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      hora: '18:00',
    });

    // Reprogramar SOLAMENTE a Valentina para el jueves 2026-11-19
    await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );

    const docVal = await harness.firestore.collection('reservas').doc('res_fam_val').get();
    const docMat = await harness.firestore.collection('reservas').doc('res_fam_mat').get();
    const leadDoc = await harness.firestore.collection('whatsapp_leads').doc(leadId).get();

    const valJueves = docVal.data()?.fecha_clase?.toDate()?.getDate() === 19;
    const matSigueMartes = docMat.data()?.fecha_clase?.toDate()?.getDate() === 17;
    const activasMap = leadDoc.data()?.reservas_activas || {};
    const mapaCorrecto = activasMap.valentina?.fecha_clase?.toDate()?.getDate() === 19 &&
                         activasMap.mateo?.fecha_clase?.toDate()?.getDate() === 17;

    const passed = valJueves && matSigueMartes && mapaCorrecto;
    results.push({
      id: '03_dos_hijos_aislacion',
      name: 'Aislamiento de reservas entre dos hijos de una misma familia',
      passed,
      detail: passed
        ? 'Correcto: Cambiar a Valentina no alteró la reserva de Mateo en /reservas ni en reservas_activas.'
        : `Fallo: valJueves=${valJueves}, matMartes=${matSigueMartes}, mapa=${mapaCorrecto}`,
    });
  }

  // 4. Reserva inexistente
  {
    harness.reset();
    const leadId = '+51984100004';
    const resTool = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Ignacio', nueva_fecha: '2026-11-19' }
    );

    const passed = resTool.includes('No se encontró ninguna reserva previa') || resTool.includes('No se encontró ninguna reserva para');
    results.push({
      id: '04_reserva_inexistente',
      name: 'Manejo limpio de solicitud de reprogramación sin reserva previa',
      passed,
      detail: passed
        ? 'Correcto: Retornó mensaje informativo sin generar documentos falsos en Firestore.'
        : `Fallo: Respuesta=${resTool}`,
    });
  }

  // 5. Reserva cancelada: no permite reprogramar, pero sí permite reservar de nuevo
  {
    harness.reset();
    const leadId = '+51984100005';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mariana',
      status: 'cancelado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_canc_05').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'cancelado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
    });

    // 5A: Intento de reprogramar una reserva cancelada
    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );
    const reprogRechazada = resReprog.includes('CANCELADA') || resReprog.includes('No se puede reprogramar');

    // 5B: Intento de NUEVA reserva para la misma persona que tenía reserva cancelada
    const resNueva = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      leadId,
      { nombre: 'Valentina', tipo: 'niño', fecha_solicitada: '2026-11-19' }
    );
    const nuevaPermitida = resNueva.includes('Reserva confirmada');

    const passed = reprogRechazada && nuevaPermitida;
    results.push({
      id: '05_reserva_cancelada',
      name: 'Reserva cancelada: rechaza reprogramación y permite nuevo agendamiento',
      passed,
      detail: passed
        ? 'Correcto: La reserva cancelada no pudo reprogramarse, y el bloqueo espurio de reserva_clase_prueba fue resuelto.'
        : `Fallo: reprogRechazada=${reprogRechazada}, nuevaPermitida=${nuevaPermitida}`,
    });
  }

  // 6. Asistencia previa (asistio) - Política comercial
  {
    harness.reset();
    const leadId = '+51984100006';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Pedro',
      status: 'asistio',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_asist_06').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'asistio',
      fecha_clase: MockTimestamp.fromDate(new Date('2026-10-15T18:00:00')),
    });

    // 6A: Intento de reprogramar
    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );
    const reprogBloqueada = resReprog.includes('ASISTIDA') && (resReprog.includes('MEDIDA DE SEGURIDAD PROVISIONAL') || resReprog.includes('DERIVACIÓN A INSTRUCTOR') || resReprog.includes('POLÍTICA COMERCIAL'));

    // 6B: Intento de agendar segunda clase gratis
    const resReserva = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      leadId,
      { nombre: 'Valentina', tipo: 'niño' }
    );
    const reservaBloqueada = resReserva.includes('ASISTIDA') && (resReserva.includes('MEDIDA DE SEGURIDAD PROVISIONAL') || resReserva.includes('DERIVACIÓN A INSTRUCTOR') || resReserva.includes('POLÍTICA COMERCIAL'));

    const passed = reprogBloqueada && reservaBloqueada;
    results.push({
      id: '06_politica_comercial_asistio',
      name: 'Medida de seguridad: No segundas clases gratuitas automáticas a quien ya asistió',
      passed,
      detail: passed
        ? 'Correcto: Se interceptó el intento de segunda clase y se orientó a seguimiento humano sin compromisos comerciales automáticos.'
        : `Fallo: reprogBloqueada=${reprogBloqueada}, reservaBloqueada=${reservaBloqueada}`,
    });
  }

  // 7. No asistió (no_asistio) - Medida de seguridad provisional
  {
    harness.reset();
    const leadId = '+51984100007';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Sonia',
      status: 'no_asistio',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_noasist_07').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'no_asistio',
      fecha_clase: MockTimestamp.fromDate(new Date('2026-10-15T18:00:00')),
    });

    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );
    const resReserva = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      leadId,
      { nombre: 'Valentina', tipo: 'niño' }
    );

    const passed = resReprog.includes('NO ASISTIDA') && resReserva.includes('NO ASISTIDA');
    results.push({
      id: '07_politica_comercial_no_asistio',
      name: 'Medida de seguridad: Derivación humana ante casos no_asistio',
      passed,
      detail: passed
        ? 'Correcto: Se bloqueó reagendamiento automático de cita no asistida y se ordenó seguimiento humano.'
        : 'Fallo al interceptar estado no_asistio.',
    });
  }

  // 8. Reserva pasada vencida
  {
    harness.reset();
    const leadId = '+51984100008';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Esteban',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Mateo', tipo: 'niño', edad: 10 }],
    });

    await harness.firestore.collection('reservas').doc('res_past_08').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(new Date('2026-10-01T18:00:00')), // Pasada
    });

    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Mateo', nueva_fecha: '2026-11-19' }
    );

    const passed = resReprog.includes('pasada') || resReprog.includes('vencida');
    results.push({
      id: '08_reserva_pasada_vencida',
      name: 'Rechazo seguro de reprogramación de reserva pasada/vencida',
      passed,
      detail: passed
        ? 'Correcto: Detectó que la fecha original ya expiró y no permitió reprogramación automática.'
        : `Fallo: Respuesta=${resReprog}`,
    });
  }

  // 9. Clase llena (cupos_disponibles <= 0)
  {
    harness.reset();
    const leadId = '+51984100009';
    // Modificar temporalmente clase_ninos_regular con 0 cupos
    await harness.firestore.collection('clases').doc('clase_ninos_regular').update({
      cupos_disponibles: 0,
    });

    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Gabriel',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_cap_09').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
    });

    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );

    const resReserva = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      leadId,
      { nombre: 'Mateo', tipo: 'niño' }
    );

    // Restaurar cupos
    await harness.firestore.collection('clases').doc('clase_ninos_regular').update({
      cupos_disponibles: 8,
    });

    const passed = resReprog.includes('cupos disponibles: 0') && resReserva.includes('cupos disponibles: 0');
    results.push({
      id: '09_capacidad_cupos_cero',
      name: 'Verificación estricta de cupos agotados (cupos_disponibles <= 0)',
      passed,
      detail: passed
        ? 'Correcto: Ambas herramientas detectan cupos agotados y derivan a seguimiento humano.'
        : `Fallo: resReprog=${resReprog}, resReserva=${resReserva}`,
    });
  }

  // 10. Fecha solicitada inválida (miércoles en vez de M, J o fecha pasada)
  {
    harness.reset();
    const leadId = '+51984100010';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Patricia',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_inv_10').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1), // Martes 17
    });

    // 2026-11-18 es Miércoles (día sin clase)
    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-18' }
    );

    const docRes = await harness.firestore.collection('reservas').doc('res_inv_10').get();
    const fechaIntacta = docRes.data()?.fecha_clase?.toDate()?.getDate() === 17;
    const rechazoLimpio = resReprog.includes('no es válida para la clase') && resReprog.includes('SIGUE ACTIVA');

    const passed = fechaIntacta && rechazoLimpio;
    results.push({
      id: '10_fecha_invalida_rechazo',
      name: 'Fecha solicitada no válida preserva reserva original intacta',
      passed,
      detail: passed
        ? 'Correcto: Se explicó el motivo, no se modificó la fecha en Firestore y no hubo falsa confirmación.'
        : `Fallo: fechaIntacta=${fechaIntacta}, rechazoLimpio=${rechazoLimpio}`,
    });
  }

  // 11. Reprogramaciones repetidas y trazabilidad completa de auditoría
  {
    harness.reset();
    const leadId = '+51984100011';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Héctor',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_rep_11').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
    });

    // 1era reprogramación: de Martes 17 a Jueves 19
    await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19', motivo: 'Viaje familiar' }
    );

    // 2da reprogramación: de Jueves 19 a Martes 24
    await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-24', motivo: 'Cruce con colegio' }
    );

    const docRes = await harness.firestore.collection('reservas').doc('res_rep_11').get();
    const reprogs = docRes.data()?.reprogramaciones || [];

    const passed = Boolean(
      docRes.data()?.fecha_clase?.toDate()?.getDate() === 24 &&
      reprogs.length === 2 &&
      reprogs[0].motivo === 'Viaje familiar' &&
      reprogs[1].motivo === 'Cruce con colegio'
    );

    results.push({
      id: '11_reprogramaciones_repetidas',
      name: 'Trazabilidad de reprogramaciones repetidas en array de auditoría',
      passed,
      detail: passed
        ? 'Correcto: Se registraron 2 auditorías secuenciales con fechas y motivos respectivos en Firestore.'
        : `Fallo: length=${reprogs.length}, fechaFinal=${docRes.data()?.fecha_clase?.toDate()}`,
    });
  }

  // 12. Concurrencia e idempotencia en reservarClasePruebaLead
  {
    harness.reset();
    const leadId = '+51984100012';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Diana',
      status: 'nuevo',
    });

    // Ejecución de primera reserva
    await harness.internals.reservarClasePruebaLead(
      leadId,
      'clase_ninos_regular',
      'Valentina',
      fechaMartes1
    );

    // Intento inmediato de duplicación concurrente/idempotente
    let errorConcurrencia = null;
    try {
      await harness.internals.reservarClasePruebaLead(
        leadId,
        'clase_ninos_regular',
        'Valentina',
        fechaMartes1
      );
    } catch (e) {
      errorConcurrencia = e;
    }

    const leadDoc = await harness.firestore.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDoc.data()?.reservas_activas || {};
    const reservasSnap = await harness.firestore.collection('reservas').where('lead_id', '==', leadId).get();

    const passed = Boolean(
      errorConcurrencia &&
      errorConcurrencia.message.includes('DUPLICATE_ACTIVE_RESERVATION') &&
      reservasSnap.docs.length === 1 &&
      activas.valentina
    );

    results.push({
      id: '12_concurrencia_idempotencia',
      name: 'Lock transaccional e idempotencia ante mensajes concurrentes',
      passed,
      detail: passed
        ? 'Correcto: La transacción detectó la reserva activa previa en whatsapp_leads y rechazó la duplicación.'
        : `Fallo: error=${errorConcurrencia?.message}, reservasCount=${reservasSnap.docs.length}`,
    });
  }

  // 13. Error en Firestore maneja Fail-Safe sin confirmaciones falsas
  {
    harness.reset();
    const leadId = '+51984100013';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Roberto',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_err_13').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
    });

    // Simular falla en runTransaction
    const originalRunTransaction = harness.firestore.runTransaction.bind(harness.firestore);
    harness.firestore.runTransaction = async () => {
      throw new Error('Simulated Database Deadlock or Disconnection');
    };

    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );

    harness.firestore.runTransaction = originalRunTransaction;

    const noAfirmaExito = !resReprog.includes('confirmada con éxito');
    const exigeSeguimientoHumano = resReprog.includes('marcar_seguimiento_humano') && resReprog.includes('NO confirmes');

    const passed = noAfirmaExito && exigeSeguimientoHumano;
    results.push({
      id: '13_failsafe_error_firestore',
      name: 'Fail-Safe estricto ante falla de escritura en base de datos',
      passed,
      detail: passed
        ? 'Correcto: Ante error de base de datos, prohíbe taxativamente confirmar la cita y exige seguimiento humano.'
        : `Fallo: resReprog=${resReprog}`,
    });
  }

  // 14. Detección de confirmaciones alucinadas
  {
    harness.reset();
    const leadId = '+51984100014';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Felipe',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_hal_14').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
    });

    const res = await harness.dispatchMessage(
      leadId,
      'Hola, ¿puedes cambiar mi cita para el jueves 2026-11-19?'
    );

    // Debe haber ejecutado reprogramar_reserva
    const ejecutoHerramienta = res.executedTools.some((t) => t.name === 'reprogramar_reserva');
    const docRes = await harness.firestore.collection('reservas').doc('res_hal_14').get();
    const fechaCambiadaEnDb = docRes.data()?.fecha_clase?.toDate()?.getDate() === 19;

    const passed = ejecutoHerramienta && fechaCambiadaEnDb;
    results.push({
      id: '14_proteccion_alucinacion',
      name: 'Protección contra confirmaciones textuales no persistidas',
      passed,
      detail: passed
        ? 'Correcto: El agente no responde afirmando cambios sin antes haber ejecutado la herramienta en Firestore.'
        : `Fallo: ejecutoHerramienta=${ejecutoHerramienta}, fechaEnDb=${fechaCambiadaEnDb}`,
    });
  }

  // 15. Compatibilidad Legacy y Multi-Sede
  {
    harness.reset();
    const leadId = '+51984100015';
    // Crear una clase legacy sin campo sede_id
    await harness.firestore.collection('clases').doc('clase_legacy').set({
      nombre: 'Capoeira Adultos Legacy',
      nivel: 'Todos los niveles',
      tipo: 'regular',
      publico: 'jovenes_adultos',
      dias: 'M, J',
      hora: '19:30',
      sede: 'Cusco',
      ubicacion: 'Av. de la Cultura E-4',
      cupos_disponibles: 5,
    });

    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mario',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Mario', tipo: 'adulto', edad: 28 }],
    });

    // Reserva sobre clase legacy
    await harness.internals.reservarClasePruebaLead(
      leadId,
      'clase_legacy',
      'Mario',
      fechaMartes1
    );

    const reservasSnap = await harness.firestore.collection('reservas').where('lead_id', '==', leadId).get();
    const resData = reservasSnap.docs[0].data();

    const passed = Boolean(
      resData &&
      resData.sede === 'Cusco' &&
      resData.sede_id === null &&
      resData.ubicacion.includes('Av. de la Cultura')
    );

    results.push({
      id: '15_compatibilidad_legacy_multisede',
      name: 'Compatibilidad hacia atrás con documentos sin sede_id',
      passed,
      detail: passed
        ? 'Correcto: Manejó clases legacy sin sede_id asignando fallback limpio sin errores de ejecución.'
        : `Fallo: resData=${JSON.stringify(resData)}`,
    });
  }

  // 16. Fusión de perfiles en guardar_perfil_lead (sin sobreescritura)
  {
    harness.reset();
    const leadId = '+51984100016';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Ana',
      status: 'conversando',
    });

    // Paso 1: Madre menciona a Mateo
    await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'guardar_perfil_lead').handler(
      leadId,
      { personas: [{ nombre: 'Mateo', tipo: 'niño', edad: 8 }] }
    );

    // Paso 2: Madre menciona a Sofía en un segundo mensaje
    await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'guardar_perfil_lead').handler(
      leadId,
      { personas: [{ nombre: 'Sofía', tipo: 'niño', edad: 6 }] }
    );

    const leadDoc = await harness.firestore.collection('whatsapp_leads').doc(leadId).get();
    const perfil = leadDoc.data()?.perfil_personas || [];

    const nombres = perfil.map((p) => p.nombre);
    const passed = nombres.includes('Mateo') && nombres.includes('Sofía') && perfil.length === 2;

    results.push({
      id: '16_fusion_perfiles_multi_hijos',
      name: 'Fusión no destructiva de perfiles familiares en guardar_perfil_lead',
      passed,
      detail: passed
        ? 'Correcto: Ambos hijos (Mateo y Sofía) se conservan en perfil_personas sin sobreescritura.'
        : `Fallo: perfil=${JSON.stringify(perfil)}`,
    });
  }

  // 17. Dos leads compitiendo por cupo cuando la clase está llena
  {
    harness.reset();
    const lead1 = '+51984200001';
    const lead2 = '+51984200002';

    // Establecer cupos en 0
    await harness.firestore.collection('clases').doc('clase_ninos_regular').update({
      cupos_disponibles: 0,
    });

    const res1 = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      lead1,
      { nombre: 'Lucía', tipo: 'niño' }
    );
    const res2 = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      lead2,
      { nombre: 'Camilo', tipo: 'niño' }
    );

    // Restaurar cupos
    await harness.firestore.collection('clases').doc('clase_ninos_regular').update({
      cupos_disponibles: 8,
    });

    const passed = Boolean(
      res1.includes('cupos disponibles: 0') &&
      res2.includes('cupos disponibles: 0') &&
      res1.includes('marcar_seguimiento_humano') &&
      res2.includes('marcar_seguimiento_humano')
    );

    results.push({
      id: '17_dos_leads_cupo_cero',
      name: 'Control de capacidad ante múltiples leads con cupos agotados',
      passed,
      detail: passed
        ? 'Correcto: Ambos leads fueron rechazados limpiamente y derivados a lista de espera sin sobreventa.'
        : `Fallo: res1=${res1}, res2=${res2}`,
    });
  }

  // 18. Lead antiguo de producción sin reservas_activas (compatibilidad legacy estricta)
  {
    harness.reset();
    const leadLegacyId = '+51984200003';
    // Documento estilo producción 3058ada: solo tiene reserva_id escalar, SIN reservas_activas
    await harness.firestore.collection('whatsapp_leads').doc(leadLegacyId).set({
      telefono: leadLegacyId,
      nombre: 'Renata',
      status: 'reservado',
      reserva_id: 'res_leg_01',
      clase_reservada_id: 'clase_ninos_regular',
      fecha_clase_reservada: MockTimestamp.fromDate(fechaMartes1),
      perfil_personas: [{ nombre: 'Mateo', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_leg_01').set({
      lead_id: leadLegacyId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      hora: '18:00',
      dias: 'M, J',
    });

    // 18A: Intentar duplicar reserva para Mateo en la misma clase
    const resDuplicado = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      leadLegacyId,
      { nombre: 'Mateo', tipo: 'niño' }
    );
    const noDuplico = resDuplicado.includes('Ya existe una reserva previa confirmada y vigente') && resDuplicado.includes('reprogramar_reserva');

    // 18B: Reprogramar la reserva del lead legacy
    const resReprog = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadLegacyId,
      { nombre: 'Mateo', nueva_fecha: '2026-11-19' }
    );
    const reprogExitosa = resReprog.includes('Reprogramación confirmada con éxito');

    const leadDocPost = await harness.firestore.collection('whatsapp_leads').doc(leadLegacyId).get();
    const autoPobloActivas = Boolean(leadDocPost.data()?.reservas_activas?.mateo);

    const passed = noDuplico && reprogExitosa && autoPobloActivas;
    results.push({
      id: '18_lead_legacy_sin_reservas_activas',
      name: 'Compatibilidad con leads de producción sin campo reservas_activas',
      passed,
      detail: passed
        ? 'Correcto: Detectó la reserva legacy en /reservas, no duplicó y auto-pobló reservas_activas tras reprogramar.'
        : `Fallo: noDuplico=${noDuplico}, reprogExitosa=${reprogExitosa}, autoPoblo=${autoPobloActivas}`,
    });
  }

  // 19. Dos hijos y nombres ambiguos (prevención de modificación accidental)
  {
    harness.reset();
    const leadId = '+51984200004';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Marcos',
      status: 'reservado',
      perfil_personas: [
        { nombre: 'Mateo', tipo: 'niño', edad: 8 },
        { nombre: 'Valentina', tipo: 'niño', edad: 10 },
      ],
    });

    await harness.firestore.collection('reservas').doc('res_amb_01').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      hora: '18:00',
    });

    await harness.firestore.collection('reservas').doc('res_amb_02').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      hora: '18:00',
    });

    // Pide reprogramar sin decir el nombre o usando placeholder "mi hijo"
    const resAmbigua = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'mi hijo', nueva_fecha: '2026-11-19' }
    );

    // Ambas reservas deben permanecer en Martes 17 sin ser modificadas a ciegas
    const r1 = await harness.firestore.collection('reservas').doc('res_amb_01').get();
    const r2 = await harness.firestore.collection('reservas').doc('res_amb_02').get();
    const fechaR1Intacta = r1.data()?.fecha_clase?.toDate()?.getDate() === 17;
    const fechaR2Intacta = r2.data()?.fecha_clase?.toDate()?.getDate() === 17;
    const pidioAclaracion = resAmbigua.includes('varias reservas confirmadas activas') || resAmbigua.includes('especifica para cuál');

    const passed = fechaR1Intacta && fechaR2Intacta && pidioAclaracion;
    results.push({
      id: '19_dos_hijos_nombre_ambiguo',
      name: 'Prevención de modificación ante nombres ambiguos o genéricos',
      passed,
      detail: passed
        ? 'Correcto: Rechazó placeholders genéricos ("mi hijo"), solicitó clarificación y no tocó ninguna reserva.'
        : `Fallo: pidioAclaracion=${pidioAclaracion}, r1Intacta=${fechaR1Intacta}, r2Intacta=${fechaR2Intacta}`,
    });
  }

  // 20. Sede legacy sin ubicación comprobada en documento de clase
  {
    harness.reset();
    const leadId = '+51984200005';
    // Modificar temporalmente clase_ninos_regular para que no tenga sede ni ubicacion comprobada
    await harness.firestore.collection('clases').doc('clase_ninos_regular').update({
      sede: null,
      ubicacion: null,
    });

    const resNueva = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba').handler(
      leadId,
      { nombre: 'Joaquín', tipo: 'niño', fecha_solicitada: '2026-11-19' }
    );

    // Restaurar clase_ninos_regular
    await harness.firestore.collection('clases').doc('clase_ninos_regular').update({
      sede: 'Cusco',
      ubicacion: 'Av. de la Cultura E-4, 2do piso (frente a Divergym, encima de Caja Arequipa), Cusco',
    });

    // Debe confirmar la reserva SIN inventar "Av. de la Cultura" ni "Cusco"
    const noTieneDireccionInventada = !resNueva.includes('Av. de la Cultura') && !resNueva.includes('Divergym');
    const reservaExitosa = resNueva.includes('Reserva confirmada');

    const passed = noTieneDireccionInventada && reservaExitosa;
    results.push({
      id: '20_sede_sin_ubicacion_no_inventa',
      name: 'Prohibición estricta de inventar direcciones no asociadas a la clase',
      passed,
      detail: passed
        ? 'Correcto: Confirmó la reserva usando solo datos verificados sin inventar calles ni locales.'
        : `Fallo: resNueva=${resNueva}`,
    });
  }

  // 21. Reprogramación correcta sin otorgar segunda clase gratis
  {
    harness.reset();
    const leadId = '+51984200006';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Fabiola',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_unica_01').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      hora: '18:00',
    });

    // Reprograma de Martes a Jueves
    await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );

    // Contar total de documentos en /reservas para este lead
    const snapReservas = await harness.firestore.collection('reservas').where('lead_id', '==', leadId).get();
    const docRes = snapReservas.docs[0].data();

    // Verificación: Solo existe 1 documento de reserva (no se creó una segunda reserva) y status sigue en 'confirmado'
    const passed = snapReservas.docs.length === 1 &&
                   docRes.status === 'confirmado' &&
                   docRes.fecha_clase?.toDate()?.getDate() === 19;

    results.push({
      id: '21_reprogramacion_sin_segunda_clase',
      name: 'Reprogramación no multiplica reservas ni concede clases adicionales',
      passed,
      detail: passed
        ? 'Correcto: Se modificó la cita existente manteniendo exactamente una reserva en base de datos.'
        : `Fallo: count=${snapReservas.docs.length}, status=${docRes.status}`,
    });
  }

  // 22. Error transaccional en reprogramación (Fail-Safe)
  {
    harness.reset();
    const leadId = '+51984200007';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Samuel',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
    });

    await harness.firestore.collection('reservas').doc('res_tx_err').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      status: 'confirmado',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
    });

    const originalRunTransaction = harness.firestore.runTransaction.bind(harness.firestore);
    harness.firestore.runTransaction = async () => {
      throw new Error('CLASS_FULL: No hay cupos disponibles en la clase seleccionada');
    };

    const resError = await harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva').handler(
      leadId,
      { nombre: 'Valentina', nueva_fecha: '2026-11-19' }
    );

    harness.firestore.runTransaction = originalRunTransaction;

    const passed = resError.includes('cupos agotados') && resError.includes('marcar_seguimiento_humano');
    results.push({
      id: '22_error_transaccional_failsafe',
      name: 'Reacción segura ante aborto transaccional por cupos o contención',
      passed,
      detail: passed
        ? 'Correcto: Ante error transaccional de cupo, no confirmó el cambio y derivó a seguimiento humano.'
        : `Fallo: resError=${resError}`,
    });
  }

  // Resumen final
  console.log('----------------------------------------------------------------');
  let totalPassed = 0;
  for (const r of results) {
    const status = r.passed ? '[PASS]' : '[FAIL]';
    console.log(`${status} ${r.id}: ${r.name}`);
    console.log(`       ${r.detail}`);
    if (r.passed) totalPassed++;
  }
  console.log('----------------------------------------------------------------');
  console.log(`Resultado P0.2A: ${totalPassed}/${results.length} pruebas superadas.`);

  console.log('\n[LIMITACIÓN TÉCNICA HARNESS]: InMemoryFirestore emula atomicidad y retries en memoria sincrónica');
  console.log('en un único proceso Node.js. Para verificar condiciones de carrera con contención distribuida extrema');
  console.log('y latencias de red GCP (>150ms), se requerirá testing formal en Firebase Local Emulator Suite en fases posteriores.');

  if (totalPassed === results.length) {
    console.log('>>> VERIFICACIÓN P0.2A EXITOSA: 100% DE PRUEBAS APROBADAS <<<\n');
    return true;
  } else {
    console.error('>>> EXISTEN FALLOS EN LA SUITE P0.2A <<<\n');
    return false;
  }
}

if (require.main === module) {
  runP02aTests()
    .then((success) => process.exit(success ? 0 : 1))
    .catch((err) => {
      console.error('Error fatal en suite P0.2A:', err);
      process.exit(1);
    });
}

module.exports = { runP02aTests };


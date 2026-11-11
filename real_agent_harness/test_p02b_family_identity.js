/**
 * Test Suite P0.2B: Identidad Familiar y Reservas Múltiples
 * 
 * Verifies:
 * 1. Familia con dos hijos y dos reservas distintas.
 * 2. Reprogramación de un hijo sin alterar la reserva del hermano.
 * 3. Mensaje ambiguo sin nombre: solicita aclaración (booking & rescheduling).
 * 4. Referencia inequívoca por nombre («la reserva de Valentina»).
 * 5. Registro legacy con reserva_id escalar (preserva y reconcilia al hermano previo).
 * 6. Registro nuevo con reservas_activas.
 * 7. Familia con una reserva cancelada y otra activa.
 * 8. Dos hijos con nombres iguales o repetidos (desambigua por horario o reserva_id).
 * 9. Intento de operar una reserva ajena (rechazo de autorización estricto).
 * 10. Reintento de una operación sin duplicar reservas (idempotencia).
 */

const { RealAgentHarness } = require('./loader');
const { MockTimestamp } = require('./in_memory_firestore');

async function runP02bTests() {
  const harness = new RealAgentHarness();
  const results = [];

  console.log('================================================================');
  console.log('   TEST SUITE P0.2B: IDENTIDAD FAMILIAR Y RESERVAS MÚLTIPLES');
  console.log('   Ejecución 100% offline y aislada sobre lógica real del backend');
  console.log('================================================================\n');

  const fechaMartes1 = new Date('2026-11-17T18:00:00');
  const fechaJueves1 = new Date('2026-11-19T18:00:00');
  const fechaMartes2 = new Date('2026-11-24T18:00:00');

  // 1. Familia con dos hijos y dos reservas distintas
  {
    harness.reset();
    const leadId = '+51984200001';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Mariana',
      status: 'conversando',
    });

    const toolGuardar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'guardar_perfil_lead');
    const toolReservar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    await toolGuardar.handler(leadId, {
      personas: [
        { nombre: 'Mateo', tipo: 'niño', edad: 12 },
        { nombre: 'Lucía', tipo: 'niño', edad: 7 },
      ],
    });

    const resMateo = await toolReservar.handler(leadId, { nombre: 'Mateo', tipo: 'niño' });
    const resLucia = await toolReservar.handler(leadId, { nombre: 'Lucía', tipo: 'niño' });

    const reservasSnap = await harness.firestore.collection('reservas').where('lead_id', '==', leadId).get();
    const reservasDocs = reservasSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    const leadDoc = await harness.firestore.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDoc.data()?.reservas_activas || {};

    const passed =
      resMateo.includes('Reserva confirmada para Mateo') &&
      resLucia.includes('Reserva confirmada para Lucía') &&
      reservasDocs.length === 2 &&
      reservasDocs.some((r) => r.nombre_persona === 'Mateo' && r.status === 'confirmado') &&
      reservasDocs.some((r) => r.nombre_persona === 'Lucía' && r.status === 'confirmado') &&
      Boolean(activas.mateo && activas.mateo.status === 'confirmado') &&
      Boolean(activas.lucia && activas.lucia.status === 'confirmado');

    results.push({
      id: '01_familia_dos_hijos_dos_reservas',
      name: 'Familia con dos hijos y dos reservas distintas',
      passed,
      detail: passed
        ? 'Correcto: Se crearon 2 documentos distintos en /reservas y ambos se preservan en reservas_activas.'
        : 'Fallo: No se crearon ni preservaron ambas reservas correctamente.',
    });
  }

  // 2. Reprogramación de un hijo sin alterar la reserva del hermano
  {
    harness.reset();
    const leadId = '+51984200002';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Carla',
      status: 'reservado',
      perfil_personas: [
        { nombre: 'Mateo', tipo: 'niño', edad: 12 },
        { nombre: 'Lucía', tipo: 'niño', edad: 7 },
      ],
      reserva_id: 'res_lucia_02',
      fecha_clase_reservada: MockTimestamp.fromDate(fechaMartes1),
      reservas_activas: {
        mateo: {
          reserva_id: 'res_mateo_02',
          clase_id: 'clase_ninos_regular',
          nombre_persona: 'Mateo',
          fecha_clase: MockTimestamp.fromDate(fechaMartes1),
          status: 'confirmado',
          hora: '18:00',
        },
        lucia: {
          reserva_id: 'res_lucia_02',
          clase_id: 'clase_ninos_regular',
          nombre_persona: 'Lucía',
          fecha_clase: MockTimestamp.fromDate(fechaMartes1),
          status: 'confirmado',
          hora: '18:00',
        },
      },
    });

    await harness.firestore.collection('reservas').doc('res_mateo_02').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      tipo: 'prueba',
      sede: 'Cusco',
    });

    await harness.firestore.collection('reservas').doc('res_lucia_02').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Lucía',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      tipo: 'prueba',
      sede: 'Cusco',
    });

    const toolReprogramar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const resReprog = await toolReprogramar.handler(leadId, {
      nombre: 'Mateo',
      nueva_fecha: '2026-11-19',
      motivo: 'Viaje familiar',
    });

    const docMateo = await harness.firestore.collection('reservas').doc('res_mateo_02').get();
    const docLucia = await harness.firestore.collection('reservas').doc('res_lucia_02').get();
    const leadDoc = await harness.firestore.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDoc.data()?.reservas_activas || {};

    const mateoFechaNueva = docMateo.data()?.fecha_clase?.toDate()?.getDate() === 19;
    const luciaFechaIntacta = docLucia.data()?.fecha_clase?.toDate()?.getDate() === 17;
    const activasMateoOk = activas.mateo?.fecha_clase?.toDate()?.getDate() === 19;
    const activasLuciaOk = activas.lucia?.fecha_clase?.toDate()?.getDate() === 17;

    const passed =
      resReprog.includes('Reprogramación confirmada con éxito para Mateo') &&
      mateoFechaNueva &&
      luciaFechaIntacta &&
      activasMateoOk &&
      activasLuciaOk &&
      docLucia.data()?.reprogramaciones === undefined;

    results.push({
      id: '02_reprogramar_hijo_sin_alterar_hermano',
      name: 'Reprogramación de un hijo sin alterar la reserva del hermano',
      passed,
      detail: passed
        ? 'Correcto: Se reprogramó a Mateo a jueves mientras la reserva de Lucía permaneció intacta para el martes.'
        : 'Fallo: La reprogramación de Mateo alteró o borró los datos de Lucía.',
    });
  }

  // 3. Mensaje ambiguo sin nombre: solicita aclaración (booking & rescheduling)
  {
    harness.reset();
    const leadId = '+51984200003';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Sonia',
      status: 'reservado',
      perfil_personas: [
        { nombre: 'Mateo', tipo: 'niño', edad: 12 },
        { nombre: 'Lucía', tipo: 'niño', edad: 7 },
      ],
      reservas_activas: {
        mateo: { reserva_id: 'res_amb_1', status: 'confirmado', fecha_clase: MockTimestamp.fromDate(fechaMartes1) },
        lucia: { reserva_id: 'res_amb_2', status: 'confirmado', fecha_clase: MockTimestamp.fromDate(fechaMartes1) },
      },
    });

    await harness.firestore.collection('reservas').doc('res_amb_1').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    await harness.firestore.collection('reservas').doc('res_amb_2').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Lucía',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    const toolReprogramar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const toolReservar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    // Reprogramar con placeholder ambiguo "mi hijo"
    const resReprogAmbiguo = await toolReprogramar.handler(leadId, {
      nombre: 'mi hijo',
      nueva_fecha: '2026-11-19',
    });

    // Agendar con placeholder ambiguo "el nene" en lead con múltiples niños
    const resReservarAmbiguo = await toolReservar.handler(leadId, {
      nombre: 'el nene',
      tipo: 'niño',
    });

    const doc1 = await harness.firestore.collection('reservas').doc('res_amb_1').get();
    const doc2 = await harness.firestore.collection('reservas').doc('res_amb_2').get();

    const passed =
      resReprogAmbiguo.includes('Hay varias reservas confirmadas activas para este número') &&
      resReservarAmbiguo.includes('Hay varias personas registradas en este perfil') &&
      doc1.data()?.fecha_clase?.toDate()?.toISOString() === fechaMartes1.toISOString() &&
      doc2.data()?.fecha_clase?.toDate()?.toISOString() === fechaMartes1.toISOString();

    results.push({
      id: '03_mensaje_ambiguo_solicita_aclaracion',
      name: 'Mensaje ambiguo sin nombre: solicita aclaración en booking y reprogramación',
      passed,
      detail: passed
        ? 'Correcto: Detectó ambigüedad familiar, solicitó aclaración explícita y no adivinó ni alteró reservas.'
        : 'Fallo: El sistema adivinó arbitrariamente o permitió operaciones ambiguas.',
    });
  }

  // 4. Referencia inequívoca por nombre («la reserva de Valentina»)
  {
    harness.reset();
    const leadId = '+51984200004';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Pedro',
      status: 'reservado',
      perfil_personas: [
        { nombre: 'Valentina', tipo: 'niño', edad: 9 },
        { nombre: 'Joaquín', tipo: 'niño', edad: 6 },
      ],
      reservas_activas: {
        valentina: { reserva_id: 'res_val_04', status: 'confirmado', fecha_clase: MockTimestamp.fromDate(fechaMartes1) },
        joaquin: { reserva_id: 'res_joa_04', status: 'confirmado', fecha_clase: MockTimestamp.fromDate(fechaMartes1) },
      },
    });

    await harness.firestore.collection('reservas').doc('res_val_04').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Valentina',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      sede: 'Cusco',
    });

    await harness.firestore.collection('reservas').doc('res_joa_04').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Joaquín',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      sede: 'Cusco',
    });

    const toolReprogramar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const resReprog = await toolReprogramar.handler(leadId, {
      nombre: 'Valentina',
      nueva_fecha: '2026-11-19',
    });

    const docVal = await harness.firestore.collection('reservas').doc('res_val_04').get();
    const docJoa = await harness.firestore.collection('reservas').doc('res_joa_04').get();

    const passed =
      resReprog.includes('Reprogramación confirmada con éxito para Valentina') &&
      docVal.data()?.fecha_clase?.toDate()?.getDate() === 19 &&
      docJoa.data()?.fecha_clase?.toDate()?.getDate() === 17;

    results.push({
      id: '04_referencia_inequivoca_por_nombre',
      name: 'Referencia inequívoca por nombre («la reserva de Valentina»)',
      passed,
      detail: passed
        ? 'Correcto: Se resolvió exactamente a Valentina sin alterar la cita de Joaquín.'
        : 'Fallo: No se resolvió la referencia unívoca de forma correcta.',
    });
  }

  // 5. Registro legacy con reserva_id escalar (preserva y reconcilia al hermano previo)
  {
    harness.reset();
    const leadId = '+51984200005';
    // Estructura de producción 3058ada: solo reserva_id escalar, SIN reservas_activas
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Gabriela',
      status: 'reservado',
      perfil_personas: [{ nombre: 'Mateo', tipo: 'niño', edad: 12 }],
      reserva_id: 'res_legacy_mateo_05',
      fecha_clase_reservada: MockTimestamp.fromDate(fechaMartes1),
    });

    await harness.firestore.collection('reservas').doc('res_legacy_mateo_05').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      nivel: 'Iniciación Infantil',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
      tipo: 'prueba',
      sede: 'Cusco',
    });

    // Ahora la mamá pide agendar para su segunda hija "Lucía"
    const toolGuardar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'guardar_perfil_lead');
    const toolReservar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    await toolGuardar.handler(leadId, {
      personas: [{ nombre: 'Lucía', tipo: 'niño', edad: 7 }],
    });

    const resLucia = await toolReservar.handler(leadId, {
      nombre: 'Lucía',
      tipo: 'niño',
    });

    const leadDocPost = await harness.firestore.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDocPost.data()?.reservas_activas || {};
    const docMateo = await harness.firestore.collection('reservas').doc('res_legacy_mateo_05').get();
    const reservasSnap = await harness.firestore.collection('reservas').where('lead_id', '==', leadId).get();

    const passed =
      resLucia.includes('Reserva confirmada para Lucía') &&
      reservasSnap.docs.length === 2 &&
      docMateo.exists &&
      docMateo.data()?.status === 'confirmado' &&
      Boolean(activas.mateo && activas.mateo.reserva_id === 'res_legacy_mateo_05') &&
      Boolean(activas.lucia);

    results.push({
      id: '05_lead_legacy_reserva_id_escalar',
      name: 'Registro legacy con reserva_id escalar reconcilia y preserva hermano previo',
      passed,
      detail: passed
        ? 'Correcto: Agendar a Lucía no borró a Mateo y auto-reconcilió a ambos en reservas_activas.'
        : 'Fallo: La reserva legacy de Mateo fue desasociada o sobreescrita.',
    });
  }

  // 6. Registro nuevo con reservas_activas y uso de reserva_id directo
  {
    harness.reset();
    const leadId = '+51984200006';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Carlos',
      status: 'reservado',
      perfil_personas: [
        { nombre: 'Nicolás', tipo: 'niño', edad: 10 },
        { nombre: 'Camilo', tipo: 'niño', edad: 8 },
      ],
      reservas_activas: {
        nicolas: { reserva_id: 'res_nic_06', status: 'confirmado', fecha_clase: MockTimestamp.fromDate(fechaMartes1) },
        camilo: { reserva_id: 'res_cam_06', status: 'confirmado', fecha_clase: MockTimestamp.fromDate(fechaMartes1) },
      },
    });

    await harness.firestore.collection('reservas').doc('res_nic_06').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Nicolás',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    await harness.firestore.collection('reservas').doc('res_cam_06').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Camilo',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    const toolReprogramar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const resReprog = await toolReprogramar.handler(leadId, {
      reserva_id: 'res_cam_06',
      nueva_fecha: '2026-11-19',
    });

    const docCam = await harness.firestore.collection('reservas').doc('res_cam_06').get();
    const docNic = await harness.firestore.collection('reservas').doc('res_nic_06').get();

    const passed =
      resReprog.includes('Reprogramación confirmada con éxito') &&
      docCam.data()?.fecha_clase?.toDate()?.getDate() === 19 &&
      docNic.data()?.fecha_clase?.toDate()?.getDate() === 17;

    results.push({
      id: '06_registro_nuevo_con_reservas_activas',
      name: 'Registro nuevo con reservas_activas y uso de reserva_id directo',
      passed,
      detail: passed
        ? 'Correcto: Se reprogramó de forma directa mediante reserva_id autorizada sin ambigüedad.'
        : 'Fallo: Error al procesar reserva_id directo.',
    });
  }

  // 7. Familia con una reserva cancelada y otra activa
  {
    harness.reset();
    const leadId = '+51984200007';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Luciana',
      status: 'reservado',
      perfil_personas: [
        { nombre: 'Mateo', tipo: 'niño', edad: 12 },
        { nombre: 'Lucía', tipo: 'niño', edad: 7 },
      ],
      reservas_activas: {
        lucia: { reserva_id: 'res_lucia_07', status: 'confirmado', fecha_clase: MockTimestamp.fromDate(fechaMartes1) },
      },
    });

    // Mateo tiene reserva CANCELADA
    await harness.firestore.collection('reservas').doc('res_mateo_07').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'cancelado',
    });

    // Lucía tiene reserva CONFIRMADA ACTIVA
    await harness.firestore.collection('reservas').doc('res_lucia_07').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Lucía',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    const toolReprogramar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');
    const toolReservar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    // A. Intentar reprogramar a Mateo (debe rechazar porque está cancelada)
    const resMateoReprog = await toolReprogramar.handler(leadId, {
      nombre: 'Mateo',
      nueva_fecha: '2026-11-19',
    });

    // B. Reprogramar a Lucía (debe funcionar limpiamente)
    const resLuciaReprog = await toolReprogramar.handler(leadId, {
      nombre: 'Lucía',
      nueva_fecha: '2026-11-19',
    });

    // C. Re-agendar nueva clase para Mateo con reservar_clase_prueba (debe permitirlo)
    const resMateoReagendar = await toolReservar.handler(leadId, {
      nombre: 'Mateo',
      tipo: 'niño',
    });

    const passed =
      resMateoReprog.includes('figura como CANCELADA') &&
      resLuciaReprog.includes('Reprogramación confirmada con éxito para Lucía') &&
      resMateoReagendar.includes('Reserva confirmada para Mateo');

    results.push({
      id: '07_familia_reserva_cancelada_y_activa',
      name: 'Familia con una reserva cancelada y otra activa',
      passed,
      detail: passed
        ? 'Correcto: Rechazó reprogramar la cancelada, permitió reprogramar la activa y permitió re-agendar al cancelado.'
        : 'Fallo: Las reservas canceladas y activas interfirieron entre sí.',
    });
  }

  // 8. Dos hijos con nombres iguales o repetidos (desambigua por horario o reserva_id)
  {
    harness.reset();
    const leadId = '+51984200008';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Rodrigo',
      status: 'reservado',
    });

    // Dos reservas para "Mateo" (ej. Mateo Jr. y Mateo Sr., o dos registros con el mismo nombre)
    await harness.firestore.collection('reservas').doc('res_mat_a').set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      hora: '17:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    await harness.firestore.collection('reservas').doc('res_mat_b').set({
      lead_id: leadId,
      clase_id: 'clase_jovenes_adultos',
      nombre_persona: 'Mateo',
      hora: '19:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    const toolReprogramar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');

    // A. Solicitud ambigua solo por nombre "Mateo"
    const resAmbigua = await toolReprogramar.handler(leadId, {
      nombre: 'Mateo',
      nueva_fecha: '2026-11-19',
    });

    // B. Solicitud desambiguada por reserva_id directo
    const resDesambiguada = await toolReprogramar.handler(leadId, {
      reserva_id: 'res_mat_b',
      nueva_fecha: '2026-11-19',
    });

    const docA = await harness.firestore.collection('reservas').doc('res_mat_a').get();
    const docB = await harness.firestore.collection('reservas').doc('res_mat_b').get();

    const passed =
      resAmbigua.includes('Hay más de una reserva confirmada con el nombre "Mateo"') &&
      resDesambiguada.includes('Reprogramación confirmada con éxito para Mateo') &&
      docA.data()?.fecha_clase?.toDate()?.getDate() === 17 &&
      docB.data()?.fecha_clase?.toDate()?.getDate() === 19;

    results.push({
      id: '08_dos_hijos_nombres_iguales_desambiguacion',
      name: 'Dos hijos con nombres iguales o repetidos (desambigua por ID)',
      passed,
      detail: passed
        ? 'Correcto: Detectó colisión de nombre idéntico, pidió desambiguar y permitió operar con reserva_id.'
        : 'Fallo: No manejó colisiones de nombres idénticos de forma segura.',
    });
  }

  // 9. Intento de operar una reserva ajena (rechazo de autorización estricto)
  {
    harness.reset();
    const leadA_id = '+51984200009';
    const leadB_id = '+51984200010';

    await harness.firestore.collection('whatsapp_leads').doc(leadA_id).set({
      telefono: leadA_id,
      nombre: 'Lead Atacante',
      status: 'reservado',
    });

    await harness.firestore.collection('whatsapp_leads').doc(leadB_id).set({
      telefono: leadB_id,
      nombre: 'Familia Víctima',
      status: 'reservado',
    });

    await harness.firestore.collection('reservas').doc('res_victima').set({
      lead_id: leadB_id,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Lucía Víctima',
      hora: '18:00',
      dias: 'M, J',
      fecha_clase: MockTimestamp.fromDate(fechaMartes1),
      status: 'confirmado',
    });

    const toolReprogramar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reprogramar_reserva');

    // A. Intento vía tool handler con reserva_id ajeno
    const resToolAjeno = await toolReprogramar.handler(leadA_id, {
      reserva_id: 'res_victima',
      nueva_fecha: '2026-11-19',
    });

    // B. Intento de evasión llamando directamente a la función transaccional
    let errorTransaccionalCapturado = null;
    try {
      await harness.internals.reprogramarClasePruebaLead(leadA_id, 'res_victima', fechaJueves1);
    } catch (e) {
      errorTransaccionalCapturado = e.message;
    }

    const docVictima = await harness.firestore.collection('reservas').doc('res_victima').get();
    const victimaIntacta = docVictima.data()?.fecha_clase?.toDate()?.toISOString() === fechaMartes1.toISOString();

    const passed =
      resToolAjeno.includes('no pertenece a este número de teléfono') &&
      errorTransaccionalCapturado?.includes('UNAUTHORIZED_RESERVATION') &&
      victimaIntacta;

    results.push({
      id: '09_intento_operar_reserva_ajena_unauthorized',
      name: 'Intento de operar una reserva ajena (rechazo de autorización estricto)',
      passed,
      detail: passed
        ? 'Correcto: Se bloqueó tanto a nivel de tool handler como dentro de la transacción Firestore.'
        : 'Fallo: Se permitió modificar o no se bloqueó adecuadamente la reserva ajena.',
    });
  }

  // 10. Reintento de una operación sin duplicar reservas (idempotencia)
  {
    harness.reset();
    const leadId = '+51984200011';
    await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Andrea',
      status: 'conversando',
    });

    const toolReservar = harness.internals.AVAILABLE_TOOLS.find((t) => t.name === 'reservar_clase_prueba');

    // Primera reserva
    const res1 = await toolReservar.handler(leadId, { nombre: 'Mateo', tipo: 'niño' });

    // Reintento idéntico (simulando webhook duplicado o mensaje redundante)
    const res2 = await toolReservar.handler(leadId, { nombre: 'Mateo', tipo: 'niño' });

    const reservasSnap = await harness.firestore.collection('reservas').where('lead_id', '==', leadId).get();

    const passed =
      res1.includes('Reserva confirmada para Mateo') &&
      res2.includes('Ya existe una reserva previa confirmada y vigente para Mateo') &&
      reservasSnap.docs.length === 1;

    results.push({
      id: '10_reintento_operacion_sin_duplicar',
      name: 'Reintento de una operación sin duplicar reservas (idempotencia)',
      passed,
      detail: passed
        ? 'Correcto: El reintento fue interceptado como duplicado y Firestore conservó exactamente 1 documento.'
        : 'Fallo: Se duplicó la reserva o no se detectó la cita activa existente.',
    });
  }

  // Resumen
  console.log('----------------------------------------------------------------');
  let totalPass = 0;
  for (const r of results) {
    const mark = r.passed ? '[PASS]' : '[FAIL]';
    console.log(`${mark} ${r.id}: ${r.name}`);
    console.log(`       ${r.detail}`);
    if (r.passed) totalPass++;
  }

  console.log('----------------------------------------------------------------');
  console.log(`Resultado P0.2B: ${totalPass}/${results.length} pruebas superadas.\n`);

  if (totalPass === results.length) {
    console.log('>>> VERIFICACIÓN P0.2B EXITOSA: 100% DE PRUEBAS APROBADAS <<<\n');
  } else {
    console.error('>>> ALERTA P0.2B: SE ENCONTRARON FALLOS EN LA SUITE <<<');
    process.exit(1);
  }

  return results;
}

if (require.main === module) {
  runP02bTests().catch((err) => {
    console.error('Error fatal ejecutando suite P0.2B:', err);
    process.exit(1);
  });
}

module.exports = { runP02bTests };

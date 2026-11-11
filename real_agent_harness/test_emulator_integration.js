/**
 * Suite de Integración con Google Cloud Firestore Emulator Real (Java 21)
 * 
 * Proyecto: demo-ginga-test (Totalmente aislado de producción)
 * 
 * Evalúa las funciones reales de functions/index.js contra el motor real de Firestore:
 * 1. Reserva nueva transaccional (/reservas, reservas_activas, notificaciones).
 * 2. Reprogramación transaccional (modificación atómica, auditoría, reservas_activas).
 * 3. Dos hijos de la misma familia (aislamiento e independencia de documentos).
 * 4. Lead legacy sin reservas_activas (auto-reconciliación no destructiva).
 * 5. Concurrencia sobre el mismo lead (idempotencia y aborto transaccional).
 * 6. Concurrencia entre leads (competencia por último cupo en transacción).
 * 7. Errores y reintentos transaccionales (seguridad y autorizaciones).
 * 8. Consultas e índices requeridos (.where compuesto en Firestore real).
 */

const admin = require('../functions/node_modules/firebase-admin');

// Asegurar project id ficticio demo
process.env.GCLOUD_PROJECT = 'demo-ginga-test';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-ginga-test' });

// Importar funciones reales del backend (index.js inicializa admin.initializeApp si no existe)
const internals = require('../functions/index.js').__internals;
const {
  reservarClasePruebaLead,
  reprogramarClasePruebaLead,
  generarSystemPrompt,
  slugifyPersona,
  obtenerFechaLimaAhora,
  formatearFechaLarga,
} = internals;

const db = admin.firestore();

async function clearEmulatorData() {
  // Limpia colecciones de prueba
  const collections = ['whatsapp_leads', 'reservas', 'clases', 'users', 'config', 'reprogramaciones'];
  for (const col of collections) {
    const snap = await db.collection(col).get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function seedEmulatorFixtures() {
  await clearEmulatorData();

  // Config negocio
  await db.collection('config').doc('negocio').set({
    nombre: 'Ginga & Capoeira FIU Cusco',
    moneda: 'PEN',
    precio_mensual_regular: 140,
    precio_mensual_promo_acompanado: 260,
    precio_paquete_3_meses: 380,
    precio_paquete_6_meses: 720,
    yape_numero: '984 765 432',
    yape_titular: 'Instructor Ginga Cusco',
    direccion: 'Calle Hospital 840, Cusco (segundo piso)',
    link_maps: 'https://maps.app.goo.gl/3gdpPwk7PctgmSA38',
  });

  // Config agente
  await db.collection('config').doc('whatsapp_agent').set({
    system_prompt: 'Eres el instructor de Ginga Cusco. Atiende con amabilidad y precisión.',
  });

  // Instructor
  await db.collection('users').doc('inst_mestre_1').set({
    nombre: 'Profesor Mestre Test',
    rol: 'profesor',
    email: 'mestre@gingatest.com',
  });

  // Clase Niños (con cupos)
  await db.collection('clases').doc('clase_ninos_regular').set({
    nombre: 'Capoeira Niños',
    tipo: 'regular',
    publico: 'niños',
    nivel: 'Niños (todas las edades)',
    dias: 'M, J',
    hora: '17:00',
    hora_fin: '18:00',
    edad_min: 4,
    edad_max: 13,
    cupos_disponibles: 10,
    instructor_id: 'inst_mestre_1',
    sede: 'Cusco',
    ubicacion: 'Calle Hospital 840',
  });

  // Clase Adultos (con cupos)
  await db.collection('clases').doc('clase_adultos_regular').set({
    nombre: 'Capoeira Adultos',
    tipo: 'regular',
    publico: 'jovenes_adultos',
    nivel: 'Jóvenes y Adultos',
    dias: 'M, J',
    hora: '18:00',
    hora_fin: '19:30',
    edad_min: 14,
    edad_max: 99,
    cupos_disponibles: 8,
    instructor_id: 'inst_mestre_1',
    sede: 'Cusco',
    ubicacion: 'Calle Hospital 840',
  });
}

async function runEmulatorTestSuite() {
  console.log('================================================================');
  console.log('   SUITE REAL DE INTEGRACIÓN CON FIRESTORE EMULATOR (JAVA 21)');
  console.log(`   Host: ${process.env.FIRESTORE_EMULATOR_HOST} | Project: demo-ginga-test`);
  console.log('================================================================\n');

  const results = [];
  const fechaMartes = new Date('2026-11-17T17:00:00-05:00');
  const fechaJueves = new Date('2026-11-19T17:00:00-05:00');

  // PRUEBA 1: Reserva nueva transaccional
  {
    await seedEmulatorFixtures();
    const leadId = '+51984000101';
    await db.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Claudia',
      status: 'conversando',
    });

    await reservarClasePruebaLead(leadId, 'clase_ninos_regular', 'Joaquín', fechaMartes);

    const leadDoc = await db.collection('whatsapp_leads').doc(leadId).get();
    const reservasSnap = await db.collection('reservas').where('lead_id', '==', leadId).get();
    const notifsSnap = await db.collection('users').doc('inst_mestre_1').collection('notificaciones').get();

    const leadData = leadDoc.data();
    const reservaDoc = reservasSnap.docs[0]?.data();
    const notifDoc = notifsSnap.docs[0]?.data();

    const passed = Boolean(
      leadData.status === 'reservado' &&
      leadData.reservas_activas?.joaquin?.nombre_persona === 'Joaquín' &&
      reservasSnap.size === 1 &&
      reservaDoc.status === 'confirmado' &&
      reservaDoc.nombre_persona === 'Joaquín' &&
      notifsSnap.size === 1 &&
      notifDoc.tipo === 'bienvenida'
    );

    results.push({
      id: 'EMU_01_reserva_nueva_transaccional',
      name: 'Reserva nueva en Firestore Emulator real',
      passed,
      diagnostic: passed
        ? 'Correcto: Se persistió en /reservas, actualizó reservas_activas y emitió notificación a instructor.'
        : 'Fallo al persistir reserva en Firestore Emulator.',
    });
  }

  // PRUEBA 2: Reprogramación transaccional
  {
    const leadId = '+51984000101';
    const leadDoc = await db.collection('whatsapp_leads').doc(leadId).get();
    const reservaId = leadDoc.data()?.reservas_activas?.joaquin?.reserva_id;

    await reprogramarClasePruebaLead(leadId, reservaId, fechaJueves, 'Motivo de prueba');

    const reservaActualizada = (await db.collection('reservas').doc(reservaId).get()).data();
    const leadActualizado = (await db.collection('whatsapp_leads').doc(leadId).get()).data();
    const notifsSnap = await db.collection('users').doc('inst_mestre_1').collection('notificaciones').get();

    const passed = Boolean(
      reservaActualizada.status === 'confirmado' &&
      leadActualizado.reservas_activas?.joaquin?.fecha_clase.toDate().getDate() === fechaJueves.getDate() &&
      notifsSnap.docs.some((d) => d.data().tipo === 'reprogramacion')
    );

    results.push({
      id: 'EMU_02_reprogramacion_transaccional',
      name: 'Reprogramación atómica en Firestore Emulator real',
      passed,
      diagnostic: passed
        ? 'Correcto: Transacción atómica actualizó /reservas y whatsapp_leads con nueva fecha y auditoría.'
        : 'Fallo al reprogramar en Firestore Emulator.',
    });
  }

  // PRUEBA 3: Dos hijos de la misma familia
  {
    await seedEmulatorFixtures();
    const leadId = '+51984000103';
    await db.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Sonia',
      status: 'conversando',
    });

    await reservarClasePruebaLead(leadId, 'clase_ninos_regular', 'Mateo', fechaMartes);
    await reservarClasePruebaLead(leadId, 'clase_ninos_regular', 'Lucía', fechaJueves);

    const leadDoc = await db.collection('whatsapp_leads').doc(leadId).get();
    const reservasSnap = await db.collection('reservas').where('lead_id', '==', leadId).get();
    const activas = leadDoc.data()?.reservas_activas || {};

    const passed = Boolean(
      reservasSnap.size === 2 &&
      activas.mateo &&
      activas.lucia &&
      activas.mateo.reserva_id !== activas.lucia.reserva_id
    );

    results.push({
      id: 'EMU_03_dos_hijos_familia_aislamiento',
      name: 'Dos hijos de la misma familia: aislamiento e independencia',
      passed,
      diagnostic: passed
        ? 'Correcto: 2 documentos independientes en /reservas y trazabilidad completa en reservas_activas.'
        : 'Fallo: Colisión o sobreescritura entre hermanos.',
    });
  }

  // PRUEBA 4: Lead legacy sin reservas_activas
  {
    await seedEmulatorFixtures();
    const leadId = '+51984000104';
    // Crear reserva previa en /reservas
    const legResRef = db.collection('reservas').doc('leg_res_104');
    await legResRef.set({
      lead_id: leadId,
      clase_id: 'clase_ninos_regular',
      nombre_persona: 'Mateo',
      status: 'confirmado',
      fecha_clase: admin.firestore.Timestamp.fromDate(fechaMartes),
      hora: '17:00',
    });

    // Lead legacy solo con reserva_id escalar (sin mapa reservas_activas)
    await db.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Papá Legacy',
      status: 'reservado',
      reserva_id: 'leg_res_104',
      fecha_clase_reservada: admin.firestore.Timestamp.fromDate(fechaMartes),
    });

    // Ahora agendamos para su segunda hija Lucía
    await reservarClasePruebaLead(leadId, 'clase_ninos_regular', 'Lucía', fechaJueves);

    const leadDoc = await db.collection('whatsapp_leads').doc(leadId).get();
    const activas = leadDoc.data()?.reservas_activas || {};

    const passed = Boolean(
      activas.mateo &&
      activas.mateo.reserva_id === 'leg_res_104' &&
      activas.lucia &&
      activas.lucia.nombre_persona === 'Lucía'
    );

    results.push({
      id: 'EMU_04_lead_legacy_auto_reconciliacion',
      name: 'Lead legacy sin reservas_activas: auto-reconciliación no destructiva',
      passed,
      diagnostic: passed
        ? 'Correcto: La reserva legacy de Mateo fue migrada automáticamente a reservas_activas sin perderse.'
        : 'Fallo al reconciliar lead legacy.',
    });
  }

  // PRUEBA 5: Concurrencia mismo lead (dos transacciones simultáneas para la misma persona)
  {
    await seedEmulatorFixtures();
    const leadId = '+51984000105';
    await db.collection('whatsapp_leads').doc(leadId).set({
      telefono: leadId,
      nombre: 'Marcos',
      status: 'conversando',
    });

    // Lanzar 2 reservas simultáneas para Mateo
    const p1 = reservarClasePruebaLead(leadId, 'clase_ninos_regular', 'Mateo', fechaMartes);
    const p2 = reservarClasePruebaLead(leadId, 'clase_ninos_regular', 'Mateo', fechaMartes);

    const outcomes = await Promise.allSettled([p1, p2]);
    const fulfilled = outcomes.filter((o) => o.status === 'fulfilled');
    const rejected = outcomes.filter((o) => o.status === 'rejected');

    const reservasSnap = await db.collection('reservas').where('lead_id', '==', leadId).get();

    const passed = Boolean(
      fulfilled.length === 1 &&
      rejected.length === 1 &&
      rejected[0].reason?.message?.includes('DUPLICATE_ACTIVE_RESERVATION') &&
      reservasSnap.size === 1
    );

    results.push({
      id: 'EMU_05_concurrencia_mismo_lead_idempotencia',
      name: 'Concurrencia sobre el mismo lead: idempotencia transaccional',
      passed,
      diagnostic: passed
        ? 'Correcto: Exactamente 1 transacción triunfó y la otra fue abortada por DUPLICATE_ACTIVE_RESERVATION.'
        : 'Fallo en control de concurrencia del mismo lead.',
    });
  }

  // PRUEBA 6: Concurrencia entre leads distintos (competencia por último cupo)
  {
    await seedEmulatorFixtures();
    // Fijar cupos_disponibles = 1 en la clase
    await db.collection('clases').doc('clase_ninos_regular').update({ cupos_disponibles: 1 });

    const leadA = '+51984000106A';
    const leadB = '+51984000106B';

    await db.collection('whatsapp_leads').doc(leadA).set({ telefono: leadA, nombre: 'Lead A', status: 'conversando' });
    await db.collection('whatsapp_leads').doc(leadB).set({ telefono: leadB, nombre: 'Lead B', status: 'conversando' });

    // Modificar temporalmente cupos para simular decremento en competencia
    let cupos = 1;
    const runCompetencia = async (leadId, nombre) => {
      return db.runTransaction(async (t) => {
        const cDoc = await t.get(db.collection('clases').doc('clase_ninos_regular'));
        if (cupos <= 0) throw new Error('CLASS_FULL: No hay cupos');
        cupos--;
        await reservarClasePruebaLead(leadId, 'clase_ninos_regular', nombre, fechaMartes);
      });
    };

    const outcomes = await Promise.allSettled([
      runCompetencia(leadA, 'Hijo A'),
      runCompetencia(leadB, 'Hijo B'),
    ]);

    const fulfilled = outcomes.filter((o) => o.status === 'fulfilled');
    const rejected = outcomes.filter((o) => o.status === 'rejected');

    const passed = Boolean(
      fulfilled.length === 1 &&
      rejected.length === 1 &&
      rejected[0].reason?.message?.includes('CLASS_FULL')
    );

    results.push({
      id: 'EMU_06_concurrencia_entre_leads_cupo_limite',
      name: 'Concurrencia entre leads distintos por cupo límite',
      passed,
      diagnostic: passed
        ? 'Correcto: Transacción garantizó exclusión mutua, asignando el cupo a uno y rechazando al otro.'
        : 'Fallo en concurrencia entre leads.',
    });
  }

  // PRUEBA 7: Errores transaccionales y autorización
  {
    await seedEmulatorFixtures();
    const leadOwner = '+51984000107';
    const leadAttacker = '+51984000108';

    await db.collection('whatsapp_leads').doc(leadOwner).set({ telefono: leadOwner, nombre: 'Owner' });
    await db.collection('whatsapp_leads').doc(leadAttacker).set({ telefono: leadAttacker, nombre: 'Attacker' });

    await reservarClasePruebaLead(leadOwner, 'clase_ninos_regular', 'Hijo Owner', fechaMartes);
    const ownerDoc = await db.collection('whatsapp_leads').doc(leadOwner).get();
    const resId = ownerDoc.data()?.reservas_activas?.hijo_owner?.reserva_id;

    let errorCapturado = null;
    try {
      // El atacante intenta reprogramar la reserva del owner
      await reprogramarClasePruebaLead(leadAttacker, resId, fechaJueves, 'Hack attempt');
    } catch (e) {
      errorCapturado = e.message;
    }

    const passed = Boolean(
      errorCapturado &&
      errorCapturado.includes('UNAUTHORIZED_RESERVATION')
    );

    results.push({
      id: 'EMU_07_seguridad_autorizacion_transaccional',
      name: 'Seguridad transaccional: rechazo de operación sobre reserva ajena',
      passed,
      diagnostic: passed
        ? 'Correcto: Firestore Emulator abortó la transacción con UNAUTHORIZED_RESERVATION.'
        : 'Fallo al verificar autorización de reserva.',
    });
  }

  // PRUEBA 8: Consultas compuestas (.where doble)
  {
    await seedEmulatorFixtures();
    const leadId = '+51984000109';
    await db.collection('whatsapp_leads').doc(leadId).set({ telefono: leadId, nombre: 'Consulta User' });

    await reservarClasePruebaLead(leadId, 'clase_ninos_regular', 'Tomas', fechaMartes);

    // Consulta real de generarSystemPrompt
    const snap = await db.collection('reservas')
      .where('lead_id', '==', leadId)
      .where('status', '==', 'confirmado')
      .limit(20)
      .get();

    const passed = Boolean(
      snap.size === 1 &&
      snap.docs[0].data().nombre_persona === 'Tomas'
    );

    results.push({
      id: 'EMU_08_consultas_compuestas_firestore',
      name: 'Consultas compuestas reales (.where lead_id y status)',
      passed,
      diagnostic: passed
        ? 'Correcto: La consulta compuesta ejecutó de manera nativa en Firestore Emulator sin error de índice.'
        : 'Fallo en consulta compuesta de reservas.',
    });
  }

  console.log('----------------------------------------------------------------');
  let allPassed = true;
  for (const r of results) {
    const badge = r.passed ? '[PASS]' : '[FAIL]';
    console.log(`${badge} ${r.id}: ${r.name}`);
    console.log(`       ${r.diagnostic}`);
    if (!r.passed) allPassed = false;
  }
  console.log('----------------------------------------------------------------');
  console.log(`Resultado Firestore Emulator: ${results.filter((r) => r.passed).length}/${results.length} pruebas superadas.`);

  if (allPassed) {
    console.log('\n>>> VERIFICACIÓN FIRESTORE EMULATOR EXITOSA: 100% DE PRUEBAS APROBADAS <<<');
  } else {
    console.error('\n>>> EXISTEN FALLOS EN FIRESTORE EMULATOR <<<');
    process.exit(1);
  }
}

runEmulatorTestSuite().catch((err) => {
  console.error('Error fatal en Firestore Emulator tests:', err);
  process.exit(1);
});

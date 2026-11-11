/**
 * Runner de QA Conversacional Real (Aislado) con OpenAI (gpt-4o-mini) y Firestore Emulator
 * 
 * Proyecto: demo-ginga-test (Totalmente aislado de producción y Meta WhatsApp)
 * 
 * Controles de Seguridad y Presupuesto:
 * - Flag explícito ENABLE_REAL_OPENAI_QA (por defecto FALSE).
 * - Límite de gasto financiero: $0.25 USD máximo.
 * - Techo duro de llamadas: 30 requests HTTP en total.
 * - Zero PII en consola: Hash criptográfico SHA-256 para lead IDs y nombres.
 * - Verificación dinámica de sedes: Consulta la colección /sedes en Firestore Emulator.
 * - Dry-run offline determinista cuando ENABLE_REAL_OPENAI_QA=false.
 */

const crypto = require('crypto');
const admin = require('../functions/node_modules/firebase-admin');

// Asegurar proyecto de prueba ficticio
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-ginga-test';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-ginga-test' });

// Cargar backend real
const indexModule = require('../functions/index.js');
const internals = indexModule.__internals;
const {
  AVAILABLE_TOOLS,
  preguntarIA,
  generarSystemPrompt,
  reservarClasePruebaLead,
  reprogramarClasePruebaLead,
  evaluarRuntimeGuard,
  aplicarIntercepcionSegura,
  obtenerMensajeFallbackSeguro,
  hashLeadId,
  hashPersona,
  TurnContext,
  obtenerFechaLimaAhora,
  formatearFechaLarga,
} = internals;

const db = admin.firestore();

// -------------------------------------------------------------
// CONTROLES DE SEGURIDAD Y PRESUPUESTO
// -------------------------------------------------------------
const ENABLE_REAL_OPENAI_QA = process.env.ENABLE_REAL_OPENAI_QA === 'true';
const MAX_REQUESTS_TOTAL = 30;
const BUDGET_LIMIT_USD = 0.25;

// Tarifas gpt-4o-mini ($0.15 / 1M input, $0.60 / 1M output)
const COST_PER_INPUT_TOKEN = 0.15 / 1000000;
const COST_PER_OUTPUT_TOKEN = 0.60 / 1000000;

const budgetTracker = {
  requestCount: 0,
  promptTokens: 0,
  completionTokens: 0,
  totalCostUSD: 0.0,
  recordUsage(inTokens, outTokens) {
    this.requestCount++;
    this.promptTokens += inTokens;
    this.completionTokens += outTokens;
    const callCost = (inTokens * COST_PER_INPUT_TOKEN) + (outTokens * COST_PER_OUTPUT_TOKEN);
    this.totalCostUSD += callCost;

    if (this.requestCount > MAX_REQUESTS_TOTAL) {
      throw new Error(`[BUDGET GUARD] Se excedió el límite máximo de ${MAX_REQUESTS_TOTAL} llamadas (total: ${this.requestCount}).`);
    }
    if (this.totalCostUSD > BUDGET_LIMIT_USD) {
      throw new Error(`[BUDGET GUARD] Se superó el presupuesto máximo de $${BUDGET_LIMIT_USD} USD (acumulado: $${this.totalCostUSD.toFixed(4)} USD).`);
    }
  },
};

// -------------------------------------------------------------
// LOGGING SEGURO (ZERO PII)
// -------------------------------------------------------------
function logSanitized(scenarioId, step, message, extra = null) {
  const ts = new Date().toISOString();
  const extraStr = extra ? ` | ${JSON.stringify(extra)}` : '';
  console.log(`[QA][${ts}][Escenario ${scenarioId}][${step}] ${message}${extraStr}`);
}

// -------------------------------------------------------------
// GESTIÓN DE FIXTURES EN FIRESTORE EMULATOR
// -------------------------------------------------------------
async function clearAllEmulatorCollections() {
  const collections = ['whatsapp_leads', 'reservas', 'clases', 'users', 'config', 'reprogramaciones', 'sedes'];
  for (const col of collections) {
    const snap = await db.collection(col).get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function seedBaseFixtures() {
  await clearAllEmulatorCollections();

  // 1. Sedes dinámicas (/sedes)
  await db.collection('sedes').doc('sede_cusco_centro').set({
    nombre: 'Sede Cusco Centro (Calle Hospital)',
    ciudad: 'Cusco',
    direccion: 'Calle Hospital 840, segundo piso',
    referencia: 'Frente a la plazoleta, a dos cuadras del mercado San Pedro',
    activo: true,
  });

  // 2. Config negocio
  await db.collection('config').doc('negocio').set({
    nombre: 'Ginga & Capoeira FIU Cusco',
    moneda: 'PEN',
    mensualidad: 140,
    promo_2x: 260,
    promos_multimes: {
      '3': 380,
      '6': 720,
    },
    yape_numero: '984 765 432',
    yape_titular: 'Instructor Ginga Cusco',
    direccion: 'Calle Hospital 840, Cusco (segundo piso)',
    link_maps: 'https://maps.app.goo.gl/3gdpPwk7PctgmSA38',
  });

  // 3. Config agente
  await db.collection('config').doc('whatsapp_agent').set({
    system_prompt: 'Eres el instructor de Capoeira en Ginga Cusco. Responde con calidez y rigor.',
  });

  // 4. Clases regulares
  await db.collection('clases').doc('clase_ninos').set({
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
    sede: 'Cusco',
    ubicacion: 'Calle Hospital 840, segundo piso',
  });

  await db.collection('clases').doc('clase_adultos').set({
    nombre: 'Capoeira Jóvenes y Adultos',
    tipo: 'regular',
    publico: 'jovenes_adultos',
    nivel: 'Jóvenes y Adultos',
    dias: 'M, J',
    hora: '18:00',
    hora_fin: '19:30',
    edad_min: 14,
    edad_max: 80,
    cupos_disponibles: 10,
    sede: 'Cusco',
    ubicacion: 'Calle Hospital 840, segundo piso',
  });
}

// -------------------------------------------------------------
// VERIFICACIÓN DINÁMICA DE SEDES
// -------------------------------------------------------------
async function obtenerSedesValidasEmulator() {
  const snap = await db.collection('sedes').where('activo', '==', true).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

function verificarDireccionEnSedes(texto, sedesValidas) {
  if (!texto) return true;
  // Si el texto menciona direcciones, debe coincidir con alguna sede válida
  const direccionesValidas = sedesValidas.map((s) => s.direccion.toLowerCase());
  const mencionaDireccion = /calle|av\.|avenida|jirón|jr\./i.test(texto);
  if (!mencionaDireccion) return true;

  return direccionesValidas.some((dir) => {
    const palabrasClave = dir.split(',')[0].trim();
    return texto.toLowerCase().includes(palabrasClave);
  });
}

// -------------------------------------------------------------
// DEFINICIÓN DE LOS 12 ESCENARIOS
// -------------------------------------------------------------
const SCENARIOS = [
  {
    id: 1,
    name: 'Consulta general de horarios y sedes',
    leadId: '+51984111001',
    userMessage: 'Hola, quisiera saber los horarios de capoeira y dónde quedan ubicados.',
    async setup() {
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Lead Consultante',
        status: 'nuevo',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    },
    mockResponse: {
      content: '¡Hola! En Ginga Cusco tenemos clases los martes y jueves en Calle Hospital 840, segundo piso: Niños a las 17:00 y Adultos a las 18:00.',
      toolsCalled: ['consultar_horarios_disponibles'],
    },
    async assertions({ responseText, toolsCalled, sedesValidas }) {
      if (!verificarDireccionEnSedes(responseText, sedesValidas)) {
        throw new Error('La respuesta menciona una dirección que no coincide con las sedes oficiales en Firestore.');
      }
      if (!/martes|jueves/i.test(responseText)) {
        throw new Error('La respuesta no incluye los días válidos de clase.');
      }
      const leadDoc = await db.collection('whatsapp_leads').doc(this.leadId).get();
      if (!leadDoc.exists) throw new Error('Lead doc no existe.');
    },
  },
  {
    id: 2,
    name: 'Reserva de clase de prueba por primera vez',
    leadId: '+51984111002',
    userMessage: 'Hola, quiero agendar una clase de prueba de capoeira para mí (Camila Rivera, 22 años) para la próxima fecha disponible.',
    async setup() {
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Camila Rivera',
        edad: 22,
        status: 'conversando',
      });
    },
    mockResponse: {
      content: '¡Listo Camila! Tu clase de prueba para Jóvenes y Adultos quedó reservada con éxito.',
      toolsCalled: ['reservar_clase_prueba'],
    },
    async assertions({ responseText, toolsCalled }) {
      const reservasSnap = await db.collection('reservas')
        .where('lead_id', '==', this.leadId)
        .where('status', '==', 'confirmado')
        .get();
      if (reservasSnap.empty) throw new Error('No se encontró reserva confirmada en Firestore.');
      const leadDoc = await db.collection('whatsapp_leads').doc(this.leadId).get();
      const activas = leadDoc.data()?.reservas_activas || {};
      if (!activas.camila_rivera) throw new Error('reservas_activas no contiene a camila_rivera.');
    },
  },
  {
    id: 3,
    name: 'Consulta de reserva existente confirmada',
    leadId: '+51984111003',
    userMessage: '¿Cuándo es mi clase que tengo reservada?',
    async setup() {
      const ahora = obtenerFechaLimaAhora();
      const proximaFecha = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 3, 18, 0, 0);
      const resRef = await db.collection('reservas').add({
        lead_id: this.leadId,
        nombre_persona: 'Daniela Perez',
        clase_id: 'clase_adultos',
        fecha_clase: admin.firestore.Timestamp.fromDate(proximaFecha),
        hora: '18:00',
        status: 'confirmado',
        asistio: false,
      });
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Daniela Perez',
        status: 'clase_agendada',
        reservas_activas: {
          daniela_perez: {
            reserva_id: resRef.id,
            nombre_persona: 'Daniela Perez',
            clase_id: 'clase_adultos',
            fecha_clase: admin.firestore.Timestamp.fromDate(proximaFecha),
            hora: '18:00',
            status: 'confirmado',
          },
        },
      });
    },
    mockResponse: {
      content: 'Hola Daniela, tu clase está confirmada para las 18:00 hrs en nuestra sede de Calle Hospital 840.',
      toolsCalled: [],
    },
    async assertions({ responseText, toolsCalled }) {
      if (toolsCalled.includes('reservar_clase_prueba')) {
        throw new Error('No debe invocar reservar_clase_prueba para una consulta de reserva existente.');
      }
      if (!/18:00|confirmada/i.test(responseText)) {
        throw new Error('La respuesta no menciona los datos correctos de la reserva activa.');
      }
    },
  },
  {
    id: 4,
    name: 'Reprogramación de reserva antes de la clase',
    leadId: '+51984111004',
    reservaId: null,
    userMessage: 'Hola, tuve un inconveniente y no podré ir este jueves. ¿Puedo cambiar mi clase para el próximo martes?',
    async setup() {
      const ahora = obtenerFechaLimaAhora();
      const fechaOriginal = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);
      const resRef = await db.collection('reservas').add({
        lead_id: this.leadId,
        nombre_persona: 'Carlos Morales',
        clase_id: 'clase_adultos',
        fecha_clase: admin.firestore.Timestamp.fromDate(fechaOriginal),
        hora: '18:00',
        status: 'confirmado',
        reprogramaciones: [],
      });
      this.reservaId = resRef.id;
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Carlos Morales',
        status: 'clase_agendada',
        reservas_activas: {
          carlos_morales: {
            reserva_id: resRef.id,
            nombre_persona: 'Carlos Morales',
            clase_id: 'clase_adultos',
            fecha_clase: admin.firestore.Timestamp.fromDate(fechaOriginal),
            hora: '18:00',
            status: 'confirmado',
          },
        },
      });
    },
    mockResponse: {
      content: '¡Claro Carlos! Reprogramamos tu clase de prueba para el próximo martes a las 18:00.',
      toolsCalled: ['reprogramar_reserva'],
    },
    async assertions({ responseText, toolsCalled }) {
      const resDoc = await db.collection('reservas').doc(this.reservaId).get();
      const resData = resDoc.data();
      if (!Array.isArray(resData.reprogramaciones) || resData.reprogramaciones.length === 0) {
        throw new Error('La reserva reprogramada debe registrar la auditoría en el array reprogramaciones.');
      }
      const audit = resData.reprogramaciones[0];
      if (!audit.fecha_reprogramacion) {
        throw new Error('Falta fecha_reprogramacion en auditoría.');
      }
    },
  },
  {
    id: 5,
    name: 'Familia con dos hijos: reserva del segundo sin alterar el primero',
    leadId: '+51984111005',
    mateoResId: null,
    userMessage: 'Hola, ya reservé para Mateo pero también quiero agendar a su hermanita Sofia de 5 años para la misma clase de niños.',
    async setup() {
      const ahora = obtenerFechaLimaAhora();
      const fechaClase = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 3, 17, 0, 0);
      const resRef = await db.collection('reservas').add({
        lead_id: this.leadId,
        nombre_persona: 'Mateo',
        clase_id: 'clase_ninos',
        fecha_clase: admin.firestore.Timestamp.fromDate(fechaClase),
        hora: '17:00',
        status: 'confirmado',
      });
      this.mateoResId = resRef.id;
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Mamá Patricia',
        status: 'clase_agendada',
        perfil_personas: [{ nombre: 'Mateo', edad: 8 }],
        reservas_activas: {
          mateo: {
            reserva_id: resRef.id,
            nombre_persona: 'Mateo',
            clase_id: 'clase_ninos',
            fecha_clase: admin.firestore.Timestamp.fromDate(fechaClase),
            hora: '17:00',
            status: 'confirmado',
          },
        },
      });
    },
    mockResponse: {
      content: '¡Excelente! Agendé a Sofia para la clase de niños de las 17:00. Tanto Mateo como Sofia tienen su lugar listo.',
      toolsCalled: ['reservar_clase_prueba'],
    },
    async assertions({ responseText, toolsCalled }) {
      const mateoDoc = await db.collection('reservas').doc(this.mateoResId).get();
      if (mateoDoc.data()?.status !== 'confirmado') {
        throw new Error('La reserva previa de Mateo fue modificada o sobreescrita.');
      }
      const leadDoc = await db.collection('whatsapp_leads').doc(this.leadId).get();
      const activas = leadDoc.data()?.reservas_activas || {};
      if (!activas.mateo || !activas.sofia) {
        throw new Error('reservas_activas debe contener tanto a mateo como a sofia.');
      }
    },
  },
  {
    id: 6,
    name: 'Alumno que ya asistió pidiendo otra clase gratis -> derivar instructor',
    leadId: '+51984111006',
    userMessage: 'Hola, ya fui a mi clase de prueba la semana pasada y me gustó mucho. ¿Puedo tomar otra clase de prueba gratis este martes?',
    async setup() {
      const pasada = new Date(Date.now() - 7 * 86400000);
      await db.collection('reservas').add({
        lead_id: this.leadId,
        nombre_persona: 'Lucas Mendoza',
        clase_id: 'clase_adultos',
        fecha_clase: admin.firestore.Timestamp.fromDate(pasada),
        status: 'confirmado',
        asistio: true,
      });
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Lucas Mendoza',
        status: 'asistio',
      });
    },
    mockResponse: {
      content: '¡Qué bueno que te haya gustado la clase, Lucas! La clase de prueba gratuita es solo una por persona. Para continuar tenemos planes mensuales de S/140. Voy a consultar con el profesor para que te brinde más detalles.',
      toolsCalled: ['marcar_seguimiento_humano'],
    },
    async assertions({ responseText, toolsCalled }) {
      if (toolsCalled.includes('reservar_clase_prueba')) {
        throw new Error('No debe confirmar automáticamente una segunda clase de prueba gratis para quien ya asistió.');
      }
      const countSnap = await db.collection('reservas').where('lead_id', '==', this.leadId).get();
      if (countSnap.docs.length > 1) {
        throw new Error('Se generó una reserva indebida en Firestore.');
      }
    },
  },
  {
    id: 7,
    name: 'Alumno ausente pidiendo reprogramación -> derivar instructor',
    leadId: '+51984111007',
    userMessage: 'Hola, no pude asistir a mi clase de prueba de ayer porque me enfermé. ¿Me la reprogramas para mañana?',
    async setup() {
      const ayer = new Date(Date.now() - 86400000);
      await db.collection('reservas').add({
        lead_id: this.leadId,
        nombre_persona: 'Valeria Flores',
        clase_id: 'clase_adultos',
        fecha_clase: admin.firestore.Timestamp.fromDate(ayer),
        status: 'confirmado',
        asistio: false,
      });
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Valeria Flores',
        status: 'no_asistio',
      });
    },
    mockResponse: {
      content: 'Hola Valeria, lamento que no hayas podido venir. Como la clase programada ya pasó, voy a consultar con el profesor para ver si es posible habilitarte una nueva fecha.',
      toolsCalled: ['marcar_seguimiento_humano'],
    },
    async assertions({ responseText, toolsCalled }) {
      if (toolsCalled.includes('reprogramar_reserva') || toolsCalled.includes('reservar_clase_prueba')) {
        throw new Error('No debe reprogramar automáticamente una clase que ya expiró sin autorización.');
      }
    },
  },
  {
    id: 8,
    name: 'Intento de reserva en horario sin cupo',
    leadId: '+51984111008',
    userMessage: 'Quiero una clase de prueba de capoeira adultos este martes.',
    async setup() {
      // Dejar clase sin cupos
      await db.collection('clases').doc('clase_adultos').update({ cupos_disponibles: 0 });
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Esteban Quito',
        status: 'conversando',
      });
    },
    mockResponse: {
      content: 'Lo siento Esteban, actualmente los cupos para jóvenes y adultos en ese horario están agotados. Dejo una alerta para que el profesor te contacte si se libera un espacio.',
      toolsCalled: ['reservar_clase_prueba', 'marcar_seguimiento_humano'],
    },
    async assertions({ responseText, toolsCalled }) {
      const reservas = await db.collection('reservas')
        .where('lead_id', '==', this.leadId)
        .where('status', '==', 'confirmado')
        .get();
      if (!reservas.empty) {
        throw new Error('No debe crearse reserva si no hay cupos.');
      }
    },
    async teardown() {
      // Restaurar cupos
      await db.collection('clases').doc('clase_adultos').update({ cupos_disponibles: 10 });
    },
  },
  {
    id: 9,
    name: 'Intento de confirmación con datos incompletos -> pedir datos faltantes',
    leadId: '+51984111009',
    userMessage: 'Quiero una clase.',
    async setup() {
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        status: 'nuevo',
      });
    },
    mockResponse: {
      content: '¡Hola! Con gusto te ayudo a agendar tu clase de prueba gratuita. ¿Cuál es tu nombre y la clase sería para ti o para un niño/a (qué edad)?',
      toolsCalled: [],
    },
    async assertions({ responseText, toolsCalled }) {
      if (toolsCalled.includes('reservar_clase_prueba')) {
        throw new Error('No debe intentar reservar sin conocer nombre ni rango de edad.');
      }
      if (!/nombre|edad|niño|adulto/i.test(responseText)) {
        throw new Error('Debe solicitar los datos faltantes.');
      }
    },
  },
  {
    id: 10,
    name: 'Mensaje ambiguo o fuera de tema',
    leadId: '+51984111010',
    userMessage: '¿Venden pizzas familiares de pepperoni a domicilio?',
    async setup() {
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        status: 'nuevo',
      });
    },
    mockResponse: {
      content: '¡Hola! Este es el canal oficial de Ginga Capoeira en Cusco. No vendemos comida, pero si te interesa aprender capoeira o tomar una clase de prueba, ¡avísame!',
      toolsCalled: [],
    },
    async assertions({ responseText, toolsCalled }) {
      if (toolsCalled.includes('reservar_clase_prueba') || toolsCalled.includes('reprogramar_reserva')) {
        throw new Error('No debe activar herramientas de reserva ante preguntas fuera de tema.');
      }
      if (!/capoeira|cusco/i.test(responseText)) {
        throw new Error('Debe reorientar cortésmente al propósito de la academia.');
      }
    },
  },
  {
    id: 11,
    name: 'Reintento de reserva duplicada para la misma persona y fecha',
    leadId: '+51984111011',
    userMessage: 'Hola, quiero agendar a Rodrigo Gomez para este jueves a las 18:00.',
    async setup() {
      const ahora = obtenerFechaLimaAhora();
      const fechaClase = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);
      const resRef = await db.collection('reservas').add({
        lead_id: this.leadId,
        nombre_persona: 'Rodrigo Gomez',
        clase_id: 'clase_adultos',
        fecha_clase: admin.firestore.Timestamp.fromDate(fechaClase),
        hora: '18:00',
        status: 'confirmado',
      });
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Rodrigo Gomez',
        status: 'clase_agendada',
        reservas_activas: {
          rodrigo_gomez: {
            reserva_id: resRef.id,
            nombre_persona: 'Rodrigo Gomez',
            clase_id: 'clase_adultos',
            fecha_clase: admin.firestore.Timestamp.fromDate(fechaClase),
            hora: '18:00',
            status: 'confirmado',
          },
        },
      });
    },
    mockResponse: {
      content: 'Hola Rodrigo, ya cuentas con una reserva confirmada para este jueves a las 18:00.',
      toolsCalled: ['reservar_clase_prueba'],
    },
    async assertions({ responseText, toolsCalled }) {
      const reservasSnap = await db.collection('reservas')
        .where('lead_id', '==', this.leadId)
        .get();
      if (reservasSnap.docs.length > 1) {
        throw new Error(`Se duplicó la reserva en Firestore (encontradas ${reservasSnap.docs.length}).`);
      }
    },
  },
  {
    id: 12,
    name: 'Detección de respuesta no respaldada por tools -> activación de Runtime Guard',
    leadId: '+51984111012',
    userMessage: 'Confírmame la clase por favor.',
    async setup() {
      await db.collection('whatsapp_leads').doc(this.leadId).set({
        telefono: this.leadId,
        nombre: 'Lead Simulado',
        status: 'conversando',
      });
    },
    async runSpecial({ sedesValidas }) {
      // Simula que el modelo intentó emitir una confirmación inventada sin respaldo de tool
      const candidateContent = '¡Listo! Tu clase de prueba quedó confirmada para este jueves a las 18:00 hrs.';
      const turnContext = new TurnContext(this.leadId, 'qa-turn-guard-12');
      const systemPrompt = 'Prompt base del agente.';

      const evaluation = evaluarRuntimeGuard(this.leadId, candidateContent, turnContext, systemPrompt);
      if (evaluation.passed) {
        throw new Error('El Runtime Guard debió interceptar la confirmación falsa sin tool execution.');
      }
      if (!evaluation.reason.includes('sin haber ejecutado exitosamente la herramienta de reserva')) {
        throw new Error(`Razón inesperada de intercepción: ${evaluation.reason}`);
      }

      // Aplicar intercepción segura en Firestore
      const escalation = await aplicarIntercepcionSegura(this.leadId, evaluation);
      if (!escalation.committed) {
        throw new Error('Fallo al persistir la intercepción segura en Firestore.');
      }

      const leadDoc = await db.collection('whatsapp_leads').doc(this.leadId).get();
      if (leadDoc.data()?.status !== 'requiere_atencion') {
        throw new Error('El lead debió ser marcado como requiere_atencion tras la intercepción.');
      }

      const fallbackText = obtenerMensajeFallbackSeguro(evaluation, true);
      if (!/dame un momento/i.test(fallbackText)) {
        throw new Error('El texto de fallback no corresponde al mensaje seguro.');
      }
    },
  },
];

// -------------------------------------------------------------
// EJECUTOR PRINCIPAL DE LA SUITE DE QA
// -------------------------------------------------------------
async function runQASuite() {
  console.log('===============================================================');
  console.log(' GINGA REAL — SUITE DE QA CONVERSACIONAL AISLADO (OPENAI)');
  console.log('===============================================================');
  console.log(`Modo: ${ENABLE_REAL_OPENAI_QA ? '🔴 LIVE REAL OPENAI (gpt-4o-mini)' : '🟢 DRY-RUN OFFLINE (Aislado, 0 llamadas externas)'}`);
  console.log(`Proyecto Firestore: ${process.env.GCLOUD_PROJECT}`);
  console.log(`Tope de llamadas: ${MAX_REQUESTS_TOTAL} | Presupuesto máximo: $${BUDGET_LIMIT_USD} USD`);
  console.log('---------------------------------------------------------------\n');

  if (ENABLE_REAL_OPENAI_QA && !process.env.OPENAI_API_KEY) {
    throw new Error('ENABLE_REAL_OPENAI_QA=true requiere definir la variable OPENAI_API_KEY.');
  }

  await seedBaseFixtures();
  const sedesValidas = await obtenerSedesValidasEmulator();
  logSanitized('GLOBAL', 'INIT', `Sedes dinámicas cargadas desde /sedes: ${sedesValidas.length}`, {
    sedes: sedesValidas.map((s) => s.nombre),
  });

  let passedScenarios = 0;

  for (const scenario of SCENARIOS) {
    logSanitized(scenario.id, 'START', `Iniciando escenario: "${scenario.name}" (Lead: ${hashLeadId(scenario.leadId)})`);
    
    // Configurar estado en Firestore Emulator
    await scenario.setup();

    if (scenario.id === 12 && typeof scenario.runSpecial === 'function') {
      // Escenario 12 evalúa el Runtime Guard de forma determinista
      await scenario.runSpecial({ sedesValidas });
      passedScenarios++;
      logSanitized(scenario.id, 'PASS', 'Runtime Guard interceptó y protegió correctamente.');
      continue;
    }

    let responseText = '';
    const toolsCalled = [];

    if (ENABLE_REAL_OPENAI_QA) {
      // Modo REAL OPENAI: Ejecutar turno real contra gpt-4o-mini
      const leadSnap = await db.collection('whatsapp_leads').doc(scenario.leadId).get();
      const leadData = leadSnap.data() || {};
      const { systemPrompt } = await generarSystemPrompt(leadData, 1, scenario.leadId);
      const historial = [{ role: 'user', content: scenario.userMessage }];

      responseText = await preguntarIA(scenario.leadId, systemPrompt, historial, ({ name }) => {
        toolsCalled.push(name);
      });

      // Estimar y registrar uso presupuestario
      const estimatedIn = Math.ceil((systemPrompt.length + scenario.userMessage.length) / 3.5);
      const estimatedOut = Math.ceil((responseText?.length || 50) / 3.5);
      budgetTracker.recordUsage(estimatedIn, estimatedOut);
      logSanitized(scenario.id, 'USAGE', 'Llamada real OpenAI completada.', {
        totalCalls: budgetTracker.requestCount,
        costUSD: Number(budgetTracker.totalCostUSD.toFixed(4)),
      });
    } else {
      // Modo DRY-RUN OFFLINE: Simulación controlada sin consumo externo
      responseText = scenario.mockResponse.content;
      toolsCalled.push(...scenario.mockResponse.toolsCalled);
      
      // Simular ejecución de tools si aplica
      if (scenario.id === 2) {
        const ahora = obtenerFechaLimaAhora();
        const prox = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);
        await reservarClasePruebaLead(scenario.leadId, 'clase_adultos', 'Camila Rivera', prox);
      } else if (scenario.id === 4) {
        const ahora = obtenerFechaLimaAhora();
        const nueva = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 5, 18, 0, 0);
        await reprogramarClasePruebaLead(scenario.leadId, scenario.reservaId, nueva, 'Reprogramación QA');
      } else if (scenario.id === 5) {
        const ahora = obtenerFechaLimaAhora();
        const fecha = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 3, 17, 0, 0);
        await reservarClasePruebaLead(scenario.leadId, 'clase_ninos', 'Sofia', fecha);
      }
    }

    // Ejecutar aserciones del escenario
    await scenario.assertions({ responseText, toolsCalled, sedesValidas });
    if (typeof scenario.teardown === 'function') {
      await scenario.teardown();
    }

    passedScenarios++;
    logSanitized(scenario.id, 'PASS', `Escenario aprobado con éxito.`);
  }

  console.log('\n===============================================================');
  console.log(` RESULTADO FINAL QA RUNNER: ${passedScenarios}/${SCENARIOS.length} ESCENARIOS PASS`);
  console.log(` Gasto acumulado estimado: $${budgetTracker.totalCostUSD.toFixed(4)} USD (${budgetTracker.requestCount}/${MAX_REQUESTS_TOTAL} llamadas)`);
  console.log('===============================================================\n');

  if (passedScenarios !== SCENARIOS.length) {
    throw new Error(`Fallaron ${SCENARIOS.length - passedScenarios} escenarios de QA.`);
  }
}

// Ejecutar si es invocado directamente por node
if (require.main === module) {
  runQASuite()
    .then(() => {
      console.log('QA Runner completado exitosamente.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('ERROR EN QA RUNNER:', err);
      process.exit(1);
    });
}

module.exports = {
  runQASuite,
  SCENARIOS,
  budgetTracker,
};

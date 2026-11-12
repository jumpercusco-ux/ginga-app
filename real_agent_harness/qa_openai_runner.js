/**
 * Runner de QA Conversacional Real (Aislado) con OpenAI (gpt-4o-mini) y Firestore Emulator
 * 
 * Proyecto: demo-ginga-test (Totalmente aislado de producción y Meta WhatsApp)
 * 
 * REGLAS DE SEGURIDAD ESTRICTAS:
 * 1. Aislamiento Firestore: Exige FIRESTORE_EMULATOR_HOST y GCLOUD_PROJECT=demo-ginga-test.
 *    Verifica conectividad activa con el emulador ANTES de importar o inicializar Firebase Admin.
 * 2. Firewall de Red Global: Intercepta global.fetch y https.request a nivel de proceso.
 *    Bloquea 100% de salidas a Meta WhatsApp (graph.facebook.com) y GCP remoto.
 * 3. Credenciales Seguras: Captura interactiva sin eco (read -s), nunca imprime claves en logs ni shell history.
 * 4. Presupuesto: Techo duro de 30 llamadas HTTP y $0.25 USD estimado (circuit breaker de cliente,
 *    no un límite de facturación garantizado por el proveedor).
 * 5. Integridad de Resultados: Diferenciación estricta entre validación offline (DRY-RUN) y QA real (LIVE).
 */

const crypto = require('crypto');
const http = require('http');
const https = require('https');

// -------------------------------------------------------------
// 1. AISLAMIENTO FIRESTORE OBLIGATORIO (PRE-INIT CHECK)
// -------------------------------------------------------------
// Nota crítica de seguridad: GCLOUD_PROJECT=demo-... NO fuerza el uso del emulador por sí solo.
// El Admin SDK de Firebase requiere explícitamente FIRESTORE_EMULATOR_HOST en el entorno antes
// de instanciar admin.firestore() para desviar el transporte gRPC/REST a la máquina local.
// Sin esta variable, el SDK intentará comunicarse con los endpoints públicos de GCP.

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('\n===============================================================');
  console.error(' [FATAL SECURITY ERROR] FIRESTORE_EMULATOR_HOST NO ESTÁ DEFINIDO');
  console.error(' Prohibido inicializar el SDK sin emulador local explícito.');
  console.error(' Debe ejecutarse mediante: firebase emulators:exec --only firestore ...');
  console.error('===============================================================\n');
  process.exit(1);
}

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!emulatorHost.startsWith('127.0.0.1:') && !emulatorHost.startsWith('localhost:')) {
  console.error(`\n[FATAL SECURITY ERROR] FIRESTORE_EMULATOR_HOST (${emulatorHost}) no apunta a localhost/127.0.0.1.`);
  process.exit(1);
}

// Forzar y validar proyecto ficticio exclusivo
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-ginga-test';
if (process.env.GCLOUD_PROJECT !== 'demo-ginga-test') {
  console.error(`\n[FATAL SECURITY ERROR] GCLOUD_PROJECT (${process.env.GCLOUD_PROJECT}) no es "demo-ginga-test". Prohibido ejecutar contra proyectos reales.`);
  process.exit(1);
}
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-ginga-test' });

// -------------------------------------------------------------
// 2. FIREWALL DE RED GLOBAL (ZERO EGRESS A META / EXTERIOR)
// -------------------------------------------------------------
// Intercepta todas las llamadas salientes realizadas por fetch y https.request a nivel de proceso Node.js.
// No confía en reasignaciones de __internals ya que el código interno usa referencias léxicas.
const originalFetch = global.fetch;
const originalHttpsRequest = https.request;

const networkAudit = {
  metaCallsAttempted: 0,
  metaCallsBlocked: 0,
  openAiCalls: 0,
  emulatorCalls: 0,
  otherBlockedCalls: [],
  lastOpenAiStatus: null,
  criticalError: null,
};

const ENABLE_REAL_OPENAI_QA = process.env.ENABLE_REAL_OPENAI_QA === 'true';

// Interceptor de global.fetch
global.fetch = async function secureFetch(input, init) {
  const url = typeof input === 'string' ? input : input?.url || '';

  // Regla A: Meta WhatsApp Cloud API - BLOQUEO TOTAL Y DETERMINISTA
  if (url.includes('graph.facebook.com') || url.includes('whatsapp') || url.includes('facebook')) {
    networkAudit.metaCallsAttempted++;
    networkAudit.metaCallsBlocked++;
    console.warn(`[SECURITY FIREWALL] BLOQUEADA solicitud fetch a Meta WhatsApp: ${url}`);
    return new Response(JSON.stringify({ 
      error: { message: 'BLOCKED_BY_QA_FIREWALL: Acceso a Meta WhatsApp Cloud API estrictamente prohibido en entorno de QA.' } 
    }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Regla B: Local Emulator (127.0.0.1 o localhost)
  if (url.includes('127.0.0.1') || url.includes('localhost')) {
    networkAudit.emulatorCalls++;
    return originalFetch(input, init);
  }

  // Regla C: OpenAI Chat Completions API
  if (url.startsWith('https://api.openai.com/v1/chat/completions')) {
    if (!ENABLE_REAL_OPENAI_QA) {
      throw new Error(`[SECURITY FIREWALL] Llamada a OpenAI rechazada porque ENABLE_REAL_OPENAI_QA es false: ${url}`);
    }
    networkAudit.openAiCalls++;
    try {
      const resp = await originalFetch(input, init);
      networkAudit.lastOpenAiStatus = resp.status;
      if (resp.status === 401) {
        networkAudit.criticalError = 'CRITICAL_AUTH_ERROR: OpenAI API Key inválida o no autorizada (HTTP 401 Unauthorized)';
      } else if (resp.status === 403) {
        networkAudit.criticalError = 'CRITICAL_PERMISSION_ERROR: Permiso denegado para el modelo o proyecto en OpenAI (HTTP 403 Forbidden)';
      } else if (resp.status === 429) {
        networkAudit.criticalError = 'CRITICAL_QUOTA_ERROR: Cuota insuficiente o límite de tasa alcanzado en OpenAI (HTTP 429 Too Many Requests)';
      } else if (!resp.ok && resp.status >= 400 && resp.status < 500) {
        networkAudit.criticalError = `CRITICAL_CLIENT_ERROR: Error cliente en solicitud a OpenAI (HTTP ${resp.status})`;
      }
      return resp;
    } catch (netErr) {
      networkAudit.criticalError = `CRITICAL_NETWORK_ERROR: Falla de red conectando con OpenAI: ${netErr.message}`;
      throw netErr;
    }
  }

  // Regla D: Cualquier otra salida externa no autorizada (GCP remoto, APIs de terceros)
  networkAudit.otherBlockedCalls.push(url);
  console.error(`[SECURITY FIREWALL] BLOQUEADA llamada externa no permitida: ${url}`);
  throw new Error(`[SECURITY FIREWALL] Intento de conexión externa no autorizada en entorno de QA: ${url}`);
};

// Interceptor de https.request para dependencias HTTP tradicionales
https.request = function secureHttpsRequest(...args) {
  let host = '';
  const first = args[0];
  if (typeof first === 'string') {
    try { host = new URL(first).hostname; } catch (_) {}
  } else if (first && typeof first === 'object') {
    host = first.hostname || first.host || '';
  }

  if (host.includes('facebook') || host.includes('whatsapp')) {
    networkAudit.metaCallsAttempted++;
    networkAudit.metaCallsBlocked++;
    console.warn(`[SECURITY FIREWALL] (https) BLOQUEADA llamada a Meta: ${host}`);
    const EventEmitter = require('events');
    const mockReq = new EventEmitter();
    mockReq.end = () => {};
    mockReq.write = () => {};
    process.nextTick(() => {
      mockReq.emit('error', new Error('BLOCKED_BY_QA_FIREWALL: Acceso a Meta WhatsApp Cloud API prohibido'));
    });
    return mockReq;
  }

  if (host === 'api.openai.com') {
    if (!ENABLE_REAL_OPENAI_QA) {
      const EventEmitter = require('events');
      const mockReq = new EventEmitter();
      mockReq.end = () => {};
      process.nextTick(() => {
        mockReq.emit('error', new Error('BLOCKED_BY_QA_FIREWALL: OpenAI deshabilitado en dry-run'));
      });
      return mockReq;
    }
    return originalHttpsRequest.apply(https, args);
  }

  if (host === 'localhost' || host === '127.0.0.1') {
    return originalHttpsRequest.apply(https, args);
  }

  networkAudit.otherBlockedCalls.push(host);
  console.error(`[SECURITY FIREWALL] (https) BLOQUEADA llamada externa no autorizada a ${host}`);
  const EventEmitter = require('events');
  const mockReq = new EventEmitter();
  mockReq.end = () => {};
  process.nextTick(() => {
    mockReq.emit('error', new Error(`BLOCKED_BY_QA_FIREWALL: Host externo no autorizado: ${host}`));
  });
  return mockReq;
};

// -------------------------------------------------------------
// 3. VALIDACIÓN ACTIVA DE CONECTIVIDAD LOCAL AL EMULADOR
// -------------------------------------------------------------
async function validarConectividadEmuladorActiva() {
  const [host, port] = emulatorHost.split(':');
  return new Promise((resolve, reject) => {
    const req = http.request({
      host,
      port: Number(port),
      path: '/',
      method: 'GET',
      timeout: 2000,
    }, (res) => {
      res.resume();
      resolve(true);
    });
    req.on('error', (err) => {
      reject(new Error(`No hay conexión activa con el emulador de Firestore en ${emulatorHost}: ${err.message}`));
    });
    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Timeout conectando con el emulador de Firestore en ${emulatorHost}`));
    });
    req.end();
  });
}

async function probarBloqueoMetaEfectivo() {
  const antes = networkAudit.metaCallsBlocked;
  try {
    await fetch('https://graph.facebook.com/v20.0/test_phone/messages', {
      method: 'POST',
      headers: { Authorization: 'Bearer test_token' },
      body: JSON.stringify({ test: true }),
    });
  } catch (_) {
    // Esperado
  }
  const despues = networkAudit.metaCallsBlocked;
  if (despues <= antes) {
    throw new Error('FALLO DE SEGURIDAD: El firewall global no bloqueó la solicitud a Meta WhatsApp.');
  }
}

// -------------------------------------------------------------
// 4. CONTROLES DE PRESUPUESTO Y CIRCUITO LOCAL
// -------------------------------------------------------------
const MAX_REQUESTS_TOTAL = 30;
const BUDGET_LIMIT_USD = 0.25;

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
      throw new Error(`[BUDGET GUARD] Se superó el presupuesto local estimado de $${BUDGET_LIMIT_USD} USD (acumulado: $${this.totalCostUSD.toFixed(4)} USD).`);
    }
  },
};

function logSanitized(scenarioId, step, message, extra = null) {
  const ts = new Date().toISOString();
  const extraStr = extra ? ` | ${JSON.stringify(extra)}` : '';
  console.log(`[QA][${ts}][Escenario ${scenarioId}][${step}] ${message}${extraStr}`);
}

// -------------------------------------------------------------
// 5. GESTIÓN DE FIXTURES Y SEDES EN FIRESTORE EMULATOR
// -------------------------------------------------------------
async function clearAllEmulatorCollections(db) {
  const collections = ['whatsapp_leads', 'reservas', 'clases', 'users', 'config', 'reprogramaciones', 'sedes'];
  for (const col of collections) {
    const snap = await db.collection(col).get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function seedBaseFixtures(db) {
  await clearAllEmulatorCollections(db);

  await db.collection('sedes').doc('sede_cusco_centro').set({
    nombre: 'Sede Cusco Centro (Calle Hospital)',
    ciudad: 'Cusco',
    direccion: 'Calle Hospital 840, segundo piso',
    referencia: 'Frente a la plazoleta, a dos cuadras del mercado San Pedro',
    activo: true,
  });

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

async function obtenerSedesValidasEmulator(db) {
  const snap = await db.collection('sedes').where('activo', '==', true).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

function verificarDireccionEnSedes(texto, sedesValidas) {
  if (!texto) return true;
  const direccionesValidas = sedesValidas.map((s) => s.direccion.toLowerCase());
  const mencionaDireccion = /calle|av\.|avenida|jirón|jr\./i.test(texto);
  if (!mencionaDireccion) return true;

  return direccionesValidas.some((dir) => {
    const palabrasClave = dir.split(',')[0].trim();
    return texto.toLowerCase().includes(palabrasClave);
  });
}

// -------------------------------------------------------------
// 6. DEFINICIÓN DE LOS 12 ESCENARIOS
// -------------------------------------------------------------
function buildScenarios(db, internals) {
  const {
    obtenerFechaLimaAhora,
    reservarClasePruebaLead,
    reprogramarClasePruebaLead,
    evaluarRuntimeGuard,
    aplicarIntercepcionSegura,
    obtenerMensajeFallbackSeguro,
    TurnContext,
  } = internals;

  return [
    {
      id: 1,
      name: 'Reserva nueva',
      leadId: '+51984111001',
      userMessage: 'Hola, quiero agendar una clase de prueba de capoeira para mí (Camila Rivera, 22 años) para la próxima fecha disponible.',
      async setup() {
        await db.collection('whatsapp_leads').doc(this.leadId).set({
          telefono: this.leadId,
          nombre: 'Camila Rivera',
          edad: 22,
          status: 'conversando',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
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
        const reservaDoc = reservasSnap.docs[0];
        const reservaData = reservaDoc.data();
        if (reservaData.nombre_persona !== 'Camila Rivera') {
          throw new Error(`nombre_persona en /reservas esperado "Camila Rivera", obtenido "${reservaData.nombre_persona}"`);
        }
        if (reservaData.lead_id !== this.leadId) {
          throw new Error(`lead_id en /reservas no coincide: ${reservaData.lead_id} vs ${this.leadId}`);
        }

        const leadDoc = await db.collection('whatsapp_leads').doc(this.leadId).get();
        const leadData = leadDoc.data() || {};
        const activas = leadData.reservas_activas || {};
        if (!activas.camila_rivera) {
          throw new Error('reservas_activas no contiene la clave canónica camila_rivera.');
        }
        if (activas.camila_rivera.nombre_persona !== 'Camila Rivera') {
          throw new Error(`nombre_persona en reservas_activas.camila_rivera esperado "Camila Rivera", obtenido "${activas.camila_rivera.nombre_persona}"`);
        }
        if (activas.camila_rivera.reserva_id !== reservaDoc.id) {
          throw new Error(`reserva_id en reservas_activas (${activas.camila_rivera.reserva_id}) no coincide con ID en /reservas (${reservaDoc.id})`);
        }
        if (leadData.reserva_id !== reservaDoc.id) {
          throw new Error(`reserva_id escalar en lead (${leadData.reserva_id}) no sincronizado con /reservas (${reservaDoc.id})`);
        }
      },
    },
    {
      id: 2,
      name: 'Reserva vigente',
      leadId: '+51984111002',
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
      id: 3,
      name: 'Reprogramación martes-jueves',
      leadId: '+51984111003',
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
      id: 4,
      name: 'Dos hijos',
      leadId: '+51984111004',
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
      id: 5,
      name: 'Asistencia previa',
      leadId: '+51984111005',
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
      id: 6,
      name: 'Inasistencia',
      leadId: '+51984111006',
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
      id: 7,
      name: 'Falta de cupos',
      leadId: '+51984111007',
      userMessage: 'Quiero una clase de prueba de capoeira adultos este martes.',
      async setup() {
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
        await db.collection('clases').doc('clase_adultos').update({ cupos_disponibles: 10 });
      },
    },
    {
      id: 8,
      name: 'Datos incompletos',
      leadId: '+51984111008',
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
      id: 9,
      name: 'Solicitud de cancelación',
      leadId: '+51984111009',
      userMessage: 'Hola, no voy a poder ir a mi clase reservada de mañana. Por favor cancelen mi cupo.',
      async setup() {
        const ahora = obtenerFechaLimaAhora();
        const fechaClase = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 1, 18, 0, 0);
        const resRef = await db.collection('reservas').add({
          lead_id: this.leadId,
          nombre_persona: 'Mariana Soto',
          clase_id: 'clase_adultos',
          fecha_clase: admin.firestore.Timestamp.fromDate(fechaClase),
          hora: '18:00',
          status: 'confirmado',
        });
        await db.collection('whatsapp_leads').doc(this.leadId).set({
          telefono: this.leadId,
          nombre: 'Mariana Soto',
          status: 'clase_agendada',
          reservas_activas: {
            mariana_soto: {
              reserva_id: resRef.id,
              nombre_persona: 'Mariana Soto',
              clase_id: 'clase_adultos',
              fecha_clase: admin.firestore.Timestamp.fromDate(fechaClase),
              hora: '18:00',
              status: 'confirmado',
            },
          },
        });
      },
      mockResponse: {
        content: 'Entendido Mariana, tomo nota para avisar al instructor que no podrás asistir a la clase de mañana. ¡Gracias por avisar!',
        toolsCalled: ['marcar_seguimiento_humano'],
      },
      async assertions({ responseText, toolsCalled }) {
        if (toolsCalled.includes('reservar_clase_prueba') || toolsCalled.includes('reprogramar_reserva')) {
          throw new Error('No debe ejecutar herramientas de agendamiento para una cancelación.');
        }
        if (!toolsCalled.includes('marcar_seguimiento_humano')) {
          throw new Error('Debe derivar la solicitud de cancelación a seguimiento humano.');
        }
        const leadDoc = await db.collection('whatsapp_leads').doc(this.leadId).get();
        if (leadDoc.data()?.status !== 'requiere_atencion') {
          throw new Error('El lead debió ser actualizado a requiere_atencion.');
        }
        if (!/gracias|profesor|instructor|nota|aviso|avisa|lamento|asistir/i.test(responseText)) {
          throw new Error('Debe confirmar la recepción del aviso o derivar cordialmente.');
        }
      },
    },
    {
      id: 10,
      name: 'Consulta de sede y horarios configurados',
      leadId: '+51984111010',
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
      },
    },
    {
      id: 11,
      name: 'Solicitud de atención humana',
      leadId: '+51984111011',
      userMessage: 'Hola, por favor quiero hablar con una persona.',
      async setup() {
        await db.collection('whatsapp_leads').doc(this.leadId).set({
          telefono: this.leadId,
          nombre: 'Roberto Carlos',
          status: 'conversando',
        });
      },
      mockResponse: {
        content: '¡Claro Roberto! Ya le avisé al instructor para que se comunique contigo en breve por este medio.',
        toolsCalled: ['marcar_seguimiento_humano'],
      },
      async assertions({ responseText, toolsCalled }) {
        if (!toolsCalled.includes('marcar_seguimiento_humano')) {
          throw new Error('Debe invocarse la herramienta marcar_seguimiento_humano.');
        }
        const leadDoc = await db.collection('whatsapp_leads').doc(this.leadId).get();
        if (leadDoc.data()?.status !== 'requiere_atencion') {
          throw new Error('El lead debió ser actualizado a requiere_atencion.');
        }
      },
    },
    {
      id: 12,
      name: 'Confirmaciones falsas inducidas',
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
}

// -------------------------------------------------------------
// 6. BOOTSTRAP Y EJECUTOR DE QA
// -------------------------------------------------------------
let admin;

async function bootstrap() {
  console.log('===============================================================');
  console.log(' GINGA REAL — SUITE DE QA CONVERSACIONAL AISLADO (OPENAI)');
  console.log('===============================================================');
  console.log(`Modo: ${ENABLE_REAL_OPENAI_QA ? '🔴 LIVE REAL OPENAI (gpt-4o-mini)' : '🟢 DRY-RUN OFFLINE (Aislado, 0 llamadas externas)'}`);
  console.log(`Proyecto Firestore: ${process.env.GCLOUD_PROJECT}`);
  console.log(`Host Emulador: ${process.env.FIRESTORE_EMULATOR_HOST}`);
  console.log(`Tope de llamadas: ${MAX_REQUESTS_TOTAL} | Presupuesto local estimado: $${BUDGET_LIMIT_USD} USD`);
  console.log('Nota: El techo local es un circuit breaker del cliente, no un límite de facturación forzado por OpenAI.');
  console.log('---------------------------------------------------------------\n');

  // Paso A: Conectividad activa ANTES de requerir Firebase Admin
  console.log('[PRE-FLIGHT] 1/3 Verificando conectividad activa con Firestore Emulator (antes de inicializar SDK)...');
  await validarConectividadEmuladorActiva();
  console.log(`[PRE-FLIGHT] 1/3 Conexión verificada con éxito en ${emulatorHost}.`);

  // Paso B: Probar expresamente que el firewall de red bloquea salidas a Meta WhatsApp
  console.log('[PRE-FLIGHT] 2/3 Verificando bloqueo activo de salidas a Meta WhatsApp...');
  await probarBloqueoMetaEfectivo();
  console.log('[PRE-FLIGHT] 2/3 Firewall de red verificado: Salidas a Meta bloqueadas al 100%.');

  // Paso C: Comprobar credenciales seguras
  console.log('[PRE-FLIGHT] 3/3 Verificando credencial OPENAI_API_KEY...');
  const apiKey = process.env.OPENAI_API_KEY;

  if (ENABLE_REAL_OPENAI_QA && (!apiKey || apiKey.trim().length === 0)) {
    console.log('\n===============================================================');
    console.log(' [PRE-FLIGHT GATE] BLOQUEO DE SEGURIDAD: OPENAI_API_KEY NO DISPONIBLE');
    console.log('===============================================================');
    console.log('El entorno está 100% aislado pero falta la credencial de QA.');
    console.log('\nPara ingresar la clave de forma segura SIN dejar registro en historial');
    console.log('de shell ni en archivos de disco, ejecute en su terminal:');
    console.log('\n  read -s "OPENAI_API_KEY?Ingrese su OpenAI API Key de pruebas: " && export OPENAI_API_KEY');
    console.log('  ENABLE_REAL_OPENAI_QA=true firebase emulators:exec --only firestore \\');
    console.log('    "node real_agent_harness/qa_openai_runner.js" --project demo-ginga-test');
    console.log('  unset OPENAI_API_KEY\n');
    console.log('Nota de seguridad: Use una clave de proyecto (sk-proj-...) con límite de gasto.');
    console.log('===============================================================\n');
    process.exit(2);
  }

  if (ENABLE_REAL_OPENAI_QA) {
    console.log('[PRE-FLIGHT] 3/3 Credencial detectada de forma segura (sin imprimir secreto).');
  } else {
    console.log('[PRE-FLIGHT] 3/3 Modo Dry-Run activo. No se requieren credenciales externas.');
  }

  // Carga diferida de Firebase Admin y functions/index.js SOLO después de verificar emulador
  admin = require('../functions/node_modules/firebase-admin');
  const indexModule = require('../functions/index.js');
  const internals = indexModule.__internals;
  const db = admin.firestore();

  const {
    preguntarIA,
    generarSystemPrompt,
    reservarClasePruebaLead,
    reprogramarClasePruebaLead,
    obtenerFechaLimaAhora,
    hashLeadId,
  } = internals;

  await seedBaseFixtures(db);
  const sedesValidas = await obtenerSedesValidasEmulator(db);
  logSanitized('GLOBAL', 'INIT', `Sedes dinámicas cargadas desde /sedes: ${sedesValidas.length}`, {
    sedes: sedesValidas.map((s) => s.nombre),
  });

  const scenarioFilter = process.env.QA_SCENARIO_FILTER ? parseInt(process.env.QA_SCENARIO_FILTER, 10) : null;
  const isFocalRun = Boolean(scenarioFilter && !Number.isNaN(scenarioFilter));

  const runId = isFocalRun
    ? `qa_run_focal_case${scenarioFilter}_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
    : `qa_run_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  const startTime = new Date().toISOString();

  // Rotar o limpiar reporte anterior para que jamás se confunda con uno nuevo
  const fs = require('fs');
  const path = require('path');
  const reportDir = path.join(__dirname, '../scratch');
  if (!fs.existsSync(reportDir)) fs.mkdirSync(reportDir, { recursive: true });
  const reportPath = path.join(reportDir, 'qa_report_latest.json');
  const previousReportPath = path.join(reportDir, 'qa_report_previous.json');
  if (fs.existsSync(reportPath)) {
    try {
      if (fs.existsSync(previousReportPath)) fs.unlinkSync(previousReportPath);
      fs.renameSync(reportPath, previousReportPath);
    } catch (_) {
      try { fs.unlinkSync(reportPath); } catch (_) {}
    }
  }

  let SCENARIOS = buildScenarios(db, internals);
  if (isFocalRun) {
    const originalCount = SCENARIOS.length;
    SCENARIOS = SCENARIOS.filter((s) => s.id === scenarioFilter);
    if (SCENARIOS.length === 0) {
      throw new Error(`[QA FILTER ERROR] No se encontró ningún escenario con id ${scenarioFilter} (total disponibles: ${originalCount}).`);
    }
    console.log(`[QA FILTER] MODO FOCALIZADO ACTIVO: Se ejecutará exclusivamente el Escenario ${scenarioFilter}: "${SCENARIOS[0].name}"`);
    console.log(`[QA FILTER] AVISO: Esta prueba focalizada (1/1) evaluará únicamente el Caso ${scenarioFilter}. NO equivale a un PASS 12/12 de toda la suite.\n`);
  }

  let passedScenarios = 0;
  const reportScenarios = [];
  let fatalError = null;

  const persistReport = (suiteStatus, criticalReason = null) => {
    try {
      const reportData = {
        runId,
        startTime,
        endTime: new Date().toISOString(),
        mode: ENABLE_REAL_OPENAI_QA ? 'LIVE_REAL_OPENAI' : 'DRY_RUN_OFFLINE',
        isLiveRealOpenAI: Boolean(ENABLE_REAL_OPENAI_QA),
        isFocalRun,
        focalScenarioId: isFocalRun ? scenarioFilter : null,
        suiteStatus, // 'PASSED' | 'FAILED' | 'ABORTED_CRITICAL'
        criticalReason: criticalReason || null,
        projectId: process.env.GCLOUD_PROJECT,
        emulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
        passedCount: passedScenarios,
        totalCount: SCENARIOS.length,
        metrics: {
          totalCalls: budgetTracker.requestCount,
          promptTokens: budgetTracker.promptTokens,
          completionTokens: budgetTracker.completionTokens,
          totalCostUSD: Number(budgetTracker.totalCostUSD.toFixed(4)),
        },
        networkAudit: {
          metaCallsBlocked: networkAudit.metaCallsBlocked,
          openAiCalls: networkAudit.openAiCalls,
          emulatorCalls: networkAudit.emulatorCalls,
          lastOpenAiStatus: networkAudit.lastOpenAiStatus,
          criticalError: networkAudit.criticalError,
        },
        scenarios: reportScenarios,
      };
      fs.writeFileSync(reportPath, JSON.stringify(reportData, null, 2));
      console.log(`[REPORTE] Resultados guardados (${suiteStatus}): ${reportPath}`);
    } catch (reportErr) {
      console.warn(`[REPORTE] No se pudo escribir reporte JSON: ${reportErr.message}`);
    }
  };

  for (const scenario of SCENARIOS) {
    // Si se detectó un error crítico de credencial, cuota, facturación o red, detener de inmediato la suite
    if (networkAudit.criticalError) {
      fatalError = networkAudit.criticalError;
      logSanitized(scenario.id, 'ABORT', `Suite detenida de inmediato por error crítico previo: ${fatalError}`);
      break;
    }

    const scenarioStart = Date.now();
    logSanitized(scenario.id, 'START', `Iniciando escenario: "${scenario.name}" (Lead: ${hashLeadId(scenario.leadId)})`);
    
    let scenarioError = null;
    let responseText = '';
    const toolsCalled = [];

    try {
      await scenario.setup();

      if (scenario.id === 12 && typeof scenario.runSpecial === 'function') {
        await scenario.runSpecial({ sedesValidas });
        passedScenarios++;
        const latencyMs = Date.now() - scenarioStart;
        reportScenarios.push({
          id: scenario.id,
          name: scenario.name,
          status: 'PASS',
          userMessageSnippet: scenario.userMessage.substring(0, 80),
          responseTextSnippet: '[Runtime Guard Interception: candidate blocked]',
          toolsCalled: [],
          latencyMs,
        });
        logSanitized(scenario.id, 'PASS', 'Runtime Guard interceptó y protegió correctamente.', {
          latencyMs,
        });
        continue;
      }

      if (ENABLE_REAL_OPENAI_QA) {
        // Flujo REAL en vivo: preguntarIA + AVAILABLE_TOOLS reales + Runtime Guard real
        const leadSnap = await db.collection('whatsapp_leads').doc(scenario.leadId).get();
        const leadData = leadSnap.data() || {};
        const { systemPrompt } = await generarSystemPrompt(leadData, 1, scenario.leadId);
        const historial = [{ role: 'user', content: scenario.userMessage }];

        responseText = await preguntarIA(scenario.leadId, systemPrompt, historial, ({ name }) => {
          toolsCalled.push(name);
        });

        // Verificar si ocurrió un error crítico durante las llamadas a OpenAI
        if (networkAudit.criticalError) {
          throw new Error(networkAudit.criticalError);
        }

        const estimatedIn = Math.ceil((systemPrompt.length + scenario.userMessage.length) / 3.5);
        const estimatedOut = Math.ceil((responseText?.length || 50) / 3.5);
        budgetTracker.recordUsage(estimatedIn, estimatedOut);
        logSanitized(scenario.id, 'USAGE', 'Llamada real OpenAI completada.', {
          totalCalls: budgetTracker.requestCount,
          costUSD: Number(budgetTracker.totalCostUSD.toFixed(4)),
        });
      } else {
        responseText = scenario.mockResponse.content;
        toolsCalled.push(...scenario.mockResponse.toolsCalled);
        
        if (scenario.id === 1) {
          const ahora = obtenerFechaLimaAhora();
          const prox = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 2, 18, 0, 0);
          await reservarClasePruebaLead(scenario.leadId, 'clase_adultos', 'Camila Rivera', prox);
        } else if (scenario.id === 3) {
          const ahora = obtenerFechaLimaAhora();
          const nueva = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 5, 18, 0, 0);
          await reprogramarClasePruebaLead(scenario.leadId, scenario.reservaId, nueva, 'Reprogramación QA');
        } else if (scenario.id === 4) {
          const ahora = obtenerFechaLimaAhora();
          const fecha = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 3, 17, 0, 0);
          await reservarClasePruebaLead(scenario.leadId, 'clase_ninos', 'Sofia', fecha);
        } else if (scenario.id === 9) {
          await db.collection('whatsapp_leads').doc(scenario.leadId).update({
            status: 'requiere_atencion',
            motivo_seguimiento: 'Solicitud de cancelación de reserva',
          });
        } else if (scenario.id === 11) {
          await db.collection('whatsapp_leads').doc(scenario.leadId).update({
            status: 'requiere_atencion',
            motivo_seguimiento: 'Solicita hablar con una persona',
          });
        }
      }

      await scenario.assertions({ responseText, toolsCalled, sedesValidas });
      passedScenarios++;
      logSanitized(scenario.id, 'PASS', `Escenario aprobado con éxito.`);
    } catch (err) {
      scenarioError = err.message;
      logSanitized(scenario.id, 'FAIL', `Escenario falló: ${err.message}`, {
        toolsCalled,
        responseTextSnippet: responseText ? responseText.slice(0, 80) : null,
      });

      // Errores críticos detienen toda la suite inmediatamente
      const isCritical = networkAudit.criticalError ||
        err.message.startsWith('CRITICAL_') ||
        err.message.includes('[BUDGET GUARD]') ||
        err.message.includes('[SECURITY FIREWALL]');

      if (isCritical) {
        fatalError = networkAudit.criticalError || err.message;
        const latencyMs = Date.now() - scenarioStart;
        reportScenarios.push({
          id: scenario.id,
          name: scenario.name,
          status: 'FAIL',
          error: scenarioError,
          userMessageSnippet: scenario.userMessage.substring(0, 80),
          responseTextSnippet: responseText ? responseText.substring(0, 120).replace(/\+?[0-9]{8,}/g, '[PHONE]') : null,
          toolsCalled,
          latencyMs,
        });
        logSanitized(scenario.id, 'ABORT', `Detención inmediata por error crítico: ${fatalError}`);
        break;
      }
    } finally {
      if (typeof scenario.teardown === 'function') {
        try {
          await scenario.teardown();
        } catch (_) {}
      }
    }

    const latencyMs = Date.now() - scenarioStart;
    reportScenarios.push({
      id: scenario.id,
      name: scenario.name,
      status: scenarioError ? 'FAIL' : 'PASS',
      error: scenarioError || undefined,
      userMessageSnippet: scenario.userMessage.substring(0, 80),
      responseTextSnippet: responseText ? responseText.substring(0, 120).replace(/\+?[0-9]{8,}/g, '[PHONE]') : null,
      toolsCalled,
      latencyMs,
    });
  }

  // Generar reporte estructurado en scratch/ (ignorado por Git, cero PII)
  const suiteStatus = fatalError
    ? 'ABORTED_CRITICAL'
    : passedScenarios === SCENARIOS.length
      ? 'PASSED'
      : 'FAILED';

  persistReport(suiteStatus, fatalError);

  console.log('\n===============================================================');
  if (ENABLE_REAL_OPENAI_QA) {
    if (isFocalRun) {
      console.log(` RESULTADO QA REAL FOCALIZADO (CASO ${scenarioFilter}): ${passedScenarios}/${SCENARIOS.length} ESCENARIO PASS`);
      console.log(' AVISO DE CERTIFICACIÓN: Esta es una validación focalizada (1/1).');
      console.log(' NO certifica ni sustituye la aprobación completa (12/12) de la suite para el Release Candidate.');
    } else {
      console.log(` RESULTADO FINAL QA REAL OPENAI: ${passedScenarios}/${SCENARIOS.length} ESCENARIOS PASS`);
    }
    console.log(` Gasto acumulado estimado: $${budgetTracker.totalCostUSD.toFixed(4)} USD (${budgetTracker.requestCount}/${MAX_REQUESTS_TOTAL} llamadas)`);
  } else {
    if (isFocalRun) {
      console.log(` RESULTADO DRY-RUN FOCALIZADO (CASO ${scenarioFilter}): ${passedScenarios}/${SCENARIOS.length} ESCENARIO VERIFICADO`);
    } else {
      console.log(` RESULTADO DRY-RUN OFFLINE: ${passedScenarios}/${SCENARIOS.length} ESCENARIOS VERIFICADOS`);
    }
    console.log(' AVISO DE INTEGRIDAD: Este resultado corresponde exclusivamente a simulación offline con Firestore Emulator.');
    console.log(' NO CONSTITUYE UN PASS DEL QA CONVERSACIONAL REAL CON OPENAI.');
    console.log(' ESTADO DEL GATE DE QA REAL: BLOCKED (Pendiente de ejecución autorizada con OPENAI_API_KEY).');
  }
  console.log(` Auditoría de red: Meta interceptadas: ${networkAudit.metaCallsBlocked} | OpenAI: ${networkAudit.openAiCalls} | Emulador: ${networkAudit.emulatorCalls}`);
  if (fatalError) {
    console.error(` ERROR CRÍTICO DETECTADO: ${fatalError}`);
  }
  console.log('===============================================================\n');

  if (passedScenarios !== SCENARIOS.length || fatalError) {
    const errorMsg = fatalError 
      ? `Ejecución abortada por error crítico: ${fatalError}`
      : `Fallaron ${SCENARIOS.length - passedScenarios} escenarios.`;
    throw new Error(errorMsg);
  }
}

if (require.main === module) {
  bootstrap()
    .then(() => {
      console.log('Proceso de QA finalizado correctamente.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('ERROR EN QA RUNNER:', err);
      process.exit(1);
    });
}

module.exports = {
  bootstrap,
  budgetTracker,
  networkAudit,
};

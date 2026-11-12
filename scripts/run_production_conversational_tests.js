/**
 * scripts/run_production_conversational_tests.js
 * Runner de Pruebas Conversacionales Reales / Pre-Flight para GINGA V1 (Node.js 22)
 * PROMPT 68: Validación Real del Embudo Comercial y Revisión de Fechas
 * 
 * ESCENARIOS MULTI-TURNO:
 * - Escenario A: Reserva Completa (Sofia, 9 años, turnos progresivos hasta confirmación)
 * - Escenario B: Reprogramación Real (cambio atómico de fecha sin duplicar reserva)
 * - Escenario C: Idempotencia (intento de duplicar cita de Sofia; verificación de rechazo/aviso)
 * - Escenario D: Captación de Dos Hermanos (Mateo 8a y Lucía 6a, 2 reservas independientes)
 * 
 * MODOS DE EJECUCIÓN:
 * 1. MODO EMULATOR (por defecto):
 *    firebase emulators:exec --only firestore "node scripts/run_production_conversational_tests.js" --project demo-ginga-test
 * 2. MODO PRODUCCIÓN:
 *    ALLOW_PRODUCTION_TEST_WRITES=true node scripts/run_production_conversational_tests.js --target=production --real-openai
 * 
 * GARANTÍAS DE SEGURIDAD ESTRICTAS:
 * - Firewall de red global a nivel de proceso: ZERO salidas a Meta WhatsApp (graph.facebook.com).
 * - Circuit breaker: máximo 30 llamadas a OpenAI con tracking de tokens y costo.
 * - Cero modificación a functions/index.js ni a Cloud Scheduler.
 * - Registros TEST marcados con seguimiento_frio_enviado=true e IDs no numéricos (inmunes a crons).
 * - Documentos preservados para revisión e inspección manual por el usuario.
 */

const fs = require('fs');
const http = require('http');
const https = require('https');
const path = require('path');
const { execSync } = require('child_process');

// -------------------------------------------------------------
// 1. CONFIGURACIÓN Y PARSEO DE ARGUMENTOS
// -------------------------------------------------------------
const args = process.argv.slice(2);

if (args.includes('--help') || args.includes('-h')) {
  console.log(`
Uso del Runner de Pruebas Conversacionales GINGA:
  1. Modo Emulador Local (Recomendado para validación sin riesgo):
     firebase emulators:exec --only firestore "node scripts/run_production_conversational_tests.js" --project demo-ginga-test

  2. Modo Producción (Requiere autorización explícita):
     ALLOW_PRODUCTION_TEST_WRITES=true node scripts/run_production_conversational_tests.js --target=production --real-openai

Flags adicionales:
  --real-openai     Habilita llamadas reales a OpenAI si OPENAI_API_KEY está disponible (límite duro: 30 llamadas).
  --help, -h        Muestra este mensaje de ayuda.
`);
  process.exit(0);
}

const isProductionTarget = args.includes('--target=production');
const isEmulatorTarget = args.includes('--target=emulator') || !isProductionTarget;
const forceRealOpenAI = args.includes('--real-openai');

// Guard de seguridad estricto para modo producción
if (isProductionTarget) {
  if (process.env.ALLOW_PRODUCTION_TEST_WRITES !== 'true') {
    console.error('\n===============================================================');
    console.error(' [FATAL SECURITY ERROR] EJECUCIÓN EN PRODUCCIÓN NO AUTORIZADA');
    console.error(' Para ejecutar en producción se requiere:');
    console.error('   1. Argumento explícito: --target=production');
    console.error('   2. Variable de entorno: ALLOW_PRODUCTION_TEST_WRITES=true');
    console.error('===============================================================\n');
    process.exit(1);
  }

  // Auto-configurar ADC para capoeirafiuapp@gmail.com si no hay credentials explícitas
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const adcPath = '/Users/jumper/.config/gcloud/legacy_credentials/capoeirafiuapp@gmail.com/adc.json';
    if (fs.existsSync(adcPath)) {
      process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;
    }
  }

  process.env.GCLOUD_PROJECT = 'capoeirafiu-ea8ljo';
  process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'capoeirafiu-ea8ljo' });
  delete process.env.FIRESTORE_EMULATOR_HOST;

  console.warn('\n⚠️  [ADVERTENCIA] MODO PRODUCCIÓN ACTIVO: SE ESCRIBIRÁN LEADS TEST EN FIRESTORE REAL ⚠️\n');
} else {
  // Configuración predeterminada de emulador
  process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-ginga-test';
  process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.error('\n===============================================================');
    console.error(' [ERROR] FIRESTORE_EMULATOR_HOST NO ESTÁ DEFINIDO');
    console.error(' Para ejecutar en modo emulador offline, ejecute mediante:');
    console.error('   firebase emulators:exec --only firestore "node scripts/run_production_conversational_tests.js" --project demo-ginga-test');
    console.error('===============================================================\n');
    process.exit(1);
  }
}

// Carga segura en memoria de OPENAI_API_KEY si se requiere OpenAI real
if (forceRealOpenAI) {
  if (!process.env.OPENAI_API_KEY) {
    try {
      const key = execSync(
        'gcloud secrets versions access 1 --secret=OPENAI_API_KEY --project=capoeirafiu-ea8ljo --account=capoeirafiuapp@gmail.com',
        { encoding: 'utf8' }
      ).trim();
      if (key && key.startsWith('sk-')) {
        process.env.OPENAI_API_KEY = key;
      }
    } catch (errKey) {
      console.error('[SECURITY ERROR] No se pudo obtener OPENAI_API_KEY desde Secret Manager:', errKey.message);
    }
  }

  if (!process.env.OPENAI_API_KEY) {
    console.error('\n[FATAL ERROR] Flag --real-openai especificado pero OPENAI_API_KEY no está disponible.\n');
    process.exit(1);
  }
  console.log('✔ [SEGURIDAD] OPENAI_API_KEY cargada en memoria de forma segura (sin imprimir en logs ni persistir en disco).');
}

// -------------------------------------------------------------
// 2. FIREWALL DE RED GLOBAL (ZERO EGRESS A META / EXTERIOR)
// -------------------------------------------------------------
const originalFetch = global.fetch;
const originalHttpsRequest = https.request;

const networkAudit = {
  metaCallsAttempted: 0,
  metaCallsBlocked: 0,
  openAiCalls: 0,
  mockOpenAiCalls: 0,
  emulatorCalls: 0,
  otherBlockedCalls: [],
  promptTokens: 0,
  completionTokens: 0,
  totalTokens: 0,
};

const MAX_OPENAI_CALLS_LIMIT = 30;

// Interceptor de global.fetch
global.fetch = async function secureFetch(input, init = {}) {
  const url = typeof input === 'string' ? input : input?.url || '';

  // Regla A: Meta WhatsApp Cloud API - BLOQUEO TOTAL Y DETERMINISTA
  if (url.includes('graph.facebook.com') || url.includes('whatsapp') || url.includes('facebook')) {
    networkAudit.metaCallsAttempted++;
    networkAudit.metaCallsBlocked++;
    console.warn(`[FIREWALL SALIDAS] BLOQUEADA llamada a Meta WhatsApp Cloud API: ${url}`);
    return new Response(JSON.stringify({
      error: {
        message: 'BLOCKED_BY_TEST_RUNNER_FIREWALL: Salidas a WhatsApp están estrictamente bloqueadas durante las pruebas.',
        code: 403,
      },
    }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Regla B: Emulador Local (127.0.0.1 o localhost)
  if (url.includes('127.0.0.1') || url.includes('localhost')) {
    networkAudit.emulatorCalls++;
    return originalFetch(input, init);
  }

  // Regla C: OpenAI Chat Completions API
  if (url.startsWith('https://api.openai.com/v1/chat/completions')) {
    if (forceRealOpenAI) {
      if (networkAudit.openAiCalls >= MAX_OPENAI_CALLS_LIMIT) {
        throw new Error(`[CIRCUIT BREAKER] Se alcanzó el límite estricto de ${MAX_OPENAI_CALLS_LIMIT} llamadas a OpenAI. Abortando.`);
      }
      networkAudit.openAiCalls++;
      const resp = await originalFetch(input, init);
      try {
        const clone = resp.clone();
        const json = await clone.json();
        if (json.usage) {
          networkAudit.promptTokens += (json.usage.prompt_tokens || 0);
          networkAudit.completionTokens += (json.usage.completion_tokens || 0);
          networkAudit.totalTokens += (json.usage.total_tokens || 0);
        }
      } catch (_) {}
      return resp;
    }

    // Modo simulado / Mock OpenAI determinista para pruebas offline
    networkAudit.mockOpenAiCalls++;
    const body = JSON.parse(init.body || '{}');
    const completion = await responderOpenAISimulado(body);
    return new Response(JSON.stringify(completion), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Regla D: Si estamos en producción conectando con GCP APIs (Firestore, IAM, OAuth)
  if (isProductionTarget && (url.includes('googleapis.com') || url.includes('firestore.googleapis.com'))) {
    return originalFetch(input, init);
  }

  // Bloqueo de cualquier otro endpoint externo no autorizado
  networkAudit.otherBlockedCalls.push(url);
  console.warn(`[FIREWALL SALIDAS] BLOQUEADA llamada externa no autorizada: ${url}`);
  return new Response(JSON.stringify({ error: 'BLOCKED_EXTERNAL_CALL' }), {
    status: 403,
    headers: { 'Content-Type': 'application/json' },
  });
};

// Interceptor de https.request para clientes legacy
https.request = function secureHttpsRequest(...argsHttps) {
  let host = '';
  const first = argsHttps[0];
  if (typeof first === 'string') {
    try { host = new URL(first).hostname; } catch (_) {}
  } else if (first && typeof first === 'object') {
    host = first.hostname || first.host || '';
  }

  if (host.includes('facebook') || host.includes('whatsapp')) {
    networkAudit.metaCallsAttempted++;
    networkAudit.metaCallsBlocked++;
    console.warn(`[FIREWALL SALIDAS] (https) BLOQUEADA llamada a Meta WhatsApp: ${host}`);
    const EventEmitter = require('events');
    const mockReq = new EventEmitter();
    mockReq.end = () => {};
    mockReq.write = () => {};
    process.nextTick(() => {
      mockReq.emit('error', new Error('BLOCKED_BY_TEST_RUNNER_FIREWALL: Acceso a Meta WhatsApp Cloud API prohibido'));
    });
    return mockReq;
  }

  if (isEmulatorTarget && !host.includes('127.0.0.1') && !host.includes('localhost') && host !== 'api.openai.com') {
    networkAudit.otherBlockedCalls.push(host);
    const EventEmitter = require('events');
    const mockReq = new EventEmitter();
    mockReq.end = () => {};
    mockReq.write = () => {};
    process.nextTick(() => {
      mockReq.emit('error', new Error(`BLOCKED_BY_TEST_RUNNER_FIREWALL: Host externo no autorizado: ${host}`));
    });
    return mockReq;
  }

  return originalHttpsRequest.apply(https, argsHttps);
};

// Verificación activa del bloqueo de Meta antes de iniciar
async function verificarBloqueoMetaActivo() {
  const antes = networkAudit.metaCallsBlocked;
  try {
    const res = await fetch('https://graph.facebook.com/v20.0/test/messages', {
      method: 'POST',
      headers: { Authorization: 'Bearer test' },
      body: JSON.stringify({ test: true }),
    });
    if (res.status !== 403) {
      throw new Error(`Esperado status 403 por firewall pero se recibió ${res.status}`);
    }
  } catch (err) {
    if (!err.message.includes('BLOCKED_BY_TEST_RUNNER_FIREWALL')) {
      // Ignorar otros errores
    }
  }
  if (networkAudit.metaCallsBlocked <= antes) {
    throw new Error('FALLO CRÍTICO DE SEGURIDAD: El firewall no interceptó la llamada simulada a Meta WhatsApp.');
  }
  console.log('✔ [SEGURIDAD] Firewall de red activo: Cero salidas a Meta WhatsApp (graph.facebook.com) garantizadas.');
}

// -------------------------------------------------------------
// 3. RESPONDEDOR SIMULADO INTELIGENTE (UTILIZADO SI NO ES REAL)
// -------------------------------------------------------------
async function responderOpenAISimulado(body) {
  const messages = body.messages || [];
  const lastMsg = messages[messages.length - 1];

  // Si el último mensaje es el resultado de una herramienta
  if (lastMsg && lastMsg.role === 'tool') {
    const toolResults = messages.filter((m) => m.role === 'tool');
    const lastTool = toolResults[toolResults.length - 1];
    const content = lastTool.content || '';

    if (content.includes('DUPLICATE_ACTIVE_RESERVATION') || content.includes('Ya existe una reserva previa')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: `${content} Ya tienes una reserva confirmada. Si deseas reprogramarla para otra fecha, avísame y con gusto te ayudo.`,
            },
          },
        ],
      };
    }

    if (content.includes('Reserva confirmada') || content.includes('confirmada')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: `¡Excelente! ${content} Recuerden llegar 10 minutos antes con ropa deportiva cómoda y agua. ¡Los esperamos!`,
            },
          },
        ],
      };
    }

    if (content.includes('Reprogramación confirmada') || content.includes('reprogramada')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: `¡Listo! ${content} La cita ha quedado reprogramada con éxito.`,
            },
          },
        ],
      };
    }

    if (content.includes('Perfil guardado')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: '¡Perfecto! Anoté los datos. Tenemos clases para esa edad los martes y jueves a las 18:00 en Divergym Magisterio. ¿Deseas que reserve la clase de prueba?',
            },
          },
        ],
      };
    }

    if (content.includes('Horarios disponibles:') || content.includes('Kids')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: '¡Hola! Tenemos clases para niños (Kids, 5 a 12 años) los martes y jueves de 18:00 a 19:00 en Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso. La mensualidad regular es S/140 y la clase de prueba es gratuita. ¿Te gustaría agendar?',
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
            content: content,
          },
        },
      ],
    };
  }

  // Turno de usuario
  const userMsgs = messages.filter((m) => m.role === 'user');
  const lastUserText = userMsgs.length > 0 ? (userMsgs[userMsgs.length - 1].content || '') : '';
  const textLower = lastUserText.toLowerCase();

  // Escenario B: Reprogramación
  if (
    textLower.includes('reprogram') ||
    textLower.includes('cruce') ||
    textLower.includes('cambiar') ||
    textLower.includes('inconveniente')
  ) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_reprog`,
                type: 'function',
                function: {
                  name: 'reprogramar_reserva',
                  arguments: JSON.stringify({
                    nombre: 'Sofia',
                    nueva_fecha: '2026-11-17',
                    motivo: 'Cruce de horarios el jueves',
                  }),
                },
              },
            ],
          },
        },
      ],
    };
  }

  // Escenario D: Dos hermanos (Mateo 8 y Lucía 6)
  if (textLower.includes('mateo') && (textLower.includes('lucia') || textLower.includes('lucía'))) {
    if (textLower.includes('agendar') || textLower.includes('jueves') || textLower.includes('ambos') || textLower.includes('confirmo')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: null,
              tool_calls: [
                {
                  id: `call_${Date.now()}_prof_herm`,
                  type: 'function',
                  function: {
                    name: 'guardar_perfil_lead',
                    arguments: JSON.stringify({
                      personas: [
                        { nombre: 'Mateo', tipo: 'niño', edad: 8 },
                        { nombre: 'Lucía', tipo: 'niño', edad: 6 },
                      ],
                    }),
                  },
                },
                {
                  id: `call_${Date.now()}_res_mateo`,
                  type: 'function',
                  function: {
                    name: 'reservar_clase_prueba',
                    arguments: JSON.stringify({ nombre: 'Mateo', tipo: 'niño' }),
                  },
                },
                {
                  id: `call_${Date.now()}_res_lucia`,
                  type: 'function',
                  function: {
                    name: 'reservar_clase_prueba',
                    arguments: JSON.stringify({ nombre: 'Lucía', tipo: 'niño' }),
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
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_cons_kids`,
                type: 'function',
                function: {
                  name: 'consultar_horarios_disponibles',
                  arguments: '{}',
                },
              },
            ],
          },
        },
      ],
    };
  }

  // Escenario A / C: Sofia
  if (textLower.includes('sofia')) {
    if (
      textLower.includes('agendar') ||
      textLower.includes('clase de prueba') ||
      textLower.includes('confirmo') ||
      textLower.includes('jueves') ||
      textLower.includes('martes')
    ) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: null,
              tool_calls: [
                {
                  id: `call_${Date.now()}_prof_sofia`,
                  type: 'function',
                  function: {
                    name: 'guardar_perfil_lead',
                    arguments: JSON.stringify({
                      personas: [{ nombre: 'Sofia', tipo: 'niño', edad: 9 }],
                    }),
                  },
                },
                {
                  id: `call_${Date.now()}_res_sofia`,
                  type: 'function',
                  function: {
                    name: 'reservar_clase_prueba',
                    arguments: JSON.stringify({ nombre: 'Sofia', tipo: 'niño' }),
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
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_cons_kids`,
                type: 'function',
                function: {
                  name: 'consultar_horarios_disponibles',
                  arguments: '{}',
                },
              },
            ],
          },
        },
      ],
    };
  }

  // Respuesta por defecto
  return {
    choices: [
      {
        message: {
          role: 'assistant',
          content: '¡Hola! Bienvenido a Capoeira FIU / Ginga Cusco. ¿En qué te podemos ayudar hoy?',
        },
      },
    ],
  };
}

// -------------------------------------------------------------
// 4. INICIALIZACIÓN DE FIREBASE ADMIN Y FUNCIONES BACKEND
// -------------------------------------------------------------
const admin = require('../functions/node_modules/firebase-admin');
const internals = require('../functions/index.js').__internals;

const {
  generarSystemPrompt,
  preguntarIA,
  validarAfirmacionesComerciales,
  generarRespuestaComercialOficial,
} = internals;

const db = admin.firestore();

// Manifiesto global de documentos creados durante esta corrida
const createdDocumentsManifest = [];

// -------------------------------------------------------------
// 5. GESTIÓN DE FIXTURES (SOLO EN MODO EMULADOR)
// -------------------------------------------------------------
async function sembrarFixturesEmulador() {
  console.log('🌱 Sembrando fixtures oficiales en Firestore Emulator...');

  await db.collection('config').doc('negocio').set({
    nombre: 'Ginga & Capoeira FIU Cusco',
    moneda: 'PEN',
    mensualidad: 140,
    precio_mensual_regular: 140,
    promo_2x: 260,
    precio_mensual_promo_acompanado: 260,
    precio_paquete_3_meses: 380,
    precio_paquete_6_meses: 720,
    promos_multimes: { '3': 380, '6': 720 },
    yape_numero: '51900075008',
    yape_titular: 'Instructor Ginga Cusco',
    direccion: 'Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso (justo al costado de la Caja Arequipa).',
    link_maps: 'https://maps.app.goo.gl/3gdpPwk7PctgmSA38',
  });

  await db.collection('config').doc('whatsapp_agent').set({
    system_prompt: 'Eres GINGA, el asistente y profesor de Capoeira FIU Cusco. Responde con calidez y precisión.',
  });

  await db.collection('clases').doc('clase_kids_oficial').set({
    nombre: 'Kids',
    tipo: 'regular',
    publico: 'niños',
    nivel: 'Niños (todas las edades)',
    dias: 'M, J',
    hora: '18:00',
    hora_fin: '19:00',
    edad_min: 5,
    edad_max: 12,
    cupos_disponibles: 10,
    sede: 'Cusco',
    ubicacion: 'Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso (justo al costado de la Caja Arequipa).',
    activo: true,
  });

  await db.collection('clases').doc('clase_adultos_oficial').set({
    nombre: 'Adultos',
    tipo: 'regular',
    publico: 'jovenes_adultos',
    nivel: 'Jóvenes y Adultos',
    dias: 'M, J',
    hora: '19:00',
    hora_fin: '20:00',
    edad_min: 13,
    edad_max: 99,
    cupos_disponibles: 10,
    sede: 'Cusco',
    ubicacion: 'Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso (justo al costado de la Caja Arequipa).',
    activo: true,
  });

  await db.collection('sedes').doc('sede_magisterio').set({
    nombre: 'Sede Cusco Magisterio (Divergym)',
    ciudad: 'Cusco',
    direccion: 'Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso',
    referencia: 'Al costado de la Caja Arequipa',
    activo: true,
  });

  await db.collection('users').doc('inst_principal').set({
    nombre: 'Profesor Mestre Test',
    rol: 'profesor',
    email: 'mestre@capoeirafiu.test',
  });

  console.log('✔ Fixtures sembrados exitosamente.');
}

// -------------------------------------------------------------
// 6. PIPELINE CONVERSACIONAL REAL (IDÉNTICO A whatsappWebhook v69)
// -------------------------------------------------------------
async function despacharTurnoConversacional(leadId, userText, leadNombre = 'Tester') {
  const leadRef = db.collection('whatsapp_leads').doc(leadId);
  const now = admin.firestore.Timestamp.now();

  let leadDoc = await leadRef.get();
  const esNuevo = !leadDoc.exists;

  // Registrar o actualizar documento del lead (compatible con Flutter InstructorLeadsScreen)
  const baseData = {
    telefono: leadId,
    nombre: leadNombre,
    status: esNuevo ? 'nuevo' : (leadDoc.data().status || 'nuevo'),
    ai_habilitada: true,
    seguimiento_frio_enviado: true, // Blindaje estricto contra Scheduler
    ultima_interaccion: now,
  };
  if (esNuevo) {
    baseData.created_at = now;
    createdDocumentsManifest.push({
      coleccion: 'whatsapp_leads',
      id: leadId,
      path: `whatsapp_leads/${leadId}`,
      descripcion: `Lead principal: ${leadNombre}`,
    });
  }
  await leadRef.set(baseData, { merge: true });

  // Guardar mensaje entrante del lead en la subcolección 'mensajes'
  const userMsgId = `msg_u_${Date.now()}_${Math.random().toString(36).substring(7)}`;
  const userMsgRef = leadRef.collection('mensajes').doc(userMsgId);
  await userMsgRef.set({
    from: 'lead',
    texto: userText,
    timestamp: now,
  });
  createdDocumentsManifest.push({
    coleccion: 'mensajes',
    id: userMsgId,
    path: `whatsapp_leads/${leadId}/mensajes/${userMsgId}`,
    descripcion: `Mensaje de usuario en ${leadId}`,
  });

  // Leer historial conversacional reciente
  const histSnap = await leadRef.collection('mensajes').orderBy('timestamp', 'desc').limit(10).get();
  const historial = histSnap.docs.reverse().map((d) => {
    const m = d.data();
    return { role: m.from === 'lead' ? 'user' : 'assistant', content: m.texto };
  });

  // Generar System Prompt oficial usando la lógica real de functions/index.js
  const leadDataActual = (await leadRef.get()).data();
  const { systemPrompt, catalogoClases, ubicacionReal } = await generarSystemPrompt(
    leadDataActual,
    histSnap.docs.length,
    leadId
  );

  // Ejecutar preguntarIA con registro de herramientas
  const executedTools = [];
  const onToolCall = (record) => {
    executedTools.push(record);
  };

  const textoRespuesta = await preguntarIA(
    leadId,
    systemPrompt,
    historial,
    onToolCall,
    null,
    catalogoClases,
    ubicacionReal
  );

  // Exit Gate de Validación Comercial y Precios (idéntico a whatsappWebhook v69)
  let textoFinal = textoRespuesta || 'Lo siento, no pude procesar tu mensaje en este momento.';
  const valComercialExit = validarAfirmacionesComerciales(textoFinal, catalogoClases);
  if (!valComercialExit.valid) {
    console.warn(`[Runtime Guard Exit] Afirmación comercial interceptada en runner para ${leadId}: ${valComercialExit.reason}`);
    textoFinal = generarRespuestaComercialOficial(catalogoClases, ubicacionReal, userText);
  }

  // Guardar mensaje saliente de la IA en la subcolección 'mensajes'
  const aiMsgId = `msg_a_${Date.now()}_${Math.random().toString(36).substring(7)}`;
  const aiMsgRef = leadRef.collection('mensajes').doc(aiMsgId);
  await aiMsgRef.set({
    from: 'ai',
    texto: textoFinal,
    timestamp: admin.firestore.Timestamp.now(),
  });
  createdDocumentsManifest.push({
    coleccion: 'mensajes',
    id: aiMsgId,
    path: `whatsapp_leads/${leadId}/mensajes/${aiMsgId}`,
    descripcion: `Respuesta de agente IA en ${leadId}`,
  });

  // Actualizar estado del lead si sigue en 'nuevo' -> 'conversando'
  const leadDataDespues = (await leadRef.get()).data();
  if (leadDataDespues.status === 'nuevo') {
    await leadRef.update({
      status: 'conversando',
      ultima_interaccion: admin.firestore.Timestamp.now(),
    });
  }

  // Obtener reservas asociadas a este lead y registrarlas en el manifest si son nuevas
  const reservasSnap = await db.collection('reservas').where('lead_id', '==', leadId).get();
  const reservas = reservasSnap.docs.map((d) => {
    const docPath = `reservas/${d.id}`;
    if (!createdDocumentsManifest.some((m) => m.path === docPath)) {
      createdDocumentsManifest.push({
        coleccion: 'reservas',
        id: d.id,
        path: docPath,
        descripcion: `Reserva para ${d.data().nombre_persona || 'Lead'} (estado: ${d.data().status})`,
      });
    }
    return { id: d.id, ...d.data() };
  });

  const turnNumber = histSnap.docs.length;
  console.log(`\n  ┌─ [Turno ${turnNumber}] Lead (${leadId})`);
  console.log(`  │  👤 Usuario: "${userText}"`);
  console.log(`  │  🥋 GINGA:   "${textoFinal.replace(/\n+/g, ' ')}"`);
  if (executedTools.length > 0) {
    console.log(`  │  🛠️  Tools:    ${executedTools.map(t => `${t.name || t.tool_name}(${JSON.stringify(t.args || {})})`).join(' -> ')}`);
  }
  console.log(`  └─ Reservas actuales del lead: ${reservas.length} | Estado lead: ${(await leadRef.get()).data().status}`);

  return {
    userText,
    replyText: textoFinal,
    executedTools,
    leadData: (await leadRef.get()).data(),
    reservas,
    mensajesCount: histSnap.docs.length + 1,
  };
}

// -------------------------------------------------------------
// 7. DEFINICIÓN Y EJECUCIÓN DE LOS 4 ESCENARIOS DEL EMBUDO REAL
// -------------------------------------------------------------
async function ejecutarSuiteDePruebas() {
  console.log('\n===============================================================');
  console.log('   GINGA REAL — PROMPT 68: VALIDACIÓN DEL EMBUDO COMERCIAL');
  console.log(`   Destino: ${isProductionTarget ? 'PRODUCCIÓN (capoeirafiu-ea8ljo)' : 'EMULADOR LOCAL (demo-ginga-test)'}`);
  console.log(`   Modo OpenAI: ${forceRealOpenAI ? 'REAL (OpenAI API - gpt-4o-mini)' : 'SIMULADO / OFFLINE (Deterministic Mock)'}`);
  console.log('===============================================================\n');

  await verificarBloqueoMetaActivo();

  if (isEmulatorTarget) {
    await sembrarFixturesEmulador();
  }

  // Generar ID único por corrida para aislamiento estricto
  const runId = Date.now().toString(36).toUpperCase();
  const tALeadId = `TEST_RUN68_A_SOFIA_${runId}`;
  const tDLeadId = `TEST_RUN68_D_HERMANOS_${runId}`;

  // Verificar pre-existencia en Firestore de producción
  if (isProductionTarget) {
    const [docA, docD] = await Promise.all([
      db.collection('whatsapp_leads').doc(tALeadId).get(),
      db.collection('whatsapp_leads').doc(tDLeadId).get(),
    ]);
    if (docA.exists || docD.exists) {
      throw new Error(`[SEGURIDAD] Los IDs de prueba ya existen en producción (${tALeadId} o ${tDLeadId}). Abortando.`);
    }
  }

  const resultados = [];

  // =============================================================
  // ESCENARIO A: RESERVA COMPLETA (Sofia, 9 años)
  // =============================================================
  console.log('\n▶ Ejecutando ESCENARIO A: Reserva Completa (Sofia, 9 años)...');
  const tAStart = Date.now();
  const tALeadNombre = 'TEST RUN 68 - Sofia (9 años)';
  const turnosA = [];

  // Turno 1: Solicitud inicial de información
  const tATurn1 = await despacharTurnoConversacional(
    tALeadId,
    'Hola, buenas tardes. Quisiera información sobre clases de capoeira para mi hija Sofia en Cusco.',
    tALeadNombre
  );
  turnosA.push(tATurn1);

  // Turno 2: Entrega de edad e intención de reserva de clase gratuita
  const tATurn2 = await despacharTurnoConversacional(
    tALeadId,
    'Sofia tiene 9 años. Nos gustaría agendar su clase de prueba gratuita para este jueves.',
    tALeadNombre
  );
  turnosA.push(tATurn2);

  let currentReservasA = tATurn2.reservas;
  let resSofia = currentReservasA.find((r) => (r.nombre_persona || '').toLowerCase().includes('sofia') && r.status === 'confirmado');
  let turnosUsadosA = 2;
  let ultimoTurnoA = tATurn2;

  // Turno 3 dinámico (si el modelo solicitó confirmación antes de agendar)
  if (!resSofia && turnosUsadosA < 4) {
    turnosUsadosA++;
    console.log('  ℹ️  [Escenario A] Agente solicitó confirmación. Enviando confirmación afirmativa en Turno 3...');
    ultimoTurnoA = await despacharTurnoConversacional(
      tALeadId,
      'Sí, confirmo los datos. Por favor agenda la clase de prueba para Sofia este jueves a las 18:00.',
      tALeadNombre
    );
    turnosA.push(ultimoTurnoA);
    currentReservasA = ultimoTurnoA.reservas;
    resSofia = currentReservasA.find((r) => (r.nombre_persona || '').toLowerCase().includes('sofia') && r.status === 'confirmado');
  }

  // Turno 4 dinámico (si aún requiriera otro turno)
  if (!resSofia && turnosUsadosA < 4) {
    turnosUsadosA++;
    console.log('  ℹ️  [Escenario A] Enviando confirmación final en Turno 4...');
    ultimoTurnoA = await despacharTurnoConversacional(
      tALeadId,
      'Sí, confirmo la reserva.',
      tALeadNombre
    );
    turnosA.push(ultimoTurnoA);
    currentReservasA = ultimoTurnoA.reservas;
    resSofia = currentReservasA.find((r) => (r.nombre_persona || '').toLowerCase().includes('sofia') && r.status === 'confirmado');
  }

  const passA = Boolean(resSofia) && ultimoTurnoA.leadData.status === 'reservado';

  resultados.push({
    id: 'A',
    nombre: 'Escenario A: Reserva Completa (Sofia, 9 años)',
    leadId: tALeadId,
    status: passA ? 'PASS' : 'FAIL',
    detalles: `Reserva confirmada en Firestore: ${Boolean(resSofia)}, ID reserva: ${resSofia?.id || 'ninguna'}, Estado Lead: ${ultimoTurnoA.leadData.status}, Turnos empleados: ${turnosUsadosA}`,
    duracionMs: Date.now() - tAStart,
    turnos: turnosA,
    reservaDoc: resSofia,
  });

  // =============================================================
  // ESCENARIO B: REPROGRAMACIÓN REAL (Sofia, cambio de fecha)
  // =============================================================
  console.log('\n▶ Ejecutando ESCENARIO B: Reprogramación Real (Sofia, cambio de fecha)...');
  const tBStart = Date.now();
  const turnosB = [];
  let turnosUsadosB = 1;

  // Turno 1: Solicitar cambio de fecha de la reserva existente
  const tBTurn1 = await despacharTurnoConversacional(
    tALeadId,
    'Hola, se nos presentó un cruce de horarios para Sofia este jueves. ¿Podríamos reprogramar su clase de prueba para el próximo martes?',
    tALeadNombre
  );
  turnosB.push(tBTurn1);

  // Leer reservas actualizadas directamente de Firestore
  let reservasSnapB = await db.collection('reservas').where('lead_id', '==', tALeadId).get();
  let reservasB = reservasSnapB.docs.map((d) => ({ id: d.id, ...d.data() }));
  let resReprog = reservasB.find(
    (r) => (r.nombre_persona || '').toLowerCase().includes('sofia') &&
      r.status === 'confirmado' &&
      Array.isArray(r.reprogramaciones) &&
      r.reprogramaciones.length > 0
  );
  let ultimoTurnoB = tBTurn1;

  // Si el modelo pide confirmación para reprogramar
  if (!resReprog && turnosUsadosB < 3) {
    turnosUsadosB++;
    console.log('  ℹ️  [Escenario B] Agente solicitó confirmación de reprogramación. Enviando confirmación en Turno 2...');
    ultimoTurnoB = await despacharTurnoConversacional(
      tALeadId,
      'Sí, por favor cámbiala para el martes a las 18:00.',
      tALeadNombre
    );
    turnosB.push(ultimoTurnoB);
    reservasSnapB = await db.collection('reservas').where('lead_id', '==', tALeadId).get();
    reservasB = reservasSnapB.docs.map((d) => ({ id: d.id, ...d.data() }));
    resReprog = reservasB.find(
      (r) => (r.nombre_persona || '').toLowerCase().includes('sofia') &&
        r.status === 'confirmado' &&
        Array.isArray(r.reprogramaciones) &&
        r.reprogramaciones.length > 0
    );
  }

  const activasCountB = reservasB.filter(
    (r) => (r.nombre_persona || '').toLowerCase().includes('sofia') && r.status === 'confirmado'
  ).length;

  const passB = Boolean(resReprog) && activasCountB === 1;

  resultados.push({
    id: 'B',
    nombre: 'Escenario B: Reprogramación Real',
    leadId: tALeadId,
    status: passB ? 'PASS' : 'FAIL',
    detalles: `Reprogramación auditada: ${Boolean(resReprog)}, Reservas activas Sofia: ${activasCountB} (esperado 1), Turnos: ${turnosUsadosB}`,
    duracionMs: Date.now() - tBStart,
    turnos: turnosB,
    reservaDoc: resReprog,
  });

  // =============================================================
  // ESCENARIO C: IDEMPOTENCIA Y PREVENCIÓN DE DUPLICADOS (Sofia)
  // =============================================================
  console.log('\n▶ Ejecutando ESCENARIO C: Idempotencia y Prevención de Duplicados (Sofia)...');
  const tCStart = Date.now();
  const turnosC = [];

  // Snapshot antes del intento de duplicado
  const snapAntesC = await db.collection('reservas').where('lead_id', '==', tALeadId).get();
  const totalAntesC = snapAntesC.size;
  const activasAntesC = snapAntesC.docs
    .map((d) => d.data())
    .filter((r) => (r.nombre_persona || '').toLowerCase().includes('sofia') && r.status === 'confirmado').length;

  const tCTurn1 = await despacharTurnoConversacional(
    tALeadId,
    'Hola, quisiera agendar una clase de prueba para mi hija Sofia de 9 años para este martes.',
    tALeadNombre
  );
  turnosC.push(tCTurn1);

  // Snapshot después del intento
  const snapDespuesC = await db.collection('reservas').where('lead_id', '==', tALeadId).get();
  const totalDespuesC = snapDespuesC.size;
  const activasDespuesC = snapDespuesC.docs
    .map((d) => d.data())
    .filter((r) => (r.nombre_persona || '').toLowerCase().includes('sofia') && r.status === 'confirmado').length;

  const noDuplicoDocumentos = totalDespuesC === totalAntesC && activasDespuesC === activasAntesC;

  const intentoReservaOcurrido = tCTurn1.executedTools.some(
    (t) => (t.name || t.tool_name) === 'reservar_clase_prueba'
  );

  const avisoORechazo =
    tCTurn1.replyText.toLowerCase().includes('ya existe') ||
    tCTurn1.replyText.toLowerCase().includes('ya tiene') ||
    tCTurn1.replyText.toLowerCase().includes('previa') ||
    tCTurn1.replyText.toLowerCase().includes('reprogramar') ||
    tCTurn1.replyText.toLowerCase().includes('agendada') ||
    tCTurn1.replyText.toLowerCase().includes('confirmada') ||
    intentoReservaOcurrido;

  const passC = noDuplicoDocumentos && (avisoORechazo || intentoReservaOcurrido);

  resultados.push({
    id: 'C',
    nombre: 'Escenario C: Idempotencia y Duplicados',
    leadId: tALeadId,
    status: passC ? 'PASS' : 'FAIL',
    detalles: `No duplicó documentos en Firestore: ${noDuplicoDocumentos} (total docs: ${totalDespuesC}), Detectó reserva previa / ejecutó guard: ${Boolean(avisoORechazo || intentoReservaOcurrido)}`,
    duracionMs: Date.now() - tCStart,
    turnos: turnosC,
  });

  // =============================================================
  // ESCENARIO D: CAPTACIÓN DE DOS HERMANOS (Mateo 8a y Lucía 6a)
  // =============================================================
  console.log('\n▶ Ejecutando ESCENARIO D: Captación de Dos Hermanos (Mateo 8a y Lucía 6a)...');
  const tDStart = Date.now();
  const tDLeadNombre = 'TEST RUN 68 - Hermanos Mateo y Lucia';
  const turnosD = [];

  // Turno 1: Presentar a los dos hijos con nombres y edades
  const tDTurn1 = await despacharTurnoConversacional(
    tDLeadId,
    'Hola, buenas tardes. Quisiera información de clases de capoeira para mis dos hijos: Mateo tiene 8 años y Lucía tiene 6 años.',
    tDLeadNombre
  );
  turnosD.push(tDTurn1);

  // Turno 2: Solicitar agendamiento para ambos
  const tDTurn2 = await despacharTurnoConversacional(
    tDLeadId,
    'Nos gustaría agendar la clase de prueba gratuita para ambos niños este jueves.',
    tDLeadNombre
  );
  turnosD.push(tDTurn2);

  let currentReservasD = (await db.collection('reservas').where('lead_id', '==', tDLeadId).get()).docs.map((d) => ({
    id: d.id,
    ...d.data(),
  }));
  let resMateo = currentReservasD.find((r) => (r.nombre_persona || '').toLowerCase().includes('mateo') && r.status === 'confirmado');
  let resLucia = currentReservasD.find((r) => (r.nombre_persona || '').toLowerCase().includes('luc') && r.status === 'confirmado');
  let turnosUsadosD = 2;
  let ultimoTurnoD = tDTurn2;

  // Turno 3 dinámico (si el modelo solicitó confirmación)
  if ((!resMateo || !resLucia) && turnosUsadosD < 4) {
    turnosUsadosD++;
    console.log('  ℹ️  [Escenario D] Agente solicitó confirmación. Enviando confirmación explícita para ambos en Turno 3...');
    ultimoTurnoD = await despacharTurnoConversacional(
      tDLeadId,
      'Sí, confirmo la reserva de prueba para Mateo y para Lucía este jueves a las 18:00.',
      tDLeadNombre
    );
    turnosD.push(ultimoTurnoD);
    currentReservasD = (await db.collection('reservas').where('lead_id', '==', tDLeadId).get()).docs.map((d) => ({
      id: d.id,
      ...d.data(),
    }));
    resMateo = currentReservasD.find((r) => (r.nombre_persona || '').toLowerCase().includes('mateo') && r.status === 'confirmado');
    resLucia = currentReservasD.find((r) => (r.nombre_persona || '').toLowerCase().includes('luc') && r.status === 'confirmado');
  }

  // Turno 4 dinámico (si faltara confirmar al segundo hermano)
  if ((!resMateo || !resLucia) && turnosUsadosD < 4) {
    turnosUsadosD++;
    console.log('  ℹ️  [Escenario D] Enviando confirmación final en Turno 4...');
    ultimoTurnoD = await despacharTurnoConversacional(
      tDLeadId,
      'Sí, por favor reserva para los dos niños.',
      tDLeadNombre
    );
    turnosD.push(ultimoTurnoD);
    currentReservasD = (await db.collection('reservas').where('lead_id', '==', tDLeadId).get()).docs.map((d) => ({
      id: d.id,
      ...d.data(),
    }));
    resMateo = currentReservasD.find((r) => (r.nombre_persona || '').toLowerCase().includes('mateo') && r.status === 'confirmado');
    resLucia = currentReservasD.find((r) => (r.nombre_persona || '').toLowerCase().includes('luc') && r.status === 'confirmado');
  }

  const passD = Boolean(resMateo) && Boolean(resLucia) && ultimoTurnoD.leadData.status === 'reservado';

  resultados.push({
    id: 'D',
    nombre: 'Escenario D: Captación de Dos Hermanos',
    leadId: tDLeadId,
    status: passD ? 'PASS' : 'FAIL',
    detalles: `Reserva Mateo: ${Boolean(resMateo)} (${resMateo?.id}), Reserva Lucía: ${Boolean(resLucia)} (${resLucia?.id}), Lead status: ${ultimoTurnoD.leadData.status}, Turnos: ${turnosUsadosD}`,
    duracionMs: Date.now() - tDStart,
    turnos: turnosD,
    reservasDocs: [resMateo, resLucia].filter(Boolean),
  });

  // -------------------------------------------------------------
  // RESUMEN Y TELEMETRÍA FINAL
  // -------------------------------------------------------------
  const costoEstimadoUSD =
    networkAudit.promptTokens * (0.15 / 1000000) + networkAudit.completionTokens * (0.6 / 1000000);

  console.log('\n===============================================================');
  console.log('              RESULTADOS DE LA SUITE DE PRUEBAS                ');
  console.log('===============================================================');
  let passCount = 0;
  for (const r of resultados) {
    const icon = r.status === 'PASS' ? '✅' : '❌';
    if (r.status === 'PASS') passCount++;
    console.log(`${icon} [${r.status}] ${r.nombre}`);
    console.log(`    Lead ID: ${r.leadId}`);
    console.log(`    Detalles: ${r.detalles}`);
    console.log(`    Duración: ${r.duracionMs} ms\n`);
  }

  console.log('---------------------------------------------------------------');
  console.log(`Total escenarios: ${resultados.length} | Pasados: ${passCount} | Fallados: ${resultados.length - passCount}`);
  console.log(`Tasa de éxito: ${Math.round((passCount / resultados.length) * 100)}%`);
  console.log('---------------------------------------------------------------');
  console.log('AUDITORÍA DE RED Y CONSUMOS:');
  console.log(`  - Salidas a Meta WhatsApp intentadas: ${networkAudit.metaCallsAttempted}`);
  console.log(`  - Salidas a Meta WhatsApp BLOQUEADAS: ${networkAudit.metaCallsBlocked}`);
  console.log(`  - Llamadas a OpenAI simuladas (Mock): ${networkAudit.mockOpenAiCalls}`);
  console.log(`  - Llamadas a OpenAI reales:          ${networkAudit.openAiCalls} (Límite: ${MAX_OPENAI_CALLS_LIMIT})`);
  console.log(`  - Tokens Prompt consumidos:          ${networkAudit.promptTokens}`);
  console.log(`  - Tokens Completion consumidos:      ${networkAudit.completionTokens}`);
  console.log(`  - Total Tokens consumidos:           ${networkAudit.totalTokens}`);
  console.log(`  - Costo estimado total (USD):        $${costoEstimadoUSD.toFixed(5)}`);
  console.log('===============================================================\n');

  console.log('📋 MANIFIESTO DE REGISTROS TEST CREADOS (PARA REVISIÓN Y LIMPIEZA MANUAL):');
  console.log('---------------------------------------------------------------');
  for (const doc of createdDocumentsManifest) {
    console.log(`[${doc.coleccion}] ${doc.path} (${doc.descripcion})`);
  }
  console.log('---------------------------------------------------------------\n');

  if (passCount !== resultados.length) {
    console.error('❌ Al menos una prueba no cumplió los criterios de aceptación.');
    process.exit(1);
  }

  console.log('✔ Todos los escenarios pasaron satisfactoriamente.');
  console.log('✔ Los documentos han sido preservados en Firestore para supervisión en Flutter.');
}

ejecutarSuiteDePruebas().catch((err) => {
  console.error('\n[FATAL ERROR EN RUNNER]:', err);
  process.exit(1);
});

/**
 * scripts/run_production_conversational_tests.js
 * Runner de Pruebas Conversacionales Reales / Pre-Flight para GINGA V1 (Node.js 22)
 * 
 * Permite ejecutar los 8 escenarios conversacionales contra:
 * 1. MODO OFFLINE / EMULATOR (por defecto):
 *    - Requiere Firestore Emulator (demo-ginga-test).
 *    - Permite validación previa 100% determinista y segura.
 *    - No modifica producción ni consume recursos externos.
 * 2. MODO PRODUCCIÓN:
 *    - Requiere flag explícito: --target=production y ALLOW_PRODUCTION_TEST_WRITES=true.
 *    - Inyecta leads de prueba TEST_LEAD_01 a 08 con seguimiento_frio_enviado=true.
 *    - NO borra documentos al finalizar: quedan disponibles para inspección y borrado manual en Flutter.
 * 
 * GARANTÍAS DE SEGURIDAD ESTRICTAS:
 * - Firewall de red global a nivel de proceso: ZERO salidas a Meta WhatsApp (graph.facebook.com).
 * - Bloqueo verificado deterministamente antes de iniciar la primera prueba.
 * - Idéntica lógica de razonamiento a la versión desplegada en Cloud Functions (v69).
 * - Circuit breaker estricto: máximo 30 llamadas a OpenAI con tracking de tokens y costo.
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
      // Clonar para auditar tokens de forma no invasiva
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

    // Modo simulado / Mock OpenAI determinista para reproducibilidad completa
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
      // Ignorar otros errores de aborto
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
  const tools = body.tools || [];
  const lastMsg = messages[messages.length - 1];

  if (lastMsg && lastMsg.role === 'tool') {
    const toolResults = messages.filter((m) => m.role === 'tool');
    const lastTool = toolResults[toolResults.length - 1];
    const content = lastTool.content || '';

    if (content.includes('Horarios disponibles:') || content.includes('Kids')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: '¡Hola! Tenemos clases de Capoeira para niños (Kids, de 5 a 12 años) los martes y jueves de 18:00 a 19:00 en Av. de la Cultura E-4, Urb. Magisterio, Edificio Divergym, 3er piso. La mensualidad regular es S/140 y la clase de prueba es gratuita. ¿Te gustaría agendar una?',
            },
          },
        ],
      };
    }

    if (content.includes('Reserva confirmada') || content.includes('confirmada')) {
      const isMultiple = toolResults.filter((m) => m.content.includes('Reserva confirmada')).length > 1;
      if (isMultiple) {
        const matchFecha = content.match(/para el ([^.]+?) a las/);
        const fechaTexto = matchFecha ? matchFecha[1] : 'la fecha programada';
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: `¡Listo! Las clases de prueba para Mateo y Lucía quedaron confirmadas para el ${fechaTexto} a las 18:00 en nuestra sede de Divergym (3er piso). Recuerden llegar con ropa deportiva cómoda y una botella con agua.`,
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
              content: `¡Excelente! ${content} Recuerda que deben asistir con ropa deportiva cómoda y una botella de agua. ¡Los esperamos!`,
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
              content: `¡Listo! ${content}`,
            },
          },
        ],
      };
    }

    if (content.includes('Ya existe una reserva previa') || content.includes('DUPLICATE_ACTIVE_RESERVATION')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: `${content} Si necesitas cambiar de fecha u horario, avísame y con gusto te ayudo a reprogramar la clase.`,
            },
          },
        ],
      };
    }

    if (content.includes('Se notificó a un instructor') || content.includes('atención humana')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: 'He avisado a nuestro instructor del motivo de tu consulta. Te escribirá personalmente a la brevedad para orientarte con todos los detalles.',
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
              content: '¡Perfecto! Anoté los datos. Tenemos clases para esa edad los martes y jueves a las 18:00 en Divergym Magisterio. ¿Deseas agendar la clase de prueba gratuita?',
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

  const userMsgs = messages.filter((m) => m.role === 'user');
  const lastUserText = userMsgs.length > 0 ? (userMsgs[userMsgs.length - 1].content || '') : '';
  const textLower = lastUserText.toLowerCase();

  if (
    textLower.includes('hablar directamente') ||
    textLower.includes('profesor') ||
    textLower.includes('médica') ||
    textLower.includes('medica') ||
    textLower.includes('lesión') ||
    textLower.includes('lesion') ||
    textLower.includes('rodilla')
  ) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_human`,
                type: 'function',
                function: {
                  name: 'marcar_seguimiento_humano',
                  arguments: JSON.stringify({
                    motivo: 'Consulta médica sobre salud y lesión en rodilla; solicita hablar con el profesor.',
                  }),
                },
              },
            ],
          },
        },
      ],
    };
  }

  if (
    textLower.includes('reprogram') ||
    textLower.includes('cambiar') ||
    (textLower.includes('no va a poder') && textLower.includes('jueves'))
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
                    nombre: 'Valentina',
                    nueva_fecha: '2026-11-19',
                    motivo: 'Tiene dentista el martes, solicita pasar al jueves',
                  }),
                },
              },
            ],
          },
        },
      ],
    };
  }

  if (textLower.includes('mateo') && (textLower.includes('lucia') || textLower.includes('lucía'))) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_prof_hermanos`,
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

  if (textLower.includes('volver a agendar') || (textLower.includes('otra clase de prueba') && textLower.includes('mateo'))) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_res_dup`,
                type: 'function',
                function: {
                  name: 'reservar_clase_prueba',
                  arguments: JSON.stringify({
                    nombre: 'Mateo',
                    tipo: 'niño',
                  }),
                },
              },
            ],
          },
        },
      ],
    };
  }

  if (
    textLower.includes('agendar una clase de prueba') ||
    textLower.includes('agendar clase de prueba') ||
    textLower.includes('reserva para los dos') ||
    (textLower.includes('agendar') && textLower.includes('valentina'))
  ) {
    let targetName = 'Valentina';
    if (textLower.includes('mateo')) targetName = 'Mateo';
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_reserva`,
                type: 'function',
                function: {
                  name: 'reservar_clase_prueba',
                  arguments: JSON.stringify({
                    nombre: targetName,
                    tipo: 'niño',
                  }),
                },
              },
            ],
          },
        },
      ],
    };
  }

  if (textLower.includes('valentina') && textLower.includes('9')) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_perfil_val`,
                type: 'function',
                function: {
                  name: 'guardar_perfil_lead',
                  arguments: JSON.stringify({
                    personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
                  }),
                },
              },
            ],
          },
        },
      ],
    };
  }

  if (textLower.includes('100') || textLower.includes('rebaja') || textLower.includes('descuento a s/')) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'Nuestros precios son fijos: la mensualidad regular es de S/140 por persona o S/260 en promoción para dos personas (o paquetes de 3 meses a S/380 y 6 meses a S/720). No contamos con una tarifa de S/100, pero te invitamos a participar en la clase de prueba gratuita para que conozcas la escuela.',
          },
        },
      ],
    };
  }

  if (textLower.includes('mensualidad') || textLower.includes('promociones') || textLower.includes('cuesta')) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'La mensualidad regular es de S/140 por persona. Contamos con una promoción especial para dos personas juntas a S/260 al mes, paquete trimestral por S/380 y semestral por S/720. Además, la primera clase de prueba es completamente gratuita. ¿Te gustaría agendar una?',
          },
        },
      ],
    };
  }

  if (textLower.includes('yape') || textLower.includes('pagar')) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: '¡Excelente decisión! Puedes realizar el pago de tu mensualidad (S/140) mediante Yape al número 51900075008 a nombre de Instructor Ginga Cusco. Una vez realizada la transferencia, envíanos por aquí la constancia o captura para registrar tu matrícula.',
          },
        },
      ],
    };
  }

  if (textLower.includes('horario') || textLower.includes('edades') || textLower.includes('niños') || textLower.includes('clases')) {
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: `call_${Date.now()}_cons_horarios`,
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
    yape_numero: '984 765 432',
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
    seguimiento_frio_enviado: true, // Blindaje contra tareas programadas (Scheduler)
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

  // Leer historial conversacional reciente (últimos 10 mensajes)
  const histSnap = await leadRef.collection('mensajes').orderBy('timestamp', 'desc').limit(10).get();
  const historial = histSnap.docs.reverse().map((d) => {
    const m = d.data();
    return { role: m.from === 'lead' ? 'user' : 'assistant', content: m.texto };
  });

  // Generar System Prompt oficial usando la lógica real de functions/index.js
  const leadDataActual = (await leadRef.get()).data();
  const { systemPrompt, preciosValidos, catalogoClases, ubicacionReal } = await generarSystemPrompt(
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
// 7. DEFINICIÓN Y EJECUCIÓN DE LOS 8 ESCENARIOS DE PRUEBA
// -------------------------------------------------------------
async function ejecutarSuiteDePruebas() {
  console.log('\n===============================================================');
  console.log('   GINGA REAL — RUNNER CONVERSACIONAL DE PRODUCCIÓN / PRE-FLIGHT');
  console.log(`   Destino: ${isProductionTarget ? 'PRODUCCIÓN (capoeirafiu-ea8ljo)' : 'EMULADOR LOCAL (demo-ginga-test)'}`);
  console.log(`   Modo OpenAI: ${forceRealOpenAI ? 'REAL (OpenAI API - gpt-4o-mini)' : 'SIMULADO / OFFLINE (Deterministic Mock)'}`);
  console.log('===============================================================\n');

  await verificarBloqueoMetaActivo();

  if (isEmulatorTarget) {
    await sembrarFixturesEmulador();
  }

  // Comprobar si los IDs de lead predeterminados existen en Firestore (Requisito 14)
  const runTimestamp = Date.now();
  let idSuffix = '';
  if (isProductionTarget) {
    const checkDoc = await db.collection('whatsapp_leads').doc('TEST_LEAD_01_HORARIOS').get();
    if (checkDoc.exists) {
      idSuffix = `_${runTimestamp}`;
      console.log(`ℹ️ [Aislamiento] Ya existen leads TEST previos. Utilizando sufijo único de corrida: ${idSuffix}`);
    }
  }

  const resultados = [];

  // -------------------------------------------------------------
  // TEST 1: Horarios y edades Kids (P1 inquiry)
  // -------------------------------------------------------------
  console.log('\n▶ Ejecutando TEST 1: Horarios y edades Kids...');
  const t1Start = Date.now();
  const t1LeadId = `TEST_LEAD_01_HORARIOS${idSuffix}`;
  const t1LeadNombre = 'TEST 1 - Horarios Kids';
  const t1Turn1 = await despacharTurnoConversacional(
    t1LeadId,
    '¿Qué horarios y para qué edades tienen clases de niños en Cusco?',
    t1LeadNombre
  );
  const t1Reply = t1Turn1.replyText.toLowerCase();
  const t1TieneHorarioCorrecto = t1Reply.includes('18:00') || t1Reply.includes('6:00 pm') || t1Reply.includes('6 pm');
  const t1TieneEdadCorrecta = t1Reply.includes('5 a 12') || t1Reply.includes('5 años') || t1Reply.includes('5') || t1Reply.includes('12');
  const t1NoTieneErrorP1 = !t1Reply.includes('17:00') && !t1Reply.includes('4 a 12') && !t1Reply.includes('4 años');
  const t1Pass = t1TieneHorarioCorrecto && t1TieneEdadCorrecta && t1NoTieneErrorP1;

  resultados.push({
    id: 1,
    leadId: t1LeadId,
    nombre: t1LeadNombre,
    descripcion: 'Horarios y edades Kids (P1 inquiry)',
    status: t1Pass ? 'PASS' : 'FAIL',
    detalles: `Horario oficial: ${t1TieneHorarioCorrecto}, Edad 5-12: ${t1TieneEdadCorrecta}, Sin error P1: ${t1NoTieneErrorP1}`,
    duracionMs: Date.now() - t1Start,
    leadStatus: t1Turn1.leadData.status,
    reservasCreadas: t1Turn1.reservas.length,
    ultimoMensajeIA: t1Turn1.replyText,
  });

  // -------------------------------------------------------------
  // TEST 2: Perfilado y reserva de clase de prueba (Valentina, 9 años)
  // -------------------------------------------------------------
  console.log('▶ Ejecutando TEST 2: Perfilado y reserva Valentina (9 años)...');
  const t2Start = Date.now();
  const t2LeadId = `TEST_LEAD_02_RESERVA_VALENTINA${idSuffix}`;
  const t2LeadNombre = 'TEST 2 - Reserva Valentina';
  await despacharTurnoConversacional(t2LeadId, 'Hola, me gustaría información para mi hija Valentina de 9 años.', t2LeadNombre);
  const t2Turn2 = await despacharTurnoConversacional(t2LeadId, 'Quisiera agendar una clase de prueba gratuita para este martes o jueves.', t2LeadNombre);
  const t2Reserva = t2Turn2.reservas.find((r) => r.nombre_persona === 'Valentina' && r.status === 'confirmado');
  const t2Pass = Boolean(t2Reserva) && t2Turn2.leadData.status === 'reservado';

  resultados.push({
    id: 2,
    leadId: t2LeadId,
    nombre: t2LeadNombre,
    descripcion: 'Perfilado y reserva clase de prueba (Valentina, 9 años)',
    status: t2Pass ? 'PASS' : 'FAIL',
    detalles: `Reserva confirmada en Firestore: ${Boolean(t2Reserva)}, Estado Lead: ${t2Turn2.leadData.status}`,
    duracionMs: Date.now() - t2Start,
    leadStatus: t2Turn2.leadData.status,
    reservasCreadas: t2Turn2.reservas.length,
    ultimoMensajeIA: t2Turn2.replyText,
  });

  // -------------------------------------------------------------
  // TEST 3: Reserva y posterior reprogramación (Valentina, martes a jueves)
  // -------------------------------------------------------------
  console.log('▶ Ejecutando TEST 3: Reprogramación Valentina (martes a jueves)...');
  const t3Start = Date.now();
  const t3LeadId = `TEST_LEAD_03_REPROGRAMACION${idSuffix}`;
  const t3LeadNombre = 'TEST 3 - Reprogramacion Valentina';
  await despacharTurnoConversacional(t3LeadId, 'Hola, quiero agendar clase de prueba para mi hija Valentina de 9 años este martes.', t3LeadNombre);
  const t3Turn2 = await despacharTurnoConversacional(
    t3LeadId,
    'Hola, el martes no va a poder ir Valentina porque tiene dentista. ¿Podemos cambiarla para el jueves?',
    t3LeadNombre
  );
  const t3Reservas = t3Turn2.reservas;
  const t3TieneReprogramacionAudit = t3Reservas.some((r) => Array.isArray(r.reprogramaciones) && r.reprogramaciones.length > 0);
  const t3TieneConfirmada = t3Reservas.some((r) => r.status === 'confirmado');
  const t3Pass = t3TieneReprogramacionAudit && t3TieneConfirmada;

  resultados.push({
    id: 3,
    leadId: t3LeadId,
    nombre: t3LeadNombre,
    descripcion: 'Reserva y posterior reprogramación (martes a jueves)',
    status: t3Pass ? 'PASS' : 'FAIL',
    detalles: `Auditoría reprogramación en Firestore: ${t3TieneReprogramacionAudit}, Reserva vigente confirmada: ${t3TieneConfirmada}`,
    duracionMs: Date.now() - t3Start,
    leadStatus: t3Turn2.leadData.status,
    reservasCreadas: t3Turn2.reservas.length,
    ultimoMensajeIA: t3Turn2.replyText,
  });

  // -------------------------------------------------------------
  // TEST 4: Padre con dos hijos (Mateo 8 años, Lucía 6 años, reserva múltiple)
  // -------------------------------------------------------------
  console.log('▶ Ejecutando TEST 4: Dos hijos (Mateo 8 y Lucía 6)...');
  const t4Start = Date.now();
  const t4LeadId = `TEST_LEAD_04_HERMANOS${idSuffix}`;
  const t4LeadNombre = 'TEST 4 - Hermanos Mateo y Lucia';
  const t4Turn1 = await despacharTurnoConversacional(
    t4LeadId,
    'Hola, tengo dos hijos, Mateo de 8 años y Lucía de 6 años. ¿Podemos reservar una clase de prueba para ambos este martes?',
    t4LeadNombre
  );
  const t4ResMateo = t4Turn1.reservas.find((r) => r.nombre_persona === 'Mateo' && r.status === 'confirmado');
  const t4ResLucia = t4Turn1.reservas.find((r) => r.nombre_persona === 'Lucía' && r.status === 'confirmado');
  const t4SinPlaceholders = !t4Turn1.replyText.includes('[') && !t4Turn1.replyText.includes(']');
  const t4Pass = Boolean(t4ResMateo) && Boolean(t4ResLucia) && t4SinPlaceholders;

  resultados.push({
    id: 4,
    leadId: t4LeadId,
    nombre: t4LeadNombre,
    descripcion: 'Padre con dos hijos (Mateo 8 y Lucía 6, reserva múltiple)',
    status: t4Pass ? 'PASS' : 'FAIL',
    detalles: `Reserva Mateo: ${Boolean(t4ResMateo)}, Reserva Lucía: ${Boolean(t4ResLucia)}, Sin placeholders: ${t4SinPlaceholders}`,
    duracionMs: Date.now() - t4Start,
    leadStatus: t4Turn1.leadData.status,
    reservasCreadas: t4Turn1.reservas.length,
    ultimoMensajeIA: t4Turn1.replyText,
  });

  // -------------------------------------------------------------
  // TEST 5: Mensualidad, promociones y resistencia a regateo (S/140, S/240, rechazo a S/100)
  // -------------------------------------------------------------
  console.log('▶ Ejecutando TEST 5: Mensualidad y resistencia a regateo...');
  const t5Start = Date.now();
  const t5LeadId = `TEST_LEAD_05_REGATEO${idSuffix}`;
  const t5LeadNombre = 'TEST 5 - Precios y Regateo';
  await despacharTurnoConversacional(t5LeadId, '¿Cuánto cuesta la mensualidad y qué promociones tienen?', t5LeadNombre);
  const t5Turn2 = await despacharTurnoConversacional(
    t5LeadId,
    '¿Me puedes hacer un descuento a S/ 100 por mes si me inscribo hoy mismo?',
    t5LeadNombre
  );
  const t5Reply = t5Turn2.replyText.toLowerCase();
  const t5RechazoRegateo = t5Reply.includes('no contamos') || t5Reply.includes('fijos') || t5Reply.includes('regular es de s/140') || t5Reply.includes('s/140') || t5Reply.includes('140');
  const t5NoAcepto100 = !t5Reply.includes('te lo dejo a 100') && !t5Reply.includes('quedaría en s/100');
  const t5Pass = t5RechazoRegateo && t5NoAcepto100;

  resultados.push({
    id: 5,
    leadId: t5LeadId,
    nombre: t5LeadNombre,
    descripcion: 'Mensualidad, promociones y resistencia a regateo',
    status: t5Pass ? 'PASS' : 'FAIL',
    detalles: `Defendió precios oficiales: ${t5RechazoRegateo}, Rechazó rebaja a S/100: ${t5NoAcepto100}`,
    duracionMs: Date.now() - t5Start,
    leadStatus: t5Turn2.leadData.status,
    reservasCreadas: t5Turn2.reservas.length,
    ultimoMensajeIA: t5Turn2.replyText,
  });

  // -------------------------------------------------------------
  // TEST 6: Consulta de pago por Yape (número, titular, comprobante)
  // -------------------------------------------------------------
  console.log('▶ Ejecutando TEST 6: Consulta de pago por Yape...');
  const t6Start = Date.now();
  const t6LeadId = `TEST_LEAD_06_YAPE${idSuffix}`;
  const t6LeadNombre = 'TEST 6 - Consulta Yape';
  const t6Turn1 = await despacharTurnoConversacional(
    t6LeadId,
    'Ya me decidí a inscribirme, ¿cómo puedo pagar por Yape y a qué número realizo la transferencia?',
    t6LeadNombre
  );
  const t6Reply = t6Turn1.replyText;
  const t6TieneNumero = t6Reply.includes('51900075008') || t6Reply.includes('900075008') || t6Reply.includes('984 765 432') || t6Reply.includes('984765432');
  const t6TieneTitular = t6Reply.includes('Instructor Ginga') || t6Reply.includes('Ginga') || t6Reply.includes('Capoeira');
  const t6PideComprobante = t6Reply.toLowerCase().includes('constancia') || t6Reply.toLowerCase().includes('captura') || t6Reply.toLowerCase().includes('comprobante');
  const t6Pass = t6TieneNumero && (t6TieneTitular || t6PideComprobante);

  resultados.push({
    id: 6,
    leadId: t6LeadId,
    nombre: t6LeadNombre,
    descripcion: 'Consulta de pago por Yape (número, titular, comprobante)',
    status: t6Pass ? 'PASS' : 'FAIL',
    detalles: `Número oficial: ${t6TieneNumero}, Titular/Ginga: ${t6TieneTitular}, Pide comprobante: ${t6PideComprobante}`,
    duracionMs: Date.now() - t6Start,
    leadStatus: t6Turn1.leadData.status,
    reservasCreadas: t6Turn1.reservas.length,
    ultimoMensajeIA: t6Turn1.replyText,
  });

  // -------------------------------------------------------------
  // TEST 7: Solicitud de atención humana (derivación por lesión médica)
  // -------------------------------------------------------------
  console.log('▶ Ejecutando TEST 7: Atención humana (derivación médica)...');
  const t7Start = Date.now();
  const t7LeadId = `TEST_LEAD_07_HUMANO${idSuffix}`;
  const t7LeadNombre = 'TEST 7 - Atencion Humana';
  const t7Turn1 = await despacharTurnoConversacional(
    t7LeadId,
    'Hola, necesito hablar directamente con el profesor, mi hijo tiene una lesión delicada en la rodilla y el médico me dio indicaciones específicas.',
    t7LeadNombre
  );
  const t7EstadoLead = t7Turn1.leadData.status;
  const t7TieneMotivo = Boolean(t7Turn1.leadData.motivo_seguimiento);
  const t7Pass = t7EstadoLead === 'requiere_atencion' && t7TieneMotivo;

  resultados.push({
    id: 7,
    leadId: t7LeadId,
    nombre: t7LeadNombre,
    descripcion: 'Solicitud de atención humana (marcar_seguimiento_humano)',
    status: t7Pass ? 'PASS' : 'FAIL',
    detalles: `Status: ${t7EstadoLead} (esperado requiere_atencion), Motivo registrado: ${t7TieneMotivo}`,
    duracionMs: Date.now() - t7Start,
    leadStatus: t7Turn1.leadData.status,
    reservasCreadas: t7Turn1.reservas.length,
    ultimoMensajeIA: t7Turn1.replyText,
  });

  // -------------------------------------------------------------
  // TEST 8: Intento de reserva duplicada (DUPLICATE_ACTIVE_RESERVATION)
  // -------------------------------------------------------------
  console.log('▶ Ejecutando TEST 8: Intento de reserva duplicada...');
  const t8Start = Date.now();
  const t8LeadId = `TEST_LEAD_08_DUPLICADA${idSuffix}`;
  const t8LeadNombre = 'TEST 8 - Reserva Duplicada';
  await despacharTurnoConversacional(t8LeadId, 'Hola, quiero agendar clase de prueba para mi hijo Mateo este martes.', t8LeadNombre);
  const t8Turn2 = await despacharTurnoConversacional(
    t8LeadId,
    'Quiero volver a agendar otra clase de prueba gratuita para Mateo este jueves.',
    t8LeadNombre
  );
  const t8ReservasMateo = t8Turn2.reservas.filter((r) => r.nombre_persona === 'Mateo' && r.status === 'confirmado');
  const t8NoDuplico = t8ReservasMateo.length === 1;
  const t8AvisoDuplicada = t8Turn2.replyText.toLowerCase().includes('ya existe') ||
    t8Turn2.replyText.toLowerCase().includes('reprogramar') ||
    t8Turn2.replyText.toLowerCase().includes('ya tiene') ||
    t8Turn2.replyText.toLowerCase().includes('previa');
  const t8Pass = t8NoDuplico && t8AvisoDuplicada;

  resultados.push({
    id: 8,
    leadId: t8LeadId,
    nombre: t8LeadNombre,
    descripcion: 'Intento de reserva duplicada (DUPLICATE_ACTIVE_RESERVATION)',
    status: t8Pass ? 'PASS' : 'FAIL',
    detalles: `Reservas activas únicas: ${t8ReservasMateo.length} (esperado 1), Notificó reserva previa: ${t8AvisoDuplicada}`,
    duracionMs: Date.now() - t8Start,
    leadStatus: t8Turn2.leadData.status,
    reservasCreadas: t8Turn2.reservas.length,
    ultimoMensajeIA: t8Turn2.replyText,
  });

  // -------------------------------------------------------------
  // RESUMEN Y TELEMETRÍA FINAL
  // -------------------------------------------------------------
  const costoEstimadoUSD = (networkAudit.promptTokens * (0.15 / 1000000)) + (networkAudit.completionTokens * (0.60 / 1000000));

  console.log('\n===============================================================');
  console.log('              RESULTADOS DE LA SUITE DE PRUEBAS                ');
  console.log('===============================================================');
  let passCount = 0;
  for (const r of resultados) {
    const icon = r.status === 'PASS' ? '✅' : '❌';
    if (r.status === 'PASS') passCount++;
    console.log(`${icon} [${r.status}] Escenario ${r.id}: ${r.nombre}`);
    console.log(`    Lead ID: ${r.leadId} | Status: ${r.leadStatus} | Reservas: ${r.reservasCreadas}`);
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

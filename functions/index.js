const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
admin.initializeApp();

/**
 * Trigger que se ejecuta cada vez que se crea una nueva notificación en el buzón
 * de un alumno en Firestore: /users/{uid}/notificaciones/{notiId}
 */
exports.onNotificationCreated = functions.firestore
  .document('users/{uid}/notificaciones/{notiId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const uid = context.params.uid;

    if (!data) {
      console.log('No hay datos en el documento de notificación.');
      return null;
    }

    // ============================================================
    //  REGLA DE NEGOCIO: FILTRO DE ASISTENCIAS (QR SCAN)
    // ============================================================
    // Si el alumno está escaneando el QR en la academia, ya tiene la app abierta.
    // Omitimos la alerta push emergente (banner) para evitar spam,
    // pero el registro queda en su buzón permanente (campana) para su historial.
    const tipo = data.tipo || 'general';
    if (tipo === 'asistencia' || tipo === 'checkin') {
      console.log(`[Push Omitted] Omitiendo alerta push por asistencia/QR para el usuario: ${uid}`);
      return null;
    }

    const titulo = data.titulo || 'Nueva notificación 🔔';
    const mensaje = data.mensaje || 'Tienes un nuevo aviso en Ginga App.';

    try {
      // 1. Buscar el token FCM del dispositivo en el perfil del alumno
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (!userDoc.exists) {
        console.log(`[Error] Documento del usuario ${uid} no encontrado.`);
        return null;
      }

      const userData = userDoc.data();
      const notificationsEnabled = userData.notifications_enabled !== false; // por defecto true
      if (!notificationsEnabled) {
        console.log(`[Skipped] El usuario ${uid} tiene las notificaciones push desactivadas por preferencia.`);
        return null;
      }

      const fcmToken = userData.fcm_token;
      if (!fcmToken) {
        console.log(`[Skipped] El usuario ${uid} no tiene un token FCM (dispositivo) registrado.`);
        return null;
      }

      console.log(`[Sending Push] Enviando alerta a UID: ${uid} | Token: ${fcmToken.substring(0, 10)}...`);

      // 2. Construir el payload del push multidispositivo
      const messagePayload = {
        token: fcmToken,
        notification: {
          title: titulo,
          body: mensaje,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          tipo: tipo,
          notificacionId: context.params.notiId,
          clase_id: data.clase_id || '',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // 3. Enviar la notificación a través de Firebase Cloud Messaging
      const response = await admin.messaging().send(messagePayload);
      console.log(`[Success] Push enviado con éxito a UID: ${uid}. Response ID: ${response}`);
      return null;
    } catch (error) {
      console.error(`[Error] Fallo al enviar push a UID ${uid}:`, error);
      return null;
    }
  });

/**
 * Tarea programada que se ejecuta diariamente a las 08:00 AM (America/Lima)
 * Busca las reservas de tipo 'prueba' del día de hoy y escribe una notificación
 * en el buzón de cada alumno para disparar el push de recordatorio.
 */
exports.enviarRecordatorioPruebaDiario = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/Lima')
  .onRun(async (context) => {
    console.log('[Scheduler] Iniciando envío de recordatorios diarios de clase de prueba...');

    // 1. Obtener rango del día de hoy en la zona horaria America/Lima
    const limaTimeString = new Date().toLocaleString('en-US', { timeZone: 'America/Lima' });
    const limaDate = new Date(limaTimeString);

    const startOfDay = new Date(limaDate.getFullYear(), limaDate.getMonth(), limaDate.getDate(), 0, 0, 0);
    const endOfDay = new Date(limaDate.getFullYear(), limaDate.getMonth(), limaDate.getDate(), 23, 59, 59);

    const startTimestamp = admin.firestore.Timestamp.fromDate(startOfDay);
    const endTimestamp = admin.firestore.Timestamp.fromDate(endOfDay);

    console.log(`[Scheduler] Rango de búsqueda Cusco/Lima: ${startOfDay.toISOString()} - ${endOfDay.toISOString()}`);

    try {
      // 2. Buscar reservas de prueba confirmadas para hoy
      const reservasSnapshot = await admin.firestore()
        .collection('reservas')
        .where('tipo', '==', 'prueba')
        .where('status', '==', 'confirmado')
        .where('fecha_clase', '>=', startTimestamp)
        .where('fecha_clase', '<=', endTimestamp)
        .get();

      if (reservasSnapshot.empty) {
        console.log('[Scheduler] No hay reservas de prueba programadas para el día de hoy.');
        return null;
      }

      console.log(`[Scheduler] Se encontraron ${reservasSnapshot.size} reservas de prueba para hoy.`);

      // 3. Procesar cada reserva
      const promesas = reservasSnapshot.docs.map(async (doc) => {
        const data = doc.data();
        const uid = data.user_id;
        const claseId = data.clase_id || '';
        const hora = data.hora || '';
        const nivel = data.nivel || 'Capoeira';

        if (!uid) {
          console.log(`[Warning] Reserva ${doc.id} no cuenta con user_id.`);
          return;
        }

        // Recuperar el perfil del usuario para validar que siga en estado 'prueba' y obtener su nombre
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (!userDoc.exists) {
          console.log(`[Warning] Usuario ${uid} no encontrado para la reserva ${doc.id}.`);
          return;
        }

        const userData = userDoc.data();
        const userStatus = userData.status || 'nuevo';
        const nombre = userData.nombre || 'Alumno';

        // Validar que el usuario siga teniendo status de prueba
        if (userStatus !== 'prueba') {
          console.log(`[Skipped] El usuario ${uid} ya no tiene status 'prueba' (status actual: ${userStatus}).`);
          return;
        }

        // 4. Crear el documento en su subcolección de notificaciones.
        // Esto activará automáticamente el disparador 'onNotificationCreated' y enviará la notificación push.
        const notiRef = admin.firestore()
          .collection('users')
          .doc(uid)
          .collection('notificaciones')
          .doc();

        await notiRef.set({
          titulo: '¡Hoy es tu clase de prueba! 🥋',
          mensaje: `Hola ${nombre}, te recordamos que hoy tienes tu clase de prueba de ${nivel} a las ${hora}. ¡Te esperamos en la academia!`,
          fecha: admin.firestore.FieldValue.serverTimestamp(),
          leido: false,
          tipo: 'recordatorio_prueba',
          clase_id: claseId,
        });

        console.log(`[Scheduler] Recordatorio de prueba registrado en buzón para UID: ${uid}`);
      });

      await Promise.all(promesas);
      console.log('[Scheduler] Finalizado el envío de recordatorios diarios con éxito.');
      return null;
    } catch (error) {
      console.error('[Scheduler] Error al procesar recordatorios diarios de clase de prueba:', error);
      return null;
    }
  });

// ============================================================
//  WHATSAPP ADS LEADS: webhook de Meta + IA (OpenAI) + reserva
// ============================================================
// Secrets requeridos (configurar con `firebase functions:secrets:set NOMBRE`):
//   META_VERIFY_TOKEN, META_APP_SECRET, META_WHATSAPP_TOKEN,
//   META_PHONE_NUMBER_ID, OPENAI_API_KEY
const WHATSAPP_SECRETS = [
  'META_VERIFY_TOKEN',
  'META_APP_SECRET',
  'META_WHATSAPP_TOKEN',
  'META_PHONE_NUMBER_ID',
  'OPENAI_API_KEY',
];

const LEAD_SYSTEM_PROMPT = `Eres el asistente de WhatsApp de Ginga, una academia de Capoeira.
Responde ÚNICAMENTE preguntas sobre clases de Capoeira, horarios, niveles, sede y la clase de prueba gratuita de Ginga.
Si preguntan sobre cualquier otro tema, responde amablemente que solo puedes ayudar con temas de Ginga.
Responde siempre en un solo bloque de texto, corto y directo (máximo 3 líneas), nunca en varios mensajes.
Si la persona confirma que quiere agendar su clase de prueba gratuita, usa la función reservar_clase_prueba.`;

/** Valida que el POST realmente venga de Meta usando el App Secret. */
function verifyMetaSignature(req) {
  const signature = req.get('X-Hub-Signature-256');
  const appSecret = process.env.META_APP_SECRET;
  if (!signature || !appSecret || !req.rawBody) return false;
  const expected = 'sha256=' + crypto
    .createHmac('sha256', appSecret)
    .update(req.rawBody)
    .digest('hex');
  const sigBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  if (sigBuffer.length !== expectedBuffer.length) return false;
  return crypto.timingSafeEqual(sigBuffer, expectedBuffer);
}

/**
 * Reserva una clase de prueba para un lead de WhatsApp (sin cuenta de Firebase Auth).
 * Misma lógica transaccional que `_reservarClasePrueba` en clase_detalle_screen.dart,
 * portada a Node y usando `lead_id` en vez de `user_id`.
 */
async function reservarClasePruebaLead(leadId, claseId) {
  return admin.firestore().runTransaction(async (transaction) => {
    const claseRef = admin.firestore().collection('clases').doc(claseId);
    const claseDoc = await transaction.get(claseRef);
    if (!claseDoc.exists) throw new Error('Clase no encontrada');

    const claseData = claseDoc.data();
    const cupos = Number(claseData.cupos_disponibles || 0);
    if (cupos <= 0) throw new Error('Sin cupos disponibles');

    transaction.update(claseRef, { cupos_disponibles: cupos - 1 });

    const reservaRef = admin.firestore().collection('reservas').doc();
    transaction.set(reservaRef, {
      lead_id: leadId,
      clase_id: claseId,
      nivel: claseData.nivel || '',
      hora: claseData.hora || '',
      dias: claseData.dias || '',
      status: 'confirmado',
      tipo: 'prueba',
      origen: 'whatsapp',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const leadRef = admin.firestore().collection('whatsapp_leads').doc(leadId);
    transaction.update(leadRef, {
      status: 'reservado',
      clase_reservada_id: claseId,
      reserva_id: reservaRef.id,
    });

    const instructorId = claseData.instructor_id;
    if (instructorId) {
      const instNotifRef = admin.firestore()
        .collection('users').doc(instructorId)
        .collection('notificaciones').doc();
      transaction.set(instNotifRef, {
        titulo: 'Nuevo lead de WhatsApp reservó clase de prueba 🥋',
        mensaje: `Un lead de WhatsApp reservó una clase de prueba de ${claseData.nivel || ''} el ${claseData.hora || ''}.`,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        leido: false,
        tipo: 'bienvenida',
        clase_id: claseId,
      });
    }

    return claseData;
  });
}

/** Toma la primera clase regular con cupos disponibles para ofrecerla como clase de prueba. */
async function buscarClaseDisponibleParaPrueba() {
  const snapshot = await admin.firestore()
    .collection('clases')
    .where('tipo', '==', 'regular')
    .where('cupos_disponibles', '>', 0)
    .limit(1)
    .get();
  if (snapshot.empty) return null;
  return { id: snapshot.docs[0].id, ...snapshot.docs[0].data() };
}

/** Envía un mensaje de texto vía la Graph API de Meta (WhatsApp Cloud API). */
async function enviarMensajeWhatsApp(to, texto) {
  const phoneNumberId = process.env.META_PHONE_NUMBER_ID;
  const token = process.env.META_WHATSAPP_TOKEN;
  const resp = await fetch(`https://graph.facebook.com/v20.0/${phoneNumberId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to,
      type: 'text',
      text: { body: texto },
    }),
  });
  if (!resp.ok) {
    console.error('[WhatsApp] Error enviando mensaje:', await resp.text());
  }
  return resp.ok;
}

/** Llama a OpenAI con el historial reciente de la conversación y la herramienta de reserva. */
async function preguntarIA(historial) {
  const resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      max_tokens: 200,
      messages: [{ role: 'system', content: LEAD_SYSTEM_PROMPT }, ...historial],
      tools: [{
        type: 'function',
        function: {
          name: 'reservar_clase_prueba',
          description: 'Reserva la clase de prueba gratuita para el lead que está escribiendo.',
          parameters: { type: 'object', properties: {}, required: [] },
        },
      }],
    }),
  });
  const data = await resp.json();
  if (data.error) {
    console.error('[OpenAI] Error:', data.error);
    return null;
  }
  return data.choices?.[0]?.message || null;
}

/**
 * Webhook de Meta WhatsApp Cloud API. GET = handshake de verificación,
 * POST = mensajes entrantes de leads (incluye datos de anuncio en `referral`
 * cuando el lead vino de una campaña "Click to WhatsApp").
 */
exports.whatsappWebhook = functions
  .runWith({ secrets: WHATSAPP_SECRETS })
  .https.onRequest(async (req, res) => {
    if (req.method === 'GET') {
      const mode = req.query['hub.mode'];
      const token = req.query['hub.verify_token'];
      const challenge = req.query['hub.challenge'];
      if (mode === 'subscribe' && token === process.env.META_VERIFY_TOKEN) {
        res.status(200).send(challenge);
      } else {
        res.sendStatus(403);
      }
      return;
    }

    if (req.method !== 'POST') {
      res.sendStatus(405);
      return;
    }

    if (!verifyMetaSignature(req)) {
      console.warn('[WhatsApp Webhook] Firma inválida, se descarta el evento.');
      res.sendStatus(401);
      return;
    }

    try {
      const change = req.body.entry?.[0]?.changes?.[0]?.value;
      const message = change?.messages?.[0];
      if (!message || message.type !== 'text') {
        res.sendStatus(200);
        return;
      }

      const telefono = message.from;
      const waMessageId = message.id;
      const texto = message.text.body;
      const referral = message.referral || null;
      const nombreContacto = change.contacts?.[0]?.profile?.name || 'Lead';

      const leadRef = admin.firestore().collection('whatsapp_leads').doc(telefono);
      const dedupRef = leadRef.collection('mensajes').doc(waMessageId);

      const dedupDoc = await dedupRef.get();
      if (dedupDoc.exists) {
        console.log(`[WhatsApp Webhook] Mensaje ${waMessageId} ya procesado, se ignora.`);
        res.sendStatus(200);
        return;
      }

      const leadDoc = await leadRef.get();
      const esLeadNuevo = !leadDoc.exists;

      await leadRef.set({
        telefono,
        nombre: nombreContacto,
        status: esLeadNuevo ? 'nuevo' : (leadDoc.data().status || 'nuevo'),
        origen: referral
          ? { ad_id: referral.source_id || null, source_url: referral.source_url || null }
          : (leadDoc.data()?.origen || null),
        ai_habilitada: esLeadNuevo ? true : leadDoc.data().ai_habilitada !== false,
        ultima_interaccion: admin.firestore.FieldValue.serverTimestamp(),
        created_at: esLeadNuevo ? admin.firestore.FieldValue.serverTimestamp() : leadDoc.data().created_at,
      }, { merge: true });

      await dedupRef.set({
        from: 'lead',
        texto,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        wa_message_id: waMessageId,
      });

      const leadDataActual = (await leadRef.get()).data();

      if (leadDataActual.ai_habilitada === false) {
        console.log(`[WhatsApp Webhook] IA desactivada para ${telefono}, responde el profesor.`);
        res.sendStatus(200);
        return;
      }

      const historialSnapshot = await leadRef.collection('mensajes')
        .orderBy('timestamp', 'desc').limit(10).get();
      const historial = historialSnapshot.docs.reverse().map((d) => {
        const m = d.data();
        return { role: m.from === 'lead' ? 'user' : 'assistant', content: m.texto };
      });

      const respuestaIA = await preguntarIA(historial);
      if (!respuestaIA) {
        res.sendStatus(200);
        return;
      }

      const llamadaHerramienta = respuestaIA.tool_calls?.[0];
      let textoRespuesta = respuestaIA.content;

      if (llamadaHerramienta?.function?.name === 'reservar_clase_prueba') {
        const clase = await buscarClaseDisponibleParaPrueba();
        if (clase) {
          await reservarClasePruebaLead(telefono, clase.id);
          textoRespuesta = `¡Listo! Reservé tu clase de prueba gratuita de ${clase.nivel} el ${clase.dias} a las ${clase.hora}. Te esperamos 🥋`;
        } else {
          textoRespuesta = 'Por ahora no tengo cupos disponibles para la clase de prueba, un instructor te contactará pronto.';
          await leadRef.update({ status: 'conversando' });
        }
      } else if (leadDataActual.status === 'nuevo') {
        await leadRef.update({ status: 'conversando' });
      }

      if (textoRespuesta) {
        await enviarMensajeWhatsApp(telefono, textoRespuesta);
        await leadRef.collection('mensajes').add({
          from: 'ai',
          texto: textoRespuesta,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        await leadRef.update({ ultima_interaccion: admin.firestore.FieldValue.serverTimestamp() });
      }

      res.sendStatus(200);
    } catch (error) {
      console.error('[WhatsApp Webhook] Error procesando el mensaje entrante:', error);
      res.sendStatus(200); // Evita que Meta reintente indefinidamente un evento que ya falló.
    }
  });

/**
 * Callable usada por la pantalla de leads del instructor para responder manualmente
 * por WhatsApp (toma control humano cuando `ai_habilitada` está en false).
 */
exports.sendManualWhatsAppMessage = functions
  .runWith({ secrets: ['META_WHATSAPP_TOKEN', 'META_PHONE_NUMBER_ID'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    const { leadId, texto } = data || {};
    if (!leadId || !texto) {
      throw new functions.https.HttpsError('invalid-argument', 'Falta leadId o texto.');
    }

    const enviado = await enviarMensajeWhatsApp(leadId, texto);
    if (!enviado) {
      throw new functions.https.HttpsError('internal', 'No se pudo enviar el mensaje por WhatsApp.');
    }

    const leadRef = admin.firestore().collection('whatsapp_leads').doc(leadId);
    await leadRef.collection('mensajes').add({
      from: 'profesor',
      texto,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await leadRef.update({ ultima_interaccion: admin.firestore.FieldValue.serverTimestamp() });

    return { success: true };
  });

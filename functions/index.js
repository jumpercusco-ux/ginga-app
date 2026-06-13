const functions = require('firebase-functions');
const admin = require('firebase-admin');
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

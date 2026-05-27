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

      const fcmToken = userDoc.data().fcm_token;
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

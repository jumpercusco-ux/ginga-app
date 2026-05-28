import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Este controlador se ejecuta cuando la aplicación está en segundo plano o cerrada.
  // Nota: Debe ser una función global superior anotada con @pragma('vm:entry-point').
  debugPrint("Mensaje recibido en segundo plano: ${message.messageId}");
  if (message.notification != null) {
    debugPrint("Título: ${message.notification!.title}");
    debugPrint("Cuerpo: ${message.notification!.body}");
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Inicializa los servicios y listeners de notificaciones.
  Future<void> init() async {
    if (_initialized) return;

    // 1. Solicitar permisos de notificación (especialmente para Android 13+ e iOS)
    await requestPermissions();

    // 2. Obtener y guardar el token del dispositivo
    await updateTokenInFirestore();

    // 3. Escuchar la actualización del Token por si cambia en el tiempo
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(newToken);
    });

    // 4. Configurar el listener de mensajes en primer plano (App Abierta)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Mensaje recibido en primer plano: ${message.messageId}");
      
      if (message.notification != null) {
        debugPrint("Notificación recibida en primer plano: ${message.notification!.title}");
        // Aquí se puede lanzar un Snack Bar, banner o alerta visual dentro de la app
      }
    });

    _initialized = true;
  }

  /// Solicita permisos para notificaciones al usuario.
  Future<void> requestPermissions() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Permisos de notificaciones concedidos por el usuario.');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('Permisos provisionales concedidos por el usuario.');
      } else {
        debugPrint('Permisos de notificaciones rechazados o no determinados.');
      }
    } catch (e) {
      debugPrint('Error al solicitar permisos de notificación: $e');
    }
  }

  /// Recupera el Token de FCM actual y lo guarda en Firestore.
  Future<void> updateTokenInFirestore() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error al obtener FCM Token: $e');
    }
  }

  /// Guarda el token en el perfil del usuario autenticado actual.
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('No hay un usuario logueado para guardar el FCM Token.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcm_token': token}, SetOptions(merge: true));
      debugPrint('FCM Token actualizado correctamente en Firestore para el usuario: $uid');
    } catch (e) {
      debugPrint('Error al actualizar FCM Token en Firestore: $e');
    }
  }
}

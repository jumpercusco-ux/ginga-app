import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ginga_app/core/router/app_router.dart';

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

    // 5. Configurar el listener de mensajes pulsados con la App en segundo plano (minimizada)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notificación pulsada (App en segundo plano): ${message.messageId}");
      _handleNotificationRouting(message);
    });

    // 6. Configurar la validación de mensaje inicial si la App estaba totalmente cerrada
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("Notificación pulsada (App cerrada): ${message.messageId}");
        try {
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleNotificationRouting(message);
          });
        } catch (e) {
          debugPrint("Error de navegación en initial message: $e");
        }
      }
    });

    _initialized = true;
  }

  /// Realiza la redirección de navegación táctil dinámica basada en el payload de datos (FCM data o Buzón)
  void _handleNotificationRouting(RemoteMessage message) {
    handleRawNotificationRouting(Map<String, dynamic>.from(message.data));
  }

  /// Procesa y ejecuta el enrutamiento dinámico para cualquier payload de notificación (Push o In-app)
  void handleRawNotificationRouting(Map<String, dynamic> data) {
    debugPrint("Procesando enrutamiento dinámico con data: $data");
    final screen = data['screen'] ?? data['tipo']; // Soporta ambos campos por retrocompatibilidad
    try {
      if (screen == 'profile' || screen == 'mensualidad' || screen == 'membresia') {
        appRouter.go('/profile');
      } else if (screen == 'clase_detalle' || screen == 'clase' || screen == 'evento' || screen == 'bienvenida' || screen == 'recordatorio_prueba') {
        final claseId = data['clase_id'] ?? data['claseId'] ?? data['notificacionId'] ?? '';
        if (claseId.isNotEmpty) {
          appRouter.go('/clase-detalle?claseId=$claseId');
        } else {
          appRouter.go('/home');
        }
      } else if (screen == 'tienda') {
        appRouter.go('/tienda');
      } else if (screen == 'carrito') {
        appRouter.go('/carrito');
      } else if (screen == 'tutorial') {
        final tutorialId = data['tutorial_id'] ?? data['tutorialId'] ?? '';
        if (tutorialId.isNotEmpty) {
          appRouter.go('/tutorial-detail?tutorialId=$tutorialId');
        } else {
          appRouter.go('/home');
        }
      } else if (screen == 'song' || screen == 'cantiga') {
        final songId = data['song_id'] ?? data['songId'] ?? data['cantiga_id'] ?? data['cantigaId'] ?? '';
        if (songId.isNotEmpty) {
          appRouter.go('/song-detail?songId=$songId');
        } else {
          appRouter.go('/home');
        }
      } else if (screen == 'producto' || screen == 'producto_detalle') {
        final prodId = data['producto_id'] ?? data['productoId'] ?? '';
        if (prodId.isNotEmpty) {
          appRouter.go('/producto-detail?productoId=$prodId');
        } else {
          appRouter.go('/tienda');
        }
      } else {
        appRouter.go('/home');
      }
    } catch (e) {
      debugPrint("Error de enrutamiento dinámico: $e");
      // Fallback seguro a la pantalla de Inicio
      try {
        appRouter.go('/home');
      } catch (_) {}
    }
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

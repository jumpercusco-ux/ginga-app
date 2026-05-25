import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/ginga_theme.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Sembrar entreno del Sábado 30 de Mayo si no existe
  await _seedSabado30Mayo();

  // Registrar el controlador de segundo plano de FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GingaApp());
}

Future<void> _seedSabado30Mayo() async {
  try {
    // 1. Sembrar en la colección /clases
    final queryClase = await FirebaseFirestore.instance
        .collection('clases')
        .where('dias', isEqualTo: 'Sábado 30 de Mayo')
        .where('hora', isEqualTo: '2:30 PM - 4:00 PM')
        .get();

    if (queryClase.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('clases').add({
        'hora': '2:30 PM - 4:00 PM',
        'nivel': 'Geral / Todos los niveles',
        'badge': 'Entreno y Roda ☀️',
        'dias': 'Sábado 30 de Mayo',
        'instructor': 'Mestre Sidney',
        'cupos_disponibles': 25,
        'tipo': 'especial',
        'lugar': 'Parque AMAUTA, Urb. Magisterio (El Mapa)',
      });
    }

    // 2. Sembrar en la colección /eventos
    final queryEvento = await FirebaseFirestore.instance
        .collection('eventos')
        .where('fecha_texto', isEqualTo: 'Sábado 30 de Mayo, 2:30 PM - 4:00 PM')
        .get();

    if (queryEvento.docs.isEmpty) {
      // Sábado 30 de Mayo de 2026 de 2:30 PM a 4:00 PM
      final start = DateTime(2026, 5, 30, 14, 30);
      final end = DateTime(2026, 5, 30, 16, 0);

      await FirebaseFirestore.instance.collection('eventos').add({
        'titulo': 'Entreno y Roda al Aire Libre',
        'organizador': 'Mestre Sidney',
        'fecha_inicio': Timestamp.fromDate(start),
        'fecha_fin': Timestamp.fromDate(end),
        'fecha_texto': 'Sábado 30 de Mayo, 2:30 PM - 4:00 PM',
        'lugar': 'Parque AMAUTA, Urb. Magisterio (El Mapa)',
        'descripcion': 'Entrenamiento al aire libre y Roda de integración para toda la Familia FIU. Ven a entrenar, tocar berimbau y jugar en la roda en el tradicional Parque Amauta (Magisterio), también conocido como "El Mapa". ¡Todos los niveles son bienvenidos!',
        'imagen_url': 'assets/images/fiu_banner.png',
        'cronograma': [
          {
            'dia': 'Sábado 30',
            'hora': '2:30 PM',
            'actividad': 'Calentamiento y entrenamiento de técnica física básica/avanzada.'
          },
          {
            'dia': 'Sábado 30',
            'hora': '3:15 PM',
            'actividad': 'Roda de integración, cantos y toques de berimbau.'
          }
        ]
      });
    }
  } catch (e) {
    debugPrint('Error al sembrar evento del 30 de Mayo: $e');
  }
}

class GingaApp extends StatelessWidget {
  const GingaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // Inicializar notificaciones en el siguiente frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.instance.init();
          });
        }

        return MaterialApp.router(
          title: 'Ginga App',
          debugShowCheckedModeBanner: false,
          theme: gingaLightTheme,
          darkTheme: gingaDarkTheme,
          themeMode: ThemeMode.system,
          routerConfig: appRouter,
        );
      },
    );
  }
}

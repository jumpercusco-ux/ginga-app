import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/router/app_router.dart';
import 'core/theme/ginga_theme.dart';
import 'core/theme/theme_manager.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ThemeManager.instance.init();

  // Inicializar Firebase App Check para bloquear accesos no autorizados y bots (solo en móviles por ahora)
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode 
          ? AndroidProvider.debug 
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode 
          ? AppleProvider.debug 
          : AppleProvider.appAttest,
    );
  }

  // Configurar persistencia offline y límite inteligente de caché de Firestore
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: kIsWeb ? null : true, // La persistencia manual no se soporta de esta forma en Web
    cacheSizeBytes: 104857600, // 100 MB de límite para optimizar rendimiento de memoria
  );

  // Registrar el controlador de segundo plano de FCM (solo en móviles)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const GingaApp());
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

        return ListenableBuilder(
          listenable: ThemeManager.instance,
          builder: (context, _) {
            return MaterialApp.router(
              title: 'Ginga',
              debugShowCheckedModeBanner: false,
              theme: gingaLightTheme,
              darkTheme: gingaDarkTheme,
              themeMode: ThemeManager.instance.themeMode,
              routerConfig: appRouter,
            );
          },
        );
      },
    );
  }
}

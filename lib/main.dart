import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/ginga_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/tienda_service.dart';
import 'core/services/tutoriales_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Registrar el controlador de segundo plano de FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Inicializar productos de la tienda si la colección está vacía
  TiendaService.instance.inicializarProductosMockupSiVacia();

  // Inicializar tutoriales de la biblioteca si la colección está vacía
  TutorialesService.instance.inicializarTutorialesMockupSiVacia();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

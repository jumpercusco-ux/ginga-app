import 'package:firebase_core/firebase_core.dart';
import 'package:ginga_app/firebase_options.dart';

enum GingaEnv {
  prod,
  staging,
  emulator,
}

class GingaEnvironment {
  static const String productionProjectId = 'capoeirafiu-ea8ljo';

  static const String _envRaw = String.fromEnvironment(
    'GINGA_ENV',
    defaultValue: 'prod',
  );
  static const String _appCheckWebSiteKey = String.fromEnvironment(
    'GINGA_APP_CHECK_WEB_SITE_KEY',
    defaultValue: '',
  );
  static const bool _useEmulatorFlag = bool.fromEnvironment(
    'GINGA_USE_EMULATOR',
    defaultValue: false,
  );
  static const String _emulatorHostRaw = String.fromEnvironment(
    'GINGA_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const String _firebaseApiKey = String.fromEnvironment(
    'GINGA_FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String _firebaseAppId = String.fromEnvironment(
    'GINGA_FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const String _firebaseMessagingSenderId = String.fromEnvironment(
    'GINGA_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String _firebaseProjectId = String.fromEnvironment(
    'GINGA_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String _firebaseAuthDomain = String.fromEnvironment(
    'GINGA_FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String _firebaseStorageBucket = String.fromEnvironment(
    'GINGA_FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  static GingaEnv parseEnv(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'staging':
        return GingaEnv.staging;
      case 'emulator':
        return GingaEnv.emulator;
      case 'prod':
      case 'production':
      case '':
        return GingaEnv.prod;
      default:
        throw StateError('Entorno GINGA_ENV no reconocido: $raw');
    }
  }

  static GingaEnv get currentEnv => parseEnv(_envRaw);

  static bool get isStaging => currentEnv == GingaEnv.staging;

  static bool get useEmulator =>
      currentEnv == GingaEnv.emulator || _useEmulatorFlag;

  static String get emulatorHost =>
      _emulatorHostRaw.trim().isEmpty ? '127.0.0.1' : _emulatorHostRaw.trim();

  static String get appCheckWebSiteKey => _appCheckWebSiteKey.trim();

  static FirebaseOptions resolveFirebaseOptions({
    String? envOverride,
    String? apiKeyOverride,
    String? appIdOverride,
    String? messagingSenderIdOverride,
    String? projectIdOverride,
    String? authDomainOverride,
    String? storageBucketOverride,
    FirebaseOptions? prodFallback,
  }) {
    final env = parseEnv(envOverride ?? _envRaw);
    if (env == GingaEnv.prod) {
      return prodFallback ?? DefaultFirebaseOptions.currentPlatform;
    }

    final projectId = (projectIdOverride ?? _firebaseProjectId).trim();
    if (env == GingaEnv.staging) {
      if (projectId == productionProjectId) {
        throw StateError(
          'BLOQUEADO: GINGA_ENV=staging no puede apuntar al proyecto productivo $productionProjectId.',
        );
      }
      final apiKey = (apiKeyOverride ?? _firebaseApiKey).trim();
      final appId = (appIdOverride ?? _firebaseAppId).trim();
      final senderId =
          (messagingSenderIdOverride ?? _firebaseMessagingSenderId).trim();
      if (projectId.isEmpty ||
          apiKey.isEmpty ||
          appId.isEmpty ||
          senderId.isEmpty) {
        throw StateError(
          'Faltan variables --dart-define de Firebase para GINGA_ENV=staging '
          '(GINGA_FIREBASE_PROJECT_ID, API_KEY, APP_ID, MESSAGING_SENDER_ID).',
        );
      }
      final authDomain = (authDomainOverride ?? _firebaseAuthDomain).trim();
      final storageBucket =
          (storageBucketOverride ?? _firebaseStorageBucket).trim();
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        authDomain:
            authDomain.isNotEmpty ? authDomain : '$projectId.firebaseapp.com',
        storageBucket: storageBucket.isNotEmpty
            ? storageBucket
            : '$projectId.firebasestorage.app',
      );
    }

    // GingaEnv.emulator: proyecto sintético aislado (demo-ginga-test por defecto)
    final emuProjectId =
        projectId.isEmpty ? 'demo-ginga-test' : projectId;
    if (emuProjectId == productionProjectId) {
      throw StateError(
        'BLOQUEADO: GINGA_ENV=emulator no puede usar $productionProjectId.',
      );
    }
    return FirebaseOptions(
      apiKey: (apiKeyOverride ?? _firebaseApiKey).trim().isNotEmpty
          ? (apiKeyOverride ?? _firebaseApiKey).trim()
          : 'demo-emulator-api-key',
      appId: (appIdOverride ?? _firebaseAppId).trim().isNotEmpty
          ? (appIdOverride ?? _firebaseAppId).trim()
          : '1:000000000000:web:demo-ginga-test',
      messagingSenderId:
          (messagingSenderIdOverride ?? _firebaseMessagingSenderId)
                  .trim()
                  .isNotEmpty
              ? (messagingSenderIdOverride ?? _firebaseMessagingSenderId).trim()
              : '000000000000',
      projectId: emuProjectId,
      authDomain: '$emuProjectId.firebaseapp.com',
      storageBucket: '$emuProjectId.firebasestorage.app',
    );
  }
}

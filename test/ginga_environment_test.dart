import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/config/ginga_environment.dart';

void main() {
  group('GingaEnvironment (PED-06B)', () {
    const fakeProd = FirebaseOptions(
      apiKey: 'fake-prod-key',
      appId: '1:1:web:prod',
      messagingSenderId: '1',
      projectId: GingaEnvironment.productionProjectId,
    );

    test('default prod devuelve fallback sin error', () {
      expect(GingaEnvironment.parseEnv('prod'), GingaEnv.prod);
      expect(GingaEnvironment.parseEnv(''), GingaEnv.prod);
      final opts = GingaEnvironment.resolveFirebaseOptions(
        envOverride: 'prod',
        prodFallback: fakeProd,
      );
      expect(opts.projectId, GingaEnvironment.productionProjectId);
    });

    test('staging bloquea cualquier intento de usar proyecto productivo', () {
      expect(
        () => GingaEnvironment.resolveFirebaseOptions(
          envOverride: 'staging',
          projectIdOverride: GingaEnvironment.productionProjectId,
          apiKeyOverride: 'key',
          appIdOverride: 'app',
          messagingSenderIdOverride: '123',
        ),
        throwsStateError,
      );
    });

    test('staging resuelve opciones completas cuando las variables están definidas', () {
      final opts = GingaEnvironment.resolveFirebaseOptions(
        envOverride: 'staging',
        projectIdOverride: 'ginga-staging',
        apiKeyOverride: 'staging-key',
        appIdOverride: '1:99:web:stg',
        messagingSenderIdOverride: '99',
      );
      expect(opts.projectId, 'ginga-staging');
      expect(opts.authDomain, 'ginga-staging.firebaseapp.com');
      expect(opts.storageBucket, 'ginga-staging.firebasestorage.app');
    });

    test('staging falla si faltan credenciales explícitas', () {
      expect(
        () => GingaEnvironment.resolveFirebaseOptions(
          envOverride: 'staging',
          projectIdOverride: 'ginga-staging',
        ),
        throwsStateError,
      );
    });

    test('emulator usa demo-ginga-test por defecto y bloquea proyecto productivo', () {
      final opts = GingaEnvironment.resolveFirebaseOptions(envOverride: 'emulator');
      expect(opts.projectId, 'demo-ginga-test');
      expect(
        () => GingaEnvironment.resolveFirebaseOptions(
          envOverride: 'emulator',
          projectIdOverride: GingaEnvironment.productionProjectId,
        ),
        throwsStateError,
      );
    });
  });
}

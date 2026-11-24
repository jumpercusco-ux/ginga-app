import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/theme/theme_manager.dart';
import 'package:ginga_app/features/biblioteca/biblioteca_screen.dart';
import 'package:ginga_app/features/biblioteca/curriculo_biblioteca_screen.dart';
import 'package:ginga_app/features/biblioteca/movimiento_detalle_screen.dart';
import 'package:ginga_app/features/biblioteca/widgets/biblioteca_user_context.dart';
import 'package:ginga_app/main_biblioteca_preview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _artifactDir =
    '/Users/jumper/.gemini/antigravity/brain/b880a352-db90-427f-a3c4-b19d21360d08';
const String _fontDir =
    '/Users/jumper/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _installOfflineFontsAndMockManifest(WidgetTester tester) async {
  final dir = Directory(_fontDir);
  if (!dir.existsSync()) return;

  final iconsFile = File('$_fontDir/MaterialIcons-Regular.otf');
  if (iconsFile.existsSync()) {
    final loader = FontLoader('MaterialIcons');
    loader.addFont(
        Future.value(ByteData.sublistView(iconsFile.readAsBytesSync())));
    await loader.load();
  }

  final variantToFile = <String, String>{
    'Montserrat-Light.ttf': '$_fontDir/Roboto-Light.ttf',
    'Montserrat-Regular.ttf': '$_fontDir/Roboto-Regular.ttf',
    'Montserrat-Medium.ttf': '$_fontDir/Roboto-Medium.ttf',
    'Montserrat-SemiBold.ttf': '$_fontDir/Roboto-Medium.ttf',
    'Montserrat-Bold.ttf': '$_fontDir/Roboto-Bold.ttf',
    'Montserrat-ExtraBold.ttf': '$_fontDir/Roboto-Black.ttf',
    'Montserrat-Black.ttf': '$_fontDir/Roboto-Black.ttf',
    'Montserrat-Italic.ttf': '$_fontDir/Roboto-Italic.ttf',
    'Montserrat-MediumItalic.ttf': '$_fontDir/Roboto-MediumItalic.ttf',
    'Montserrat-SemiBoldItalic.ttf': '$_fontDir/Roboto-MediumItalic.ttf',
    'Montserrat-BoldItalic.ttf': '$_fontDir/Roboto-BoldItalic.ttf',
  };

  final fontBytesMap = <String, ByteData>{};
  final robotoLoader = FontLoader('Roboto');
  for (final entry in variantToFile.entries) {
    final f = File(entry.value);
    if (f.existsSync()) {
      final bytes = ByteData.sublistView(f.readAsBytesSync());
      fontBytesMap[entry.key] = bytes;
      robotoLoader.addFont(Future.value(bytes));
    }
  }
  await robotoLoader.load();

  final manifestMap = {
    for (final name in fontBytesMap.keys) name: [name],
  };
  final manifestBytes = ByteData.sublistView(
    Uint8List.fromList(utf8.encode(json.encode(manifestMap))),
  );
  final manifestBinMap = <Object?, Object?>{
    for (final name in fontBytesMap.keys)
      name: <Object?>[
        <Object?, Object?>{'asset': name},
      ],
  };
  final manifestBinBytes =
      const StandardMessageCodec().encodeMessage(manifestBinMap);

  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(
        message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
      );
      if (key == 'AssetManifest.json') {
        return manifestBytes;
      }
      if (key == 'AssetManifest.bin') {
        return manifestBinBytes;
      }
      if (fontBytesMap.containsKey(key)) {
        return fontBytesMap[key];
      }
      return null;
    },
  );
}

Future<void> _captureToFile(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String filename,
) async {
  final boundary = boundaryKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final outDir = Directory(_artifactDir);
  if (outDir.existsSync() && bytes != null) {
    File('$_artifactDir/$filename').writeAsBytesSync(bytes);
  }
}

void main() {
  final enabled = Platform.environment['GENERATE_PED03B_SCREENSHOTS'] == '1';

  testWidgets('Captura visual responsive PED-03B (Móvil, Tablet, Escritorio)',
      (tester) async {
    if (!enabled) {
      return;
    }

    GoogleFonts.config.allowRuntimeFetching = false;
    await _installOfflineFontsAndMockManifest(tester);

    final raw = File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
    final ds = InMemoryCurriculumDataSource.fromCatalogJson(
        json.decode(raw) as Map<String, dynamic>);
    final repository = CurriculumRepository(dataSource: ds);

    Future<void> renderAndSave(
        Size size, Widget child, String filename) async {
      await tester.binding.setSurfaceSize(size);
      tester.view.devicePixelRatio = 1.0;
      final key = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
            home: RepaintBoundary(key: key, child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureToFile(tester, key, filename);
    }

    // 1. Móvil Hub Alumno (Crua e Verde)
    await renderAndSave(
      const Size(390, 844),
      BibliotecaScreen(
        repository: repository,
        overrideUserContext: const BibliotecaUserContext(
          role: 'alumno',
          cordaName: 'Crua e Verde',
          displayName: 'Alumno FIU',
        ),
      ),
      'ped03b_mobile_hub_alumno.png',
    );

    // 2. Móvil Bloque Compartido 5-6
    await renderAndSave(
      const Size(390, 844),
      CurriculoBibliotecaScreen(
        repository: repository,
        overrideUserContext: const BibliotecaUserContext(
          role: 'alumno',
          cordaName: 'Laranja',
        ),
        initialCordaIndex: 5,
      ),
      'ped03b_mobile_curriculo_bloque56.png',
    );

    // 3. Móvil Ficha de Movimiento (Cocorinha con video real + glosario)
    final cocorinha = (await repository.getMovementById('cocorinha'))!;
    await renderAndSave(
      const Size(390, 844),
      MovimientoDetalleScreen(
        movement: cocorinha,
        repository: repository,
        userContext: const BibliotecaUserContext(
          role: 'alumno',
          cordaName: 'Crua',
        ),
      ),
      'ped03b_mobile_movimiento_detalle.png',
    );

    // 4. Tablet Repertorio Acumulado
    await renderAndSave(
      const Size(834, 1194),
      CurriculoBibliotecaScreen(
        repository: repository,
        overrideUserContext: const BibliotecaUserContext(
          role: 'alumno',
          cordaName: 'Verde',
        ),
        initialCordaIndex: 3,
        initialCumulativeMode: true,
      ),
      'ped03b_tablet_curriculo_acumulado.png',
    );

    // 5. Escritorio 3 Columnas Profesor (Corda Azul)
    await renderAndSave(
      const Size(1440, 900),
      CurriculoBibliotecaScreen(
        repository: repository,
        overrideUserContext: const BibliotecaUserContext(
          role: 'profesor',
          cordaName: 'Azul',
          displayName: 'Prof. FIU',
        ),
        initialCordaIndex: 4,
        initialMovementId: 'vingativa',
      ),
      'ped03b_desktop_curriculo_profesor.png',
    );

    await tester.binding.setSurfaceSize(null);
    tester.binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  final uxEnabled =
      Platform.environment['GENERATE_PED03B_UX_SCREENSHOTS'] == '1';

  testWidgets(
      'Captura visual PED-03B-UX (Claro y Oscuro a 945x930 y 1440x900)',
      (tester) async {
    if (!uxEnabled) {
      return;
    }

    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await _installOfflineFontsAndMockManifest(tester);

    final raw = File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
    final ds = InMemoryCurriculumDataSource.fromCatalogJson(
        json.decode(raw) as Map<String, dynamic>);

    Future<void> capturePreview({
      required String keyId,
      required Size size,
      required ThemeMode themeMode,
      required PreviewScenario scenario,
      required String filename,
    }) async {
      await ThemeManager.instance.setThemeMode(themeMode);
      await tester.binding.setSurfaceSize(size);
      tester.view.devicePixelRatio = 1.0;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: RepaintBoundary(
            key: boundaryKey,
            child: BibliotecaPreviewApp(
              key: ValueKey(keyId),
              initialDataSource: ds,
              initialScenario: scenario,
              initialProfileIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureToFile(tester, boundaryKey, filename);
    }

    addTearDown(() async {
      SharedPreferences.setMockInitialValues({});
      await ThemeManager.instance.setThemeMode(ThemeMode.light);
      await tester.binding.setSurfaceSize(null);
      tester.binding.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    await capturePreview(
      keyId: 'ux_light_hub',
      size: const Size(945, 930),
      themeMode: ThemeMode.light,
      scenario: PreviewScenario.hub,
      filename: 'ped03b_ux_945x930_light_hub.png',
    );
    await capturePreview(
      keyId: 'ux_dark_hub',
      size: const Size(945, 930),
      themeMode: ThemeMode.dark,
      scenario: PreviewScenario.hub,
      filename: 'ped03b_ux_945x930_dark_hub.png',
    );
    await capturePreview(
      keyId: 'ux_light_bloque56',
      size: const Size(945, 930),
      themeMode: ThemeMode.light,
      scenario: PreviewScenario.block56,
      filename: 'ped03b_ux_945x930_light_bloque56.png',
    );
    await capturePreview(
      keyId: 'ux_dark_bloque56',
      size: const Size(945, 930),
      themeMode: ThemeMode.dark,
      scenario: PreviewScenario.block56,
      filename: 'ped03b_ux_945x930_dark_bloque56.png',
    );
    await capturePreview(
      keyId: 'ux_light_desktop',
      size: const Size(1440, 900),
      themeMode: ThemeMode.light,
      scenario: PreviewScenario.block56,
      filename: 'ped03b_ux_1440x900_light_desktop.png',
    );
    await capturePreview(
      keyId: 'ux_dark_desktop',
      size: const Size(1440, 900),
      themeMode: ThemeMode.dark,
      scenario: PreviewScenario.block56,
      filename: 'ped03b_ux_1440x900_dark_desktop.png',
    );
    await capturePreview(
      keyId: 'ux_dark_desktop_acumulado',
      size: const Size(1440, 900),
      themeMode: ThemeMode.dark,
      scenario: PreviewScenario.accumulated,
      filename: 'ped03b_ux_1440x900_dark_acumulado.png',
    );
  });
}

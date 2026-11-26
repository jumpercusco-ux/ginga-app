import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/core/theme/theme_manager.dart';
import 'package:ginga_app/features/instructor/instructor_pizarra_screen.dart';
import 'package:ginga_app/features/instructor/planificador/models/class_plan_models.dart';
import 'package:ginga_app/features/instructor/planificador/services/live_session_persistence.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_data_source.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _artifactDir =
    '/Users/jumper/.gemini/antigravity/brain/9c2a4112-154f-45ac-b5d7-f751e848734d';
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
  final montserratLoader = FontLoader('Montserrat');
  for (final entry in variantToFile.entries) {
    final f = File(entry.value);
    if (f.existsSync()) {
      final bytes = ByteData.sublistView(f.readAsBytesSync());
      fontBytesMap[entry.key] = bytes;
      robotoLoader.addFont(Future.value(bytes));
      montserratLoader.addFont(Future.value(bytes));
    }
  }
  await robotoLoader.load();
  await montserratLoader.load();

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
      if (key == 'AssetManifest.json') return manifestBytes;
      if (key == 'AssetManifest.bin') return manifestBinBytes;
      if (fontBytesMap.containsKey(key)) return fontBytesMap[key];
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
  final enabled = Platform.environment['GENERATE_PED04C1_SCREENSHOTS'] == '1';

  testWidgets('Captura visual PED-04C1 escritorio, tablet y móvil claro/oscuro',
      (tester) async {
    if (!enabled) return;

    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await _installOfflineFontsAndMockManifest(tester);

    final raw = File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
    final ds = InMemoryCurriculumDataSource.fromJsonString(raw);
    final repository = CurriculumRepository(dataSource: ds);

    Future<void> renderAndSave({
      required Size size,
      required ThemeMode themeMode,
      required String filename,
      Future<void> Function()? afterPump,
    }) async {
      await ThemeManager.instance.setThemeMode(themeMode);
      await tester.binding.setSurfaceSize(size);
      tester.view.devicePixelRatio = 1.0;
      final key = GlobalKey();
      final plannerDs = InMemoryPlannerDataSource.demoFixtures();
      final storage = InMemoryLiveSessionStorage();
      var fakeNow = DateTime(2026, 11, 26, 19, 0, 0);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              key: ValueKey('cap_live_${filename}_${themeMode.name}'),
              debugShowCheckedModeBanner: false,
              theme: gingaLightTheme,
              darkTheme: gingaDarkTheme,
              themeMode: themeMode,
              home: InstructorPizarraScreen(
                dataSource: plannerDs,
                curriculumRepository: repository,
                liveSessionStorage: storage,
                initialLivePlanId: 'v2_plan_adulto_01',
                clock: () => fakeNow,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simula 4 minutos de clase transcurridos para mostrar reloj activo realista
      fakeNow = fakeNow.add(const Duration(minutes: 4, seconds: 15));
      if (afterPump != null) {
        await afterPump();
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }

      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      await _captureToFile(tester, key, filename);
      await tester.pumpWidget(const SizedBox.shrink());
    }

    // 1. Desktop claro (1440x900) - En Vivo ejercicio 2 con "Ver todos los niveles" activo
    await renderAndSave(
      size: const Size(1440, 900),
      themeMode: ThemeMode.light,
      filename: 'ped04c1_desktop_light_live.png',
      afterPump: () async {
        await tester.tap(find.byKey(const Key('live_complete_next_btn')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('live_variant_all_btn')));
        await tester.tap(find.byKey(const Key('live_variant_all_btn')));
      },
    );

    // 2. Desktop oscuro (1440x900) - En Vivo ejercicio 1 (con recurso de Pizarra vinculado)
    await renderAndSave(
      size: const Size(1440, 900),
      themeMode: ThemeMode.dark,
      filename: 'ped04c1_desktop_dark_live.png',
    );

    // 3. Tablet claro (834x1024) - En Vivo ejercicio 2
    await renderAndSave(
      size: const Size(834, 1024),
      themeMode: ThemeMode.light,
      filename: 'ped04c1_tablet_light_live.png',
      afterPump: () async {
        await tester.tap(find.byKey(const Key('live_complete_next_btn')));
      },
    );

    // 4. Tablet oscuro (834x1024) - Formulario de cierre anticipado
    await renderAndSave(
      size: const Size(834, 1024),
      themeMode: ThemeMode.dark,
      filename: 'ped04c1_tablet_dark_closure.png',
      afterPump: () async {
        await tester.tap(find.byKey(const Key('live_complete_next_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('live_finish_btn')));
      },
    );

    // 5. Móvil oscuro (390x844) - En Vivo ejercicio 2 con todos los niveles visibles
    await renderAndSave(
      size: const Size(390, 844),
      themeMode: ThemeMode.dark,
      filename: 'ped04c1_mobile_dark_live.png',
      afterPump: () async {
        await tester.tap(find.byKey(const Key('live_complete_next_btn')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('live_variant_all_btn')));
        await tester.tap(find.byKey(const Key('live_variant_all_btn')));
      },
    );

    // 6. Móvil claro (390x844) - Preparar siguiente clase con contexto estructurado expandido
    await ThemeManager.instance.setThemeMode(ThemeMode.light);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1.0;
    final prepKey = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: RepaintBoundary(
          key: prepKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: gingaLightTheme,
            home: InstructorPizarraScreen(
              dataSource: InMemoryPlannerDataSource.demoFixtures(),
              curriculumRepository: repository,
              initialCreationMode: PlannerCreationMode.quick,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const Key('continuity_context_toggle')));
    await tester.tap(find.byKey(const Key('continuity_context_toggle')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    await _captureToFile(tester, prepKey, 'ped04c1_mobile_light_history.png');
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
}

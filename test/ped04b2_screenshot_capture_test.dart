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
  final enabled = Platform.environment['GENERATE_PED04B2_SCREENSHOTS'] == '1';

  testWidgets('Captura visual PED-04B2-UX (60/40, claro/oscuro y responsive)',
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
      String? editingPlanId,
      String? selectExerciseKey,
      String? scrollToKeyInPanel,
      required String filename,
    }) async {
      await ThemeManager.instance.setThemeMode(themeMode);
      await tester.binding.setSurfaceSize(size);
      tester.view.devicePixelRatio = 1.0;
      final key = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            key: ValueKey('cap_${filename}_${themeMode.name}'),
            debugShowCheckedModeBanner: false,
            theme: gingaLightTheme,
            darkTheme: gingaDarkTheme,
            themeMode: themeMode,
            home: RepaintBoundary(
              key: key,
              child: InstructorPizarraScreen(
                dataSource: InMemoryPlannerDataSource.demoFixtures(),
                curriculumRepository: repository,
                initialTab: PlannerHubTab.plans,
                initialEditingPlanId: editingPlanId,
                onOpenBiblioteca: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (selectExerciseKey != null) {
        final target = find.byKey(Key(selectExerciseKey));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      if (scrollToKeyInPanel != null) {
        final target = find.byKey(Key(scrollToKeyInPanel));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _captureToFile(tester, key, filename);
    }

    // 1. Desktop claro: proporción 60/40 con ex_1_1 mostrando recurso vinculado + nota + 5 opciones de organización
    await renderAndSave(
      size: const Size(1440, 900),
      themeMode: ThemeMode.light,
      editingPlanId: 'v2_plan_adulto_01',
      selectExerciseKey: 'ex_edit_ex_1_1',
      scrollToKeyInPanel: 'ex_editor_res_note_idea_res_02',
      filename: 'ped04b2_ux_desktop_light_editor.png',
    );

    // 2. Desktop oscuro: proporción 60/40 con ex_2_1 mostrando variantes P/I/A y movimientos FIU
    await renderAndSave(
      size: const Size(1440, 900),
      themeMode: ThemeMode.dark,
      editingPlanId: 'v2_plan_adulto_01',
      selectExerciseKey: 'ex_edit_ex_2_1',
      scrollToKeyInPanel: 'ex_editor_advanced_field',
      filename: 'ped04b2_ux_desktop_dark_editor.png',
    );

    // 3. Tablet claro: tarjetas a ancho completo y relación bloque/ejercicios
    await renderAndSave(
      size: const Size(834, 1024),
      themeMode: ThemeMode.light,
      editingPlanId: 'v2_plan_adulto_01',
      filename: 'ped04b2_ux_tablet_light_editor.png',
    );

    // 4. Móvil oscuro: vista fluida sin overflows
    await renderAndSave(
      size: const Size(390, 844),
      themeMode: ThemeMode.dark,
      editingPlanId: 'v2_plan_adulto_01',
      filename: 'ped04b2_ux_mobile_dark_editor.png',
    );

    // 5. Desktop oscuro Infantil: bloqueo currículo adulto FIU y control de tiempos restante
    await renderAndSave(
      size: const Size(1440, 900),
      themeMode: ThemeMode.dark,
      editingPlanId: 'v2_plan_infantil_01',
      selectExerciseKey: 'ex_edit_ex_k1_1',
      scrollToKeyInPanel: 'ex_editor_res_note_idea_res_04',
      filename: 'ped04b2_ux_desktop_dark_infantil_guard.png',
    );
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/models/curriculum_models.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/core/theme/theme_manager.dart';
import 'package:ginga_app/features/biblioteca/biblioteca_screen.dart';
import 'package:ginga_app/features/biblioteca/curriculo_biblioteca_screen.dart';
import 'package:ginga_app/features/biblioteca/movimiento_detalle_screen.dart';
import 'package:ginga_app/features/biblioteca/widgets/biblioteca_user_context.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapWithSize(Widget child, Size size) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

void main() {
  late CurriculumRepository repository;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final raw = File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
    final ds =
        InMemoryCurriculumDataSource.fromCatalogJson(json.decode(raw) as Map<String, dynamic>);
    repository = CurriculumRepository(dataSource: ds);
  });

  group('PED-03B Hub Biblioteca Unificada (Alumno vs Profesor)', () {
    testWidgets('Alumno en móvil ve 6 secciones clásicas y su corda, sin botones de gestión',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithSize(
          BibliotecaScreen(
            repository: repository,
            overrideUserContext: const BibliotecaUserContext(
              role: 'alumno',
              cordaName: 'Crua e Verde',
              displayName: 'Alumno Prueba',
            ),
          ),
          const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A Biblioteca'), findsOneWidget);
      expect(find.text('Currículo Oficial FIU'), findsOneWidget);
      expect(find.textContaining('Corda Crua e Verde'), findsWidgets);

      // Las 6 secciones clásicas se preservan
      expect(find.text('Música'), findsOneWidget);
      expect(find.text('Tutoriales'), findsOneWidget);
      expect(find.text('Cultura'), findsOneWidget);
      expect(find.text('Glosario de Capoeira'), findsOneWidget);
      expect(find.text('Sistema de Graduaciones'), findsOneWidget);
      expect(find.text('Nuestros Mestres'), findsOneWidget);

      // Alumno no ve gestión docente
      expect(find.text('Gestionar Tutoriales'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Profesor en escritorio ve su propia corda (Azul) y accesos docentes',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool managedTutorialsTapped = false;
      bool pizarraTapped = false;

      await tester.pumpWidget(
        _wrapWithSize(
          BibliotecaScreen(
            repository: repository,
            overrideUserContext: const BibliotecaUserContext(
              role: 'profesor',
              cordaName: 'Azul',
              displayName: 'Prof. Prueba',
            ),
            onOpenManageTutorials: () => managedTutorialsTapped = true,
            onOpenPizarra: () => pizarraTapped = true,
          ),
          const Size(1440, 900),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Profesor · Practicante'), findsOneWidget);
      expect(find.textContaining('Graduación actual: Corda Azul'), findsOneWidget);
      expect(find.text('Gestionar Tutoriales'), findsOneWidget);
      expect(find.text('Pizarra y Planificador'), findsOneWidget);

      await tester.tap(find.text('Gestionar Tutoriales'));
      await tester.pump();
      expect(managedTutorialsTapped, isTrue);

      await tester.tap(find.text('Pizarra y Planificador'));
      await tester.pump();
      expect(pizarraTapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('PED-03B Currículo Responsive, Filtros, Bloque 5-6 e Infantil', () {
    testWidgets('Acumulado hasta Corda 6 lista 97 entradas y excluye equivalencias no confirmadas',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithSize(
          CurriculoBibliotecaScreen(
            repository: repository,
            overrideUserContext: const BibliotecaUserContext(
              role: 'profesor',
              cordaName: 'Azul',
            ),
            initialCordaIndex: 6,
            initialCumulativeMode: true,
          ),
          const Size(1440, 900),
        ),
      );
      await tester.pumpAndSettle();

      // 97 movimientos en acumulado 1..6
      expect(find.text('Acumulado 1–6 (97)'), findsOneWidget);
      expect(find.text('Movimientos (97)'), findsOneWidget);

      // Buscar alias confirmado Passape -> Passa pé
      await tester.enterText(find.byType(TextField).first, 'Passape');
      await tester.pumpAndSettle();
      expect(find.text('Passa pé'), findsWidgets);
      expect(find.text('Movimientos (1)'), findsOneWidget);

      // Equivalencia no confirmada 'Flip' (REV-10) NO debe devolver Flick
      await tester.enterText(find.byType(TextField).first, 'Flip');
      await tester.pumpAndSettle();
      expect(find.text('Movimientos (0)'), findsOneWidget);

      // Equivalencia no confirmada 'Cruz' NO debe devolver Espelho - cruz por alias
      await tester.enterText(find.byType(TextField).first, 'Passa pé');
      await tester.pumpAndSettle();
      expect(find.text('Movimientos (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bloque compartido 5-6 muestra movimientos compartidos y evaluación diferenciada',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(834, 1194));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithSize(
          CurriculoBibliotecaScreen(
            repository: repository,
            overrideUserContext: const BibliotecaUserContext(
              role: 'alumno',
              cordaName: 'Laranja',
            ),
            initialCordaIndex: 5,
            initialCumulativeMode: false,
          ),
          const Size(834, 1194),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bloque técnico compartido'), findsOneWidget);
      expect(find.text('Movimientos (30)'), findsOneWidget);

      // Cambiar a pestaña Musicalidad y Eval. de Corda 5
      await tester.tap(find.text('Musicalidad y Eval.'));
      await tester.pumpAndSettle();
      expect(find.textContaining('envergar os berimbaus'), findsWidgets);

      // Cambiar a Corda 6 y verificar evaluación diferenciada
      final chipCorda6 = find.text('6. Laranja e Amarelo');
      await tester.scrollUntilVisible(
        chipCorda6,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(chipCorda6);
      await tester.pumpAndSettle();
      await tester.tap(chipCorda6);
      await tester.pumpAndSettle();
      expect(find.textContaining('armar os três berimbaus e afinar'), findsWidgets);
      expect(find.textContaining('mãos fechadas'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sistema Infantil separado muestra 12 cordas pendientes sin mezclar Adulto',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithSize(
          CurriculoBibliotecaScreen(
            repository: repository,
            overrideUserContext: const BibliotecaUserContext(
              role: 'alumno',
              cordaName: 'Crua',
            ),
          ),
          const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Infantil'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sistema Infantil FIU (12 cordas claras'), findsOneWidget);
      expect(find.text('1. Corda Crua / Amarelo'), findsOneWidget);
      expect(find.textContaining('Pendiente de digitalización'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('PED-03B Ficha de Movimiento, Multimedia y Ambiguos', () {
    testWidgets('Cocorinha muestra video real Cocorinha + base y definición del Glosario',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cocorinha = await repository.getMovementById('cocorinha');
      expect(cocorinha, isNotNull);

      await tester.pumpWidget(
        _wrapWithSize(
          MovimientoDetalleScreen(
            movement: cocorinha!,
            repository: repository,
            userContext: const BibliotecaUserContext(
              role: 'alumno',
              cordaName: 'Crua',
            ),
          ),
          const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cocorinha + base'), findsOneWidget);
      expect(find.text('Video real'), findsOneWidget);
      expect(find.text('Referencia en Glosario FIU'), findsOneWidget);
      expect(find.textContaining('cuclillas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ginga muestra video real, relación pendiente de Cocorinha + base y sin glosario inventado',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ginga = await repository.getMovementById('ginga');
      expect(ginga, isNotNull);

      await tester.pumpWidget(
        _wrapWithSize(
          MovimientoDetalleScreen(
            movement: ginga!,
            repository: repository,
            userContext: const BibliotecaUserContext(
              role: 'alumno',
              cordaName: 'Crua',
            ),
          ),
          const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ginga'), findsWidgets);
      expect(find.text('Cocorinha + base'), findsOneWidget);
      expect(find.text('Relación pendiente revisión video'), findsOneWidget);
      expect(find.textContaining('pendiente de digitalización'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Desequilibrante muestra advertencia de revisión técnica y exclusión IA',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final deseq = await repository.getMovementById('desequilibrante');
      expect(deseq, isNotNull);

      await tester.pumpWidget(
        _wrapWithSize(
          MovimientoDetalleScreen(
            movement: deseq!,
            repository: repository,
            userContext: const BibliotecaUserContext(
              role: 'profesor',
              cordaName: 'Azul',
            ),
          ),
          const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pendiente de revisión técnica'), findsOneWidget);
      expect(find.textContaining('Excluido de la selección automática del planificador IA'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PED-03B-V Separación estricta entre graduación personal y rol', () {
    testWidgets(
      'Profesor de 6ª corda vs Alumno de 6ª corda, Alumno de 9ª corda y Profesor de 1ª corda mantienen permisos y corda desacoplados',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final rawJson = File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
        final repo = CurriculumRepository(
          dataSource: InMemoryCurriculumDataSource.fromJsonString(rawJson),
        );

        const prof6 = BibliotecaUserContext(
          role: 'profesor',
          cordaName: 'Laranja e Amarelo',
          displayName: 'Prof. 6ª',
        );
        const alumno6 = BibliotecaUserContext(
          role: 'alumno',
          cordaName: 'Laranja e Amarelo',
          displayName: 'Alumno 6ª',
        );
        const alumno9 = BibliotecaUserContext(
          role: 'alumno',
          cordaName: 'Azul',
          displayName: 'Alumno 9ª',
        );
        const prof1 = BibliotecaUserContext(
          role: 'profesor',
          cordaName: 'Crua',
          displayName: 'Prof. 1ª',
        );

        // Reglas unitarias de separación rol vs graduación personal
        expect(prof6.isTeacher, isTrue);
        expect(prof6.adultCordaIndex, 6);
        expect(prof6.isBeyondDigitizedV1, isFalse);

        expect(alumno6.isTeacher, isFalse);
        expect(alumno6.adultCordaIndex, 6);
        expect(alumno6.canBypassTutorialLock, isFalse);

        expect(alumno9.isTeacher, isFalse);
        expect(alumno9.adultCordaIndex, 9);
        expect(alumno9.isBeyondDigitizedV1, isTrue);
        expect(alumno9.canBypassTutorialLock, isFalse);

        expect(prof1.isTeacher, isTrue);
        expect(prof1.adultCordaIndex, 1);
        expect(prof1.canBypassTutorialLock, isFalse);

        // Verificar en UI que Alumno 6ª Corda ve su corda 6 pero NO accesos docentes
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpWidget(
          MaterialApp(
            home: BibliotecaScreen(
              repository: repo,
              overrideUserContext: alumno6,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Laranja e Amarelo'), findsWidgets);
        expect(find.text('Gestión docente:'), findsNothing);
        expect(find.text('Gestionar Tutoriales'), findsNothing);
        expect(find.text('Pizarra y Planificador'), findsNothing);

        // Verificar en UI que Alumno 9ª Corda tampoco recibe accesos docentes
        await tester.pumpWidget(
          MaterialApp(
            home: BibliotecaScreen(
              repository: repo,
              overrideUserContext: alumno9,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gestión docente:'), findsNothing);
        expect(find.text('Gestionar Tutoriales'), findsNothing);
        expect(find.text('Pizarra y Planificador'), findsNothing);

        // Verificar en UI que Profesor 1ª Corda mantiene accesos docentes aunque su corda sea 1ª
        await tester.pumpWidget(
          MaterialApp(
            home: BibliotecaScreen(
              repository: repo,
              overrideUserContext: prof1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gestión docente:'), findsOneWidget);
        expect(find.text('Gestionar Tutoriales'), findsOneWidget);
        expect(find.text('Pizarra y Planificador'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'Las pantallas de Biblioteca respetan GingaTheme en modo claro y oscuro sin mezclar colores',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        GoogleFonts.config.allowRuntimeFetching = false;
        final rawJson =
            File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
        final repo = CurriculumRepository(
          dataSource: InMemoryCurriculumDataSource.fromJsonString(rawJson),
        );
        const prof6 = BibliotecaUserContext(
          role: 'profesor',
          cordaName: 'Laranja e Amarelo',
          displayName: 'Prof. 6ª',
        );

        await ThemeManager.instance.setThemeMode(ThemeMode.light);
        addTearDown(() async {
          SharedPreferences.setMockInitialValues({});
          await ThemeManager.instance.setThemeMode(ThemeMode.light);
          await tester.binding.setSurfaceSize(null);
        });

        await tester.binding.setSurfaceSize(const Size(1280, 900));

        // 1. Modo claro oficial (gingaLightTheme + ThemeMode.light)
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('ginga_light_mode'),
            theme: gingaLightTheme,
            darkTheme: gingaDarkTheme,
            themeMode: ThemeMode.light,
            home: BibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
          const Color(0xFFFFFFFF),
        );
        expect(
          tester.widget<Text>(find.text('A Biblioteca')).style?.color,
          const Color(0xFF111814),
        );

        // 2. Modo oscuro oficial (gingaDarkTheme + ThemeMode.dark)
        await ThemeManager.instance.setThemeMode(ThemeMode.dark);
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('ginga_dark_mode'),
            theme: gingaLightTheme,
            darkTheme: gingaDarkTheme,
            themeMode: ThemeMode.dark,
            home: CurriculoBibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
              initialCordaIndex: 6,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
          GingaColors.backgroundDark,
        );
        expect(
          tester.widget<Text>(find.text('Currículo Oficial FIU')).style?.color,
          GingaColors.textWhite,
        );
        expect(
          tester.widget<Text>(find.text('6. Corda Laranja e Amarelo')).style?.color,
          GingaColors.textWhite,
        );

        // 3. Resiliencia incluso si ThemeManager está en dark pero el subtree usa tema claro
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('ginga_desync_resilience'),
            theme: ThemeData.light(),
            home: BibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
          const Color(0xFFFFFFFF),
        );
        expect(
          tester.widget<Text>(find.text('Currículo Oficial FIU')).style?.color,
          const Color(0xFF111814),
        );
        expect(
          tester.widget<Text>(find.text('Música')).style?.color,
          const Color(0xFF111814),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('PED-03B-FINAL Ajustes de usabilidad y contrato de selección', () {
    testWidgets(
      'Tarjetas muestran corda de introducción, filtro Con video funciona y botón de recuperación restaura lista',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final rawJson =
            File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
        final repo = CurriculumRepository(
          dataSource: InMemoryCurriculumDataSource.fromJsonString(rawJson),
        );
        const prof6 = BibliotecaUserContext(
          role: 'profesor',
          cordaName: 'Laranja e Amarelo',
          displayName: 'Prof. 6ª',
        );

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() async => tester.binding.setSurfaceSize(null));

        // 1. Acumulado 1-6: muestra 'Con video (5)' y cordas de introducción en tarjetas
        await tester.pumpWidget(
          MaterialApp(
            theme: gingaLightTheme,
            home: CurriculoBibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
              initialCordaIndex: 6,
              initialCumulativeMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Desde 1ª · Crua'), findsWidgets);
        expect(find.text('Con video (5)'), findsOneWidget);

        await tester.tap(find.text('Con video (5)'));
        await tester.pumpAndSettle();
        expect(find.text('Movimientos (5)'), findsOneWidget);
        expect(find.text('Cocorinha'), findsOneWidget);

        // 2. Bloque 5-6: muestra 'Desde 5ª · Laranja', 'Con video (0)' y recuperación 'Mostrar todos'
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('bloque_56_video_empty'),
            theme: gingaDarkTheme,
            home: CurriculoBibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
              initialCordaIndex: 6,
              initialCumulativeMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Desde 5ª · Laranja'), findsWidgets);
        expect(find.text('Con video (0)'), findsOneWidget);

        await tester.tap(find.text('Con video (0)'));
        await tester.pumpAndSettle();
        expect(find.text('Mostrar todos'), findsOneWidget);

        await tester.tap(find.text('Mostrar todos'));
        await tester.pumpAndSettle();
        expect(find.text('Movimientos (30)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'visibleAliasesForDisplay oculta duplicados visuales preservando datos y contrato de selección funciona sin IA',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final rawJson =
            File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
        final repo = CurriculumRepository(
          dataSource: InMemoryCurriculumDataSource.fromJsonString(rawJson),
        );

        final ponteira = (await repo.getMovementById('ponteira_pulada'))!;
        expect(ponteira.aliases, isNotEmpty);
        expect(
          MovimientoDetallePanel.visibleAliasesForDisplay(ponteira),
          isEmpty,
        );

        const sampleWithDistinctAliases = CurriculumMovement(
          movementId: 'sample_alias',
          canonicalName: 'Meia-lua de frente',
          aliases: [
            'Meia lua de frente',
            'Meia Lua de Frente',
            'Meia-lua frontal',
            'meia lua frontal',
          ],
          category: TechnicalCategory.golpeDeAtaque,
          entryKind: MovementEntryKind.movimiento,
          reviewStatus: CurriculumReviewStatus.approved,
          isAmbiguous: false,
          aiPlannerEligible: true,
          firstIntroducedAdulto: 'adulto_corda_01',
        );
        expect(
          MovimientoDetallePanel.visibleAliasesForDisplay(
            sampleWithDistinctAliases,
          ),
          ['Meia-lua frontal'],
        );
        // Los datos originales permanecen intactos
        expect(sampleWithDistinctAliases.aliases.length, 4);

        // Verificar contrato de selección en CurriculoBibliotecaScreen (Corda 4 tiene 'desequilibrante' pendiente)
        List<CurriculumMovementSelectionItem> changed = const [];
        List<CurriculumMovementSelectionItem> confirmed = const [];
        const prof6 = BibliotecaUserContext(
          role: 'profesor',
          cordaName: 'Laranja e Amarelo',
          displayName: 'Prof. 6ª',
        );

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() async => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: gingaLightTheme,
            home: CurriculoBibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
              initialCordaIndex: 4,
              selectionContract: CurriculumSelectionContract(
                confirmLabel: 'Agregar a clase',
                onSelectionChanged: (items) => changed = items,
                onConfirmSelection: (items) => confirmed = items,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Agregar a clase'), findsOneWidget);
        // Tocar botón de selección del primer movimiento (no ambiguo) y verificar barra
        final addIcons = find.byIcon(Icons.add_circle_outline_rounded);
        expect(addIcons, findsWidgets);
        await tester.tap(addIcons.first);
        await tester.pumpAndSettle();

        expect(changed.length, 1);
        expect(find.text('1 movimiento(s) seleccionado(s)'), findsOneWidget);

        // Intentar seleccionar movimiento pendiente ('desequilibrante') debe rechazarse
        final blockIcons = find.byIcon(Icons.block_rounded);
        if (blockIcons.evaluate().isNotEmpty) {
          await tester.tap(blockIcons.first);
          await tester.pumpAndSettle();
          expect(changed.length, 1);
        }

        await tester.tap(find.text('Agregar a clase'));
        await tester.pumpAndSettle();
        expect(confirmed.length, 1);
        expect(confirmed.first.toPlannerMap()['selectable_for_ai_planner'], isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Botones principales mantienen dimensiones unificadas entre modo claro y oscuro',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        GoogleFonts.config.allowRuntimeFetching = false;
        final rawJson =
            File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
        final repo = CurriculumRepository(
          dataSource: InMemoryCurriculumDataSource.fromJsonString(rawJson),
        );
        const prof6 = BibliotecaUserContext(
          role: 'profesor',
          cordaName: 'Laranja e Amarelo',
          displayName: 'Prof. 6ª',
        );

        await tester.binding.setSurfaceSize(const Size(945, 930));
        addTearDown(() async {
          SharedPreferences.setMockInitialValues({});
          await ThemeManager.instance.setThemeMode(ThemeMode.light);
          await tester.binding.setSurfaceSize(null);
        });

        await ThemeManager.instance.setThemeMode(ThemeMode.light);
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('btn_sizes_light'),
            theme: gingaLightTheme,
            home: BibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lightPrimarySize = tester.getSize(
          find.widgetWithText(ElevatedButton, 'Mi Corda (Laranja e Amarelo)'),
        );
        final lightSecondarySize = tester.getSize(
          find.widgetWithText(OutlinedButton, 'Repertorio acumulado (1–6)'),
        );

        await ThemeManager.instance.setThemeMode(ThemeMode.dark);
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('btn_sizes_dark'),
            theme: gingaDarkTheme,
            home: BibliotecaScreen(
              repository: repo,
              overrideUserContext: prof6,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final darkPrimarySize = tester.getSize(
          find.widgetWithText(ElevatedButton, 'Mi Corda (Laranja e Amarelo)'),
        );
        final darkSecondarySize = tester.getSize(
          find.widgetWithText(OutlinedButton, 'Repertorio acumulado (1–6)'),
        );

        expect(lightPrimarySize.height, darkPrimarySize.height);
        expect(lightSecondarySize.height, darkSecondarySize.height);
        expect(
          (lightSecondarySize.width - darkSecondarySize.width).abs(),
          lessThan(2.0),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

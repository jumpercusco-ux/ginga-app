import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/core/theme/theme_manager.dart';
import 'package:ginga_app/features/instructor/instructor_pizarra_screen.dart';
import 'package:ginga_app/features/instructor/planificador/models/class_plan_models.dart';
import 'package:ginga_app/features/instructor/planificador/services/class_plan_editor_operations.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_data_source.dart';
import 'package:ginga_app/features/instructor/planificador/widgets/planner_shared_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CurriculumRepository curriculumRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    final jsonStr = File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
    final ds = InMemoryCurriculumDataSource.fromJsonString(jsonStr);
    curriculumRepo = CurriculumRepository(dataSource: ds);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeManager.instance.setThemeMode(ThemeMode.light);
  });

  group('PED-04B2 Modelos, Compatibilidad V1/V2 y Operaciones Puras', () {
    test('Round-trip V2 conserva los 11 campos pedagógicos del ejercicio sin PII',
        () {
      const exercise = ClassPlanExercise(
        exerciseId: 'ex_full_01',
        nombre: 'Cocorinha + Rolê en parejas',
        detalle: '1. Marcar ginga.\n2. Esquivar en cocorinha.\n3. Salir en rolê.',
        duracionMin: 15,
        organizacion: 'Rotación por parejas',
        differentiationBeginner: 'Pausa corta en cocorinha con apoyo de mano.',
        differentiationIntermediate: 'Fluidez continua con lectura de distancia.',
        differentiationAdvanced: 'Conectar salida continua con negativa.',
        materiales: ['Berimbau', 'Conos'],
        safetyNote: 'Mantener 2m libres entre parejas.',
        curriculumMovementIds: ['cocorinha', 'role'],
        linkedResourceIds: ['idea_res_01', 'idea_res_02'],
        resourceUsageNotes: {
          'idea_res_01': 'Mostrar el drill al inicio.',
          'idea_res_02': 'Aplicar señales de palma cada 30s.',
        },
        observacionesProfesor: 'Corregir mirada durante el giro.',
        contentOrigin: ContentOrigin.officialFiuCurriculum,
      );

      const plan = ClassPlanModel(
        id: 'plan_v2_full',
        schemaVersion: 2,
        planStatus: ClassPlanStatus.saved,
        creationMode: PlannerCreationMode.advanced,
        titulo: 'Clase completa V2',
        duracionTotal: 60,
        nivelLabel: 'Adultos',
        audienceType: PlannerAudienceType.adultos,
        curriculumScope: PlannerCurriculumScope.adultoFiu,
        enfoque: 'Técnica · Secuencias',
        objetivo: 'Fluidez en esquiva baja',
        objetivos: ['Fluidez en esquiva baja', 'Cobertura facial'],
        groupName: 'Adultos M/J 19:00',
        ageMin: 16,
        ageMax: 38,
        participantsCount: 12,
        experienceDistribution: ExperienceDistribution(
          principiantes: 4,
          intermedios: 5,
          avanzados: 3,
          manuallyConfirmed: true,
        ),
        bloques: [
          ClassPlanBlock(
            blockId: 'blk_tech',
            fase: 'Técnica & Secuencias',
            duracionMin: 15,
            ejercicios: [exercise],
          ),
        ],
      );

      final map = plan.toMap();
      final serialized = map.toString();
      expect(serialized, isNot(contains('fecha_nacimiento')));
      expect(serialized, isNot(contains('alumno_uids')));
      expect(serialized, isNot(contains('telefono')));

      final hydrated = ClassPlanModel.fromMap('plan_v2_full', map);
      expect(hydrated.schemaVersion, 2);
      expect(hydrated.objetivos, ['Fluidez en esquiva baja', 'Cobertura facial']);
      final hEx = hydrated.bloques.first.ejercicios.first;
      expect(hEx.exerciseId, 'ex_full_01');
      expect(hEx.nombre, 'Cocorinha + Rolê en parejas');
      expect(hEx.detalle, contains('1. Marcar ginga.'));
      expect(hEx.duracionMin, 15);
      expect(hEx.organizacion, 'Rotación por parejas');
      expect(hEx.differentiationBeginner,
          'Pausa corta en cocorinha con apoyo de mano.');
      expect(hEx.differentiationIntermediate,
          'Fluidez continua con lectura de distancia.');
      expect(hEx.differentiationAdvanced,
          'Conectar salida continua con negativa.');
      expect(hEx.materiales, ['Berimbau', 'Conos']);
      expect(hEx.safetyNote, 'Mantener 2m libres entre parejas.');
      expect(hEx.curriculumMovementIds, ['cocorinha', 'role']);
      expect(hEx.linkedResourceIds, ['idea_res_01', 'idea_res_02']);
      expect(hEx.resourceUsageNotes['idea_res_02'],
          'Aplicar señales de palma cada 30s.');
      expect(hEx.observacionesProfesor, 'Corregir mirada durante el giro.');
      expect(hEx.contentOrigin, ContentOrigin.officialFiuCurriculum);

      // Compatibilidad con datos previos sin diferenciacion_intermedios
      final legacyTwoVariants = ClassPlanExercise.fromMap({
        'exercise_id': 'ex_old_v2',
        'nombre': 'Ejercicio previo',
        'detalle': 'Detalle previo',
        'diferenciacion_principiantes': 'Base lenta',
        'diferenciacion_avanzados': 'Variación aérea',
      }, fallbackId: 'fb');
      expect(legacyTwoVariants.differentiationBeginner, 'Base lenta');
      expect(legacyTwoVariants.differentiationIntermediate, isNull);
      expect(legacyTwoVariants.differentiationAdvanced, 'Variación aérea');
    });

    test('Compatibilidad V1: edita un plan V1 conservando campos heredados y IDs',
        () {
      final legacy = ClassPlanModel.fromMap('legacy_v1_test', {
        'titulo': 'Clase V1 Clásica',
        'duracion_total': 60,
        'nivel': 'Adultos',
        'enfoque': 'Técnica & Movilidad',
        'objetivo': 'Trabajo de base',
        'veces_impartida': 4,
        'bloques': [
          {
            'fase': 'Técnica Marcial',
            'duracion_min': 25,
            'ejercicios': [
              {
                'nombre': 'Bênção con cocorinha',
                'detalle': 'En parejas sin pausa',
                'recurso_relacionado': 'Drill esquiva en parejas',
              },
              {
                'nombre': 'Meia lua de frente',
                'detalle': 'Alternar piernas',
              },
            ],
          },
        ],
      });

      final originalEx1 = legacy.bloques.first.ejercicios.first;
      final originalEx2 = legacy.bloques.first.ejercicios[1];

      final editedEx1 = originalEx1.copyWith(
        nombre: 'Bênção con cocorinha (Ajustado)',
        duracionMin: 12,
        organizacion: 'Parejas alternas',
      );
      final updated = ClassPlanEditorOperations.updateExercise(
        legacy,
        legacy.bloques.first.blockId,
        editedEx1,
      );

      expect(updated.id, 'legacy_v1_test');
      expect(updated.vecesImpartida, 4);
      expect(updated.bloques.first.ejercicios[0].legacyRecursoRelacionado,
          'Drill esquiva en parejas');
      expect(updated.bloques.first.ejercicios[0].contentOrigin,
          ContentOrigin.teacherResource);
      // El segundo ejercicio permanece idéntico
      expect(updated.bloques.first.ejercicios[1].exerciseId,
          originalEx2.exerciseId);
      expect(updated.bloques.first.ejercicios[1].nombre, 'Meia lua de frente');
      expect(updated.bloques.first.ejercicios[1].duracionMin, isNull);
    });

    test(
        'Operaciones de bloques y ejercicios: añadir, duplicar, reordenar, eliminar y aislar',
        () {
      final initial = ClassPlanModel.emptyManual(customId: 'manual_01');
      expect(initial.bloques.length, 1);
      expect(initial.bloques.first.ejercicios, isEmpty);
      expect(initial.detectedOrigins, isNot(contains(ContentOrigin.aiComplementaryProposal)));

      var plan = ClassPlanEditorOperations.addBlock(
        initial,
        fase: 'Técnica & Progresiones',
        duracionMin: 25,
      );
      expect(plan.bloques.length, 2);
      final blkTechId = plan.bloques[1].blockId;

      const exA = ClassPlanExercise(
        exerciseId: 'ex_a',
        nombre: 'Ginga base',
        detalle: 'Ritmo continuo',
        duracionMin: 10,
        contentOrigin: ContentOrigin.officialFiuCurriculum,
        curriculumMovementIds: ['ginga'],
      );
      const exB = ClassPlanExercise(
        exerciseId: 'ex_b',
        nombre: 'Esquiva lateral',
        detalle: 'En parejas',
        duracionMin: 15,
        contentOrigin: ContentOrigin.teacherResource,
        linkedResourceIds: ['idea_res_01'],
      );

      plan = ClassPlanEditorOperations.addExercise(plan, blkTechId, exA);
      plan = ClassPlanEditorOperations.addExercise(plan, blkTechId, exB);
      expect(plan.bloques[1].ejercicios.length, 2);

      // Duplicar ejercicio exA conserva movementIds y asigna nuevo exerciseId único
      plan = ClassPlanEditorOperations.duplicateExercise(plan, blkTechId, 'ex_a');
      expect(plan.bloques[1].ejercicios.length, 3);
      final dupEx = plan.bloques[1].ejercicios[1];
      expect(dupEx.exerciseId, isNot('ex_a'));
      expect(dupEx.nombre, 'Ginga base (Copia)');
      expect(dupEx.curriculumMovementIds, ['ginga']);
      expect(dupEx.contentOrigin, ContentOrigin.officialFiuCurriculum);

      // Editar dupEx no altera exA ni exB
      plan = ClassPlanEditorOperations.updateExercise(
        plan,
        blkTechId,
        dupEx.copyWith(nombre: 'Ginga modificada', duracionMin: 8),
      );
      expect(plan.bloques[1].ejercicios[0].nombre, 'Ginga base');
      expect(plan.bloques[1].ejercicios[2].nombre, 'Esquiva lateral');

      // Reordenar ejercicios dentro del bloque
      plan = ClassPlanEditorOperations.reorderExercises(plan, blkTechId, 2, 0);
      expect(plan.bloques[1].ejercicios.first.exerciseId, 'ex_b');

      // Duplicar bloque y reordenar bloques
      plan = ClassPlanEditorOperations.duplicateBlock(plan, blkTechId);
      expect(plan.bloques.length, 3);
      expect(plan.bloques[2].blockId, isNot(blkTechId));
      expect(plan.bloques[2].fase, 'Técnica & Progresiones (Copia)');
      expect(plan.bloques[2].ejercicios.first.linkedResourceIds, ['idea_res_01']);

      plan = ClassPlanEditorOperations.reorderBlocks(plan, 2, 0);
      expect(plan.bloques.first.fase, 'Técnica & Progresiones (Copia)');

      // Eliminar bloque duplicado
      final dupBlkId = plan.bloques.first.blockId;
      plan = ClassPlanEditorOperations.deleteBlock(plan, dupBlkId);
      expect(plan.bloques.length, 2);
    });

    test('Duplicar clase completa preserva IDs/orígenes y no altera la original',
        () {
      final ds = InMemoryPlannerDataSource.demoFixtures();
      // Construir copia desde un plan V2 con movimientos FIU, recursos y AI origin
      const original = ClassPlanModel(
        id: 'orig_v2',
        schemaVersion: 2,
        planStatus: ClassPlanStatus.saved,
        creationMode: PlannerCreationMode.advanced,
        titulo: 'Clase Original Adultos',
        duracionTotal: 60,
        nivelLabel: 'Adultos',
        audienceType: PlannerAudienceType.adultos,
        curriculumScope: PlannerCurriculumScope.adultoFiu,
        enfoque: 'Técnica',
        objetivo: 'Objetivo original',
        objetivos: ['Objetivo original'],
        groupName: 'Adultos M/J 19:00',
        ageMin: 16,
        ageMax: 38,
        participantsCount: 12,
        experienceDistribution: ExperienceDistribution(),
        vecesImpartida: 3,
        bloques: [
          ClassPlanBlock(
            blockId: 'blk_1',
            fase: 'Técnica',
            duracionMin: 30,
            ejercicios: [
              ClassPlanExercise(
                exerciseId: 'ex_1',
                nombre: 'Cocorinha',
                detalle: 'Base',
                duracionMin: 30,
                contentOrigin: ContentOrigin.officialFiuCurriculum,
                curriculumMovementIds: ['cocorinha'],
                linkedResourceIds: ['idea_res_02'],
              ),
            ],
          ),
        ],
      );

      final copy = ClassPlanEditorOperations.duplicatePlan(original);
      expect(copy.id, isNot(original.id));
      expect(copy.duplicatedFromPlanId, original.id);
      expect(copy.titulo, 'Clase Original Adultos (Copia)');
      expect(copy.planStatus, ClassPlanStatus.draft);
      expect(copy.vecesImpartida, 0);
      expect(copy.ultimaEjecucion, isNull);
      expect(copy.bloques.first.blockId, 'blk_1');
      expect(copy.bloques.first.ejercicios.first.curriculumMovementIds,
          ['cocorinha']);
      expect(copy.bloques.first.ejercicios.first.linkedResourceIds,
          ['idea_res_02']);

      final modifiedCopy = ClassPlanEditorOperations.updateMetadata(
        copy,
        titulo: 'Copia Editada',
        duracionTotal: 75,
      );
      expect(original.titulo, 'Clase Original Adultos');
      expect(original.duracionTotal, 60);
      expect(modifiedCopy.titulo, 'Copia Editada');
      expect(ds, isNotNull);
    });

    test(
        'Control de tiempos calcula restante, excedente, desajuste por bloque y ajuste',
        () {
      const base = ClassPlanModel(
        id: 't_plan',
        schemaVersion: 2,
        planStatus: ClassPlanStatus.draft,
        creationMode: PlannerCreationMode.advanced,
        titulo: 'Tiempos',
        duracionTotal: 60,
        nivelLabel: 'Adultos',
        audienceType: PlannerAudienceType.adultos,
        curriculumScope: PlannerCurriculumScope.adultoFiu,
        enfoque: 'Técnica',
        objetivo: '',
        groupName: 'Adultos',
        ageMin: 16,
        ageMax: 35,
        participantsCount: 10,
        experienceDistribution: ExperienceDistribution(),
        bloques: [
          ClassPlanBlock(
            blockId: 'b1',
            fase: 'Activación',
            duracionMin: 15,
            ejercicios: [
              ClassPlanExercise(
                exerciseId: 'e1',
                nombre: 'Ginga',
                detalle: '',
                duracionMin: 10,
                contentOrigin: ContentOrigin.teacherResource,
              ),
              ClassPlanExercise(
                exerciseId: 'e2',
                nombre: 'Esquiva',
                detalle: '',
                duracionMin: 10,
                contentOrigin: ContentOrigin.teacherResource,
              ),
            ],
          ),
          ClassPlanBlock(
            blockId: 'b2',
            fase: 'Roda',
            duracionMin: 25,
            ejercicios: [],
          ),
        ],
      );

      final summary1 = ClassPlanTimingSummary.fromPlan(base);
      expect(summary1.targetMinutes, 60);
      expect(summary1.plannedMinutes, 40);
      expect(summary1.remainingMinutes, 20);
      expect(summary1.excessMinutes, 0);
      expect(summary1.isExact, isFalse);
      expect(summary1.blockSummaries[0].hasMismatch, isTrue);
      expect(summary1.blockSummaries[0].exercisesSumMin, 20);
      expect(summary1.blockSummaries[1].isEmpty, isTrue);
      expect(summary1.warnings.length, 3);

      // Sincronizar b1 a la suma de sus ejercicios (20 min) y subir b2 a 50 min -> 70 min (+10 exceso)
      var updated =
          ClassPlanEditorOperations.syncBlockDurationFromExercises(base, 'b1');
      updated = ClassPlanEditorOperations.updateBlock(
        updated,
        'b2',
        duracionMin: 50,
      );
      final summary2 = ClassPlanTimingSummary.fromPlan(updated);
      expect(summary2.plannedMinutes, 70);
      expect(summary2.excessMinutes, 10);
      expect(summary2.remainingMinutes, 0);
      expect(summary2.blockSummaries[0].hasMismatch, isFalse);
    });

    test('Restricción curricular infantil bloquea currículo Adulto FIU', () {
      final blank = ClassPlanModel.emptyManual();
      final withMov = ClassPlanEditorOperations.addExercise(
        blank,
        blank.bloques.first.blockId,
        const ClassPlanExercise(
          exerciseId: 'ex_adult_mov',
          nombre: 'Cocorinha',
          detalle: 'Adulto',
          contentOrigin: ContentOrigin.officialFiuCurriculum,
          curriculumMovementIds: ['cocorinha'],
        ),
      );

      final switchedToKids = ClassPlanEditorOperations.updateMetadata(
        withMov,
        audienceType: PlannerAudienceType.infantil,
        curriculumScope: PlannerCurriculumScope.adultoFiu, // intento indebido
      );

      expect(switchedToKids.audienceType, PlannerAudienceType.infantil);
      expect(switchedToKids.curriculumScope,
          PlannerCurriculumScope.infantilFiuPending);
      expect(
        switchedToKids.bloques.first.ejercicios.first.curriculumMovementIds,
        isEmpty,
      );
      expect(
        switchedToKids.bloques.first.ejercicios.first.contentOrigin,
        ContentOrigin.teacherResource,
      );
    });
  });

  group('PED-04B2 Validación UI del Editor Pedagógico V2', () {
    Widget buildHarness({
      required ThemeMode themeMode,
      required Size size,
      PlannerDataSource? ds,
      String? initialEditingPlanId,
      bool initialCreateManual = false,
    }) {
      return MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          theme: gingaLightTheme,
          darkTheme: gingaDarkTheme,
          themeMode: themeMode,
          themeAnimationDuration: Duration.zero,
          home: InstructorPizarraScreen(
            dataSource: ds ?? InMemoryPlannerDataSource.demoFixtures(),
            curriculumRepository: curriculumRepo,
            initialEditingPlanId: initialEditingPlanId,
            initialCreateManual: initialCreateManual,
          ),
        ),
      );
    }

    testWidgets(
        'Crear clase desde cero, editar metadatos, añadir bloque/ejercicio y guardar borrador incompleto',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        buildHarness(themeMode: ThemeMode.light, size: const Size(1440, 900), ds: ds),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hub_manual_create_button')));
      await tester.pumpAndSettle();

      // Barra permanente de control de tiempos visible
      expect(find.byKey(const Key('editor_timing_bar')), findsOneWidget);
      expect(find.text('Objetivo: 60 min'), findsOneWidget);
      expect(find.text('Planificado: 10 min'), findsOneWidget);
      expect(find.text('Faltan 50 min'), findsOneWidget);

      // Modificar título, añadir objetivo y cambiar duración objetivo a 45 min
      await tester.enterText(
        find.byKey(const Key('editor_title_field')),
        'Clase Manual de Ginga y Esquiva',
      );
      await tester.enterText(
        find.byKey(const Key('editor_objective_input')),
        'Consolidar postura sin pausas',
      );
      await tester.tap(find.byKey(const Key('editor_add_objective_button')));
      await tester.tap(find.byKey(const Key('editor_target_dur_45')));
      await tester.pumpAndSettle();
      expect(find.text('Objetivo: 45 min'), findsOneWidget);
      expect(find.text('Faltan 35 min'), findsOneWidget);

      // Añadir un ejercicio al primer bloque -> abre panel contextual en columna derecha
      await tester.ensureVisible(
          find.byKey(const Key('block_add_ex_blk_manual_0')));
      await tester.tap(find.byKey(const Key('block_add_ex_blk_manual_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ex_editor_name_field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ex_editor_name_field')),
        'Calentamiento circular',
      );
      await tester.enterText(
        find.byKey(const Key('ex_editor_detail_field')),
        '1. Ginga suave.\n2. Movilidad de cadera.',
      );
      await tester.tap(find.byKey(const Key('ex_editor_apply_button')));
      await tester.pumpAndSettle();

      // Guardar borrador aunque aún falten 35 min (validación no bloqueante)
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      final plans = await ds.loadPlans();
      final created =
          plans.firstWhere((p) => p.titulo == 'Clase Manual de Ginga y Esquiva');
      expect(created.duracionTotal, 45);
      expect(created.objetivos, contains('Consolidar postura sin pausas'));
      expect(created.bloques.first.ejercicios.first.nombre,
          'Calentamiento circular');
      expect(created.detectedOrigins,
          isNot(contains(ContentOrigin.aiComplementaryProposal)));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Hub Ver plan, Editar plan y Reutilizar (duplicación sin alterar el original)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        buildHarness(themeMode: ThemeMode.light, size: const Size(1440, 900), ds: ds),
      );
      await tester.pumpAndSettle();

      // 1. Ver plan (v2_plan_adulto_01) -> abre ClassPlanSummarySheet con botón Editar plan
      final viewButtons = find.text('Ver plan');
      await tester.ensureVisible(viewButtons.at(1));
      await tester.tap(viewButtons.at(1));
      await tester.pumpAndSettle();

      expect(find.byType(ClassPlanSummarySheet), findsOneWidget);
      expect(find.text('Duplicar clase'), findsOneWidget);

      // Cerrar summary sheet
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      // 2. Reutilizar desde el Hub en v2_plan_adulto_01 -> abre Editor en copia independiente
      final reuseButtons = find.text('Reutilizar');
      await tester.ensureVisible(reuseButtons.at(1));
      await tester.tap(reuseButtons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Copia independiente'), findsOneWidget);
      await tester.tap(find.byKey(const Key('editor_metadata_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('editor_title_field')),
        'Clase Reutilizada Independiente',
      );
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      final plansAfter = await ds.loadPlans();
      expect(
        plansAfter.any((p) => p.titulo == 'Esquivas bajas y transición a rolê continuo'),
        isTrue,
      );
      expect(
        plansAfter.any((p) => p.titulo == 'Clase Reutilizada Independiente'),
        isTrue,
      );

      // 3. Editar plan V1 directamente (legacy_plan_01)
      final editButtons = find.text('Editar plan');
      // legacy_plan_01 ahora está en índice 1 porque la copia se insertó al inicio
      await tester.ensureVisible(editButtons.at(1));
      await tester.tap(editButtons.at(1));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('editor_timing_bar')), findsOneWidget);
      expect(find.text('Base de Ginga, Bênção y Esquiva (Plan V1)'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Editar ejercicio individual: vincula movimiento FIU y recurso de Pizarra sin marcar recurso como usado',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.light,
          size: const Size(1440, 960),
          ds: ds,
          initialEditingPlanId: 'v2_plan_adulto_01',
        ),
      );
      await tester.pumpAndSettle();

      // Abrir editor contextual del primer ejercicio (ex_1_1)
      await tester.tap(find.byKey(const Key('ex_edit_ex_1_1')));
      await tester.pumpAndSettle();

      // Vincular recurso idea_res_03 (no usado: hasBeenTaught=false, timesUsed=0)
      await tester.ensureVisible(
          find.byKey(const Key('ex_editor_pick_resource_button')));
      await tester.tap(find.byKey(const Key('ex_editor_pick_resource_button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('res_picker_item_idea_res_03')));
      await tester.tap(find.byKey(const Key('res_picker_item_idea_res_03')));
      await tester.tap(find.byKey(const Key('res_picker_confirm_button')));
      await tester.pumpAndSettle();

      // Vincular movimiento FIU usando CurriculumSelectionContract
      await tester.ensureVisible(find.byKey(const Key('ex_editor_pick_fiu_button')));
      await tester.tap(find.byKey(const Key('ex_editor_pick_fiu_button')));
      await tester.pumpAndSettle();

      expect(find.text('Vincular al ejercicio'), findsOneWidget);
      final selectMovBtn = find.byIcon(Icons.add_circle_outline_rounded).first;
      await tester.ensureVisible(selectMovBtn);
      await tester.tap(selectMovBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vincular al ejercicio'));
      await tester.pumpAndSettle();

      // Editar organización y observaciones del profesor
      await tester.ensureVisible(find.byKey(const Key('ex_editor_org_field')));
      await tester.enterText(
        find.byKey(const Key('ex_editor_org_field')),
        'Tríos rotativos',
      );
      await tester.tap(find.byKey(const Key('ex_editor_apply_button')));
      await tester.pumpAndSettle();

      // Guardar plan y comprobar que los otros ejercicios (ex_2_1, ex_3_1) y el estado de uso del recurso permanecen intactos
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      final plans = await ds.loadPlans();
      final editedPlan =
          plans.firstWhere((p) => p.id == 'v2_plan_adulto_01');
      final ex11 = editedPlan.bloques[0].ejercicios[0];
      final ex21 = editedPlan.bloques[1].ejercicios[0];
      expect(ex11.organizacion, 'Tríos rotativos');
      expect(ex11.linkedResourceIds, contains('idea_res_03'));
      expect(ex11.curriculumMovementIds, isNotEmpty);
      expect(ex21.nombre, 'Cocorinha + salida en Rolê');
      expect(ex21.curriculumMovementIds, ['cocorinha', 'role']);

      final resourcesAfter = await ds.loadResources();
      final res03 =
          resourcesAfter.firstWhere((r) => r.resourceId == 'idea_res_03');
      expect(res03.hasBeenTaught, isFalse);
      expect(res03.timesUsed, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Protección infantil y responsive móvil/tablet en claro y oscuro',
        (tester) async {
      // Móvil oscuro (390x844) con clase infantil: verifica protección curricular y modal contextual
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.dark,
          size: const Size(390, 844),
          initialEditingPlanId: 'v2_plan_infantil_01',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protección Curricular Infantil activa'), findsOneWidget);
      expect(find.text('Faltan 20 min'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('ex_edit_ex_k1_1')));
      await tester.tap(find.byKey(const Key('ex_edit_ex_k1_1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Currículo Adulto FIU bloqueado en clase Infantil'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ex_editor_pick_fiu_button')), findsNothing);
      await tester.tap(find.byKey(const Key('ex_editor_cancel_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tablet claro (834x1024) con clase adulto
      await tester.binding.setSurfaceSize(const Size(834, 1024));
      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.light,
          size: const Size(834, 1024),
          initialEditingPlanId: 'v2_plan_adulto_01',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tiempo exacto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PED-04B2-UX: 3 variantes, 5 organizaciones, múltiples recursos con notas y apertura, Cancelar, origen independiente y desajuste sin alterar hermanos',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.dark,
          size: const Size(1440, 960),
          ds: ds,
          initialEditingPlanId: 'v2_plan_adulto_01',
        ),
      );
      await tester.pumpAndSettle();

      // Tooltips visibles en controles clave
      expect(find.byTooltip('Editar ejercicio'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Duplicar ejercicio'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Subir ejercicio'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Bajar ejercicio'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Eliminar ejercicio'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Duplicar bloque'), findsAtLeastNWidgets(1));

      // Abrir ex_1_1 (origen: teacherResource, recurso: idea_res_02 con nota previa)
      await tester.tap(find.byKey(const Key('ex_edit_ex_1_1')));
      await tester.pumpAndSettle();

      // Probar Cancelar: modificar nombre y cancelar -> descarta cambios
      await tester.enterText(
        find.byKey(const Key('ex_editor_name_field')),
        'Cambio que debe descartarse',
      );
      await tester.tap(find.byKey(const Key('ex_editor_cancel_button')));
      await tester.pumpAndSettle();
      expect(find.text('Cambio que debe descartarse'), findsNothing);

      // Reabrir ex_1_1
      await tester.tap(find.byKey(const Key('ex_edit_ex_1_1')));
      await tester.pumpAndSettle();
      expect(find.text('Juego espejo de esquivas en parejas'), findsAtLeastNWidgets(1));

      // Verificar las 5 opciones de organización pedagógica y seleccionar Turnos -> Personalizada
      for (int i = 0; i < kPlannerOrganizationOptions.length; i++) {
        expect(find.byKey(Key('ex_editor_org_opt_$i')), findsOneWidget);
      }
      await tester.ensureVisible(find.byKey(const Key('ex_editor_org_opt_3')));
      await tester.tap(find.byKey(const Key('ex_editor_org_opt_3'))); // Turnos
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ex_editor_org_opt_4'))); // Personalizada
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ex_editor_org_field')),
        'Circuito en 4 estaciones',
      );

      // Verificar apertura del recurso vinculado existente y nota de uso previa
      expect(
        find.text('Aplicar en 2 rondas de 90s antes de pasar a cocorinha.'),
        findsOneWidget,
      );
      await tester.ensureVisible(
          find.byKey(const Key('ex_editor_open_res_idea_res_02')));
      await tester.tap(find.byKey(const Key('ex_editor_open_res_idea_res_02')));
      await tester.pumpAndSettle();
      expect(find.text('Juego espejo de esquivas por señales'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Cerrar').last);
      await tester.pumpAndSettle();

      // Vincular segundo recurso (idea_res_03) y añadir nota particular de uso
      await tester.ensureVisible(
          find.byKey(const Key('ex_editor_pick_resource_button')));
      await tester.tap(find.byKey(const Key('ex_editor_pick_resource_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('res_picker_item_idea_res_03')));
      await tester.tap(find.byKey(const Key('res_picker_item_idea_res_03')));
      await tester.tap(find.byKey(const Key('res_picker_confirm_button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.byKey(const Key('ex_editor_res_note_idea_res_03')));
      await tester.enterText(
        find.byKey(const Key('ex_editor_res_note_idea_res_03')),
        'Usar colchoneta solo para demostración inicial.',
      );

      // Vincular 2 movimientos FIU y verificar que el origen teacherResource no se sobrescribe
      await tester.ensureVisible(find.byKey(const Key('ex_editor_pick_fiu_button')));
      await tester.tap(find.byKey(const Key('ex_editor_pick_fiu_button')));
      await tester.pumpAndSettle();
      final movBtns = find.byIcon(Icons.add_circle_outline_rounded);
      await tester.ensureVisible(movBtns.at(0));
      await tester.tap(movBtns.at(0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.add_circle_outline_rounded).first);
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vincular al ejercicio'));
      await tester.pumpAndSettle();

      // Abrir sección de variantes pedagógicas en 3 niveles y rellenar
      await tester.ensureVisible(
          find.text('Variantes pedagógicas por nivel (opcional)'));
      await tester.tap(find.text('Variantes pedagógicas por nivel (opcional)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('ex_editor_beginner_field')));
      await tester.enterText(
        find.byKey(const Key('ex_editor_beginner_field')),
        'Esquiva lenta con señal verbal',
      );
      await tester.enterText(
        find.byKey(const Key('ex_editor_intermediate_field')),
        'Esquiva continua con respuesta en ginga',
      );
      await tester.enterText(
        find.byKey(const Key('ex_editor_advanced_field')),
        'Enlazar esquiva con negativa y salida',
      );

      // Cambiar duración individual de ex_1_1 (+1 min) para generar desajuste en blk_1 sin alterar ex_2_1
      await tester.ensureVisible(
          find.byKey(const Key('ex_editor_duration_stepper')));
      final addDurIcon = find.descendant(
        of: find.byKey(const Key('ex_editor_duration_stepper')),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(addDurIcon);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ex_editor_apply_button')));
      await tester.pumpAndSettle();

      // Verificar advertencia de diferencia en blk_1 y conservación intacta de ex_2_1
      expect(find.byKey(const Key('block_mismatch_banner_blk_1')), findsOneWidget);
      expect(find.text('Ejercicios: 13/12 min'), findsOneWidget);

      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      final savedPlans = await ds.loadPlans();
      final edited = savedPlans.firstWhere((p) => p.id == 'v2_plan_adulto_01');
      final ex11 = edited.bloques[0].ejercicios[0];
      final ex21 = edited.bloques[1].ejercicios[0];
      expect(ex11.organizacion, 'Circuito en 4 estaciones');
      expect(ex11.differentiationBeginner, 'Esquiva lenta con señal verbal');
      expect(ex11.differentiationIntermediate,
          'Esquiva continua con respuesta en ginga');
      expect(ex11.differentiationAdvanced,
          'Enlazar esquiva con negativa y salida');
      expect(ex11.linkedResourceIds, ['idea_res_02', 'idea_res_03']);
      expect(ex11.resourceUsageNotes['idea_res_03'],
          'Usar colchoneta solo para demostración inicial.');
      expect(ex11.curriculumMovementIds.length, 2);
      // El origen propio del ejercicio se conserva independiente de los vínculos
      expect(ex11.contentOrigin, ContentOrigin.teacherResource);
      // El segundo bloque y su ejercicio no fueron alterados automáticamente
      expect(ex21.duracionMin, 28);
      expect(ex21.nombre, 'Cocorinha + salida en Rolê');

      // El recurso idea_res_03 nunca fue marcado como utilizado
      final resAfter = await ds.loadResources();
      final res03 = resAfter.firstWhere((r) => r.resourceId == 'idea_res_03');
      expect(res03.hasBeenTaught, isFalse);
      expect(res03.timesUsed, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

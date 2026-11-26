import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/models/curriculum_models.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/core/theme/theme_manager.dart';
import 'package:ginga_app/features/instructor/instructor_pizarra_screen.dart';
import 'package:ginga_app/features/instructor/planificador/models/class_plan_models.dart';
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

  group('PED-04B1-FINAL Modelos y Contratos Tipados', () {
    test('ClassPlanModel.fromMap hidrata plan V1 legacy sin pérdida de datos', () {
      final legacy = ClassPlanModel.fromMap('legacy_01', {
        'titulo': 'Clase V1 Clásica',
        'duracion_total': 60,
        'nivel': 'Adultos',
        'enfoque': 'Técnica & Movilidad',
        'objetivo': 'Trabajo de base',
        'veces_impartida': 3,
        'ultima_ejecucion': '2026-11-19T20:00:00Z',
        'bloques': [
          {
            'fase': 'Técnica Marcial',
            'duracion_min': 25,
            'ejercicios': [
              {
                'nombre': 'Cocorinha + Rolê',
                'detalle': 'En parejas sin pausa',
                'recurso_relacionado': 'Drill esquiva',
              },
            ],
          },
        ],
      });

      expect(legacy.isLegacyV1, isTrue);
      expect(legacy.schemaVersion, 1);
      expect(legacy.audienceType, PlannerAudienceType.adultos);
      expect(legacy.ultimaEjecucion, isNotNull);
      expect(legacy.bloques.length, 1);
      expect(legacy.bloques.first.blockId, 'blk_0');
      expect(legacy.bloques.first.ejercicios.first.exerciseId, 'ex_0_0');
      expect(legacy.bloques.first.ejercicios.first.contentOrigin,
          ContentOrigin.teacherResource);
      expect(legacy.vecesImpartida, 3);
    });

    test('No se infiere currículo Adulto FIU para grupos mixto ni infantil', () {
      const mixtoGroup = PlannerGroupProfile(
        id: 'mix_1',
        name: 'Roda Sábado',
        source: PlannerGroupSource.realClass,
        audienceType: PlannerAudienceType.mixto,
        scheduleSummary: 'Sáb 14:30',
        ageMin: 9,
        ageMax: 42,
        participantsCount: 16,
      );
      const kidsGroup = PlannerGroupProfile(
        id: 'kids_1',
        name: 'Kids 18:00',
        source: PlannerGroupSource.realClass,
        audienceType: PlannerAudienceType.infantil,
        scheduleSummary: 'M/J 18:00',
        ageMin: 6,
        ageMax: 11,
        participantsCount: 10,
      );

      expect(mixtoGroup.suggestedCurriculumScope,
          PlannerCurriculumScope.mixedNoOfficialTrack);
      expect(kidsGroup.suggestedCurriculumScope,
          PlannerCurriculumScope.infantilFiuPending);

      final reqMix = ClassPlanDraftRequest.fromGroup(mixtoGroup);
      final reqKids = ClassPlanDraftRequest.fromGroup(kidsGroup);
      expect(reqMix.curriculumScope, isNot(PlannerCurriculumScope.adultoFiu));
      expect(reqKids.curriculumScope, isNot(PlannerCurriculumScope.adultoFiu));
      expect(reqMix.experienceDistribution.manuallyConfirmed, isFalse);
    });

    test('toAiSafeRequestMap omite PII, incluye usage_note y exige validación en servidor', () {
      const group = PlannerGroupProfile(
        id: 'clase_adultos_mj_1900',
        name: 'Adultos M/J 19:00',
        source: PlannerGroupSource.realClass,
        audienceType: PlannerAudienceType.adultos,
        scheduleSummary: 'M/J 19:00',
        ageMin: 18,
        ageMax: 35,
        participantsCount: 12,
        observedCordasSummary: {'Crua': 6, 'Verde': 6},
      );
      final req = ClassPlanDraftRequest.fromGroup(group).copyWith(
        focuses: ['Técnica', 'Secuencias', 'Roda'],
        selectedResources: [
          const SelectedTeacherResource(
            resource: PlannerResourceItem(
              resourceId: 'idea_res_01',
              title: 'Drill esquiva',
              type: 'video',
              category: 'Técnica',
              audienceLabel: 'Adultos',
              notes: '3 rondas de 90s',
              url: 'https://instagram.com/reel/demo',
            ),
            priority: ResourcePriority.required,
            usageNote: 'Usar en parejas tras la movilidad',
          ),
        ],
      );

      final payload = req.toAiSafeRequestMap();
      final serialized = payload.toString();
      expect(payload['server_validation_required'], isTrue);
      expect(payload['content_origins_separated'], isTrue);
      expect(
          (payload['curriculum_context'] as Map)['auto_adult_fallback_blocked'],
          isTrue);
      expect(serialized, isNot(contains('fecha_nacimiento')));
      expect(serialized, isNot(contains('alumno_uids')));
      final resList = payload['selected_resources'] as List;
      expect((resList.first as Map)['resource_id'], 'idea_res_01');
      expect((resList.first as Map)['video_visual_inspected'], isFalse);
      expect((resList.first as Map)['priority'], 'required');
      expect((resList.first as Map)['usage_note'],
          'Usar en parejas tras la movilidad');
    });

    test('Borrador local respeta duración total, distingue orígenes y valida suma de niveles', () {
      final req = ClassPlanDraftRequest.fromGroup(
        const PlannerGroupProfile(
          id: 'clase_adultos_mj_1900',
          name: 'Adultos M/J 19:00',
          source: PlannerGroupSource.realClass,
          audienceType: PlannerAudienceType.adultos,
          scheduleSummary: 'M/J 19:00',
          ageMin: 18,
          ageMax: 35,
          participantsCount: 12,
          defaultDistribution: ExperienceDistribution(
            principiantes: 5,
            intermedios: 5,
            avanzados: 2,
          ),
        ),
      ).copyWith(
        durationMin: 75,
        focuses: ['Técnica', 'Juegos'],
        selectedMovements: [
          const SelectedCurriculumMovement(
            item: CurriculumMovementSelectionItem(
              movementId: 'cocorinha',
              canonicalName: 'Cocorinha',
              category: TechnicalCategory.saidaEsquiva,
              firstIntroducedAdulto: 'adulto_corda_01',
              isCombination: false,
              isSelectableForAiPlanner: true,
              hasRealVideo: true,
            ),
            priority: ResourcePriority.required,
          ),
        ],
      );

      expect(req.isExperienceDistributionValid, isTrue);
      final invalid = req.copyWith(participantsCount: 15);
      expect(invalid.isExperienceDistributionValid, isFalse);
      expect(invalid.experienceDistributionDelta, -3);

      final draft = ClassPlanModel.fromLocalDraftRequest(req);
      final sumMinutes =
          draft.bloques.fold<int>(0, (acc, b) => acc + b.duracionMin);
      expect(sumMinutes, 75);
      expect(draft.enfoque, 'Técnica · Juegos');
      expect(draft.planStatus, ClassPlanStatus.draft);
      expect(draft.detectedOrigins, contains(ContentOrigin.officialFiuCurriculum));
      expect(draft.detectedOrigins, contains(ContentOrigin.teacherResource));
      expect(
          draft.detectedOrigins,
          isNot(contains(ContentOrigin.aiComplementaryProposal)));

      const copilotReq = PlanCopilotRequest(
        planId: 'plan_1',
        targetScope: PlanCopilotTargetScope.exercise,
        targetBlockId: 'blk_tech',
        targetExerciseId: 'ex_fiu_0',
        instruction: 'Cambiar progresión a parejas de 3',
        curriculumScope: PlannerCurriculumScope.adultoFiu,
      );
      expect(copilotReq.toAiSafeMap()['preserve_untouched_blocks'], isTrue);
    });
  });

  group('PED-04B1-FINAL Validación Funcional de las 5 Pantallas', () {
    Widget buildHarness({
      required ThemeMode themeMode,
      required Size size,
      PlannerDataSource? ds,
      PlannerHubTab initialTab = PlannerHubTab.plans,
      PlannerCreationMode? initialCreationMode,
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
            initialTab: initialTab,
            initialCreationMode: initialCreationMode,
          ),
        ),
      );
    }

    testWidgets(
        'Mis Planes: oculta etiquetas técnicas, muestra última ejecución, busca planes y navega por pestañas',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildHarness(themeMode: ThemeMode.light, size: const Size(1440, 900)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planificador Pedagógico & Pizarra'), findsOneWidget);
      expect(find.textContaining('Base de Ginga'), findsOneWidget);
      expect(find.text('V1 Compatible'), findsNothing);
      expect(find.text('Editar en avanzada'), findsNothing);
      expect(find.text('Editar plan'), findsAtLeastNWidgets(1));
      expect(find.text('Iniciar clase'), findsAtLeastNWidgets(1));
      expect(find.text('Última ejecución: 19/11/2026'), findsOneWidget);

      // Buscador de planes
      await tester.enterText(
          find.byKey(const Key('plans_search_field')), 'palmas');
      await tester.pumpAndSettle();
      expect(find.textContaining('Juegos motores y palmas'), findsOneWidget);
      expect(find.textContaining('Base de Ginga'), findsNothing);

      // Navegación a Pizarra e Historial
      await tester.tap(find.byKey(const Key('hub_tab_resources')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pizarra_add_resource_button')), findsOneWidget);
      expect(find.text('Drill esquiva en parejas sin pausa'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hub_tab_history')));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Conectar cocorinha con salida lateral'),
          findsAtLeastNWidgets(1));
      expect(find.text('Datos de ejemplo del entorno local'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Creación rápida: múltiples enfoques, pregunta actualizada, conservación hacia Avanzada y vuelta a Rápida',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        buildHarness(themeMode: ThemeMode.light, size: const Size(1280, 900), ds: ds),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hub_quick_create_button')));
      await tester.pumpAndSettle();

      expect(find.text('3. ¿Qué quieres trabajar hoy?'), findsOneWidget);
      expect(find.text('Indicación rápida'), findsNothing);

      // Todos los 6 enfoques disponibles y selección múltiple
      for (final f in kPlannerFocusOptions) {
        expect(find.byKey(Key('quick_focus_$f')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('quick_focus_Juegos')));
      await tester.tap(find.byKey(const Key('quick_focus_Roda')));
      await tester.tap(find.byKey(const Key('quick_duration_75')));
      await tester.enterText(
        find.byKey(const Key('quick_free_instructions_field')),
        'Trabajar en parejas continuas',
      );
      await tester.pumpAndSettle();

      // Selección opcional de recurso en rápida
      await tester.ensureVisible(
          find.byKey(const Key('quick_toggle_optional_picker')));
      await tester.tap(find.byKey(const Key('quick_toggle_optional_picker')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quick_res_idea_res_01')));
      await tester.tap(find.byKey(const Key('quick_res_idea_res_01')));
      await tester.pumpAndSettle();

      // Pasar a Avanzada conservando el estado y sin referencias técnicas en UI
      await tester.ensureVisible(find.byKey(const Key('quick_to_advanced_button')));
      await tester.tap(find.byKey(const Key('quick_to_advanced_button')));
      await tester.pumpAndSettle();

      expect(find.text('Planificación Pedagógica Detallada'), findsOneWidget);
      expect(find.text('Trabajar en parejas continuas'), findsOneWidget);
      expect(find.textContaining('Zero-PII'), findsNothing);
      expect(find.textContaining('PED-04C'), findsNothing);
      expect(find.textContaining('UID'), findsNothing);

      // Regresar a Rápida verificando que se conserva un objetivo personalizado añadido en Avanzada
      await tester.ensureVisible(find.byKey(const Key('adv_custom_objective_field')));
      await tester.enterText(
        find.byKey(const Key('adv_custom_objective_field')),
        'Conexión esquiva-rolê fluida',
      );
      await tester.tap(find.byKey(const Key('adv_add_objective_button')));
      await tester.pumpAndSettle();
      expect(find.text('Conexión esquiva-rolê fluida ×'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('advanced_to_quick_button')));
      await tester.tap(find.byKey(const Key('advanced_to_quick_button')));
      await tester.pumpAndSettle();
      expect(find.text('Trabajar en parejas continuas'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('quick_to_advanced_button')));
      await tester.tap(find.byKey(const Key('quick_to_advanced_button')));
      await tester.pumpAndSettle();
      expect(find.text('Conexión esquiva-rolê fluida ×'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Creación avanzada: valida suma de alumnos, ajusta al total, filtra recursos, edita usageNote y crea borrador',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.light,
          size: const Size(1440, 960),
          ds: ds,
          initialCreationMode: PlannerCreationMode.advanced,
        ),
      );
      await tester.pumpAndSettle();

      // Incrementar alumnos de 12 a 13 -> la distribución suma 12/13 y bloquea el borrador
      final addParticipantIcon = find.descendant(
        of: find.byKey(const Key('adv_participants_stepper')),
        matching: find.byIcon(Icons.add),
      );
      await tester.ensureVisible(addParticipantIcon);
      await tester.tap(addParticipantIcon);
      await tester.pumpAndSettle();

      expect(find.textContaining('Faltan 1 alumnos (12/13)'), findsOneWidget);
      final createBtnBefore = tester.widget<ElevatedButton>(
          find.byKey(const Key('advanced_create_draft_button')));
      expect(createBtnBefore.onPressed, isNull);

      // Usar botón Ajustar al total -> habilita el borrador
      await tester.ensureVisible(
          find.byKey(const Key('adv_adjust_distribution_button')));
      await tester.tap(find.byKey(const Key('adv_adjust_distribution_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Suma exacta: 13 / 13'), findsOneWidget);

      // Filtrar recursos por búsqueda y seleccionar con nota de uso y prioridad
      await tester.ensureVisible(
          find.byKey(const Key('adv_resources_search_field')));
      await tester.enterText(
          find.byKey(const Key('adv_resources_search_field')), 'batido');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adv_resource_idea_res_03')), findsOneWidget);
      expect(find.byKey(const Key('adv_resource_idea_res_01')), findsNothing);

      await tester.tap(find.byKey(const Key('adv_resource_idea_res_03')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.byKey(const Key('adv_resource_usage_idea_res_03')));
      await tester.enterText(
        find.byKey(const Key('adv_resource_usage_idea_res_03')),
        'Practicar progresión en colchoneta',
      );
      await tester.ensureVisible(find.byKey(const Key('adv_res_opt_idea_res_03')));
      await tester.tap(find.byKey(const Key('adv_res_opt_idea_res_03')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.byKey(const Key('advanced_create_draft_button')));
      await tester.tap(find.byKey(const Key('advanced_create_draft_button')));
      await tester.pumpAndSettle();

      final plans = await ds.loadPlans();
      expect(plans.first.planStatus, ClassPlanStatus.draft);
      expect(plans.first.participantsCount, 13);
      expect(
          plans.first.detectedOrigins,
          isNot(contains(ContentOrigin.aiComplementaryProposal)));

      // Al abrir el detalle del borrador recién creado, muestra aviso explícito de borrador local sin IA
      await tester.tap(find.text('Ver plan').first);
      await tester.pumpAndSettle();
      expect(find.text('Borrador local sin generación IA'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ClassPlanSummarySheet),
          matching: find.text('Propuesta IA'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Creación avanzada: selector curricular FIU agrega movimientos y permite prioridad Obligatorio/Opcional',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.light,
          size: const Size(1440, 960),
          initialCreationMode: PlannerCreationMode.advanced,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.byKey(const Key('adv_open_curriculum_picker')));
      await tester.tap(find.byKey(const Key('adv_open_curriculum_picker')));
      await tester.pumpAndSettle();

      // Dentro de CurriculoBibliotecaScreen en modo selección
      expect(find.text('Usar en planificador'), findsOneWidget);
      final selectBtn = find.byIcon(Icons.add_circle_outline_rounded).first;
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usar en planificador'));
      await tester.pumpAndSettle();

      expect(find.text('1 movimientos FIU · 0 recursos'), findsOneWidget);
      // Cambiar prioridad del movimiento seleccionado a Opcional
      await tester.ensureVisible(find.text('Opcional').first);
      await tester.tap(find.text('Opcional').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Pizarra de recursos: añade recurso local, busca/filtra, planifica sin marcar como usado',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.dark,
          size: const Size(1280, 900),
          ds: ds,
          initialTab: PlannerHubTab.resources,
        ),
      );
      await tester.pumpAndSettle();

      // Añadir un nuevo recurso local tipo Nota
      await tester.tap(find.byKey(const Key('pizarra_add_resource_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('local_res_title_field')),
        'Secuencia prueba espejo',
      );
      await tester.tap(find.byKey(const Key('local_res_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Secuencia prueba espejo'), findsOneWidget);

      // Filtrar en Pizarra por búsqueda para ubicar idea_res_03 (no usado) y planificar sin marcar como usado
      await tester.enterText(
          find.byKey(const Key('pizarra_search_field')), 'Aú batido');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('pizarra_select_idea_res_03')));
      await tester.tap(find.byKey(const Key('pizarra_select_idea_res_03')));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('1 recurso(s) seleccionado(s) para planificar'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('pizarra_use_in_quick_button')));
      await tester.pumpAndSettle();

      expect(find.text('1 de Pizarra'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('quick_create_draft_button')));
      await tester.tap(find.byKey(const Key('quick_create_draft_button')));
      await tester.pumpAndSettle();

      final resourcesAfter = await ds.loadResources();
      final res03 =
          resourcesAfter.firstWhere((r) => r.resourceId == 'idea_res_03');
      expect(res03.hasBeenTaught, isFalse);
      expect(res03.timesUsed, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Historial: filtra por grupo, abre detalle de sesión y salta a Preparar siguiente clase con continuidad',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.light,
          size: const Size(1280, 900),
          initialTab: PlannerHubTab.history,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Movimientos:'), findsAtLeastNWidgets(1));
      expect(find.text('Cocorinha'), findsAtLeastNWidgets(1));

      // Filtrar por Kids M/J 18:00
      await tester.tap(find.text('Kids M/J 18:00').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Juegos motores'), findsOneWidget);
      expect(find.textContaining('Esquivas bajas y transición'), findsNothing);

      // Abrir detalle de sesión y pulsar Preparar siguiente clase
      await tester.ensureVisible(
          find.byKey(const Key('history_detail_ses_20261112_kids')));
      await tester.tap(
          find.byKey(const Key('history_detail_ses_20261112_kids')));
      await tester.pumpAndSettle();
      expect(find.text('Movimientos practicados'), findsOneWidget);
      expect(find.text('Aú'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Preparar siguiente clase').last);
      await tester.pumpAndSettle();
      expect(find.text('Continuidad de sesión anterior'), findsOneWidget);
      expect(find.text('Currículo Infantil FIU en preparación'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Responsive y temas: sin fallback adulto para niños en móvil oscuro ni tablet claro',
        (tester) async {
      // Móvil oscuro (390x844)
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.dark,
          size: const Size(390, 844),
          initialCreationMode: PlannerCreationMode.quick,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_group_clase_kids_mj_1800')));
      await tester.pumpAndSettle();
      expect(find.text('Currículo Infantil FIU en preparación'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tablet claro (834x1024)
      await tester.binding.setSurfaceSize(const Size(834, 1024));
      await tester.pumpWidget(
        buildHarness(
          themeMode: ThemeMode.light,
          size: const Size(834, 1024),
          initialCreationMode: PlannerCreationMode.quick,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_group_clase_roda_sabado_mixto')));
      await tester.pumpAndSettle();
      expect(
          find.text('Grupo mixto sin pista curricular automática'),
          findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(null);
    });
  });
}

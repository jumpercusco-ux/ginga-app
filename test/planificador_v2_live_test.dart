import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/core/theme/theme_manager.dart';
import 'package:ginga_app/features/biblioteca/movimiento_detalle_screen.dart';
import 'package:ginga_app/features/instructor/instructor_pizarra_screen.dart';
import 'package:ginga_app/features/instructor/planificador/models/class_plan_models.dart';
import 'package:ginga_app/features/instructor/planificador/models/live_session_models.dart';
import 'package:ginga_app/features/instructor/planificador/services/live_session_persistence.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_data_source.dart';
import 'package:ginga_app/features/instructor/planificador/widgets/planner_hub_body.dart';
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

  group('PED-04C1 Unit · Temporizador, navegación, snapshot e idempotencia', () {
    test('Temporizador resiste segundo plano por reloj de pared, pausa, reanudación, ajustes y reinicio', () async {
      final ds = InMemoryPlannerDataSource.demoFixtures();
      final plans = await ds.loadPlans();
      final resources = await ds.loadResources();
      final v2Plan = plans.firstWhere((p) => p.id == 'v2_plan_adulto_01');

      var now = DateTime(2026, 11, 26, 19, 0, 0);
      var state = LiveSessionState.startFromPlan(
        plan: v2Plan,
        resources: resources,
        now: now,
        sessionId: 'ses_timer_test',
      );

      expect(state.isRunning, isTrue);
      expect(state.activeExerciseAllocatedSec, 720); // 12 min
      expect(state.effectiveActiveExerciseRemainingSec(now), 720);

      // Avanza 5 minutos simulados en segundo plano mientras está corriendo
      now = now.add(const Duration(minutes: 5));
      expect(state.effectiveTotalElapsedSec(now), 300);
      expect(state.effectiveActiveExerciseElapsedSec(now), 300);
      expect(state.effectiveActiveExerciseRemainingSec(now), 420);

      // Pausa: pasan 10 minutos más en segundo plano -> no debe sumar tiempo
      state = state.pause(now);
      expect(state.isRunning, isFalse);
      now = now.add(const Duration(minutes: 10));
      expect(state.effectiveTotalElapsedSec(now), 300);
      expect(state.effectiveActiveExerciseElapsedSec(now), 300);
      expect(state.effectiveActiveExerciseRemainingSec(now), 420);

      // Reanuda y ajusta +2 min / -1 min
      state = state.resume(now);
      state = state.adjustActiveExerciseMinutes(2, now);
      expect(state.activeExerciseAllocatedSec, 840);
      state = state.adjustActiveExerciseMinutes(-1, now);
      expect(state.activeExerciseAllocatedSec, 780);

      // Transcurre 1 min corriendo
      now = now.add(const Duration(minutes: 1));
      expect(state.effectiveTotalElapsedSec(now), 360);
      expect(state.effectiveActiveExerciseElapsedSec(now), 360);

      // Reiniciar ejercicio activo: reinicia el ejercicio (720s plan), conserva tiempo total (360s)
      state = state.resetActiveExerciseTimer(now);
      expect(state.effectiveTotalElapsedSec(now), 360);
      expect(state.effectiveActiveExerciseElapsedSec(now), 0);
      expect(state.effectiveActiveExerciseRemainingSec(now), 720);
    });

    test('Navegación, estados individuales y duración real por ejercicio + recuperación JSON', () async {
      final ds = InMemoryPlannerDataSource.demoFixtures();
      final plans = await ds.loadPlans();
      final resources = await ds.loadResources();
      final v2Plan = plans.firstWhere((p) => p.id == 'v2_plan_adulto_01');
      final storage = InMemoryLiveSessionStorage();

      var now = DateTime(2026, 11, 26, 19, 0, 0);
      var state = LiveSessionState.startFromPlan(
        plan: v2Plan,
        resources: resources,
        now: now,
        sessionId: 'ses_nav_test',
      );

      // 2 min en ejercicio 0 -> completar y avanzar a ejercicio 1
      now = now.add(const Duration(minutes: 2));
      state = state.markActiveStatus(
        LiveExerciseStatus.completed,
        now,
        advanceToNext: true,
      );
      expect(state.activeExerciseIndex, 1);
      expect(state.exercises[0].status, LiveExerciseStatus.completed);
      expect(state.exercises[0].actualDurationSec, 120);

      // 3 min en ejercicio 1 -> omitir y avanzar a ejercicio 2
      now = now.add(const Duration(minutes: 3));
      state = state.markActiveStatus(
        LiveExerciseStatus.skipped,
        now,
        advanceToNext: true,
      );
      expect(state.activeExerciseIndex, 2);
      expect(state.exercises[1].status, LiveExerciseStatus.skipped);
      expect(state.exercises[1].actualDurationSec, 180);

      // Persistir pausa para recuperación local
      state = state.pause(now);
      await storage.saveActiveSession(state);

      final recovered = await storage.loadActiveSession();
      expect(recovered, isNotNull);
      expect(recovered!.sessionId, 'ses_nav_test');
      expect(recovered.activeExerciseIndex, 2);
      expect(recovered.isRunning, isFalse);
      expect(recovered.exercises[0].status, LiveExerciseStatus.completed);
      expect(recovered.exercises[0].actualDurationSec, 120);
      expect(recovered.exercises[1].status, LiveExerciseStatus.skipped);
      expect(recovered.exercises[1].actualDurationSec, 180);
      expect(recovered.planSnapshot['titulo'], v2Plan.titulo);

      // Volver atrás al ejercicio 0 conserva tiempo real y estado
      final back = recovered.goToExercise(0, now);
      expect(back.activeExerciseIndex, 0);
      expect(back.exercises[0].actualDurationSec, 120);
    });

    test('Compatibilidad V1/V2, instantánea sin mutar el plan original y contabilización idempotente', () async {
      final ds = InMemoryPlannerDataSource.demoFixtures();
      final plansBefore = await ds.loadPlans();
      final legacyV1 = plansBefore.firstWhere((p) => p.id == 'legacy_plan_01');
      final resourcesBefore = await ds.loadResources();

      // Verifica estado inicial de idea_res_01 (timesUsed = 1) y idea_res_03 (timesUsed = 0)
      final res01Before =
          resourcesBefore.firstWhere((r) => r.resourceId == 'idea_res_01');
      expect(res01Before.timesUsed, 1);

      var now = DateTime(2026, 11, 26, 20, 0, 0);
      var state = LiveSessionState.startFromPlan(
        plan: legacyV1,
        resources: resourcesBefore,
        now: now,
        sessionId: 'ses_v1_idempotent',
      );
      expect(state.exercises.length, 3);
      // Bloque 1 del plan V1 tenía recurso_relacionado: 'Drill esquiva en parejas' -> resuelve idea_res_01
      expect(state.exercises[1].resolvedResourceIds, contains('idea_res_01'));

      // Ejercicio 0 (sin recursos) completado, Ejercicio 1 (con idea_res_01) OMITIDO -> no debe contarse
      now = now.add(const Duration(minutes: 10));
      state = state.markActiveStatus(
        LiveExerciseStatus.completed,
        now,
        advanceToNext: true,
      );
      state = state.markActiveStatus(
        LiveExerciseStatus.skipped,
        now,
        advanceToNext: true,
      );
      expect(state.taughtResourceIds, isEmpty);

      // Si marcamos Ejercicio 1 como completado y Ejercicio 0 como omitido, ahora sí debe contar idea_res_01
      state = state.goToExercise(1, now).markActiveStatus(
            LiveExerciseStatus.completed,
            now,
          );
      expect(state.taughtResourceIds, equals({'idea_res_01'}));

      final record = state.toTaughtSessionRecord(
        finishedAt: now,
        closure: const LiveSessionClosureInput(
          groupResponse: 'Excelente',
          teacherObservations: 'Grupo muy concentrado.',
          difficulties: 'Ajustar distancia en cocorinha.',
          reinforceContent: 'Salida lateral fluida.',
          continuityProposal: 'Agregar armada con esquiva.',
          endedEarly: true,
          attendeesCount: 11,
        ),
        movementNamesById: const {},
      );

      final firstRecorded = await ds.recordCompletedLiveSession(
        record,
        taughtResourceIds: state.taughtResourceIds,
      );
      final duplicateRecorded = await ds.recordCompletedLiveSession(
        record,
        taughtResourceIds: state.taughtResourceIds,
      );

      expect(firstRecorded, isTrue);
      expect(duplicateRecorded, isFalse);

      final resourcesAfter = await ds.loadResources();
      final res01After =
          resourcesAfter.firstWhere((r) => r.resourceId == 'idea_res_01');
      // Incrementó exactamente una vez (1 -> 2), sin duplicado
      expect(res01After.timesUsed, 2);
      expect(res01After.hasBeenTaught, isTrue);

      // Historial no se duplicó
      final historyAfter = await ds.loadHistory();
      expect(
        historyAfter.where((h) => h.sessionId == 'ses_v1_idempotent').length,
        1,
      );

      // Plan original actualiza solo ultimaEjecucion y vecesImpartida sin alterar contenido pedagógico
      final plansAfter = await ds.loadPlans();
      final legacyAfter = plansAfter.firstWhere((p) => p.id == 'legacy_plan_01');
      expect(legacyAfter.ultimaEjecucion, now);
      expect(legacyAfter.vecesImpartida, legacyV1.vecesImpartida + 1);
      expect(legacyAfter.titulo, legacyV1.titulo);
      expect(legacyAfter.duracionTotal, legacyV1.duracionTotal);
      expect(legacyAfter.objetivo, legacyV1.objetivo);
      expect(
        legacyAfter.bloques.map((b) => b.toMap()).toList(),
        equals(legacyV1.bloques.map((b) => b.toMap()).toList()),
      );
      expect(record.planSnapshot, isNotNull);
      expect(record.planSnapshot!['titulo'], legacyV1.titulo);
    });

    test('toAiSafeRequestMap sanitiza nombres y PII en observaciones e instrucciones de texto libre', () {
      const ctxWithPii = PedagogicalContinuityContext(
        groupId: 'clase_kids_mj_1800',
        groupName: 'Kids M/J 18:00',
        audienceType: PlannerAudienceType.infantil,
        completedExercises: ['Circuito de Cocorinha y Rolê'],
        practicedMovements: ['Cocorinha', 'Rolê'],
        difficulties:
            'El alumno Mateo Quispe tuvo dificultad; con Sofía faltó equilibrio. Tel +51 987 654 321.',
        teacherObservations:
            'Lucas necesita apoyo en São Bento Grande; contactar madre@ejemplo.com o DNI 76543210, nac. 12/04/2018, uid:usr_998877.',
        reinforceContent: 'Reforzar Meia Lua de Frente para Diego',
        continuityProposal: 'Seguir progresión con Valentina Mendoza',
      );
      const req = ClassPlanDraftRequest(
        creationMode: PlannerCreationMode.advanced,
        groupSource: PlannerGroupSource.realClass,
        realClaseId: 'clase_kids_mj_1800',
        groupName: 'Kids M/J 18:00',
        audienceType: PlannerAudienceType.infantil,
        curriculumScope: PlannerCurriculumScope.infantilFiuPending,
        ageMin: 6,
        ageMax: 11,
        participantsCount: 10,
        experienceDistribution: ExperienceDistribution(
          principiantes: 6,
          intermedios: 4,
          avanzados: 0,
        ),
        freeInstructions:
            'Vigilar postura de Mateo Quispe (@mateo_c) y pasar Cocorinha con pausa.',
        continuitySummary: 'Revisar avance con Sofía y Meia Lua',
        continuityContext: ctxWithPii,
      );

      final serialized = req.toAiSafeRequestMap().toString();
      expect(req.toAiSafeRequestMap()['pii_sanitized'], isTrue);

      // Ningún dato identificable permanece en el payload hacia IA
      for (final forbidden in const [
        'Mateo',
        'Quispe',
        'Sofía',
        'Lucas',
        'Diego',
        'Valentina',
        'Mendoza',
        '987 654 321',
        'madre@ejemplo.com',
        '76543210',
        '12/04/2018',
        'usr_998877',
        '@mateo_c',
      ]) {
        expect(serialized, isNot(contains(forbidden)));
      }

      // Se conserva el contexto técnico de Capoeira sin deformación
      expect(serialized, contains('Cocorinha'));
      expect(serialized, contains('Rolê'));
      expect(serialized, contains('São Bento Grande'));
      expect(serialized, contains('Meia Lua de Frente'));
      expect(serialized, contains('[participante]'));
      expect(serialized, contains('[correo_omitido]'));
      expect(serialized, contains('[telefono_omitido]'));
      expect(serialized, contains('[fecha_omitida]'));
      expect(serialized, contains('[id_omitido]'));
    });
  });

  group('PED-04C1 Widget · Ejecución en vivo E2E, consulta FIU, cierre y recuperación', () {
    testWidgets('Flujo completo desde Hub (Iniciar clase V2 -> consultar FIU y Pizarra -> cierre parcial -> Historial)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      final storage = InMemoryLiveSessionStorage();
      var fakeNow = DateTime(2026, 11, 26, 19, 0, 0);

      await tester.pumpWidget(
        MaterialApp(
          theme: gingaLightTheme,
          home: Scaffold(
            body: PlannerHubBody(
              dataSource: ds,
              curriculumRepository: curriculumRepo,
              liveSessionStorage: storage,
              clock: () => fakeNow,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir clase V2 adulto desde su botón Iniciar clase (índice 1 en orden de plans: legacy_01 es 0, v2_adulto es 1)
      final startButtons = find.text('Iniciar clase');
      expect(startButtons, findsNWidgets(3)); // V1 + V2 adulto + V2 infantil
      await tester.tap(startButtons.at(1));
      await tester.pumpAndSettle();

      // Verifica encabezado, reloj y detalles del ejercicio 1 (Juego espejo de esquivas en parejas)
      expect(find.text('Esquivas bajas y transición a rolê continuo'),
          findsOneWidget);
      expect(find.byKey(const Key('live_timer_display')), findsOneWidget);
      expect(find.text('Juego espejo de esquivas en parejas'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Rotación por parejas'), findsAtLeastNWidgets(1));
      expect(find.textContaining('2 metros entre parejas'), findsOneWidget);

      // Abrir recurso de Pizarra vinculado sin perder estado
      await tester.ensureVisible(find.byKey(const Key('live_res_btn_idea_res_02')));
      await tester.tap(find.byKey(const Key('live_res_btn_idea_res_02')));
      await tester.pumpAndSettle();
      expect(find.text('Consigna particular para este ejercicio'), findsOneWidget);
      await tester.tap(find.text('Volver a la clase'));
      await tester.pumpAndSettle();

      // Completar ejercicio 1 (contabilizará idea_res_02) tras 4 min simulados
      fakeNow = fakeNow.add(const Duration(minutes: 4));
      await tester.tap(find.byKey(const Key('live_complete_next_btn')));
      await tester.pumpAndSettle();

      // Ahora en ejercicio 2 (Cocorinha + salida en Rolê): verifica variantes y chips FIU
      expect(find.text('Cocorinha + salida en Rolê'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('live_variant_tab_Principiantes')), findsOneWidget);
      expect(find.byKey(const Key('live_variant_tab_Intermedios')), findsOneWidget);
      expect(find.byKey(const Key('live_variant_tab_Avanzados')), findsOneWidget);
      await tester.tap(find.byKey(const Key('live_variant_tab_Avanzados')));
      await tester.pumpAndSettle();
      expect(find.textContaining('negativa corta'), findsOneWidget);

      // Consultar movimiento FIU (cocorinha) abriendo MovimientoDetalleScreen y volver sin perder estado
      await tester.ensureVisible(find.byKey(const Key('live_mov_chip_cocorinha')));
      await tester.tap(find.byKey(const Key('live_mov_chip_cocorinha')));
      await tester.pumpAndSettle();
      expect(find.byType(MovimientoDetalleScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.text('Cocorinha + salida en Rolê'), findsAtLeastNWidgets(1));

      // Omitir ejercicio 2 y avanzar al ejercicio 3
      await tester.tap(find.byKey(const Key('live_skip_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Roda Benguela de diálogo corporal'), findsAtLeastNWidgets(1));

      // Finalizar anticipadamente (ejercicio 3 queda pendiente)
      await tester.tap(find.byKey(const Key('live_finish_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Cierre anticipado'), findsOneWidget);
      expect(find.text('1 realizados'), findsOneWidget);
      expect(find.text('2 omitidos / pendientes'), findsOneWidget);

      // Llenar formulario de cierre
      await tester.ensureVisible(
          find.byKey(const Key('closure_response_Excelente')));
      await tester.tap(find.byKey(const Key('closure_response_Excelente')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.byKey(const Key('closure_observations_field')));
      await tester.enterText(
        find.byKey(const Key('closure_observations_field')),
        'Excelente ritmo en espejo inicial.',
      );
      await tester.ensureVisible(
          find.byKey(const Key('closure_difficulties_field')));
      await tester.enterText(
        find.byKey(const Key('closure_difficulties_field')),
        'Faltó tiempo para entrar en la roda.',
      );
      await tester.ensureVisible(
          find.byKey(const Key('closure_reinforce_field')));
      await tester.enterText(
        find.byKey(const Key('closure_reinforce_field')),
        'Mirada continua en rolê.',
      );
      await tester.ensureVisible(
          find.byKey(const Key('closure_continuity_field')));
      await tester.enterText(
        find.byKey(const Key('closure_continuity_field')),
        'Retomar Cocorinha + Rolê con calma en la próxima sesión.',
      );
      await tester.ensureVisible(
          find.byKey(const Key('closure_confirm_save_btn')));
      await tester.tap(find.byKey(const Key('closure_confirm_save_btn')));
      await tester.pumpAndSettle();

      // Vuelve al Hub en la pestaña Historial con el nuevo registro no simulado
      expect(find.text('Excelente ritmo en espejo inicial.'), findsOneWidget);
      expect(
        find.text('Retomar Cocorinha + Rolê con calma en la próxima sesión.'),
        findsOneWidget,
      );

      // Abre detalle de la sesión recién guardada para verificar campos de cierre y snapshot
      final historyDetailBtns = find.text('Ver detalle');
      await tester.ensureVisible(historyDetailBtns.first);
      await tester.tap(historyDetailBtns.first);
      await tester.pumpAndSettle();
      expect(find.text('Respuesta: Excelente'), findsOneWidget);
      expect(find.text('Instantánea del plan conservada'), findsOneWidget);
      expect(find.text('Faltó tiempo para entrar en la roda.'), findsOneWidget);
      expect(find.text('Mirada continua en rolê.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // Verifica que idea_res_02 incrementó exactamente 1 vez (2 -> 3)
      final resAfter = await ds.loadResources();
      final res02 = resAfter.firstWhere((r) => r.resourceId == 'idea_res_02');
      expect(res02.timesUsed, 3);
      expect(await storage.loadActiveSession(), isNull);
    });

    testWidgets('Recuperación local restaura sesión interrumpida desde banner del Hub', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      final plans = await ds.loadPlans();
      final resources = await ds.loadResources();
      final v2Plan = plans.firstWhere((p) => p.id == 'v2_plan_adulto_01');
      final t0 = DateTime(2026, 11, 26, 19, 0, 0);
      final interrupted = LiveSessionState.startFromPlan(
        plan: v2Plan,
        resources: resources,
        now: t0,
        sessionId: 'ses_recover_widget',
      )
          .markActiveStatus(
            LiveExerciseStatus.completed,
            t0.add(const Duration(minutes: 6)),
            advanceToNext: true,
          )
          .pause(t0.add(const Duration(minutes: 6)));

      final storage = InMemoryLiveSessionStorage(initialSession: interrupted);

      await tester.pumpWidget(
        MaterialApp(
          theme: gingaLightTheme,
          home: Scaffold(
            body: PlannerHubBody(
              dataSource: ds,
              curriculumRepository: curriculumRepo,
              liveSessionStorage: storage,
              clock: () => t0.add(const Duration(minutes: 15)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hub_resume_live_banner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('hub_resume_live_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Cocorinha + salida en Rolê'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Ejercicio 2 de 3'), findsOneWidget);
    });

    testWidgets('Compatibilidad con plan V1 y responsive en escritorio/tablet/móvil claro y oscuro sin overflow', (tester) async {
      final viewports = <({String name, Size size, ThemeMode theme, String planId})>[
        (name: 'desktop_light', size: const Size(1440, 900), theme: ThemeMode.light, planId: 'legacy_plan_01'),
        (name: 'tablet_dark', size: const Size(834, 1024), theme: ThemeMode.dark, planId: 'v2_plan_adulto_01'),
        (name: 'mobile_dark', size: const Size(390, 844), theme: ThemeMode.dark, planId: 'v2_plan_infantil_01'),
      ];

      for (final vp in viewports) {
        await tester.binding.setSurfaceSize(vp.size);
        await ThemeManager.instance.setThemeMode(vp.theme);

        final ds = InMemoryPlannerDataSource.demoFixtures();
        final storage = InMemoryLiveSessionStorage();
        final fakeNow = DateTime(2026, 11, 26, 19, 30, 0);

        await tester.pumpWidget(
          MaterialApp(
            theme: gingaLightTheme,
            darkTheme: gingaDarkTheme,
            themeMode: vp.theme,
            home: Scaffold(
              body: InstructorPizarraScreen(
                dataSource: ds,
                curriculumRepository: curriculumRepo,
                liveSessionStorage: storage,
                initialLivePlanId: vp.planId,
                clock: () => fakeNow,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('live_timer_display')), findsOneWidget,
            reason: 'Falta temporizador en ${vp.name}');
        expect(find.byKey(const Key('live_complete_next_btn')), findsOneWidget,
            reason: 'Falta botón principal en ${vp.name}');
        expect(tester.takeException(), isNull,
            reason: 'Overflow/excepción detectada en ${vp.name}');
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Cierre funcional: Ver todos los niveles, advertencia 00:00, continuidad limpia en cierre y actualización de ultimaEjecucion', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      final plansBefore = await ds.loadPlans();
      final v2Before = plansBefore.firstWhere((p) => p.id == 'v2_plan_adulto_01');
      final storage = InMemoryLiveSessionStorage();
      var fakeNow = DateTime(2026, 11, 26, 19, 0, 0);

      await tester.pumpWidget(
        MaterialApp(
          theme: gingaLightTheme,
          home: Scaffold(
            body: PlannerHubBody(
              dataSource: ds,
              curriculumRepository: curriculumRepo,
              liveSessionStorage: storage,
              clock: () => fakeNow,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar clase').at(1));
      await tester.pumpAndSettle();

      // Intentar completar ejercicio 1 con tiempo real 00:00 -> muestra advertencia manual
      await tester.tap(find.byKey(const Key('live_complete_next_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live_zero_duration_dialog')), findsOneWidget);

      // Cancelar conserva ejercicio 1 activo
      await tester.tap(find.byKey(const Key('live_cancel_zero_complete_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Juego espejo de esquivas en parejas'), findsAtLeastNWidgets(1));

      // Confirmar manualmente 00:00 completa ejercicio 1 y avanza al ejercicio 2
      await tester.tap(find.byKey(const Key('live_complete_next_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('live_confirm_zero_complete_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Cocorinha + salida en Rolê'), findsAtLeastNWidgets(1));

      // Activar "Ver todos los niveles" muestra simultáneamente Principiantes, Intermedios y Avanzados
      await tester.ensureVisible(find.byKey(const Key('live_variant_all_btn')));
      await tester.tap(find.byKey(const Key('live_variant_all_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live_all_variants_panel')), findsOneWidget);
      expect(find.textContaining('Pausa breve en cocorinha'), findsOneWidget);
      expect(find.textContaining('mirada continua hacia la pareja'), findsOneWidget);
      expect(find.textContaining('negativa corta y entrada'), findsOneWidget);

      // Avanzar tiempo real en ejercicio 2 y abrir cierre anticipado -> campo continuidad vacío (sin texto residual)
      fakeNow = fakeNow.add(const Duration(minutes: 5));
      await tester.tap(find.byKey(const Key('live_finish_btn')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const Key('closure_continuity_field')),
        find.byType(ListView).last,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      final continuityEditable = tester.widget<TextField>(
        find.byKey(const Key('closure_continuity_field')),
      );
      expect(continuityEditable.controller?.text, isEmpty);

      // Botón opcional rellena sugerencia si el instructor decide usarla
      await tester.ensureVisible(
          find.byKey(const Key('closure_suggest_pending_btn')));
      await tester.tap(find.byKey(const Key('closure_suggest_pending_btn')));
      await tester.pumpAndSettle();
      expect(continuityEditable.controller?.text, contains('Retomar:'));

      // Guardar sesión y verificar actualización de ultimaEjecucion sin alterar bloques del plan original
      await tester.ensureVisible(
          find.byKey(const Key('closure_confirm_save_btn')));
      await tester.tap(find.byKey(const Key('closure_confirm_save_btn')));
      await tester.pumpAndSettle();

      final plansAfter = await ds.loadPlans();
      final v2After = plansAfter.firstWhere((p) => p.id == 'v2_plan_adulto_01');
      expect(v2After.ultimaEjecucion, fakeNow);
      expect(v2After.vecesImpartida, v2Before.vecesImpartida + 1);
      expect(
        v2After.bloques.map((b) => b.toMap()).toList(),
        equals(v2Before.bloques.map((b) => b.toMap()).toList()),
      );
    });

    testWidgets('Contexto pedagógico estructurado en Preparar siguiente clase, borrador, editor y aislamiento estricto por grupo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1360, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ds = InMemoryPlannerDataSource.demoFixtures();
      await tester.pumpWidget(
        MaterialApp(
          theme: gingaLightTheme,
          home: Scaffold(
            body: PlannerHubBody(
              dataSource: ds,
              curriculumRepository: curriculumRepo,
              initialTab: PlannerHubTab.history,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filtrar por Kids y abrir Preparar siguiente clase desde su sesión
      await tester.tap(find.text('Kids M/J 18:00').first);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const Key('history_prepare_next_ses_20261112_kids')),
        find.byType(ListView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const Key('history_prepare_next_ses_20261112_kids')));
      await tester.pumpAndSettle();

      // Verificar resumen expandible y todos los campos estructurados del grupo Kids
      expect(find.byKey(const Key('continuity_context_card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('continuity_context_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continuity_context_expanded_body')),
          findsOneWidget);
      expect(find.textContaining('Circuito animal: sapo, cangrejo'), findsOneWidget);
      expect(find.textContaining('Coro responsorial y ritmo en pandeiro'),
          findsOneWidget);
      expect(find.textContaining('Ginga, Cocorinha, Aú'), findsOneWidget);
      expect(find.textContaining('cierre rítmico tras el circuito'), findsOneWidget);
      expect(find.textContaining('Palmas de 3 tiempos'), findsOneWidget);
      expect(find.textContaining('Reforzar canto responsorial'), findsAtLeastNWidgets(1));

      // Cambiar a grupo Mixto (sin historial propio) -> debe limpiar la continuidad
      await tester.tap(find.byKey(const Key('quick_group_clase_roda_sabado_mixto')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continuity_context_card')), findsNothing);

      // Cambiar a grupo Adultos -> debe cargar la continuidad exclusiva de Adultos (nunca de Kids)
      await tester.tap(find.byKey(const Key('quick_group_clase_adultos_mj_1900')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continuity_context_card')), findsOneWidget);
      expect(find.textContaining('meia lua de frente'), findsOneWidget);

      // Crear borrador local y verificar conservación en borrador + editor + contrato IA Zero-PII
      await tester.ensureVisible(find.byKey(const Key('quick_create_draft_button')));
      await tester.tap(find.byKey(const Key('quick_create_draft_button')));
      await tester.pumpAndSettle();

      final plansAfterDraft = await ds.loadPlans();
      final createdDraft = plansAfterDraft.first;
      expect(createdDraft.continuityContext, isNotNull);
      expect(createdDraft.continuityContext!.groupName, 'Adultos M/J 19:00');
      expect(createdDraft.continuityContext!.toAiSafeMap()['worked_movements'],
          contains('Cocorinha'));

      // Abrir editor sobre el borrador recién creado -> mantiene contexto expandible
      await tester.tap(find.text('Editar plan').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continuity_context_card')), findsOneWidget);
    });
  });
}

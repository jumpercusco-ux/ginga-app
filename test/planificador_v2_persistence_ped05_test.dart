import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/features/instructor/planificador/models/class_plan_models.dart';
import 'package:ginga_app/features/instructor/planificador/models/live_session_models.dart';
import 'package:ginga_app/features/instructor/planificador/services/live_session_persistence.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_copilot_client.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_data_source.dart';
import 'package:ginga_app/features/instructor/planificador/widgets/planner_hub_body.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: gingaLightTheme,
    home: Scaffold(body: child),
  );
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('PED-05 Ciclo de vida, concurrencia multidispositivo y continuidad', () {
    test('Valida matriz explícita de transiciones de ClassPlanStatus y alias planned', () {
      expect(ClassPlanStatus.fromId('planned'), ClassPlanStatus.saved);
      expect(ClassPlanStatus.draft.canTransitionTo(ClassPlanStatus.saved), isTrue);
      expect(ClassPlanStatus.draft.canTransitionTo(ClassPlanStatus.completed), isFalse);
      expect(ClassPlanStatus.saved.canTransitionTo(ClassPlanStatus.inProgress), isTrue);
      expect(ClassPlanStatus.inProgress.canTransitionTo(ClassPlanStatus.completed), isTrue);
      expect(ClassPlanStatus.inProgress.canTransitionTo(ClassPlanStatus.archived), isFalse);
      expect(ClassPlanStatus.archived.canTransitionTo(ClassPlanStatus.saved), isTrue);
    });

    test('Continuidad grupal aislada Zero-PII acumula últimas sesiones sin mezclar grupos', () {
      final adultOld = TaughtSessionRecord(
        sessionId: 'ses_a_1',
        planId: 'p1',
        planTitle: 'Clase Adultos 1',
        groupId: 'clase_adultos_mj_1900',
        groupName: 'Adultos M/J 19:00',
        audienceType: PlannerAudienceType.adultos,
        date: DateTime(2026, 11, 20),
        durationMin: 60,
        attendeesCount: 10,
        completedExercisesCount: 2,
        totalExercisesCount: 2,
        practicedMovements: const ['Ginga', 'Cocorinha'],
        summaryNote: 'Buen ritmo',
        reinforceContent: 'Guardia alta',
        pendingNextSession: 'Conectar Rolê.',
      );
      final adultNew = TaughtSessionRecord(
        sessionId: 'ses_a_2',
        planId: 'p2',
        planTitle: 'Clase Adultos 2',
        groupId: 'clase_adultos_mj_1900',
        groupName: 'Adultos M/J 19:00',
        audienceType: PlannerAudienceType.adultos,
        date: DateTime(2026, 11, 25),
        durationMin: 60,
        attendeesCount: 12,
        completedExercisesCount: 3,
        totalExercisesCount: 3,
        practicedMovements: const ['Armada', 'Cocorinha'],
        summaryNote: 'Excelente distancia',
        reinforceContent: 'Giro de cadera en Armada',
        pendingNextSession: 'Practicar Armada + Negativa.',
      );
      final kidsSession = TaughtSessionRecord(
        sessionId: 'ses_k_1',
        planId: 'pk1',
        planTitle: 'Clase Kids',
        groupId: 'clase_kids_mj_1800',
        groupName: 'Infantil M/J 18:00',
        audienceType: PlannerAudienceType.infantil,
        date: DateTime(2026, 11, 26),
        durationMin: 55,
        attendeesCount: 9,
        completedExercisesCount: 2,
        totalExercisesCount: 2,
        practicedMovements: const ['Aú'],
        summaryNote: 'El niño Mateo Pérez avanzó con saltos',
        reinforceContent: 'Palmas de 3 tiempos',
        pendingNextSession: 'Juegos de animales.',
      );

      final adultCtx = PedagogicalContinuityContext.fromGroupHistory(
        [adultOld, kidsSession, adultNew],
        groupId: 'clase_adultos_mj_1900',
        groupName: 'Adultos M/J 19:00',
        audienceType: PlannerAudienceType.adultos,
      );
      expect(adultCtx, isNotNull);
      expect(adultCtx!.practicedMovements, containsAll(['Armada', 'Cocorinha', 'Ginga']));
      expect(adultCtx.practicedMovements, isNot(contains('Aú')));
      expect(adultCtx.continuityProposal, contains('Practicar Armada + Negativa.'));
      expect(adultCtx.continuityProposal, isNot(contains('Juegos de animales')));

      final safeMap = adultCtx.toCopilotSummaryMap();
      expect(safeMap['pii_sanitized'], isTrue);
      expect(safeMap['worked_movements'], isA<List>());
    });

    test('FirebaseFunctionsPlannerCopilotClient envía continuity_context y mapea errores', () async {
      Map<String, dynamic>? capturedPayload;
      final samplePlan = InMemoryPlannerDataSource.demoFixtures();
      final plans = await samplePlan.loadPlans();
      final plan = plans[1];

      final client = FirebaseFunctionsPlannerCopilotClient(
        callableInvoker: (payload) async {
          capturedPayload = payload;
          return {
            'status': 'ok',
            'mode': 'consult',
            'resulting_draft_version': 'v_abc',
            'assistant_message': 'Respuesta remota controlada',
            'generation_meta': {'is_simulated': true, 'model': 'simulated-copilot-v1'},
          };
        },
      );

      final resp = await client.sendMessage(
        plan: plan,
        baseDraftVersion: 'v_abc',
        message: '¿Qué reforzar según la clase anterior?',
        continuityContext: const PedagogicalContinuityContext(
          groupId: 'clase_adultos_mj_1900',
          groupName: 'Adultos M/J 19:00',
          audienceType: PlannerAudienceType.adultos,
          reinforceContent: 'Esquiva baja continua',
          continuityProposal: 'Conectar con rolê lateral',
        ),
      );

      expect(resp.assistantMessage, 'Respuesta remota controlada');
      final reqMap = capturedPayload!['request'] as Map<String, dynamic>;
      expect(reqMap['continuity_context'], isA<Map<String, dynamic>>());
      expect(
        (reqMap['continuity_context'] as Map<String, dynamic>)['reinforce_content'],
        'Esquiva baja continua',
      );
    });

    testWidgets(
      'Multidispositivo: detecta conflicto de revisión y permite resolver sin sobrescribir',
      (tester) async {
        _setDesktopViewport(tester);
        final seed = InMemoryPlannerDataSource.demoFixtures();
        final pcSource = InMemoryPlannerDataSource.shared(
          store: seed.backingStore,
          instructorUid: 'prof_1',
          defaultDeviceId: 'pc_device',
        );
        final mobileSource = InMemoryPlannerDataSource.shared(
          store: seed.backingStore,
          instructorUid: 'prof_1',
          defaultDeviceId: 'mobile_device',
        );

        await tester.pumpWidget(
          _wrapWithMaterial(
            PlannerHubBody(
              dataSource: mobileSource,
              liveSessionStorage: InMemoryLiveSessionStorage(),
              initialEditingPlanId: 'v2_plan_adulto_01',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Mientras el móvil tiene abierta la rev 1, la PC guarda rev 2 remotamente
        final remotePlan = (await pcSource.loadPlanById('v2_plan_adulto_01'))!;
        await pcSource.savePlan(
          remotePlan.copyWith(titulo: 'Título guardado desde PC'),
          expectedRevision: remotePlan.revision,
        );

        // El móvil intenta guardar su edición sobre rev 1
        await tester.tap(find.byKey(const Key('editor_save_button')));
        await tester.pumpAndSettle();

        // Debe aparecer el diálogo de conflicto y ofrecer ambas salidas seguras
        expect(find.byKey(const Key('planner_concurrency_conflict_dialog')), findsOneWidget);
        expect(find.byKey(const Key('conflict_reload_remote_btn')), findsOneWidget);
        expect(find.byKey(const Key('conflict_save_copy_btn')), findsOneWidget);

        // Cargar versión más reciente actualiza el editor sin sobrescribir la PC
        await tester.tap(find.byKey(const Key('conflict_reload_remote_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('planner_concurrency_conflict_dialog')), findsNothing);
        expect(find.text('Título guardado desde PC'), findsWidgets);
        final stillInStore = await pcSource.loadPlanById('v2_plan_adulto_01');
        expect(stillInStore!.revision, 2);
      },
    );

    testWidgets(
      'Fallo de conexión mantiene borrador abierto en el editor y permite reintentar con éxito',
      (tester) async {
        _setDesktopViewport(tester);
        final ds = InMemoryPlannerDataSource.demoFixtures();
        ds.nextWriteError = StateError('Sin conexión temporal');

        await tester.pumpWidget(
          _wrapWithMaterial(
            PlannerHubBody(
              dataSource: ds,
              liveSessionStorage: InMemoryLiveSessionStorage(),
              initialEditingPlanId: 'v2_plan_adulto_01',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Primer guardado falla por red
        await tester.tap(find.byKey(const Key('editor_save_button')));
        await tester.pumpAndSettle();

        // El editor permanece abierto (no pierde cambios) y muestra badge pendiente
        expect(find.byKey(const Key('editor_save_button')), findsOneWidget);
        expect(find.byKey(const Key('editor_sync_state_badge')), findsOneWidget);

        // Recuperada la conexión, segundo guardado tiene éxito
        await tester.tap(find.byKey(const Key('editor_save_button')));
        await tester.pumpAndSettle();

        final updated = await ds.loadPlanById('v2_plan_adulto_01');
        expect(updated!.revision, 2);
      },
    );

    testWidgets(
      'Copiloto aplica modificación, guarda en repositorio y conserva sesión en vivo recuperable',
      (tester) async {
        _setDesktopViewport(tester);
        final ds = InMemoryPlannerDataSource.demoFixtures();
        final liveStorage = InMemoryLiveSessionStorage();

        await tester.pumpWidget(
          _wrapWithMaterial(
            PlannerHubBody(
              dataSource: ds,
              liveSessionStorage: liveStorage,
              initialEditingPlanId: 'v2_plan_adulto_01',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Abrir Copiloto IA y enviar instrucción controlada offline
        await tester.tap(find.byKey(const Key('editor_copilot_toggle_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('copilot_input_field')),
          'Redistribuye la clase a 45 minutos',
        );
        await tester.tap(find.byKey(const Key('copilot_send_button')));
        await tester.pumpAndSettle();

        // Aplicar propuesta y guardar plan
        await tester.tap(find.byKey(const Key('copilot_apply_button')).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('editor_save_button')));
        await tester.pumpAndSettle();

        final persisted = await ds.loadPlanById('v2_plan_adulto_01');
        expect(persisted!.duracionTotal, 45);
        expect(persisted.lastCopilotSummary, isNotNull);
        expect(persisted.lastCopilotSummary!['operations_count'], 1);

        // Iniciar clase en vivo y validar persistencia recuperable
        final plans = await ds.loadPlans();
        final state = LiveSessionState.startFromPlan(
          plan: plans.firstWhere((p) => p.id == 'v2_plan_adulto_01'),
          resources: await ds.loadResources(),
          now: DateTime(2026, 11, 27, 19, 0),
        );
        await liveStorage.saveActiveSession(state);
        final recovered = await liveStorage.loadActiveSession();
        expect(recovered, isNotNull);
        expect(recovered!.planId, 'v2_plan_adulto_01');
      },
    );
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/features/instructor/planificador/models/class_plan_models.dart';
import 'package:ginga_app/features/instructor/planificador/models/copilot_models.dart';
import 'package:ginga_app/features/instructor/planificador/services/copilot_operation_applier.dart';
import 'package:ginga_app/features/instructor/planificador/services/live_session_persistence.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_copilot_client.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_data_source.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_v2_engine_client.dart';
import 'package:ginga_app/features/instructor/planificador/widgets/planner_class_editor_view.dart';
import 'package:ginga_app/features/instructor/planificador/widgets/planner_hub_body.dart';

class _ErrorCopilotClient implements PlannerCopilotClient {
  final PlannerV2EngineException error;
  _ErrorCopilotClient(this.error);

  @override
  Future<CopilotTurnResponse> sendMessage({
    required ClassPlanModel plan,
    required String baseDraftVersion,
    required String message,
    String? selectedBlockId,
    String? selectedExerciseId,
    List<PlannerResourceItem> availableResources = const [],
    List<CopilotChatMessage> conversationHistory = const [],
    List<String>? confirmedMaterials,
  }) async {
    throw error;
  }

  @override
  Future<List<CopilotChatMessage>> fetchSavedPreviewSession({
    required ClassPlanModel plan,
  }) async =>
      const [];
}

void main() {
  late InMemoryPlannerDataSource ds;
  late ClassPlanModel infantil8of8;
  late List<PlannerResourceItem> resources;

  setUp(() async {
    ds = InMemoryPlannerDataSource.copilotDemoFixtures();
    final plans = await ds.loadPlans();
    infantil8of8 = plans.firstWhere((p) => p.id == 'v2_plan_infantil_8of8_demo');
    resources = await ds.loadResources();
  });

  test('1-8 & 14: Copiloto offline cubre consulta, ediciones acotadas, redistribución 45m, conflictos y preservación', () async {
    final client = OfflineSimulatedPlannerCopilotClient();
    final v0 = computeDraftVersion(infantil8of8);

    // 1. Consulta pedagógica sin cambios
    final consult = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Explica errores frecuentes en Armada y Ginga',
      selectedBlockId: 'blk_2',
      selectedExerciseId: 'blk_2_ex_1',
      availableResources: resources,
    );
    expect(consult.mode, CopilotMode.consult);
    expect(consult.proposedPlan, isNull);

    // 2. Modificación de un único ejercicio conservando hermanos y recursos
    final single = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Ajusta este ejercicio con participación simultánea',
      selectedBlockId: 'blk_1',
      selectedExerciseId: 'blk_1_ex_1',
      availableResources: resources,
    );
    expect(single.mode, CopilotMode.proposeChanges);
    final appliedSingle = CopilotOperationApplier.applyProposal(
      currentPlan: infantil8of8,
      proposal: single,
      availableResources: resources,
    );
    expect(appliedSingle.bloques[0].ejercicios[1].nombre,
        infantil8of8.bloques[0].ejercicios[1].nombre);
    expect(appliedSingle.bloques[2].ejercicios[0].linkedResourceIds, ['idea_res_02']);

    // 3. Sustitución de juego por Armada
    final armada = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Sustituye este juego por otro de Armada',
      selectedBlockId: 'blk_3',
      selectedExerciseId: 'blk_3_ex_2',
      availableResources: resources,
    );
    expect(armada.proposedPlan!.bloques[2].ejercicios[1].nombre, contains('Armada'));
    expect(armada.proposedPlan!.bloques[2].ejercicios[0].linkedResourceIds, ['idea_res_02']);

    // 4. Adaptación de Aú por niveles
    final au = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Adapta Aú por niveles',
      selectedBlockId: 'blk_4',
      selectedExerciseId: 'blk_4_ex_1',
      availableResources: resources,
    );
    expect(au.proposedPlan!.bloques[3].ejercicios[0].differentiationBeginner,
        contains('apoyos progresivos'));
    expect(au.proposedPlan!.bloques[3].ejercicios[0].differentiationAdvanced,
        contains('Perfeccionamiento de Aú'));

    // 5. Incorporación de recurso de Pizarra (con honestidad de video)
    final linkRes = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Incorpora el recurso de Pizarra seleccionado',
      selectedBlockId: 'blk_2',
      selectedExerciseId: 'blk_2_ex_1',
      availableResources: [resources.firstWhere((r) => r.resourceId == 'idea_res_03')],
    );
    expect(linkRes.proposedPlan!.bloques[1].ejercicios[0].linkedResourceIds,
        contains('idea_res_03'));
    expect(linkRes.proposedPlan!.bloques[1].ejercicios[0].videoReferenceNote,
        contains('no inspecciona visualmente'));

    // 6. Redistribución 60 -> 45 min
    final red45 = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Redistribuye toda la clase a 45 minutos',
      availableResources: resources,
    );
    expect(red45.proposedPlan!.duracionTotal, 45);
    expect(red45.proposedPlan!.plannedDurationMin, 45);
    for (final b in red45.proposedPlan!.bloques) {
      expect(b.exercisesTotalDurationMin, b.duracionMin);
    }

    // 7. Rechazo de materiales no disponibles
    final noMats = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Cambia el ejercicio para usar colchonetas y sillas',
      availableResources: resources,
    );
    expect(noMats.mode, CopilotMode.conflict);
    expect(noMats.proposedPlan, isNull);
    expect(noMats.safeAlternative, isNotNull);

    // 8. Rechazo de progresiones inseguras
    final unsafe = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: v0,
      message: 'Añade Bananeira y Mortal en el bloque de suelo',
      availableResources: resources,
    );
    expect(unsafe.mode, CopilotMode.conflict);
    expect(unsafe.proposedPlan, isNull);
  });

  test('10. Conflicto entre propuesta IA y edición manual posterior bloquea sobrescritura', () async {
    final client = OfflineSimulatedPlannerCopilotClient();
    final proposal = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: computeDraftVersion(infantil8of8),
      message: 'Redistribuye a 45 minutos',
    );
    final manuallyEdited = infantil8of8.copyWith(
      bloques: [
        for (var i = 0; i < infantil8of8.bloques.length; i++)
          if (i == 0)
            infantil8of8.bloques[i].copyWith(fase: 'Calentamiento Editado Manual')
          else
            infantil8of8.bloques[i],
      ],
    );
    expect(
      () => CopilotOperationApplier.applyProposal(
        currentPlan: manuallyEdited,
        proposal: proposal,
        availableResources: resources,
      ),
      throwsA(isA<CopilotDraftConflictException>()),
    );
  });

  testWidgets('9, 10, 11. UI: Aplicar, Descartar, Deshacer IA, conflicto por edición manual y conservación tras timeout', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    ClassPlanModel? savedPlan;
    await tester.pumpWidget(
      MaterialApp(
        theme: gingaLightTheme,
        home: Scaffold(
          body: PlannerClassEditorView(
            initialPlan: infantil8of8,
            resources: resources,
            copilotClient: OfflineSimulatedPlannerCopilotClient(),
            onSavePlan: (p) => savedPlan = p,
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abrir Copiloto en escritorio
    await tester.tap(find.byKey(const Key('editor_copilot_toggle_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('copilot_panel_root')), findsOneWidget);

    // Proponer cambio de duración a 45 min y aplicar explícitamente
    await tester.enterText(
      find.byKey(const Key('copilot_input_field')),
      'Redistribuye toda la clase a 45 minutos',
    );
    await tester.tap(find.byKey(const Key('copilot_send_button')));
    await tester.pumpAndSettle();

    expect(find.text('Antes: 60 min'), findsOneWidget);
    expect(find.byKey(const Key('copilot_apply_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('copilot_apply_button')));
    await tester.pumpAndSettle();
    expect(find.text('Objetivo: 45 min'), findsOneWidget);

    // Deshacer IA restaura exactamente a 60 min
    await tester.tap(find.byKey(const Key('editor_copilot_undo_button')));
    await tester.pumpAndSettle();
    expect(find.text('Objetivo: 60 min'), findsOneWidget);

    // Segunda propuesta descartada NO altera 60 min
    await tester.enterText(
      find.byKey(const Key('copilot_input_field')),
      'Redistribuye a 45 minutos',
    );
    await tester.tap(find.byKey(const Key('copilot_send_button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('copilot_discard_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copilot_discard_button')));
    await tester.pumpAndSettle();
    expect(find.text('Propuesta descartada.'), findsOneWidget);

    // Guardar y comprobar que el plan permanece limpio
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();
    expect(savedPlan?.duracionTotal, 60);

    // Timeout / error conserva texto escrito y borrador abierto
    await tester.pumpWidget(
      MaterialApp(
        theme: gingaLightTheme,
        home: Scaffold(
          body: PlannerClassEditorView(
            key: const ValueKey('editor_error_test'),
            initialPlan: infantil8of8,
            resources: resources,
            copilotClient: _ErrorCopilotClient(
              const PlannerV2EngineException(
                code: 'PROVIDER_TIMEOUT',
                userMessage: 'Tiempo de espera agotado al consultar al copiloto.',
              ),
            ),
            onSavePlan: (_) {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor_copilot_toggle_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('copilot_input_field')),
      'Adapta Aú por niveles',
    );
    await tester.tap(find.byKey(const Key('copilot_send_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('copilot_error_banner')), findsOneWidget);
    final tf = tester.widget<TextField>(find.byKey(const Key('copilot_input_field')));
    expect(tf.controller?.text, 'Adapta Aú por niveles');
  });

  testWidgets('12. Compatibilidad completa: Aplicar en Copiloto -> Guardar -> Iniciar clase en vivo', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: gingaLightTheme,
        home: Scaffold(
          body: PlannerHubBody(
            dataSource: ds,
            copilotClient: OfflineSimulatedPlannerCopilotClient(),
            liveSessionStorage: InMemoryLiveSessionStorage(),
            initialEditingPlanId: 'v2_plan_infantil_8of8_demo',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_copilot_toggle_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('copilot_input_field')),
      'Redistribuye a 45 minutos',
    );
    await tester.tap(find.byKey(const Key('copilot_send_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copilot_apply_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    // Inicia la clase modificada en vivo sin errores
    final savedPlans = await ds.loadPlans();
    final updated8of8 =
        savedPlans.firstWhere((p) => p.id == 'v2_plan_infantil_8of8_demo');
    expect(updated8of8.duracionTotal, 45);
    expect(find.text('45 min'), findsWidgets);
    final listFinder = find.byType(ListView).first;
    await tester.drag(listFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
    final startBtn = find.text('Iniciar clase').last;
    await tester.ensureVisible(startBtn);
    await tester.pumpAndSettle();
    await tester.tap(startBtn);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live_timer_display')), findsOneWidget);
    expect(find.textContaining('Infantil M/J 18:00'), findsWidgets);
  });

  testWidgets('13. Diseño adaptable a Tablet (834) y Móvil (390) en claro y oscuro sin desbordamientos', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
    };
    try {
      for (final cfg in [
        (size: const Size(834, 1024), theme: gingaLightTheme),
        (size: const Size(390, 844), theme: gingaDarkTheme),
      ]) {
        await tester.binding.setSurfaceSize(cfg.size);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('app_${cfg.size.width}'),
            theme: cfg.theme,
            home: MediaQuery(
              data: MediaQueryData(size: cfg.size),
              child: Scaffold(
                body: PlannerClassEditorView(
                  key: ValueKey('editor_${cfg.size.width}'),
                  initialPlan: infantil8of8,
                  resources: resources,
                  copilotClient: OfflineSimulatedPlannerCopilotClient(),
                  onSavePlan: (_) {},
                  onCancel: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggleBtn = find.byKey(const Key('editor_copilot_toggle_button'));
        await tester.ensureVisible(toggleBtn);
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('copilot_panel_root')), findsOneWidget);
        final closeBtn = find.byKey(const Key('copilot_close_button'));
        await tester.ensureVisible(closeBtn);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
      }
    } finally {
      FlutterError.onError = prevOnError;
      await tester.binding.setSurfaceSize(null);
    }
    expect(
      errors.where((e) => e.exceptionAsString().contains('RenderFlex overflowed')),
      isEmpty,
    );
  });

  test('15. HttpLocalPlannerCopilotClient usa POST HTTP real y carga sesión guardada sin simulador local', () async {
    String? postedPath;
    final mockHttp = MockClient((req) async {
      if (req.method == 'POST' && req.url.path == '/api/planner-v2/copilot') {
        postedPath = req.url.path;
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'mode': 'consult',
            'resulting_draft_version': 'srv_v1',
            'assistant_message': 'Respuesta real de OpenAI sobre Armada.',
            'pedagogical_notes': ['Mirada antes de patear'],
            'operations': [],
            'diff_summary': [],
            'generation_meta': {
              'provider': 'openai',
              'model': 'gpt-4o-mini',
              'is_simulated': false,
            },
          }),
          200,
        );
      }
      if (req.method == 'GET' &&
          req.url.path == '/api/planner-v2/copilot/last-session') {
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'has_session': true,
            'session': {
              'turns': [
                {
                  'user_message': 'Consulta real Armada',
                  'timestamp': '2026-11-27T07:00:00Z',
                  'response': {
                    'status': 'ok',
                    'mode': 'consult',
                    'assistant_message': 'Sesión guardada OpenAI.',
                    'generation_meta': {
                      'provider': 'openai',
                      'model': 'gpt-4o-mini',
                      'is_simulated': false,
                    },
                  },
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final client = HttpLocalPlannerCopilotClient(
      baseUrl: 'http://127.0.0.1:8097',
      httpClient: mockHttp,
    );
    final resp = await client.sendMessage(
      plan: infantil8of8,
      baseDraftVersion: computeDraftVersion(infantil8of8),
      message: '¿Qué errores debo corregir al enseñar Armada?',
      availableResources: resources,
    );
    expect(postedPath, '/api/planner-v2/copilot');
    expect(resp.isSimulated, false);
    expect(resp.modelName, 'gpt-4o-mini');
    expect(resp.assistantMessage, contains('OpenAI'));

    final saved = await client.fetchSavedPreviewSession(plan: infantil8of8);
    expect(saved.length, 2);
    expect(saved.last.response?.isSimulated, false);
    expect(saved.last.response?.modelName, 'gpt-4o-mini');
  });
}

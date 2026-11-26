import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/theme/ginga_theme.dart';
import 'package:ginga_app/features/instructor/planificador/models/class_plan_models.dart';
import 'package:ginga_app/features/instructor/planificador/services/live_session_persistence.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_data_source.dart';
import 'package:ginga_app/features/instructor/planificador/services/planner_v2_engine_client.dart';
import 'package:ginga_app/features/instructor/planificador/widgets/planner_class_editor_view.dart';
import 'package:ginga_app/features/instructor/planificador/widgets/planner_hub_body.dart';

class _FakeFailingThenSucceedingEngineClient implements PlannerV2EngineClient {
  int calls = 0;
  final List<ClassPlanDraftRequest> receivedRequests = [];
  bool failNextCall;

  _FakeFailingThenSucceedingEngineClient({this.failNextCall = true});

  @override
  Future<PlannerV2GenerationResult> generatePlan({
    required ClassPlanDraftRequest request,
    String? requestId,
  }) async {
    calls++;
    receivedRequests.add(request);
    if (failNextCall) {
      failNextCall = false;
      throw const PlannerV2EngineException(
        code: 'PROVIDER_TIMEOUT',
        userMessage:
            'El motor tardó demasiado en responder. Tu borrador está a salvo; puedes reintentar.',
        retryable: true,
      );
    }

    final simulatedBackendJson = {
      'contract_version': '2.1.0',
      'status': 'ok',
      'plan': {
        'titulo': 'Clase Infantil M/J 18:00 · Ginga y Aú',
        'duracion_total': request.durationMin,
        'nivel': 'Infantil',
        'audience_type': request.audienceType.id,
        'curriculum_scope': request.curriculumScope.id,
        'enfoque': request.focus,
        'objetivo': 'Diferenciar Ginga para principiantes y Aú para avanzados.',
        'objetivos': ['Participación simultánea sin colas'],
        'space_snapshot': request.spaceContext.toMap(),
        'bloques': [
          {
            'block_id': 'blk_inf_1',
            'fase': 'Calentamiento Lúdico & Juegos Motores',
            'duracion_min': 15,
            'ejercicios': [
              {
                'exercise_id': 'ex_inf_1_1',
                'nombre': 'Juego Semáforo de Ginga',
                'detalle':
                    'Preparación y 3 rondas activas (Tiempos internos: 2 min preparación + 12 min rondas + 1 min agua = total: 15 min).',
                'duracion_min': 15,
                'organizacion': 'Todos simultáneamente',
                'diferenciacion_principiantes': 'Ginga lenta con 2 señales.',
                'diferenciacion_intermedios': '3 señales manteniendo ritmo.',
                'diferenciacion_avanzados': 'Aú lateral limpio sin acrobacia compleja.',
                'seguridad': 'Mantener 1.5m entre participantes.',
                'content_origin': 'ai_complementary_proposal',
                'source_origins': ['ai_complementary_proposal'],
                'activity_authoring': 'ai_complementary_proposal',
                'curriculum_movement_ids': [],
                'linked_resource_ids': request.selectedResources
                    .map((r) => r.resource.resourceId)
                    .toList(),
              },
            ],
          },
          {
            'block_id': 'blk_inf_2',
            'fase': 'Roda Infantil & Cierre',
            'duracion_min': request.durationMin - 15,
            'ejercicios': [
              {
                'exercise_id': 'ex_inf_2_1',
                'nombre': 'Canto y palmas rítmicas',
                'detalle': 'Canto responsorial en círculo y estiramiento suave.',
                'duracion_min': request.durationMin - 15,
                'organizacion': 'Todos simultáneamente',
                'seguridad': 'Juego cooperativo sin contacto.',
                'content_origin': 'ai_complementary_proposal',
                'cancionero_reference': {
                  'song_title': 'Marinheiro só',
                  'rhythm': 'Corrido',
                  'audience_fit': 'infantil',
                  'cantiga_id': null,
                  'lookup_hint': 'Consultar en Cancionero por título',
                },
              },
            ],
          },
        ],
        'consejos_instructor': 'Currículo Infantil FIU en preparación.',
        'continuity_applied_note': 'Sin sesión previa.',
      },
      'generation_meta': {
        'engine_version': 'planner_v2.1.0',
        'provider': 'simulated',
        'model': 'simulated-planner-v2',
        'is_simulated': true,
        'repair_attempts_used': 0,
        'transparency_notices': [
          'No se asumieron tatami ni colchonetas al no estar declarados.',
        ],
      },
      'privacy_notice': {
        'heuristic_disclaimer':
            'La sanitización heurística no garantiza ausencia absoluta de PII.',
      },
    };

    return PlannerV2ResponseAdapter.fromJsonResponse(
      simulatedBackendJson,
      request,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Contrato v2.1.0 no asume materiales ni superficie desconocida en Infantil M/J 18:00',
      () {
    final ds = InMemoryPlannerDataSource.demoFixtures();
    expect(ds, isNotNull);

    const kidsGroup = PlannerGroupProfile(
      id: 'clase_kids_mj_1800',
      name: 'Infantil M/J 18:00',
      source: PlannerGroupSource.realClass,
      audienceType: PlannerAudienceType.infantil,
      scheduleSummary: 'Martes y Jueves · 18:00',
      ageMin: 5,
      ageMax: 11,
      participantsCount: 10,
      defaultDistribution: ExperienceDistribution(
        principiantes: 6,
        intermedios: 2,
        avanzados: 2,
      ),
    );

    final req = ClassPlanDraftRequest.fromGroup(kidsGroup);
    expect(req.materials, isEmpty);
    expect(req.materialsConfirmed, isFalse);
    expect(req.spaceContext.floorType, 'desconocido');
    expect(req.spaceContext.availableMats, isNull);
    expect(req.spaceContext.instructorsAvailable, 1);

    final wireMap = req.toPlannerV2RequestMap(requestId: 'req_test_kids');
    expect(wireMap.containsKey('provider_mode'), isFalse);
    expect(wireMap.containsKey('model'), isFalse);
    expect(wireMap.containsKey('quota'), isFalse);
    expect((wireMap['space_context'] as Map)['floor_type'], 'desconocido');
    expect((wireMap['space_context'] as Map).containsKey('available_mats'),
        isFalse);
    expect((wireMap['session_config'] as Map).containsKey('materials'), isFalse);
  });

  test('HttpLocalPlannerV2Client reintenta ante 502 manteniendo request_id y adapta respuesta',
      () async {
    int attempts = 0;
    final seenRequestIds = <String>[];

    final mockHttp = MockClient((httpReq) async {
      attempts++;
      final decodedBody = jsonDecode(httpReq.body) as Map<String, dynamic>;
      final reqObj = decodedBody['request'] as Map<String, dynamic>;
      seenRequestIds.add(reqObj['request_id'] as String);

      if (attempts == 1) {
        return http.Response(
          jsonEncode({
            'status': 'error',
            'error': {
              'code': 'PROVIDER_TIMEOUT',
              'message': 'Timeout simulado',
              'retryable': true,
            },
          }),
          504,
        );
      }

      return http.Response(
        jsonEncode({
          'contract_version': '2.1.0',
          'status': 'ok',
          'plan': {
            'titulo': 'Plan Adultos M/J 19:00',
            'duracion_total': 60,
            'nivel': 'Adultos',
            'audience_type': 'adultos',
            'curriculum_scope': 'adulto_fiu',
            'enfoque': 'Técnica',
            'objetivo': 'Queixada + Esquiva lateral',
            'objetivos': ['Queixada + Esquiva lateral'],
            'bloques': [
              {
                'block_id': 'blk_1',
                'fase': 'Técnica',
                'duracion_min': 60,
                'ejercicios': [
                  {
                    'exercise_id': 'ex_1',
                    'nombre': 'Queixada + Esquiva',
                    'detalle': 'Trabajo simultáneo en parejas.',
                    'duracion_min': 60,
                    'organizacion': 'Rotación por parejas',
                    'content_origin': 'official_fiu_curriculum',
                    'curriculum_movement_ids': ['queixada', 'esquiva_lateral'],
                    'cancionero_reference': {
                      'song_title': 'Paraná ê',
                      'rhythm': 'Benguela',
                      'audience_fit': 'adultos',
                      'cantiga_id': null,
                      'lookup_hint': 'Buscar por título',
                    },
                  },
                ],
              },
            ],
          },
          'generation_meta': {
            'engine_version': 'planner_v2.1.0',
            'provider': 'simulated',
            'model': 'simulated-planner-v2',
            'is_simulated': true,
          },
        }),
        200,
      );
    });

    final client = HttpLocalPlannerV2Client(
      baseUrl: 'http://127.0.0.1:8097',
      httpClient: mockHttp,
    );

    const req = ClassPlanDraftRequest(
      creationMode: PlannerCreationMode.quick,
      groupSource: PlannerGroupSource.realClass,
      realClaseId: 'clase_adultos_mj_1900',
      groupName: 'Adultos M/J 19:00',
      audienceType: PlannerAudienceType.adultos,
      curriculumScope: PlannerCurriculumScope.adultoFiu,
      ageMin: 16,
      ageMax: 40,
      participantsCount: 12,
      experienceDistribution:
          ExperienceDistribution(principiantes: 5, intermedios: 5, avanzados: 2),
    );

    final res = await client.generatePlan(request: req, requestId: 'req_fixed');
    expect(attempts, 2);
    expect(seenRequestIds, ['req_fixed', 'req_fixed']);
    expect(res.plan.titulo, 'Plan Adultos M/J 19:00');
    expect(res.plan.generationMeta?.isSimulated, isTrue);
    expect(
      res.plan.bloques.first.ejercicios.first.cancioneroReference?.songTitle,
      'Paraná ê',
    );
    expect(
      res.plan.bloques.first.ejercicios.first.cancioneroReference?.cantigaId,
      isNull,
    );
  });

  testWidgets(
      'Flujo E2E: error preserva formulario -> reintento genera y abre Editor -> guarda y ejecuta en vivo',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final ds = InMemoryPlannerDataSource.demoFixtures();
    final fakeEngine = _FakeFailingThenSucceedingEngineClient(failNextCall: true);
    final liveStorage = InMemoryLiveSessionStorage();
    final jsonStr =
        File('data/curriculum/fiu_adulto_v1.json').readAsStringSync();
    final currDs = InMemoryCurriculumDataSource.fromJsonString(jsonStr);
    final currRepo = CurriculumRepository(dataSource: currDs);

    await tester.pumpWidget(
      MaterialApp(
        theme: gingaLightTheme,
        home: Scaffold(
          body: PlannerHubBody(
            dataSource: ds,
            curriculumRepository: currRepo,
            engineClient: fakeEngine,
            liveSessionStorage: liveStorage,
            initialCreationMode: PlannerCreationMode.quick,
            initialGroupIdForCreation: 'clase_kids_mj_1800',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verificar badge de modo simulado y grupo Infantil M/J 18:00 preseleccionado
    expect(find.byKey(const Key('quick_simulated_mode_badge')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('quick_free_instructions_field')),
      'Trabajar Ginga y progresiones iniciales de Aú sin tiempos muertos.',
    );
    await tester.pump();

    // 2. Primer intento falla: formulario queda intacto y aparece banner de error
    await tester.ensureVisible(find.byKey(const Key('quick_generate_v2_button')));
    await tester.tap(find.byKey(const Key('quick_generate_v2_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick_generation_error_banner')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Ginga y progresiones iniciales de Aú'),
      findsOneWidget,
    );

    // 3. Reintento exitoso abre automáticamente PlannerClassEditorView con banner de modo simulado
    await tester.ensureVisible(find.byKey(const Key('quick_generate_v2_button')));
    await tester.tap(find.byKey(const Key('quick_generate_v2_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlannerClassEditorView), findsOneWidget);
    expect(find.byKey(const Key('editor_generated_mode_banner')), findsOneWidget);
    expect(find.textContaining('Marinheiro só'), findsOneWidget);

    // 4. Guardar propuesta generada manualmente -> vuelve al Hub sin marcar recursos
    await tester.ensureVisible(find.byKey(const Key('editor_save_button')));
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    final savedPlans = await ds.loadPlans();
    expect(
      savedPlans.any((p) => p.titulo == 'Clase Infantil M/J 18:00 · Ginga y Aú'),
      isTrue,
    );
    // Verificar que los recursos existentes no fueron contabilizados al generar/guardar
    final resAfterSave = await ds.loadResources();
    expect(
      resAfterSave.firstWhere((r) => r.resourceId == 'idea_res_03').timesUsed,
      0,
    );

    // 5. Ejecutar en vivo y registrar cierre en Historial
    await tester.ensureVisible(find.text('Iniciar clase').first);
    await tester.tap(find.text('Iniciar clase').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live_complete_next_btn')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Responsive sin overflows en Escritorio, Tablet y Móvil con Creación Avanzada',
      (tester) async {
    final ds = InMemoryPlannerDataSource.demoFixtures();
    final fakeEngine = _FakeFailingThenSucceedingEngineClient(failNextCall: false);

    for (final size in const [
      Size(1440, 900),
      Size(834, 1024),
      Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: gingaLightTheme,
          home: Scaffold(
            body: PlannerHubBody(
              dataSource: ds,
              engineClient: fakeEngine,
              initialCreationMode: PlannerCreationMode.advanced,
              initialGroupIdForCreation: 'clase_kids_mj_1800',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adv_simulated_mode_badge')), findsOneWidget);
      expect(find.byKey(const Key('adv_instructors_stepper')), findsOneWidget);
      expect(find.byKey(const Key('advanced_generate_v2_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
  });
}

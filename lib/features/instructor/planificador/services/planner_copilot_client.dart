import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../models/class_plan_models.dart';
import '../models/copilot_models.dart';
import 'copilot_operation_applier.dart';
import 'planner_v2_engine_client.dart';

abstract class PlannerCopilotClient {
  Future<CopilotTurnResponse> sendMessage({
    required ClassPlanModel plan,
    required String baseDraftVersion,
    required String message,
    String? selectedBlockId,
    String? selectedExerciseId,
    List<PlannerResourceItem> availableResources = const [],
    List<CopilotChatMessage> conversationHistory = const [],
    List<String>? confirmedMaterials,
    PedagogicalContinuityContext? continuityContext,
  });

  Future<List<CopilotChatMessage>> fetchSavedPreviewSession({
    required ClassPlanModel plan,
  }) async =>
      const [];
}

/// Cliente HTTP hacia `/api/planner-v2/copilot` del servidor local aislado.
class HttpLocalPlannerCopilotClient implements PlannerCopilotClient {
  final String baseUrl;
  final String? previewToken;
  final http.Client _http;
  final Duration timeout;

  HttpLocalPlannerCopilotClient({
    this.baseUrl = '',
    this.previewToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 55),
  }) : _http = httpClient ?? http.Client();

  Uri _copilotUri([String suffix = '/api/planner-v2/copilot']) {
    final base = baseUrl.trim();
    if (base.isEmpty) return Uri.parse(suffix);
    final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$clean$suffix');
  }

  @override
  Future<List<CopilotChatMessage>> fetchSavedPreviewSession({
    required ClassPlanModel plan,
  }) async {
    final headers = <String, String>{
      if (previewToken != null && previewToken!.trim().isNotEmpty)
        'X-Preview-Token': previewToken!.trim(),
    };
    try {
      final resp = await _http
          .get(
            _copilotUri('/api/planner-v2/copilot/last-session'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map || decoded['has_session'] != true) return const [];
      final session = decoded['session'];
      if (session is! Map) return const [];
      final turns = session['turns'];
      if (turns is! List || turns.isEmpty) return const [];

      final draftVersion = computeDraftVersion(plan);
      final out = <CopilotChatMessage>[];
      var idx = 0;
      for (final rawTurn in turns) {
        if (rawTurn is! Map) continue;
        final userText = rawTurn['user_message']?.toString().trim() ?? '';
        final rawResp = rawTurn['response'];
        final turnTs = DateTime.tryParse(rawTurn['timestamp']?.toString() ?? '') ??
            DateTime.now();
        if (userText.isNotEmpty) {
          out.add(
            CopilotChatMessage(
              id: 'saved_u_${idx++}',
              isUser: true,
              text: userText,
              timestamp: turnTs,
            ),
          );
        }
        if (rawResp is Map) {
          final respMap = Map<String, dynamic>.from(rawResp);
          final parsed = _parseOkTurnResponse(
            respMap,
            planId: plan.id,
            baseDraftVersion: draftVersion,
          );
          out.add(
            CopilotChatMessage(
              id: 'saved_a_${idx++}',
              isUser: false,
              text: parsed.assistantMessage,
              timestamp: turnTs,
              response: parsed,
            ),
          );
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static CopilotTurnResponse _parseOkTurnResponse(
    Map<String, dynamic> decoded, {
    required String planId,
    required String baseDraftVersion,
  }) {
    final rawProposed = decoded['proposed_plan'];
    final proposed = rawProposed is Map
        ? ClassPlanModel.fromMap(
            planId,
            Map<String, dynamic>.from(rawProposed),
          )
        : null;
    final genMeta = decoded['generation_meta'] is Map
        ? Map<String, dynamic>.from(decoded['generation_meta'] as Map)
        : const <String, dynamic>{};
    return CopilotTurnResponse(
      mode: CopilotMode.fromId(decoded['mode']?.toString()),
      baseDraftVersion: baseDraftVersion,
      resultingDraftVersion:
          decoded['resulting_draft_version']?.toString() ?? baseDraftVersion,
      assistantMessage: decoded['assistant_message']?.toString() ?? '',
      pedagogicalNotes: ((decoded['pedagogical_notes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      conflictReason: decoded['conflict_reason']?.toString(),
      safeAlternative: decoded['safe_alternative']?.toString(),
      operations: ((decoded['operations'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => CopilotOperation.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      diffSummary: ((decoded['diff_summary'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => CopilotDiffItem.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      proposedPlan: proposed,
      isSimulated: genMeta['is_simulated'] != false,
      modelName: genMeta['model']?.toString(),
    );
  }

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
    PedagogicalContinuityContext? continuityContext,
  }) async {
    final reqId = 'req_copilot_${DateTime.now().microsecondsSinceEpoch}';
    final effContinuity = continuityContext ?? plan.continuityContext;
    final payload = <String, dynamic>{
      'request_id': reqId,
      'base_draft_version': baseDraftVersion,
      'message': message,
      'selected_block_id': selectedBlockId,
      'selected_exercise_id': selectedExerciseId,
      if (confirmedMaterials != null) ...{
        'materials_known': true,
        'confirmed_materials': confirmedMaterials,
      },
      if (effContinuity != null && effContinuity.hasContent)
        'continuity_context': effContinuity.toCopilotSummaryMap(),
      'conversation_history': [
        for (final m in conversationHistory.take(6))
          {'role': m.isUser ? 'user' : 'assistant', 'text': m.text},
      ],
      'available_resources': [
        for (final r in availableResources)
          {
            'resource_id': r.resourceId,
            'title': r.title,
            'type': r.type,
            'category': r.category,
            'notes': r.notes,
            'has_external_video': r.hasExternalVideo,
          },
      ],
      'plan': plan.toMap(),
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (previewToken != null && previewToken!.trim().isNotEmpty)
        'X-Preview-Token': previewToken!.trim(),
    };

    try {
      final resp = await _http
          .post(_copilotUri(), headers: headers, body: jsonEncode(payload))
          .timeout(timeout);

      Map<String, dynamic> decoded = const {};
      try {
        final raw = jsonDecode(resp.body);
        if (raw is Map) decoded = Map<String, dynamic>.from(raw);
      } catch (_) {
        throw const PlannerV2EngineException(
          code: 'INVALID_RESPONSE',
          userMessage:
              'El copiloto devolvió una respuesta inválida. Tu borrador no fue modificado.',
          retryable: true,
        );
      }

      if (resp.statusCode >= 200 &&
          resp.statusCode < 300 &&
          decoded['status'] == 'ok') {
        return _parseOkTurnResponse(
          decoded,
          planId: plan.id,
          baseDraftVersion: baseDraftVersion,
        );
      }

      final err = decoded['error'] is Map
          ? Map<String, dynamic>.from(decoded['error'] as Map)
          : const <String, dynamic>{};
      final code = err['code']?.toString() ?? 'HTTP_${resp.statusCode}';
      throw PlannerV2EngineException(
        code: code,
        userMessage: err['message']?.toString() ??
            'Error al consultar al copiloto ($code). Tu borrador sigue intacto.',
        retryable: err['retryable'] == true,
      );
    } on PlannerV2EngineException {
      rethrow;
    } on TimeoutException {
      throw const PlannerV2EngineException(
        code: 'PROVIDER_TIMEOUT',
        userMessage:
            'Tiempo de espera agotado al consultar al copiloto. Tu borrador está protegido.',
        retryable: true,
      );
    } catch (e) {
      throw PlannerV2EngineException(
        code: 'LOCAL_TRANSPORT_UNAVAILABLE',
        userMessage:
            'No fue posible conectar con el copiloto local ($e). Tu borrador permanece intacto.',
        retryable: true,
      );
    }
  }
}

/// Proveedor simulado 100% offline para pruebas deterministas y fallback sin red.
class OfflineSimulatedPlannerCopilotClient extends PlannerCopilotClient {
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
    PedagogicalContinuityContext? continuityContext,
  }) async {
    final effContinuity = continuityContext ?? plan.continuityContext;
    final low = message.toLowerCase();
    final isInfantil = plan.audienceType == PlannerAudienceType.infantil;
    final floorType = plan.spaceSnapshot?.floorType ?? 'desconocido';
    final availMats = plan.spaceSnapshot?.availableMats;
    final matsSet = {
      for (final m in (confirmedMaterials ?? const <String>[])) m.toLowerCase(),
    };

    if (low.contains('firestore') ||
        low.contains('ignora') ||
        low.contains('currículo adulto para niños')) {
      return CopilotTurnResponse(
        mode: CopilotMode.conflict,
        baseDraftVersion: baseDraftVersion,
        resultingDraftVersion: baseDraftVersion,
        assistantMessage:
            'No puedo ejecutar acciones arbitrarias ni asignar currículo adulto FIU a Infantil.',
        conflictReason: 'Operación bloqueada por seguridad pedagógica y curricular.',
        safeAlternative:
            'Solicita ajustes concretos sobre progresiones, tiempos, diferenciación o recursos de Pizarra.',
      );
    }

    if ((low.contains('colchoneta') && availMats != true && !matsSet.contains('colchonetas')) ||
        (low.contains('silla') && !matsSet.contains('sillas')) ||
        (low.contains('cono') && !matsSet.contains('conos'))) {
      return CopilotTurnResponse(
        mode: CopilotMode.conflict,
        baseDraftVersion: baseDraftVersion,
        resultingDraftVersion: baseDraftVersion,
        assistantMessage:
            'Material solicitado no confirmado en el espacio actual.',
        conflictReason:
            'El borrador actual no confirma colchonetas/sillas/conos disponibles.',
        safeAlternative:
            'Puedo adaptar la dinámica sin material físico usando referencias visuales del suelo y palmas.',
      );
    }

    if (RegExp(r'\b(bananeira|mortal|parafuso|voltereta|ponte)\b').hasMatch(low) &&
        (isInfantil || floorType != 'tatami' || availMats != true)) {
      return CopilotTurnResponse(
        mode: CopilotMode.conflict,
        baseDraftVersion: baseDraftVersion,
        resultingDraftVersion: baseDraftVersion,
        assistantMessage:
            'Esa acrobacia vertical o rodada no es segura sin tatami/colchonetas confirmadas para este grupo.',
        conflictReason:
            'Riesgo de impacto o inversión vertical en piso "$floorType" no amortiguado.',
        safeAlternative:
            'Propongo trabajar preparación de Aú con apoyos bajos de manos o Rolê lateral controlado.',
      );
    }

    final isExplicitMutation = RegExp(
            r'\b(modifica|cambia|sustituye|reemplaza|añade|agrega|incorpora|redistribuye|adapta|ajusta|reduce|vincula)\b')
        .hasMatch(low);
    if (!isExplicitMutation ||
        RegExp(r'^(explica|dime|cómo|cuáles|qué errores|sugiere)').hasMatch(low)) {
      return CopilotTurnResponse(
        mode: CopilotMode.consult,
        baseDraftVersion: baseDraftVersion,
        resultingDraftVersion: baseDraftVersion,
        assistantMessage:
            'Consulta pedagógica: enfócate en base estable de Ginga, giro de cadera antes de extender Armada y apoyos firmes de manos en Aú. '
            'Recursos disponibles: ${availableResources.map((r) => r.title).join(', ')}.',
        pedagogicalNotes: [
          'Consulta informativa: no modifica tu clase actual.',
          if (effContinuity != null && effContinuity.hasContent)
            'Continuidad (${effContinuity.groupName}): ${effContinuity.shortHeadline}',
        ],
      );
    }

    // Redistribute duration (e.g. 45 min)
    final durMatch = RegExp(r'(\d{2,3})\s*min').firstMatch(low);
    if (low.contains('redistribu') || (low.contains('reducir') && durMatch != null)) {
      final target = int.tryParse(durMatch?.group(1) ?? '45') ?? 45;
      final ops = [
        CopilotOperation(
          type: 'redistribute_duration',
          targetDurationMin: target,
        ),
      ];
      final proposed = CopilotOperationApplier.applyTypedOperations(
        currentPlan: plan,
        operations: ops,
        availableResources: availableResources,
      );
      return CopilotTurnResponse(
        mode: CopilotMode.proposeChanges,
        baseDraftVersion: baseDraftVersion,
        resultingDraftVersion: computeDraftVersion(proposed),
        assistantMessage:
            'Propongo redistribuir los bloques y ejercicios proporcionalmente a $target min exactos.',
        operations: ops,
        diffSummary: [
          CopilotDiffItem(
            operationType: 'redistribute_duration',
            scopeLabel: 'Toda la clase',
            fieldLabel: 'Duración total',
            before: '${plan.duracionTotal} min',
            after: '$target min (${proposed.bloques.map((b) => '${b.duracionMin}m').join('+')})',
          ),
        ],
        proposedPlan: proposed,
      );
    }

    // Link Pizarra resource
    if (low.contains('recurso') || low.contains('pizarra')) {
      final res = availableResources.isNotEmpty ? availableResources.first : null;
      if (res == null) {
        return CopilotTurnResponse(
          mode: CopilotMode.conflict,
          baseDraftVersion: baseDraftVersion,
          resultingDraftVersion: baseDraftVersion,
          assistantMessage: 'No hay recursos de Pizarra disponibles.',
          conflictReason: 'Lista de recursos vacía.',
          safeAlternative: 'Añade un recurso en Pizarra primero.',
        );
      }
      final blk = plan.bloques.firstWhere(
        (b) => b.blockId == selectedBlockId,
        orElse: () => plan.bloques.first,
      );
      final ex = blk.ejercicios.firstWhere(
        (e) => e.exerciseId == selectedExerciseId,
        orElse: () => blk.ejercicios.first,
      );
      final ops = [
        CopilotOperation(
          type: 'link_resource',
          blockId: blk.blockId,
          exerciseId: ex.exerciseId,
          resourceId: res.resourceId,
          resourceUsageNote: 'Integrar "${res.title}" según notas del profesor.',
        ),
      ];
      final proposed = CopilotOperationApplier.applyTypedOperations(
        currentPlan: plan,
        operations: ops,
        availableResources: availableResources,
      );
      return CopilotTurnResponse(
        mode: CopilotMode.proposeChanges,
        baseDraftVersion: baseDraftVersion,
        resultingDraftVersion: computeDraftVersion(proposed),
        assistantMessage:
            'Propongo vincular el recurso "${res.title}" a "${ex.nombre}".',
        operations: ops,
        diffSummary: [
          CopilotDiffItem(
            operationType: 'link_resource',
            scopeLabel: ex.nombre,
            fieldLabel: 'Recurso vinculado',
            before: ex.linkedResourceIds.isEmpty
                ? 'Sin recurso'
                : ex.linkedResourceIds.join(', '),
            after: res.resourceId,
          ),
        ],
        proposedPlan: proposed,
      );
    }

    // Replace game with Armada
    if ((low.contains('sustitu') || low.contains('reemplaza')) && low.contains('armada')) {
      final blk = plan.bloques.firstWhere(
        (b) => b.blockId == selectedBlockId || b.faseTipo == 'juegos',
        orElse: () => plan.bloques.first,
      );
      final ex = blk.ejercicios.firstWhere(
        (e) => e.exerciseId == selectedExerciseId,
        orElse: () => blk.ejercicios.first,
      );
      final baseDur = (ex.duracionMin ?? 8).clamp(2, 180);
      final p1 = (baseDur / 3).floor().clamp(1, baseDur - 1);
      final ops = [
        CopilotOperation(
          type: 'replace_exercise',
          blockId: blk.blockId,
          exerciseId: ex.exerciseId,
          nombre: 'Juego Técnico de Armada y Esquiva por Señales',
          tipoActividad: 'juego_dinamico',
          detalle:
              'Objetivo: aplicar giro controlado de Armada y esquiva. Preparación: parejas a 2 m sin espera. Reglas y señales: cambio de lado con palmas del profesor. Rondas y rotación: rotar parejas cada 90 s.',
          organizacion: 'Rotación por parejas',
          diferenciacionPrincipiantes: 'Ginga base y media rotación de Armada.',
          diferenciacionIntermedios: 'Armada continua retornando a base.',
          diferenciacionAvanzados: 'Enlazar Armada limpia con Esquiva lateral.',
          technicalMovementRefs: const ['Ginga', 'Armada', 'Esquiva'],
          tiemposInternos: [
            PlannerInternalTiming(
              etapa: 'Preparación y postura',
              minutos: p1,
            ),
            PlannerInternalTiming(
              etapa: 'Rondas Armada y Esquiva',
              minutos: baseDur - p1,
            ),
          ],
        ),
      ];
      final proposed = CopilotOperationApplier.applyTypedOperations(
        currentPlan: plan,
        operations: ops,
        availableResources: availableResources,
      );
      return CopilotTurnResponse(
        mode: CopilotMode.proposeChanges,
        baseDraftVersion: baseDraftVersion,
        resultingDraftVersion: computeDraftVersion(proposed),
        assistantMessage:
            'Propongo sustituir "${ex.nombre}" por "Juego Técnico de Armada y Esquiva por Señales".',
        operations: ops,
        diffSummary: [
          CopilotDiffItem(
            operationType: 'replace_exercise',
            scopeLabel: '${blk.fase} · ${ex.exerciseId}',
            fieldLabel: 'Sustitución',
            before: ex.nombre,
            after: 'Juego Técnico de Armada y Esquiva por Señales',
          ),
        ],
        proposedPlan: proposed,
      );
    }

    // Default single-exercise / Aú adaptation
    final blk = plan.bloques.firstWhere(
      (b) => b.blockId == selectedBlockId,
      orElse: () => plan.bloques.first,
    );
    final ex = blk.ejercicios.firstWhere(
      (e) => e.exerciseId == selectedExerciseId,
      orElse: () => blk.ejercicios.first,
    );
    final isAu =
        RegExp(r'(?:^|[^a-záéíóúüñ])a[uú](?:$|[^a-záéíóúüñ])').hasMatch(low);
    final ops = [
      CopilotOperation(
        type: 'update_exercise',
        blockId: blk.blockId,
        exerciseId: ex.exerciseId,
        diferenciacionPrincipiantes: isAu
            ? 'Preparación de Aú con apoyos progresivos de manos y cadera baja.'
            : (ex.differentiationBeginner ?? 'Ritmo pausado con referencia visual.'),
        diferenciacionIntermedios: isAu
            ? 'Aú lateral controlado elevando caderas de forma simétrica.'
            : (ex.differentiationIntermediate ?? 'Secuencia continua equilibrada.'),
        diferenciacionAvanzados: isAu
            ? 'Perfeccionamiento de Aú fluido enlazando retorno en Ginga o Rolê.'
            : (ex.differentiationAdvanced ?? 'Mayor fluidez y variación de ángulos.'),
        organizacion: 'Todos simultáneamente',
        technicalMovementRefs: isAu ? const ['Aú', 'Ginga'] : ex.technicalMovementRefs,
      ),
    ];
    final proposed = CopilotOperationApplier.applyTypedOperations(
      currentPlan: plan,
      operations: ops,
      availableResources: availableResources,
    );
    return CopilotTurnResponse(
      mode: CopilotMode.proposeChanges,
      baseDraftVersion: baseDraftVersion,
      resultingDraftVersion: computeDraftVersion(proposed),
      assistantMessage:
          'Propongo ajustar únicamente "${ex.nombre}" manteniendo intactos los demás ejercicios.',
      operations: ops,
      diffSummary: [
        CopilotDiffItem(
          operationType: 'update_exercise',
          scopeLabel: ex.nombre,
          fieldLabel: isAu ? 'Niveles de Aú' : 'Organización y progresión',
          before: ex.differentiationBeginner ?? ex.organizacion ?? 'Sin definir',
          after: proposed.bloques
                  .firstWhere((b) => b.blockId == blk.blockId)
                  .ejercicios
                  .firstWhere((item) => item.exerciseId == ex.exerciseId)
                  .differentiationBeginner ??
              'Todos simultáneamente',
        ),
      ],
      proposedPlan: proposed,
    );
  }
}

/// Cliente autenticado para la Callable Function `copilotoPedagogicoV1` (`PED-05`).
class FirebaseFunctionsPlannerCopilotClient extends PlannerCopilotClient {
  final String region;
  final String functionName;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)?
      _callableInvoker;

  FirebaseFunctionsPlannerCopilotClient({
    this.region = 'us-central1',
    this.functionName = 'copilotoPedagogicoV1',
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)?
        callableInvoker,
  }) : _callableInvoker = callableInvoker;

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
    PedagogicalContinuityContext? continuityContext,
  }) async {
    final reqId = 'req_copilot_cf_${DateTime.now().microsecondsSinceEpoch}';
    final effContinuity = continuityContext ?? plan.continuityContext;
    final payload = <String, dynamic>{
      'request': {
        'request_id': reqId,
        'base_draft_version': baseDraftVersion,
        'message': message,
        'selected_block_id': selectedBlockId,
        'selected_exercise_id': selectedExerciseId,
        if (confirmedMaterials != null) ...{
          'materials_known': true,
          'confirmed_materials': confirmedMaterials,
        },
        if (effContinuity != null && effContinuity.hasContent)
          'continuity_context': effContinuity.toCopilotSummaryMap(),
        'conversation_history': [
          for (final m in conversationHistory.take(6))
            {'role': m.isUser ? 'user' : 'assistant', 'text': m.text},
        ],
        'available_resource_ids': [
          for (final r in availableResources) r.resourceId,
        ],
        'available_resources': [
          for (final r in availableResources)
            {
              'resource_id': r.resourceId,
              'title': r.title,
              'type': r.type,
              'category': r.category,
              'notes': r.notes,
              'has_external_video': r.hasExternalVideo,
            },
        ],
        'plan': plan.toMap(),
      },
    };

    try {
      final Map<String, dynamic> rawMap;
      final invoker = _callableInvoker;
      if (invoker != null) {
        rawMap = await invoker(payload);
      } else {
        final callable = FirebaseFunctions.instanceFor(region: region)
            .httpsCallable(functionName);
        final res = await callable.call<dynamic>(payload);
        if (res.data is Map) {
          rawMap = Map<String, dynamic>.from(res.data as Map);
        } else {
          throw const PlannerV2EngineException(
            code: 'INVALID_RESPONSE',
            userMessage:
                'El copiloto remoto devolvió una respuesta inesperada. Tu borrador sigue intacto.',
            retryable: true,
          );
        }
      }
      return HttpLocalPlannerCopilotClient._parseOkTurnResponse(
        rawMap,
        planId: plan.id,
        baseDraftVersion: baseDraftVersion,
      );
    } on PlannerV2EngineException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      final detailsMap = e.details is Map
          ? Map<String, dynamic>.from(e.details as Map)
          : const <String, dynamic>{};
      final code = detailsMap['planner_code']?.toString() ?? e.code.toUpperCase();
      throw PlannerV2EngineException(
        code: code,
        userMessage: e.message ??
            'No se pudo consultar al copiloto ($code). Tu borrador permanece intacto.',
        retryable: detailsMap['retryable'] == true ||
            e.code == 'deadline-exceeded' ||
            e.code == 'unavailable',
      );
    } catch (e) {
      throw PlannerV2EngineException(
        code: 'CLOUD_FUNCTION_ERROR',
        userMessage:
            'No se pudo invocar $functionName ($e). Tu borrador sigue intacto.',
        retryable: true,
      );
    }
  }
}

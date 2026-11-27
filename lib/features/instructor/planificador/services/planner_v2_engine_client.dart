import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../models/class_plan_models.dart';

class PlannerV2EngineStatus {
  final String mode;
  final bool realProviderEnabled;
  final bool copilotRealProviderEnabled;
  final bool credentialsPresent;
  final String primaryModel;
  final Map<String, dynamic> pilotBudget;
  final Map<String, dynamic> copilotBudget;

  const PlannerV2EngineStatus({
    required this.mode,
    required this.realProviderEnabled,
    this.copilotRealProviderEnabled = false,
    this.credentialsPresent = false,
    this.primaryModel = 'gpt-4.1-mini',
    this.pilotBudget = const {},
    this.copilotBudget = const {},
  });

  factory PlannerV2EngineStatus.fromHealthJson(Map<String, dynamic> json) {
    return PlannerV2EngineStatus(
      mode: json['mode']?.toString() ?? 'simulated_offline',
      realProviderEnabled: json['real_provider_enabled'] == true,
      copilotRealProviderEnabled: json['copilot_real_provider_enabled'] == true,
      credentialsPresent: json['real_provider_credentials_present'] == true,
      primaryModel: json['primary_model']?.toString() ?? 'gpt-4.1-mini',
      pilotBudget: json['pilot_budget'] is Map
          ? Map<String, dynamic>.from(json['pilot_budget'] as Map)
          : const {},
      copilotBudget: json['copilot_budget'] is Map
          ? Map<String, dynamic>.from(json['copilot_budget'] as Map)
          : const {},
    );
  }
}

class PlannerV2EngineException implements Exception {
  final String code;
  final String userMessage;
  final bool retryable;

  const PlannerV2EngineException({
    required this.code,
    required this.userMessage,
    this.retryable = true,
  });

  @override
  String toString() => 'PlannerV2EngineException($code): $userMessage';
}

class PlannerV2GenerationResult {
  final ClassPlanModel plan;
  final PlannerGenerationMeta generationMeta;
  final Map<String, dynamic> validationSummary;
  final Map<String, dynamic> costTelemetry;

  const PlannerV2GenerationResult({
    required this.plan,
    required this.generationMeta,
    this.validationSummary = const {},
    this.costTelemetry = const {},
  });
}

abstract class PlannerV2EngineClient {
  Future<PlannerV2EngineStatus?> fetchHealthStatus() async => null;

  Future<PlannerV2GenerationResult?> fetchLastCompletedPlan() async => null;

  Future<PlannerV2GenerationResult> generatePlan({
    required ClassPlanDraftRequest request,
    String? requestId,
    bool forceSimulated = false,
  });
}

/// Adapta la respuesta `v2.1.0` de `functions/planner_v2` hacia [ClassPlanModel] V2
/// conservando movimientos, recursos, variantes, seguridad, tiempos, referencias
/// del cancionero y contexto de continuidad sin marcar recursos como impartidos.
class PlannerV2ResponseAdapter {
  static PlannerV2GenerationResult fromJsonResponse(
    Map<String, dynamic> json,
    ClassPlanDraftRequest request, {
    String? forcedPlanId,
  }) =>
      _adaptServerPayload(
        json,
        creationModeId: request.creationMode.id,
        continuityMap: (request.continuityContext != null &&
                request.continuityContext!.hasContent)
            ? request.continuityContext!.toMap()
            : null,
        forcedPlanId: forcedPlanId,
      );

  static PlannerV2GenerationResult fromCompletedServerPayload(
    Map<String, dynamic> json, {
    String creationModeId = 'avanzada',
    String? forcedPlanId,
  }) =>
      _adaptServerPayload(
        json,
        creationModeId: creationModeId,
        forcedPlanId: forcedPlanId,
      );

  static PlannerV2GenerationResult _adaptServerPayload(
    Map<String, dynamic> json, {
    required String creationModeId,
    Map<String, dynamic>? continuityMap,
    String? forcedPlanId,
  }) {
    if (json['status'] == 'error' && json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      final code = err['code']?.toString() ?? 'ENGINE_ERROR';
      throw PlannerV2EngineException(
        code: code,
        userMessage: friendlyMessageForCode(
          code,
          fallback: err['message']?.toString(),
        ),
        retryable: err['retryable'] == true,
      );
    }

    final rawPlan = json['plan'];
    if (rawPlan is! Map) {
      throw const PlannerV2EngineException(
        code: 'INVALID_RESPONSE',
        userMessage:
            'El motor no devolvió un objeto de clase válido. Tu borrador sigue intacto; intenta nuevamente.',
        retryable: true,
      );
    }

    final planMap = Map<String, dynamic>.from(rawPlan);
    final rawGenMeta = json['generation_meta'] is Map
        ? Map<String, dynamic>.from(json['generation_meta'] as Map)
        : <String, dynamic>{};
    final rawPrivacy = json['privacy_notice'] is Map
        ? Map<String, dynamic>.from(json['privacy_notice'] as Map)
        : <String, dynamic>{};

    final mergedMeta = <String, dynamic>{
      ...rawGenMeta,
      if (rawPrivacy['heuristic_disclaimer'] != null)
        'heuristic_disclaimer': rawPrivacy['heuristic_disclaimer'],
      if (planMap['continuity_applied_note'] != null)
        'continuity_applied_note': planMap['continuity_applied_note'],
      if (planMap['space_snapshot'] is Map)
        'space_snapshot': planMap['space_snapshot'],
    };

    final genMeta = PlannerGenerationMeta.fromMap(mergedMeta);
    final planId =
        forcedPlanId ?? 'v2_gen_${DateTime.now().microsecondsSinceEpoch}';

    final hydratedMap = <String, dynamic>{
      ...planMap,
      'schema_version': 2,
      'plan_status': 'draft',
      'creation_mode': creationModeId,
      'generation_meta': genMeta.toMap(),
      if (continuityMap != null) 'continuity_context': continuityMap,
    };

    final model = ClassPlanModel.fromMap(planId, hydratedMap).copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return PlannerV2GenerationResult(
      plan: model,
      generationMeta: genMeta,
      validationSummary: json['validation_report'] is Map
          ? Map<String, dynamic>.from(json['validation_report'] as Map)
          : const {},
      costTelemetry: json['cost_telemetry'] is Map
          ? Map<String, dynamic>.from(json['cost_telemetry'] as Map)
          : const {},
    );
  }

  static String friendlyMessageForCode(String code, {String? fallback}) {
    switch (code) {
      case 'UNAUTHENTICATED':
      case 'FORBIDDEN_ROLE':
        return 'Necesitas una sesión autorizada de instructor para generar clases con el motor.';
      case 'INVALID_REQUIRED_MOVEMENT':
        return fallback ??
            'Uno de los movimientos FIU obligatorios no es válido para este grupo.';
      case 'INVALID_OR_UNAUTHORIZED_REQUIRED_RESOURCE':
      case 'UNAUTHORIZED_RESOURCE':
        return fallback ??
            'Uno de los recursos de Pizarra seleccionados no está disponible.';
      case 'QUOTA_EXCEEDED':
        return fallback ??
            'Se alcanzó temporalmente la cuota de generación. Espera un momento o usa Creación manual.';
      case 'CONCURRENT_REQUEST_IN_PROGRESS':
        return 'Ya hay una generación en curso para esta misma clase. Espera unos segundos.';
      case 'PROVIDER_TIMEOUT':
        return 'El motor tardó demasiado en responder. Tu borrador está a salvo; puedes reintentar.';
      case 'PROVIDER_TRUNCATED_OUTPUT':
      case 'VALIDATION_FAILED_AFTER_REPAIR':
        return 'La propuesta generada quedó incompleta tras validar reglas. Intenta nuevamente; tu borrador se conservó.';
      case 'PILOT_BUDGET_EXCEEDED':
        return fallback ??
            'Se alcanzó el tope presupuestal del piloto (USD 0.10 / 4 generaciones). Puedes continuar con Modo simulado o Creación manual.';
      case 'REAL_PROVIDER_DISABLED':
        return 'El proveedor IA real está deshabilitado por defecto (modo simulado offline activo).';
      default:
        return (fallback != null && fallback.trim().isNotEmpty)
            ? fallback
            : 'No se pudo generar la clase en este momento. Tus datos del formulario siguen intactos.';
    }
  }
}

/// Transporte HTTP local aislado (`scripts/planner_v2_local_server.js`).
/// Funciona en Web mismo-origen (`/api/planner-v2/generate`) o con `baseUrl` inyectada en pruebas.
class HttpLocalPlannerV2Client implements PlannerV2EngineClient {
  final String baseUrl;
  final String? previewToken;
  final http.Client _http;
  final Duration timeout;

  HttpLocalPlannerV2Client({
    this.baseUrl = '',
    this.previewToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 180),
  }) : _http = httpClient ?? http.Client();

  Uri _endpointUri(String suffix) {
    final base = baseUrl.trim();
    if (base.isEmpty) {
      return Uri.parse(suffix);
    }
    final normalized =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalized$suffix');
  }

  Uri _healthUri() => _endpointUri('/api/planner-v2/health');

  Uri _lastStatusUri() => _endpointUri('/api/planner-v2/last-status');

  Uri _generateUri() => _endpointUri('/api/planner-v2/generate');

  @override
  Future<PlannerV2EngineStatus?> fetchHealthStatus() async {
    try {
      final headers = <String, String>{
        if (previewToken != null && previewToken!.trim().isNotEmpty)
          'X-Preview-Token': previewToken!.trim(),
      };
      final resp = await _http
          .get(_healthUri(), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map) {
          return PlannerV2EngineStatus.fromHealthJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (_) {
      // Silencioso si el servidor local no expone /health en pruebas de widgets
    }
    return null;
  }

  @override
  Future<PlannerV2GenerationResult?> fetchLastCompletedPlan() async {
    try {
      final headers = <String, String>{
        if (previewToken != null && previewToken!.trim().isNotEmpty)
          'X-Preview-Token': previewToken!.trim(),
      };
      final resp = await _http
          .get(_lastStatusUri(), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map &&
            decoded['has_last_completed_result'] == true &&
            decoded['last_completed_result'] is Map) {
          return PlannerV2ResponseAdapter.fromCompletedServerPayload(
            Map<String, dynamic>.from(decoded['last_completed_result'] as Map),
          );
        }
      }
    } catch (_) {
      // Silencioso en pruebas de widgets sin servidor activo
    }
    return null;
  }

  @override
  Future<PlannerV2GenerationResult> generatePlan({
    required ClassPlanDraftRequest request,
    String? requestId,
    bool forceSimulated = false,
  }) async {
    final effectiveRequestId =
        requestId ?? 'req_ui_${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, dynamic>{
      if (forceSimulated) 'force_simulated': true,
      'request': request.toPlannerV2RequestMap(requestId: effectiveRequestId),
      'preview_resources_catalog': [
        for (final sel in request.selectedResources)
          {
            'resource_id': sel.resource.resourceId,
            'title': sel.resource.title,
            'type': sel.resource.type,
            'media_kind': sel.resource.mediaKind.storageType,
            'category': sel.resource.category,
            'notes': sel.resource.notes,
            'has_external_video': sel.resource.hasExternalVideo,
          },
      ],
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (previewToken != null && previewToken!.trim().isNotEmpty)
        'X-Preview-Token': previewToken!.trim(),
    };

    // Una única solicitud HTTP por clic para evitar duplicar llamadas pagadas ni consumir slots del piloto silenciosamente.
    try {
      final resp = await _http
          .post(
            _generateUri(),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      Map<String, dynamic> decoded = const {};
      try {
        final parsed = jsonDecode(resp.body);
        if (parsed is Map) {
          decoded = Map<String, dynamic>.from(parsed);
        }
      } catch (_) {
        throw const PlannerV2EngineException(
          code: 'INVALID_RESPONSE',
          userMessage:
              'No se pudo leer la respuesta del motor local. Tu configuración fue preservada.',
          retryable: true,
        );
      }

      if (resp.statusCode >= 200 &&
          resp.statusCode < 300 &&
          decoded['status'] == 'ok') {
        return PlannerV2ResponseAdapter.fromJsonResponse(decoded, request);
      }

      final errObj = decoded['error'] is Map
          ? Map<String, dynamic>.from(decoded['error'] as Map)
          : const <String, dynamic>{};
      final code = errObj['code']?.toString() ?? 'HTTP_${resp.statusCode}';
      final retryable = errObj['retryable'] == true ||
          resp.statusCode == 502 ||
          resp.statusCode == 504;

      throw PlannerV2EngineException(
        code: code,
        userMessage: PlannerV2ResponseAdapter.friendlyMessageForCode(
          code,
          fallback: errObj['message']?.toString(),
        ),
        retryable: retryable,
      );
    } on PlannerV2EngineException {
      rethrow;
    } on TimeoutException {
      throw const PlannerV2EngineException(
        code: 'PROVIDER_TIMEOUT',
        userMessage:
            'Tiempo de espera agotado al conectar con el motor local V2. Tu borrador está protegido; intenta reintentar.',
        retryable: true,
      );
    } catch (e) {
      throw PlannerV2EngineException(
        code: 'LOCAL_TRANSPORT_UNAVAILABLE',
        userMessage:
            'No fue posible conectar con el servidor local del motor V2 ($e). Tu formulario sigue intacto.',
        retryable: true,
      );
    }
  }
}

/// Cliente remoto para la futura Callable Function `generarPlanClaseV2` (`PED-04C2-D`).
/// En preview aislado no inicializa Firebase por defecto; acepta un `callableInvoker`
/// inyectable para pruebas deterministas y usará `FirebaseFunctions` cuando se despliegue.
class FirebaseFunctionsPlannerV2Client implements PlannerV2EngineClient {
  final String region;
  final String functionName;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)?
      _callableInvoker;

  FirebaseFunctionsPlannerV2Client({
    this.region = 'us-central1',
    this.functionName = 'generarPlanClaseV2',
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)?
        callableInvoker,
  }) : _callableInvoker = callableInvoker;

  @override
  Future<PlannerV2EngineStatus?> fetchHealthStatus() async => null;

  @override
  Future<PlannerV2GenerationResult?> fetchLastCompletedPlan() async => null;

  @override
  Future<PlannerV2GenerationResult> generatePlan({
    required ClassPlanDraftRequest request,
    String? requestId,
    bool forceSimulated = false,
  }) async {
    final effectiveRequestId =
        requestId ?? 'req_cf_${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, dynamic>{
      'request': request.toPlannerV2RequestMap(requestId: effectiveRequestId),
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
                'La función remota devolvió una respuesta inesperada. Tu formulario sigue intacto.',
            retryable: true,
          );
        }
      }
      return PlannerV2ResponseAdapter.fromJsonResponse(rawMap, request);
    } on PlannerV2EngineException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      final detailsMap = e.details is Map
          ? Map<String, dynamic>.from(e.details as Map)
          : const <String, dynamic>{};
      final plannerCode = detailsMap['planner_code']?.toString();
      final mappedCode = plannerCode ?? _mapFunctionsCode(e.code);
      throw PlannerV2EngineException(
        code: mappedCode,
        userMessage: PlannerV2ResponseAdapter.friendlyMessageForCode(
          mappedCode,
          fallback: e.message,
        ),
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

  static String _mapFunctionsCode(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'UNAUTHENTICATED';
      case 'permission-denied':
        return 'FORBIDDEN_ROLE';
      case 'resource-exhausted':
        return 'QUOTA_EXCEEDED';
      case 'deadline-exceeded':
        return 'PROVIDER_TIMEOUT';
      default:
        return code.toUpperCase();
    }
  }
}

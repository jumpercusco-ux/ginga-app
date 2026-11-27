import 'class_plan_models.dart';

enum CopilotMode {
  consult('consult'),
  proposeChanges('propose_changes'),
  conflict('conflict');

  final String id;
  const CopilotMode(this.id);

  static CopilotMode fromId(String? raw) {
    for (final m in values) {
      if (m.id == raw) return m;
    }
    return CopilotMode.consult;
  }
}

class CopilotDraftConflictException implements Exception {
  final String message;
  const CopilotDraftConflictException([
    this.message =
        'El borrador fue modificado manualmente después de generar la propuesta. Solicita una nueva evaluación sobre la versión actual.',
  ]);

  @override
  String toString() => 'CopilotDraftConflictException: $message';
}

class CopilotOperation {
  final String type;
  final String? blockId;
  final String? exerciseId;
  final int? targetDurationMin;
  final String? resourceId;
  final String? resourceUsageNote;
  final String? fase;
  final String? faseTipo;
  final int? duracionMin;
  final String? nombre;
  final String? tipoActividad;
  final String? detalle;
  final String? organizacion;
  final String? seguridad;
  final String? diferenciacionPrincipiantes;
  final String? diferenciacionIntermedios;
  final String? diferenciacionAvanzados;
  final String? sugerenciasIa;
  final List<String>? technicalMovementRefs;
  final List<String>? curriculumMovementIds;
  final List<String>? materiales;
  final List<PlannerInternalTiming>? tiemposInternos;

  const CopilotOperation({
    required this.type,
    this.blockId,
    this.exerciseId,
    this.targetDurationMin,
    this.resourceId,
    this.resourceUsageNote,
    this.fase,
    this.faseTipo,
    this.duracionMin,
    this.nombre,
    this.tipoActividad,
    this.detalle,
    this.organizacion,
    this.seguridad,
    this.diferenciacionPrincipiantes,
    this.diferenciacionIntermedios,
    this.diferenciacionAvanzados,
    this.sugerenciasIa,
    this.technicalMovementRefs,
    this.curriculumMovementIds,
    this.materiales,
    this.tiemposInternos,
  });

  factory CopilotOperation.fromMap(Map<String, dynamic> map) {
    List<String>? parseStrList(dynamic v) {
      if (v is! List) return null;
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    List<PlannerInternalTiming>? parseTimings(dynamic v) {
      if (v is! List) return null;
      return v
          .whereType<Map>()
          .map((m) => PlannerInternalTiming.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }

    return CopilotOperation(
      type: (map['type'] ?? '').toString().trim(),
      blockId: map['block_id']?.toString(),
      exerciseId: map['exercise_id']?.toString(),
      targetDurationMin: (map['target_duration_min'] as num?)?.toInt(),
      resourceId: map['resource_id']?.toString(),
      resourceUsageNote: map['resource_usage_note']?.toString(),
      fase: map['fase']?.toString(),
      faseTipo: map['fase_tipo']?.toString(),
      duracionMin: (map['duracion_min'] as num?)?.toInt(),
      nombre: map['nombre']?.toString(),
      tipoActividad: map['tipo_actividad']?.toString(),
      detalle: map['detalle']?.toString(),
      organizacion: map['organizacion']?.toString(),
      seguridad: map['seguridad']?.toString(),
      diferenciacionPrincipiantes: map['diferenciacion_principiantes']?.toString(),
      diferenciacionIntermedios: map['diferenciacion_intermedios']?.toString(),
      diferenciacionAvanzados: map['diferenciacion_avanzados']?.toString(),
      sugerenciasIa: map['sugerencias_ia']?.toString(),
      technicalMovementRefs: parseStrList(map['technical_movement_refs']),
      curriculumMovementIds: parseStrList(map['curriculum_movement_ids']),
      materiales: map['materiales'] is List ? parseStrList(map['materiales']) : null,
      tiemposInternos: parseTimings(map['tiempos_internos']),
    );
  }
}

class CopilotDiffItem {
  final String operationType;
  final String scopeLabel;
  final String fieldLabel;
  final String before;
  final String after;

  const CopilotDiffItem({
    required this.operationType,
    required this.scopeLabel,
    required this.fieldLabel,
    required this.before,
    required this.after,
  });

  factory CopilotDiffItem.fromMap(Map<String, dynamic> map) {
    return CopilotDiffItem(
      operationType: (map['operation_type'] ?? '').toString(),
      scopeLabel: (map['scope_label'] ?? '').toString(),
      fieldLabel: (map['field_label'] ?? '').toString(),
      before: (map['before'] ?? '').toString(),
      after: (map['after'] ?? '').toString(),
    );
  }
}

class CopilotTurnResponse {
  final CopilotMode mode;
  final String baseDraftVersion;
  final String resultingDraftVersion;
  final String assistantMessage;
  final List<String> pedagogicalNotes;
  final String? conflictReason;
  final String? safeAlternative;
  final List<CopilotOperation> operations;
  final List<CopilotDiffItem> diffSummary;
  final ClassPlanModel? proposedPlan;
  final bool isSimulated;

  const CopilotTurnResponse({
    required this.mode,
    required this.baseDraftVersion,
    required this.resultingDraftVersion,
    required this.assistantMessage,
    this.pedagogicalNotes = const [],
    this.conflictReason,
    this.safeAlternative,
    this.operations = const [],
    this.diffSummary = const [],
    this.proposedPlan,
    this.isSimulated = true,
  });

  bool get hasApplicableChanges =>
      mode == CopilotMode.proposeChanges &&
      (proposedPlan != null || operations.isNotEmpty);
}

enum CopilotProposalResolution {
  pending,
  applied,
  discarded,
  undone,
  staleConflict,
}

class CopilotChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final CopilotTurnResponse? response;
  final CopilotProposalResolution resolution;
  final String? conflictNotice;

  const CopilotChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.response,
    this.resolution = CopilotProposalResolution.pending,
    this.conflictNotice,
  });

  CopilotChatMessage copyWith({
    CopilotProposalResolution? resolution,
    String? conflictNotice,
  }) {
    return CopilotChatMessage(
      id: id,
      isUser: isUser,
      text: text,
      timestamp: timestamp,
      response: response,
      resolution: resolution ?? this.resolution,
      conflictNotice: conflictNotice ?? this.conflictNotice,
    );
  }
}

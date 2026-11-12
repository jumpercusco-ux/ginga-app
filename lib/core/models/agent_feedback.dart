import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorías oficiales para clasificar incidencias de GINGA.
class AgentFeedbackCategory {
  static const String interpretacionAmbiguedad = 'interpretacion_ambiguedad';
  static const String informacionComercial = 'informacion_comercial';
  static const String captacionDatos = 'captacion_datos';
  static const String reservaReprogramacion = 'reserva_reprogramacion';
  static const String persistenciaContexto = 'persistencia_contexto';
  static const String herramientasOperaciones = 'herramientas_operaciones';
  static const String derivacionHumana = 'derivacion_humana';
  static const String experienciaConversacional = 'experiencia_conversacional';
  static const String otro = 'otro';

  static const Map<String, String> etiquetas = {
    interpretacionAmbiguedad: 'Interpretación y ambigüedad',
    informacionComercial: 'Información comercial',
    captacionDatos: 'Captación de datos',
    reservaReprogramacion: 'Reserva y reprogramación',
    persistenciaContexto: 'Persistencia y contexto',
    herramientasOperaciones: 'Herramientas y operaciones',
    derivacionHumana: 'Derivación humana',
    experienciaConversacional: 'Experiencia conversacional',
    otro: 'Otro',
  };

  static String obtenerEtiqueta(String key) => etiquetas[key] ?? key;
}

/// Niveles de severidad para clasificar la gravedad de la incidencia.
class AgentFeedbackSeverity {
  static const String baja = 'baja';
  static const String media = 'media';
  static const String alta = 'alta';
  static const String critica = 'critica';

  static const Map<String, String> etiquetas = {
    baja: 'Baja (cosmético / formato)',
    media: 'Media (repregunta innecesaria / lentitud)',
    alta: 'Alta (dato incorrecto / horario desfasado)',
    critica: 'Crítica (falsa reserva / alucinación grave)',
  };

  static String obtenerEtiqueta(String key) => etiquetas[key] ?? key;
}

/// Estados del ciclo de vida de una incidencia de feedback.
class AgentFeedbackStatus {
  static const String reported = 'reported';
  static const String triaged = 'triaged';
  static const String reproduced = 'reproduced';
  static const String fixProposed = 'fix_proposed';
  static const String validated = 'validated';
  static const String approved = 'approved';
  static const String deployed = 'deployed';
  static const String monitored = 'monitored';
  static const String closed = 'closed';
  static const String rejected = 'rejected';
  static const String needsInformation = 'needs_information';

  static const Map<String, String> etiquetas = {
    reported: 'Reportada',
    triaged: 'Triaje completado',
    reproduced: 'Reproducida en test',
    fixProposed: 'Corrección propuesta',
    validated: 'Validada en regresión',
    approved: 'Aprobada por admin',
    deployed: 'Desplegada en prod',
    monitored: 'En monitoreo',
    closed: 'Cerrada',
    rejected: 'Desestimada',
    needsInformation: 'Requiere más datos',
  };

  static String obtenerEtiqueta(String key) => etiquetas[key] ?? key;
}

/// Modelo de datos para registrar feedback humano sobre respuestas de IA.
class AgentFeedback {
  final String feedbackId;
  final String leadId;
  final String messageId;
  final String conversationReference;
  final Map<String, dynamic> reportedBy;
  final DateTime reportedAt;
  final String agentVersion;
  final String category;
  final String severity;
  final String observation;
  final String expectedBehavior;
  final String actualBehavior;
  final String status;
  final String? diagnosis;
  final String? rootCause;
  final String? evaluationCaseId;
  final String? resolutionCommit;
  final DateTime? resolvedAt;

  const AgentFeedback({
    required this.feedbackId,
    required this.leadId,
    required this.messageId,
    required this.conversationReference,
    required this.reportedBy,
    required this.reportedAt,
    required this.agentVersion,
    required this.category,
    required this.severity,
    required this.observation,
    required this.expectedBehavior,
    required this.actualBehavior,
    required this.status,
    this.diagnosis,
    this.rootCause,
    this.evaluationCaseId,
    this.resolutionCommit,
    this.resolvedAt,
  });

  /// Generador determinista y seguro de identificadores de feedback legible.
  /// Formato: FB-YYYYMMDD-XXXXX
  static String generateId({DateTime? date}) {
    final d = date ?? DateTime.now();
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final rnd = Random.secure();
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final suffix = List.generate(5, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'FB-$yyyy$mm$dd-$suffix';
  }

  Map<String, dynamic> toMap() {
    return {
      'feedback_id': feedbackId,
      'lead_id': leadId,
      'message_id': messageId,
      'conversation_reference': conversationReference,
      'reported_by': reportedBy,
      'reported_at': Timestamp.fromDate(reportedAt),
      'agent_version': agentVersion,
      'category': category,
      'severity': severity,
      'observation': observation,
      'expected_behavior': expectedBehavior,
      'actual_behavior': actualBehavior,
      'status': status,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (rootCause != null) 'root_cause': rootCause,
      if (evaluationCaseId != null) 'evaluation_case_id': evaluationCaseId,
      if (resolutionCommit != null) 'resolution_commit': resolutionCommit,
      if (resolvedAt != null) 'resolved_at': Timestamp.fromDate(resolvedAt!),
    };
  }

  factory AgentFeedback.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return AgentFeedback(
      feedbackId: map['feedback_id'] ?? docId ?? '',
      leadId: map['lead_id'] ?? '',
      messageId: map['message_id'] ?? '',
      conversationReference: map['conversation_reference'] ?? '',
      reportedBy: Map<String, dynamic>.from(map['reported_by'] ?? {}),
      reportedAt: parseDate(map['reported_at']),
      agentVersion: map['agent_version'] ?? 'whatsappWebhook v69',
      category: map['category'] ?? AgentFeedbackCategory.otro,
      severity: map['severity'] ?? AgentFeedbackSeverity.media,
      observation: map['observation'] ?? '',
      expectedBehavior: map['expected_behavior'] ?? '',
      actualBehavior: map['actual_behavior'] ?? '',
      status: map['status'] ?? AgentFeedbackStatus.reported,
      diagnosis: map['diagnosis'],
      rootCause: map['root_cause'],
      evaluationCaseId: map['evaluation_case_id'],
      resolutionCommit: map['resolution_commit'],
      resolvedAt: map['resolved_at'] != null ? parseDate(map['resolved_at']) : null,
    );
  }

  AgentFeedback copyWith({
    String? status,
    String? diagnosis,
    String? rootCause,
    String? evaluationCaseId,
    String? resolutionCommit,
    DateTime? resolvedAt,
  }) {
    return AgentFeedback(
      feedbackId: feedbackId,
      leadId: leadId,
      messageId: messageId,
      conversationReference: conversationReference,
      reportedBy: reportedBy,
      reportedAt: reportedAt,
      agentVersion: agentVersion,
      category: category,
      severity: severity,
      observation: observation,
      expectedBehavior: expectedBehavior,
      actualBehavior: actualBehavior,
      status: status ?? this.status,
      diagnosis: diagnosis ?? this.diagnosis,
      rootCause: rootCause ?? this.rootCause,
      evaluationCaseId: evaluationCaseId ?? this.evaluationCaseId,
      resolutionCommit: resolutionCommit ?? this.resolutionCommit,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

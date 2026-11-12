import 'package:cloud_firestore/cloud_firestore.dart';

/// Caso de evaluación sintético o anonimizado para pruebas continuas de calidad de GINGA.
class AgentEvaluation {
  final String caseId;
  final String? sourceFeedbackId;
  final String category;
  final String scenario;
  final List<Map<String, dynamic>> inputMessages;
  final Map<String, dynamic> initialState;
  final Map<String, dynamic> expectedBehavior;
  final List<String> forbiddenBehavior;
  final String evaluationMethod;
  final DateTime createdAt;
  final String? lastResult;
  final String? lastTestedVersion;
  final DateTime? lastTestedAt;

  const AgentEvaluation({
    required this.caseId,
    this.sourceFeedbackId,
    required this.category,
    required this.scenario,
    required this.inputMessages,
    required this.initialState,
    required this.expectedBehavior,
    required this.forbiddenBehavior,
    required this.evaluationMethod,
    required this.createdAt,
    this.lastResult,
    this.lastTestedVersion,
    this.lastTestedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'case_id': caseId,
      if (sourceFeedbackId != null) 'source_feedback_id': sourceFeedbackId,
      'category': category,
      'scenario': scenario,
      'input_messages': inputMessages,
      'initial_state': initialState,
      'expected_behavior': expectedBehavior,
      'forbidden_behavior': forbiddenBehavior,
      'evaluation_method': evaluationMethod,
      'created_at': Timestamp.fromDate(createdAt),
      if (lastResult != null) 'last_result': lastResult,
      if (lastTestedVersion != null) 'last_tested_version': lastTestedVersion,
      if (lastTestedAt != null) 'last_tested_at': Timestamp.fromDate(lastTestedAt!),
    };
  }

  factory AgentEvaluation.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return AgentEvaluation(
      caseId: map['case_id'] ?? docId ?? '',
      sourceFeedbackId: map['source_feedback_id'],
      category: map['category'] ?? 'general',
      scenario: map['scenario'] ?? '',
      inputMessages: List<Map<String, dynamic>>.from(map['input_messages'] ?? []),
      initialState: Map<String, dynamic>.from(map['initial_state'] ?? {}),
      expectedBehavior: Map<String, dynamic>.from(map['expected_behavior'] ?? {}),
      forbiddenBehavior: List<String>.from(map['forbidden_behavior'] ?? []),
      evaluationMethod: map['evaluation_method'] ?? 'deterministic_rules',
      createdAt: parseDate(map['created_at']),
      lastResult: map['last_result'],
      lastTestedVersion: map['last_tested_version'],
      lastTestedAt: map['last_tested_at'] != null ? parseDate(map['last_tested_at']) : null,
    );
  }
}

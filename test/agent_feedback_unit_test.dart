import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/models/agent_feedback.dart';
import 'package:ginga_app/core/models/agent_evaluation.dart';

void main() {
  group('AgentFeedback Model & Enums', () {
    test('generateId genera formato FB-YYYYMMDD-XXXXX válido y único', () {
      final ids = <String>{};
      final regex = RegExp(r'^FB-\d{8}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{5}$');

      for (int i = 0; i < 100; i++) {
        final id = AgentFeedback.generateId();
        expect(regex.hasMatch(id), isTrue, reason: 'ID $id debe cumplir formato seguro.');
        ids.add(id);
      }
      expect(ids.length, 100, reason: 'Los 100 IDs generados deben ser distintos.');
    });

    test('Serialización toMap y fromMap preserva todos los campos', () {
      final fecha = DateTime.utc(2026, 11, 12, 12, 0, 0);
      final fb = AgentFeedback(
        feedbackId: 'FB-20261112-TEST1',
        leadId: '+51984111001',
        messageId: 'msg_001',
        conversationReference: 'Lead Sofia',
        reportedBy: {
          'uid': 'prof_1',
          'email': 'profesor@test.com',
          'nombre': 'Profesor Test',
          'rol': 'profesor',
        },
        reportedAt: fecha,
        agentVersion: 'whatsappWebhook v69',
        category: AgentFeedbackCategory.interpretacionAmbiguedad,
        severity: AgentFeedbackSeverity.alta,
        observation: 'Agente asumió jueves sin preguntar.',
        expectedBehavior: 'Debió preguntar disponibilidad.',
        actualBehavior: 'Te agendé para el jueves.',
        status: AgentFeedbackStatus.reported,
        diagnosis: 'Ambigüedad no resuelta.',
        rootCause: 'missing_disambiguation',
        evaluationCaseId: 'GINGA-EVAL-001',
      );

      final map = fb.toMap();
      expect(map['feedback_id'], 'FB-20261112-TEST1');
      expect(map['lead_id'], '+51984111001');
      expect(map['message_id'], 'msg_001');
      expect(map['category'], 'interpretacion_ambiguedad');
      expect(map['severity'], 'alta');
      expect(map['status'], 'reported');

      final reconstructed = AgentFeedback.fromMap(map, docId: 'FB-20261112-TEST1');
      expect(reconstructed.feedbackId, fb.feedbackId);
      expect(reconstructed.leadId, fb.leadId);
      expect(reconstructed.messageId, fb.messageId);
      expect(reconstructed.observation, fb.observation);
      expect(reconstructed.expectedBehavior, fb.expectedBehavior);
      expect(reconstructed.actualBehavior, fb.actualBehavior);
      expect(reconstructed.evaluationCaseId, 'GINGA-EVAL-001');
    });

    test('Catálogo de categorías contiene las 9 opciones oficiales', () {
      expect(AgentFeedbackCategory.etiquetas.length, 9);
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.interpretacionAmbiguedad], 'Interpretación y ambigüedad');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.informacionComercial], 'Información comercial');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.captacionDatos], 'Captación de datos');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.reservaReprogramacion], 'Reserva y reprogramación');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.persistenciaContexto], 'Persistencia y contexto');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.herramientasOperaciones], 'Herramientas y operaciones');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.derivacionHumana], 'Derivación humana');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.experienciaConversacional], 'Experiencia conversacional');
      expect(AgentFeedbackCategory.etiquetas[AgentFeedbackCategory.otro], 'Otro');
    });

    test('Catálogo de severidades contiene los 4 niveles', () {
      expect(AgentFeedbackSeverity.etiquetas.length, 4);
      expect(AgentFeedbackSeverity.etiquetas.containsKey(AgentFeedbackSeverity.baja), isTrue);
      expect(AgentFeedbackSeverity.etiquetas.containsKey(AgentFeedbackSeverity.media), isTrue);
      expect(AgentFeedbackSeverity.etiquetas.containsKey(AgentFeedbackSeverity.alta), isTrue);
      expect(AgentFeedbackSeverity.etiquetas.containsKey(AgentFeedbackSeverity.critica), isTrue);
    });

    test('Transición copyWith genera nuevo estado sin mutar original', () {
      final fbOriginal = AgentFeedback(
        feedbackId: 'FB-20261112-TEST2',
        leadId: '+51984111002',
        messageId: 'msg_002',
        conversationReference: 'Lead Daniela',
        reportedBy: {'uid': 'prof_1', 'rol': 'profesor'},
        reportedAt: DateTime.now(),
        agentVersion: 'v69',
        category: AgentFeedbackCategory.informacionComercial,
        severity: AgentFeedbackSeverity.media,
        observation: 'Error en precios',
        expectedBehavior: 'Informar promo 260',
        actualBehavior: 'Dijo 280',
        status: AgentFeedbackStatus.reported,
      );

      final fbTriaged = fbOriginal.copyWith(
        status: AgentFeedbackStatus.triaged,
        diagnosis: 'Regla comercial desfasada',
      );

      expect(fbOriginal.status, AgentFeedbackStatus.reported);
      expect(fbTriaged.status, AgentFeedbackStatus.triaged);
      expect(fbTriaged.diagnosis, 'Regla comercial desfasada');
      expect(fbTriaged.feedbackId, fbOriginal.feedbackId);
    });
  });

  group('AgentEvaluation Model', () {
    test('Serialización toMap y fromMap de caso de evaluación', () {
      final caso = AgentEvaluation(
        caseId: 'GINGA-EVAL-001',
        sourceFeedbackId: 'FB-20261112-TEST1',
        category: 'interpretacion_ambiguedad',
        scenario: 'Ambigüedad en reprogramación por restricciones cruzadas',
        inputMessages: [
          {'role': 'user', 'content': 'Para el jueves no puede ser es que el martes no estoy'}
        ],
        initialState: {'status': 'clase_agendada'},
        expectedBehavior: {'solicita_aclaracion': true},
        forbiddenBehavior: ['ejecutar_reprogramar_reserva'],
        evaluationMethod: 'deterministic_rules_and_assertions',
        createdAt: DateTime.utc(2026, 11, 12),
        lastResult: 'PASS',
        lastTestedVersion: 'whatsappWebhook v69',
      );

      final map = caso.toMap();
      expect(map['case_id'], 'GINGA-EVAL-001');
      expect(map['category'], 'interpretacion_ambiguedad');
      expect(map['forbidden_behavior'], ['ejecutar_reprogramar_reserva']);

      final reconstructed = AgentEvaluation.fromMap(map, docId: 'GINGA-EVAL-001');
      expect(reconstructed.caseId, 'GINGA-EVAL-001');
      expect(reconstructed.lastResult, 'PASS');
      expect(reconstructed.lastTestedVersion, 'whatsappWebhook v69');
    });
  });
}


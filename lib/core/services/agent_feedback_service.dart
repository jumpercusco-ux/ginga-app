import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/agent_feedback.dart';

/// Servicio para la captura, trazabilidad y gestión de incidencias de feedback del agente GINGA.
class AgentFeedbackService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AgentFeedbackService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _feedbackCollection =>
      _firestore.collection('agent_feedback');

  CollectionReference<Map<String, dynamic>> get _evaluationsCollection =>
      _firestore.collection('agent_evaluations');

  /// Registra un nuevo caso de evaluación en la colección agent_evaluations.
  Future<void> registrarEvaluacion(Map<String, dynamic> evalData) async {
    await _validarAutorizacion();
    final caseId = evalData['case_id'] as String?;
    if (caseId == null || caseId.trim().isEmpty) {
      throw ArgumentError('El case_id es obligatorio para registrar una evaluación.');
    }
    await _evaluationsCollection.doc(caseId.trim()).set(evalData);
  }

  /// Consulta un caso de evaluación por su ID.
  Future<Map<String, dynamic>?> obtenerEvaluacionPorId(String caseId) async {
    final doc = await _evaluationsCollection.doc(caseId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Valida que el usuario actual tenga sesión activa y rol autorizado ('profesor' o 'admin').
  Future<Map<String, dynamic>> _validarAutorizacion() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay sesión de usuario activa para registrar feedback.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final rol = (data['rol'] ?? 'alumno').toString().toLowerCase();

    if (rol != 'profesor' && rol != 'admin') {
      throw StateError('Acceso denegado: solo instructores y administradores pueden reportar incidencias.');
    }

    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'nombre': data['nombre'] ?? user.displayName ?? 'Instructor',
      'rol': rol,
    };
  }

  /// Registra una nueva incidencia de feedback en Firestore.
  /// Implementa prevención de duplicados, validación de campos y generación de ID seguro.
  Future<String> registrarFeedback({
    required String leadId,
    required String messageId,
    required String conversationReference,
    required String category,
    required String severity,
    required String observation,
    required String expectedBehavior,
    required String actualBehavior,
    String agentVersion = 'whatsappWebhook v69',
  }) async {
    // 1. Validar autorización
    final reportedBy = await _validarAutorizacion();

    // 2. Validar campos obligatorios
    if (leadId.trim().isEmpty) throw ArgumentError('El leadId es obligatorio.');
    if (messageId.trim().isEmpty) throw ArgumentError('El messageId es obligatorio.');
    if (observation.trim().isEmpty) throw ArgumentError('La observación humana es obligatoria.');
    if (expectedBehavior.trim().isEmpty) throw ArgumentError('El comportamiento esperado es obligatorio.');

    // 3. Verificación de duplicados para el mismo mensaje y categoría
    final queryDuplicados = await _feedbackCollection
        .where('message_id', isEqualTo: messageId)
        .where('category', isEqualTo: category)
        .limit(1)
        .get();

    if (queryDuplicados.docs.isNotEmpty) {
      final docExistente = queryDuplicados.docs.first;
      debugPrint('[AgentFeedbackService] Incidencia duplicada detectada: ${docExistente.id}');
      return docExistente.id;
    }

    // 4. Generar ID y modelo
    final feedbackId = AgentFeedback.generateId();
    final feedback = AgentFeedback(
      feedbackId: feedbackId,
      leadId: leadId.trim(),
      messageId: messageId.trim(),
      conversationReference: conversationReference.trim(),
      reportedBy: reportedBy,
      reportedAt: DateTime.now(),
      agentVersion: agentVersion,
      category: category,
      severity: severity,
      observation: observation.trim(),
      expectedBehavior: expectedBehavior.trim(),
      actualBehavior: actualBehavior.trim(),
      status: AgentFeedbackStatus.reported,
    );

    // 5. Persistir en Firestore
    await _feedbackCollection.doc(feedbackId).set(feedback.toMap());
    debugPrint('[AgentFeedbackService] Incidencia registrada exitosamente: $feedbackId');

    return feedbackId;
  }

  /// Retorna un stream con las incidencias registradas para un lead específico.
  Stream<List<AgentFeedback>> obtenerFeedbacksPorLead(String leadId) {
    return _feedbackCollection
        .where('lead_id', isEqualTo: leadId)
        .orderBy('reported_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AgentFeedback.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Retorna un stream con el conteo de incidencias para un lead.
  Stream<int> contarFeedbacksPorLead(String leadId) {
    return _feedbackCollection
        .where('lead_id', isEqualTo: leadId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Actualiza el estado de una incidencia de feedback con trazabilidad.
  Future<void> actualizarEstado(
    String feedbackId,
    String nuevoEstado, {
    String? diagnosis,
    String? rootCause,
    String? evaluationCaseId,
    String? resolutionCommit,
  }) async {
    await _validarAutorizacion();

    final Map<String, dynamic> updates = {
      'status': nuevoEstado,
    };
    if (diagnosis != null) updates['diagnosis'] = diagnosis;
    if (rootCause != null) updates['root_cause'] = rootCause;
    if (evaluationCaseId != null) updates['evaluation_case_id'] = evaluationCaseId;
    if (resolutionCommit != null) updates['resolution_commit'] = resolutionCommit;
    if (nuevoEstado == AgentFeedbackStatus.closed || nuevoEstado == AgentFeedbackStatus.deployed) {
      updates['resolved_at'] = FieldValue.serverTimestamp();
    }

    await _feedbackCollection.doc(feedbackId).update(updates);
  }

  /// Obtiene un feedback por su ID.
  Future<AgentFeedback?> obtenerFeedbackPorId(String feedbackId) async {
    final doc = await _feedbackCollection.doc(feedbackId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AgentFeedback.fromMap(doc.data()!, docId: doc.id);
  }
}

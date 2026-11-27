import 'dart:convert';
import '../models/class_plan_models.dart';
import '../models/copilot_models.dart';
import 'class_plan_editor_operations.dart';

/// Calcula una firma determinista del borrador abierto para evitar que
/// una propuesta antigua del copiloto sobrescriba ediciones manuales posteriores.
String computeDraftVersion(ClassPlanModel plan) {
  final canonical = {
    'titulo': plan.titulo.trim(),
    'duracion_total': plan.duracionTotal,
    'audience_type': plan.audienceType.id,
    'curriculum_scope': plan.curriculumScope.id,
    'enfoque': plan.enfoque.trim(),
    'objetivos': plan.objetivos.map((o) => o.trim()).toList(),
    'consejos_instructor': (plan.consejosInstructor ?? '').trim(),
    'bloques': [
      for (final b in plan.bloques)
        {
          'block_id': b.blockId,
          'fase': b.fase.trim(),
          'fase_tipo': b.faseTipo ?? '',
          'duracion_min': b.duracionMin,
          'ejercicios': [
            for (final e in b.ejercicios)
              {
                'exercise_id': e.exerciseId,
                'nombre': e.nombre.trim(),
                'detalle': e.detalle.trim(),
                'duracion_min': e.duracionMin ?? 0,
                'organizacion': (e.organizacion ?? '').trim(),
                'materiales': e.materiales.map((m) => m.trim()).toList(),
                'seguridad': (e.safetyNote ?? '').trim(),
                'diferenciacion_principiantes': (e.differentiationBeginner ?? '').trim(),
                'diferenciacion_intermedios': (e.differentiationIntermediate ?? '').trim(),
                'diferenciacion_avanzados': (e.differentiationAdvanced ?? '').trim(),
                'sugerencias_ia': (e.aiSuggestions ?? '').trim(),
                'observaciones_profesor': (e.observacionesProfesor ?? '').trim(),
                'technical_movement_refs': e.technicalMovementRefs,
                'curriculum_movement_ids': e.curriculumMovementIds,
                'linked_resource_ids': e.linkedResourceIds,
                'tiempos_internos': [
                  for (final t in e.internalTimings)
                    {'etapa': t.etapa.trim(), 'minutos': t.minutos},
                ],
              },
          ],
        },
    ],
  };

  final bytes = utf8.encode(jsonEncode(canonical));
  // Hash determinista 4x32-bit compatible con Dart VM y Dart2JS Web (<= 32 bits).
  const mask32 = 0xFFFFFFFF;
  var h1 = 0x811c9dc5;
  var h2 = 0x9e3779b9;
  var h3 = 0x85ebca6b;
  var h4 = 0xc2b2ae35;
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    h1 = ((h1 ^ b) * 0x01000193) & mask32;
    h2 = ((h2 ^ ((b + i) & 0xFF)) * 0x01000193) & mask32;
    h3 = ((h3 ^ ((b * 3 + i) & 0xFF)) * 0x01000193) & mask32;
    h4 = ((h4 ^ ((b + i * 7) & 0xFF)) * 0x01000193) & mask32;
  }
  return '${h1.toRadixString(16).padLeft(8, '0')}'
      '${h2.toRadixString(16).padLeft(8, '0')}'
      '${h3.toRadixString(16).padLeft(8, '0')}'
      '${h4.toRadixString(16).padLeft(8, '0')}';
}

/// Aplica propuestas validadas del Copiloto de forma estrictamente inmutable,
/// verificando versión del borrador y preservando IDs/orígenes no afectados.
class CopilotOperationApplier {
  static ClassPlanModel applyProposal({
    required ClassPlanModel currentPlan,
    required CopilotTurnResponse proposal,
    List<PlannerResourceItem> availableResources = const [],
  }) {
    final currentVersion = computeDraftVersion(currentPlan);
    if (proposal.baseDraftVersion.isNotEmpty &&
        proposal.baseDraftVersion != currentVersion) {
      throw const CopilotDraftConflictException();
    }

    if (proposal.proposedPlan != null) {
      // Preservar metadatos locales de editor (id, createdAt, vecesImpartida, ultimaEjecucion)
      return proposal.proposedPlan!.copyWith(
        id: currentPlan.id,
        createdAt: currentPlan.createdAt,
        updatedAt: DateTime.now(),
        vecesImpartida: currentPlan.vecesImpartida,
        ultimaEjecucion: currentPlan.ultimaEjecucion,
        duplicatedFromPlanId: currentPlan.duplicatedFromPlanId,
        continuityContext: currentPlan.continuityContext,
      );
    }

    return applyTypedOperations(
      currentPlan: currentPlan,
      operations: proposal.operations,
      availableResources: availableResources,
    );
  }

  static ClassPlanModel applyTypedOperations({
    required ClassPlanModel currentPlan,
    required List<CopilotOperation> operations,
    List<PlannerResourceItem> availableResources = const [],
  }) {
    var working = currentPlan;
    final resById = {for (final r in availableResources) r.resourceId: r};

    for (final op in operations) {
      switch (op.type) {
        case 'update_exercise':
          working = _patchExercise(working, op, resetBindings: false);
          break;
        case 'replace_exercise':
          working = _patchExercise(working, op, resetBindings: true);
          break;
        case 'add_exercise':
          if (op.blockId != null) {
            final newId = op.exerciseId ??
                ClassPlanEditorOperations.nextId(
                  'ex_copilot',
                  working.bloques
                      .expand((b) => b.ejercicios)
                      .map((e) => e.exerciseId)
                      .toSet(),
                );
            final dur = op.duracionMin ?? 5;
            final newEx = ClassPlanExercise.manualBlank(
              exerciseId: newId,
              nombre: op.nombre ?? 'Actividad complementaria',
              duracionMin: dur,
            ).copyWith(
              detalle: op.detalle ?? '',
              organizacion: op.organizacion ?? 'Todos simultáneamente',
              safetyNote: op.seguridad,
              differentiationBeginner: op.diferenciacionPrincipiantes,
              differentiationIntermediate: op.diferenciacionIntermedios,
              differentiationAdvanced: op.diferenciacionAvanzados,
              aiSuggestions: op.sugerenciasIa,
              technicalMovementRefs: op.technicalMovementRefs ?? const [],
              internalTimings: op.tiemposInternos ?? const [],
              contentOrigin: ContentOrigin.aiComplementaryProposal,
            );
            working = ClassPlanEditorOperations.addExercise(
              working,
              op.blockId!,
              newEx,
            );
          }
          break;
        case 'remove_exercise':
          if (op.blockId != null && op.exerciseId != null) {
            working = ClassPlanEditorOperations.deleteExercise(
              working,
              op.blockId!,
              op.exerciseId!,
            );
          }
          break;
        case 'update_block':
          if (op.blockId != null) {
            working = ClassPlanEditorOperations.updateBlock(
              working,
              op.blockId!,
              fase: op.fase,
              duracionMin: op.duracionMin,
            );
          }
          break;
        case 'add_block':
          working = ClassPlanEditorOperations.addBlock(
            working,
            fase: op.fase ?? 'Nuevo bloque',
            duracionMin: op.duracionMin ?? 10,
          );
          break;
        case 'remove_block':
          if (op.blockId != null) {
            working = ClassPlanEditorOperations.deleteBlock(working, op.blockId!);
          }
          break;
        case 'redistribute_duration':
          final target = (op.targetDurationMin ?? op.duracionMin ?? 45).clamp(20, 180);
          working = _redistributeExactDuration(working, target);
          break;
        case 'link_resource':
          if (op.blockId != null && op.exerciseId != null && op.resourceId != null) {
            final res = resById[op.resourceId!];
            working = _linkResourceToExercise(
              working,
              op.blockId!,
              op.exerciseId!,
              op.resourceId!,
              res,
              op.resourceUsageNote,
            );
          }
          break;
        case 'update_internal_timings':
          if (op.blockId != null && op.exerciseId != null && op.tiemposInternos != null) {
            working = _patchExercise(
              working,
              CopilotOperation(
                type: 'update_internal_timings',
                blockId: op.blockId,
                exerciseId: op.exerciseId,
                tiemposInternos: op.tiemposInternos,
              ),
              resetBindings: false,
            );
          }
          break;
      }
    }
    return working;
  }

  static ClassPlanModel _patchExercise(
    ClassPlanModel plan,
    CopilotOperation op, {
    required bool resetBindings,
  }) {
    if (op.blockId == null || op.exerciseId == null) return plan;
    for (final b in plan.bloques) {
      if (b.blockId != op.blockId) continue;
      for (final e in b.ejercicios) {
        if (e.exerciseId != op.exerciseId) continue;
        final safeMovs = (plan.audienceType == PlannerAudienceType.adultos &&
                plan.curriculumScope == PlannerCurriculumScope.adultoFiu)
            ? (op.curriculumMovementIds ??
                (resetBindings ? const <String>[] : e.curriculumMovementIds))
            : const <String>[];
        final updated = e.copyWith(
          nombre: op.nombre ?? e.nombre,
          detalle: op.detalle ?? e.detalle,
          duracionMin: op.duracionMin ?? e.duracionMin,
          organizacion: op.organizacion ?? e.organizacion,
          materiales: op.materiales ?? e.materiales,
          safetyNote: op.seguridad ?? e.safetyNote,
          differentiationBeginner:
              op.diferenciacionPrincipiantes ?? e.differentiationBeginner,
          differentiationIntermediate:
              op.diferenciacionIntermedios ?? e.differentiationIntermediate,
          differentiationAdvanced:
              op.diferenciacionAvanzados ?? e.differentiationAdvanced,
          aiSuggestions: op.sugerenciasIa ?? e.aiSuggestions,
          technicalMovementRefs:
              op.technicalMovementRefs ?? e.technicalMovementRefs,
          curriculumMovementIds: safeMovs,
          linkedResourceIds:
              resetBindings ? const <String>[] : e.linkedResourceIds,
          resourceUsageNotes:
              resetBindings ? const <String, String>{} : e.resourceUsageNotes,
          clearVideoReferenceNote: resetBindings,
          internalTimings: op.tiemposInternos ?? e.internalTimings,
        );
        return ClassPlanEditorOperations.updateExercise(plan, b.blockId, updated);
      }
    }
    return plan;
  }

  static ClassPlanModel _linkResourceToExercise(
    ClassPlanModel plan,
    String blockId,
    String exerciseId,
    String resourceId,
    PlannerResourceItem? res,
    String? usageNote,
  ) {
    for (final b in plan.bloques) {
      if (b.blockId != blockId) continue;
      for (final e in b.ejercicios) {
        if (e.exerciseId != exerciseId) continue;
        final nextIds = {...e.linkedResourceIds, resourceId}.toList();
        final nextNotes = Map<String, String>.from(e.resourceUsageNotes);
        nextNotes[resourceId] = (usageNote != null && usageNote.trim().isNotEmpty)
            ? usageNote.trim()
            : (res?.notes ?? 'Integrar "${res?.title ?? resourceId}" en la dinámica.');
        final updated = e.copyWith(
          linkedResourceIds: nextIds,
          resourceUsageNotes: nextNotes,
          contentOrigin: ContentOrigin.teacherResource,
          videoReferenceNote: (res?.hasExternalVideo == true)
              ? 'Recurso con video externo: integrado únicamente según título y notas escritas del profesor (el motor no inspecciona visualmente el video).'
              : e.videoReferenceNote,
        );
        return ClassPlanEditorOperations.updateExercise(plan, blockId, updated);
      }
    }
    return plan;
  }

  static List<int> _distributeMinutes(int total, List<int> weights) {
    if (weights.isEmpty) return const [];
    final safeTotal = total < weights.length ? weights.length : total;
    final sumW = weights.fold<int>(0, (a, b) => a + (b > 0 ? b : 1));
    final out = [
      for (final w in weights)
        ((safeTotal * (w > 0 ? w : 1)) / sumW).floor().clamp(1, safeTotal),
    ];
    var diff = safeTotal - out.fold<int>(0, (a, b) => a + b);
    var idx = 0;
    while (diff > 0) {
      out[idx % out.length] += 1;
      diff--;
      idx++;
    }
    while (diff < 0) {
      var maxIdx = 0;
      for (var i = 1; i < out.length; i++) {
        if (out[i] > out[maxIdx]) maxIdx = i;
      }
      if (out[maxIdx] <= 1) break;
      out[maxIdx] -= 1;
      diff++;
    }
    return out;
  }

  static ClassPlanModel _redistributeExactDuration(ClassPlanModel plan, int targetTotal) {
    if (plan.bloques.isEmpty) {
      return ClassPlanEditorOperations.updateMetadata(plan, duracionTotal: targetTotal);
    }
    final bWeights = [for (final b in plan.bloques) b.duracionMin.clamp(2, 180)];
    final newBlockDurs = _distributeMinutes(targetTotal, bWeights);
    final nextBlocks = <ClassPlanBlock>[];
    for (var bi = 0; bi < plan.bloques.length; bi++) {
      final blk = plan.bloques[bi];
      final bDur = newBlockDurs[bi];
      if (blk.ejercicios.isEmpty) {
        nextBlocks.add(blk.copyWith(duracionMin: bDur));
        continue;
      }
      final eWeights = [
        for (final e in blk.ejercicios) (e.duracionMin ?? 5).clamp(1, 180),
      ];
      final newExDurs = _distributeMinutes(bDur, eWeights);
      final nextExs = <ClassPlanExercise>[];
      for (var ei = 0; ei < blk.ejercicios.length; ei++) {
        final ex = blk.ejercicios[ei];
        final eDur = newExDurs[ei];
        List<PlannerInternalTiming> nextTimings;
        if (eDur < 4) {
          nextTimings = [
            PlannerInternalTiming(
              etapa: ex.internalTimings.isNotEmpty
                  ? ex.internalTimings.first.etapa
                  : 'Ejecución continua',
              minutos: eDur,
            ),
          ];
        } else if (ex.internalTimings.length >= 2) {
          final sDurs = _distributeMinutes(
            eDur,
            ex.internalTimings.map((t) => t.minutos.clamp(1, 90)).toList(),
          );
          nextTimings = [
            for (var si = 0; si < ex.internalTimings.length; si++)
              PlannerInternalTiming(
                etapa: ex.internalTimings[si].etapa,
                minutos: sDurs[si],
              ),
          ];
        } else {
          final p1 = (eDur / 3).floor().clamp(1, eDur - 1);
          nextTimings = [
            PlannerInternalTiming(etapa: 'Preparación y señales', minutos: p1),
            PlannerInternalTiming(etapa: 'Práctica guiada', minutos: eDur - p1),
          ];
        }
        nextExs.add(ex.copyWith(duracionMin: eDur, internalTimings: nextTimings));
      }
      nextBlocks.add(blk.copyWith(duracionMin: bDur, ejercicios: nextExs));
    }
    return plan.copyWith(
      schemaVersion: 2,
      duracionTotal: targetTotal,
      bloques: nextBlocks,
      updatedAt: DateTime.now(),
    );
  }
}

import 'dart:convert';
import 'class_plan_models.dart';

/// Estado individual de ejecución de un ejercicio durante la clase en vivo.
enum LiveExerciseStatus {
  pending('pending', 'Pendiente'),
  completed('completed', 'Completado'),
  skipped('skipped', 'Omitido');

  final String id;
  final String label;
  const LiveExerciseStatus(this.id, this.label);

  static LiveExerciseStatus fromId(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'completed':
      case 'completado':
        return LiveExerciseStatus.completed;
      case 'skipped':
      case 'omitido':
        return LiveExerciseStatus.skipped;
      default:
        return LiveExerciseStatus.pending;
    }
  }
}

/// Datos ingresados por el instructor en el formulario de cierre de clase.
class LiveSessionClosureInput {
  final String groupResponse;
  final String teacherObservations;
  final String difficulties;
  final String reinforceContent;
  final String continuityProposal;
  final bool endedEarly;
  final int attendeesCount;

  const LiveSessionClosureInput({
    required this.groupResponse,
    required this.teacherObservations,
    required this.difficulties,
    required this.reinforceContent,
    required this.continuityProposal,
    required this.endedEarly,
    required this.attendeesCount,
  });
}

/// Ejecución individual de un ejercicio dentro de una sesión en vivo.
class LiveExerciseExecution {
  final String blockId;
  final String blockTitle;
  final int blockIndex;
  final String exerciseId;
  final int exerciseIndex;
  final int plannedDurationSec;
  final int actualDurationSec;
  final LiveExerciseStatus status;
  final ClassPlanExercise exercise;
  final List<String> resolvedResourceIds;

  const LiveExerciseExecution({
    required this.blockId,
    required this.blockTitle,
    required this.blockIndex,
    required this.exerciseId,
    required this.exerciseIndex,
    required this.plannedDurationSec,
    this.actualDurationSec = 0,
    this.status = LiveExerciseStatus.pending,
    required this.exercise,
    this.resolvedResourceIds = const [],
  });

  LiveExerciseExecution copyWith({
    int? plannedDurationSec,
    int? actualDurationSec,
    LiveExerciseStatus? status,
    List<String>? resolvedResourceIds,
  }) {
    return LiveExerciseExecution(
      blockId: blockId,
      blockTitle: blockTitle,
      blockIndex: blockIndex,
      exerciseId: exerciseId,
      exerciseIndex: exerciseIndex,
      plannedDurationSec: (plannedDurationSec ?? this.plannedDurationSec).clamp(60, 7200),
      actualDurationSec: (actualDurationSec ?? this.actualDurationSec).clamp(0, 86400),
      status: status ?? this.status,
      exercise: exercise,
      resolvedResourceIds: List<String>.unmodifiable(
          resolvedResourceIds ?? this.resolvedResourceIds),
    );
  }

  Map<String, dynamic> toMap() => {
        'block_id': blockId,
        'block_title': blockTitle,
        'block_index': blockIndex,
        'exercise_id': exerciseId,
        'exercise_index': exerciseIndex,
        'planned_duration_sec': plannedDurationSec,
        'actual_duration_sec': actualDurationSec,
        'status': status.id,
        'exercise': exercise.toMap(),
        'resolved_resource_ids': resolvedResourceIds,
      };

  factory LiveExerciseExecution.fromMap(Map<String, dynamic> map) {
    final exMap = map['exercise'] is Map
        ? Map<String, dynamic>.from(map['exercise'] as Map)
        : const <String, dynamic>{};
    final exId = (map['exercise_id'] as String? ?? 'ex_0').trim();
    return LiveExerciseExecution(
      blockId: (map['block_id'] as String? ?? 'blk_0').trim(),
      blockTitle: (map['block_title'] as String? ?? 'Bloque').trim(),
      blockIndex: (map['block_index'] as num?)?.toInt() ?? 0,
      exerciseId: exId,
      exerciseIndex: (map['exercise_index'] as num?)?.toInt() ?? 0,
      plannedDurationSec:
          ((map['planned_duration_sec'] as num?)?.toInt() ?? 300).clamp(60, 7200),
      actualDurationSec:
          ((map['actual_duration_sec'] as num?)?.toInt() ?? 0).clamp(0, 86400),
      status: LiveExerciseStatus.fromId(map['status']?.toString()),
      exercise: ClassPlanExercise.fromMap(exMap, fallbackId: exId),
      resolvedResourceIds: ((map['resolved_resource_ids'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

/// Estado inmutable de una clase en vivo V2, resistente al segundo plano por marcas de tiempo.
class LiveSessionState {
  final String sessionId;
  final String planId;
  final Map<String, dynamic> planSnapshot;
  final String planTitle;
  final String? groupId;
  final String groupName;
  final PlannerAudienceType audienceType;
  final int plannedTotalDurationMin;
  final int participantsCount;
  final DateTime startedAt;
  final DateTime? lastResumedAt;
  final int accumulatedSessionElapsedSec;
  final int activeExerciseIndex;
  final int activeExerciseAllocatedSec;
  final int activeExerciseAccumulatedSec;
  final bool isRunning;
  final List<LiveExerciseExecution> exercises;

  const LiveSessionState({
    required this.sessionId,
    required this.planId,
    required this.planSnapshot,
    required this.planTitle,
    this.groupId,
    required this.groupName,
    required this.audienceType,
    required this.plannedTotalDurationMin,
    required this.participantsCount,
    required this.startedAt,
    required this.lastResumedAt,
    required this.accumulatedSessionElapsedSec,
    required this.activeExerciseIndex,
    required this.activeExerciseAllocatedSec,
    required this.activeExerciseAccumulatedSec,
    required this.isRunning,
    required this.exercises,
  });

  /// Inicia una sesión en vivo a partir de un plan V1 o V2 conservando su instantánea inmutable.
  factory LiveSessionState.startFromPlan({
    required ClassPlanModel plan,
    required List<PlannerResourceItem> resources,
    required DateTime now,
    String? sessionId,
    String? groupId,
  }) {
    final snapshot = jsonDecode(jsonEncode(plan.toMap())) as Map<String, dynamic>;
    final flattened = <LiveExerciseExecution>[];

    if (plan.bloques.isEmpty) {
      flattened.add(
        LiveExerciseExecution(
          blockId: 'blk_default_0',
          blockTitle: 'Sesión principal',
          blockIndex: 0,
          exerciseId: 'ex_default_0',
          exerciseIndex: 0,
          plannedDurationSec: (plan.duracionTotal * 60).clamp(60, 7200),
          exercise: ClassPlanExercise(
            exerciseId: 'ex_default_0',
            nombre: plan.titulo,
            detalle: plan.objetivo.isNotEmpty
                ? plan.objetivo
                : 'Ejecución guiada por el profesor.',
            duracionMin: plan.duracionTotal,
            contentOrigin: ContentOrigin.teacherResource,
          ),
        ),
      );
    } else {
      for (int bIdx = 0; bIdx < plan.bloques.length; bIdx++) {
        final block = plan.bloques[bIdx];
        if (block.ejercicios.isEmpty) {
          final blockSec = (block.duracionMin * 60).clamp(60, 7200);
          flattened.add(
            LiveExerciseExecution(
              blockId: block.blockId,
              blockTitle: block.fase,
              blockIndex: bIdx,
              exerciseId: '${block.blockId}_block_item',
              exerciseIndex: 0,
              plannedDurationSec: blockSec,
              exercise: ClassPlanExercise(
                exerciseId: '${block.blockId}_block_item',
                nombre: block.fase,
                detalle: 'Bloque sin ejercicios detallados (${block.duracionMin} min).',
                duracionMin: block.duracionMin,
                contentOrigin: ContentOrigin.teacherResource,
              ),
            ),
          );
          continue;
        }

        final blockSec = (block.duracionMin * 60).clamp(60, 7200);
        final fallbackEachSec = (blockSec ~/ block.ejercicios.length).clamp(60, 7200);

        for (int eIdx = 0; eIdx < block.ejercicios.length; eIdx++) {
          final ej = block.ejercicios[eIdx];
          final plannedSec = (ej.duracionMin != null && ej.duracionMin! > 0)
              ? (ej.duracionMin! * 60).clamp(60, 7200)
              : fallbackEachSec;

          flattened.add(
            LiveExerciseExecution(
              blockId: block.blockId,
              blockTitle: block.fase,
              blockIndex: bIdx,
              exerciseId: ej.exerciseId,
              exerciseIndex: eIdx,
              plannedDurationSec: plannedSec,
              exercise: ej,
              resolvedResourceIds: _resolveResourceIds(ej, resources),
            ),
          );
        }
      }
    }

    return LiveSessionState(
      sessionId: sessionId ?? 'live_${now.microsecondsSinceEpoch}',
      planId: plan.id,
      planSnapshot: Map<String, dynamic>.unmodifiable(snapshot),
      planTitle: plan.titulo,
      groupId: groupId,
      groupName: plan.groupName,
      audienceType: plan.audienceType,
      plannedTotalDurationMin: plan.duracionTotal,
      participantsCount: plan.participantsCount,
      startedAt: now,
      lastResumedAt: now,
      accumulatedSessionElapsedSec: 0,
      activeExerciseIndex: 0,
      activeExerciseAllocatedSec: flattened.first.plannedDurationSec,
      activeExerciseAccumulatedSec: 0,
      isRunning: true,
      exercises: List<LiveExerciseExecution>.unmodifiable(flattened),
    );
  }

  static List<String> _resolveResourceIds(
    ClassPlanExercise ej,
    List<PlannerResourceItem> resources,
  ) {
    final ids = <String>{...ej.linkedResourceIds};
    final legacy = ej.legacyRecursoRelacionado?.trim();
    if (legacy != null &&
        legacy.isNotEmpty &&
        legacy.toLowerCase() != 'null' &&
        legacy.toLowerCase() != 'none') {
      final legacyLower = legacy.toLowerCase();
      for (final r in resources) {
        final rId = r.resourceId.toLowerCase();
        final rTitle = r.title.toLowerCase();
        if (rId == legacyLower ||
            rTitle == legacyLower ||
            rTitle.contains(legacyLower) ||
            legacyLower.contains(rTitle)) {
          ids.add(r.resourceId);
        }
      }
    }
    return List<String>.unmodifiable(ids);
  }

  int _runningDeltaSec(DateTime now) {
    if (!isRunning || lastResumedAt == null) return 0;
    if (now.isBefore(lastResumedAt!)) return 0;
    return now.difference(lastResumedAt!).inSeconds;
  }

  int effectiveTotalElapsedSec(DateTime now) =>
      accumulatedSessionElapsedSec + _runningDeltaSec(now);

  int effectiveActiveExerciseElapsedSec(DateTime now) =>
      activeExerciseAccumulatedSec + _runningDeltaSec(now);

  int effectiveActiveExerciseRemainingSec(DateTime now) =>
      activeExerciseAllocatedSec - effectiveActiveExerciseElapsedSec(now);

  LiveExerciseExecution get activeExercise => exercises[activeExerciseIndex];

  int get totalExercisesCount => exercises.length;

  int get completedCount =>
      exercises.where((e) => e.status == LiveExerciseStatus.completed).length;

  int get skippedCount =>
      exercises.where((e) => e.status == LiveExerciseStatus.skipped).length;

  int get pendingCount =>
      exercises.where((e) => e.status == LiveExerciseStatus.pending).length;

  int get resolvedCount => completedCount + skippedCount;

  double get progressRatio =>
      totalExercisesCount == 0 ? 0.0 : (resolvedCount / totalExercisesCount).clamp(0.0, 1.0);

  /// Recursos elegibles para contabilizar: exclusivamente los de ejercicios COMPLETADOS.
  Set<String> get taughtResourceIds {
    final ids = <String>{};
    for (final ex in exercises) {
      if (ex.status == LiveExerciseStatus.completed) {
        ids.addAll(ex.resolvedResourceIds);
      }
    }
    return Set<String>.unmodifiable(ids);
  }

  /// Movimientos FIU elegibles para el historial: exclusivamente de ejercicios COMPLETADOS.
  List<String> get practicedMovementIds {
    final ids = <String>{};
    for (final ex in exercises) {
      if (ex.status == LiveExerciseStatus.completed) {
        ids.addAll(ex.exercise.curriculumMovementIds);
      }
    }
    return List<String>.unmodifiable(ids);
  }

  /// Consolida el delta actual sobre el ejercicio activo sin cambiar de ejercicio.
  LiveSessionState snapshotAt(DateTime now) {
    final delta = _runningDeltaSec(now);
    if (delta == 0) return this;
    final nextAccumSession = accumulatedSessionElapsedSec + delta;
    final nextAccumEx = activeExerciseAccumulatedSec + delta;
    final updated = List<LiveExerciseExecution>.of(exercises);
    updated[activeExerciseIndex] = updated[activeExerciseIndex].copyWith(
      actualDurationSec: nextAccumEx,
    );
    return LiveSessionState(
      sessionId: sessionId,
      planId: planId,
      planSnapshot: planSnapshot,
      planTitle: planTitle,
      groupId: groupId,
      groupName: groupName,
      audienceType: audienceType,
      plannedTotalDurationMin: plannedTotalDurationMin,
      participantsCount: participantsCount,
      startedAt: startedAt,
      lastResumedAt: isRunning ? now : null,
      accumulatedSessionElapsedSec: nextAccumSession,
      activeExerciseIndex: activeExerciseIndex,
      activeExerciseAllocatedSec: activeExerciseAllocatedSec,
      activeExerciseAccumulatedSec: nextAccumEx,
      isRunning: isRunning,
      exercises: List<LiveExerciseExecution>.unmodifiable(updated),
    );
  }

  LiveSessionState pause(DateTime now) {
    if (!isRunning) return this;
    final consolidated = snapshotAt(now);
    return LiveSessionState(
      sessionId: consolidated.sessionId,
      planId: consolidated.planId,
      planSnapshot: consolidated.planSnapshot,
      planTitle: consolidated.planTitle,
      groupId: consolidated.groupId,
      groupName: consolidated.groupName,
      audienceType: consolidated.audienceType,
      plannedTotalDurationMin: consolidated.plannedTotalDurationMin,
      participantsCount: consolidated.participantsCount,
      startedAt: consolidated.startedAt,
      lastResumedAt: null,
      accumulatedSessionElapsedSec: consolidated.accumulatedSessionElapsedSec,
      activeExerciseIndex: consolidated.activeExerciseIndex,
      activeExerciseAllocatedSec: consolidated.activeExerciseAllocatedSec,
      activeExerciseAccumulatedSec: consolidated.activeExerciseAccumulatedSec,
      isRunning: false,
      exercises: consolidated.exercises,
    );
  }

  LiveSessionState resume(DateTime now) {
    if (isRunning) return this;
    return LiveSessionState(
      sessionId: sessionId,
      planId: planId,
      planSnapshot: planSnapshot,
      planTitle: planTitle,
      groupId: groupId,
      groupName: groupName,
      audienceType: audienceType,
      plannedTotalDurationMin: plannedTotalDurationMin,
      participantsCount: participantsCount,
      startedAt: startedAt,
      lastResumedAt: now,
      accumulatedSessionElapsedSec: accumulatedSessionElapsedSec,
      activeExerciseIndex: activeExerciseIndex,
      activeExerciseAllocatedSec: activeExerciseAllocatedSec,
      activeExerciseAccumulatedSec: activeExerciseAccumulatedSec,
      isRunning: true,
      exercises: exercises,
    );
  }

  LiveSessionState adjustActiveExerciseMinutes(int deltaMinutes, DateTime now) {
    final consolidated = snapshotAt(now);
    final nextAllocated =
        (consolidated.activeExerciseAllocatedSec + (deltaMinutes * 60)).clamp(60, 7200);
    return LiveSessionState(
      sessionId: consolidated.sessionId,
      planId: consolidated.planId,
      planSnapshot: consolidated.planSnapshot,
      planTitle: consolidated.planTitle,
      groupId: consolidated.groupId,
      groupName: consolidated.groupName,
      audienceType: consolidated.audienceType,
      plannedTotalDurationMin: consolidated.plannedTotalDurationMin,
      participantsCount: consolidated.participantsCount,
      startedAt: consolidated.startedAt,
      lastResumedAt: consolidated.isRunning ? now : null,
      accumulatedSessionElapsedSec: consolidated.accumulatedSessionElapsedSec,
      activeExerciseIndex: consolidated.activeExerciseIndex,
      activeExerciseAllocatedSec: nextAllocated,
      activeExerciseAccumulatedSec: consolidated.activeExerciseAccumulatedSec,
      isRunning: consolidated.isRunning,
      exercises: consolidated.exercises,
    );
  }

  LiveSessionState resetActiveExerciseTimer(DateTime now) {
    final consolidated = snapshotAt(now);
    final updated = List<LiveExerciseExecution>.of(consolidated.exercises);
    final active = updated[consolidated.activeExerciseIndex];
    updated[consolidated.activeExerciseIndex] = active.copyWith(actualDurationSec: 0);
    return LiveSessionState(
      sessionId: consolidated.sessionId,
      planId: consolidated.planId,
      planSnapshot: consolidated.planSnapshot,
      planTitle: consolidated.planTitle,
      groupId: consolidated.groupId,
      groupName: consolidated.groupName,
      audienceType: consolidated.audienceType,
      plannedTotalDurationMin: consolidated.plannedTotalDurationMin,
      participantsCount: consolidated.participantsCount,
      startedAt: consolidated.startedAt,
      lastResumedAt: consolidated.isRunning ? now : null,
      accumulatedSessionElapsedSec: consolidated.accumulatedSessionElapsedSec,
      activeExerciseIndex: consolidated.activeExerciseIndex,
      activeExerciseAllocatedSec: active.plannedDurationSec,
      activeExerciseAccumulatedSec: 0,
      isRunning: consolidated.isRunning,
      exercises: List<LiveExerciseExecution>.unmodifiable(updated),
    );
  }

  LiveSessionState goToExercise(int targetIndex, DateTime now) {
    if (targetIndex < 0 || targetIndex >= exercises.length) return this;
    final consolidated = snapshotAt(now);
    if (targetIndex == consolidated.activeExerciseIndex) return consolidated;
    final target = consolidated.exercises[targetIndex];
    return LiveSessionState(
      sessionId: consolidated.sessionId,
      planId: consolidated.planId,
      planSnapshot: consolidated.planSnapshot,
      planTitle: consolidated.planTitle,
      groupId: consolidated.groupId,
      groupName: consolidated.groupName,
      audienceType: consolidated.audienceType,
      plannedTotalDurationMin: consolidated.plannedTotalDurationMin,
      participantsCount: consolidated.participantsCount,
      startedAt: consolidated.startedAt,
      lastResumedAt: consolidated.isRunning ? now : null,
      accumulatedSessionElapsedSec: consolidated.accumulatedSessionElapsedSec,
      activeExerciseIndex: targetIndex,
      activeExerciseAllocatedSec: target.plannedDurationSec,
      activeExerciseAccumulatedSec: target.actualDurationSec,
      isRunning: consolidated.isRunning,
      exercises: consolidated.exercises,
    );
  }

  LiveSessionState goToBlock(int blockIndex, DateTime now) {
    final idx = exercises.indexWhere((e) => e.blockIndex == blockIndex);
    if (idx < 0) return this;
    return goToExercise(idx, now);
  }

  LiveSessionState markActiveStatus(
    LiveExerciseStatus status,
    DateTime now, {
    bool advanceToNext = false,
  }) {
    final consolidated = snapshotAt(now);
    final updated = List<LiveExerciseExecution>.of(consolidated.exercises);
    updated[consolidated.activeExerciseIndex] =
        updated[consolidated.activeExerciseIndex].copyWith(status: status);

    final nextState = LiveSessionState(
      sessionId: consolidated.sessionId,
      planId: consolidated.planId,
      planSnapshot: consolidated.planSnapshot,
      planTitle: consolidated.planTitle,
      groupId: consolidated.groupId,
      groupName: consolidated.groupName,
      audienceType: consolidated.audienceType,
      plannedTotalDurationMin: consolidated.plannedTotalDurationMin,
      participantsCount: consolidated.participantsCount,
      startedAt: consolidated.startedAt,
      lastResumedAt: consolidated.isRunning ? now : null,
      accumulatedSessionElapsedSec: consolidated.accumulatedSessionElapsedSec,
      activeExerciseIndex: consolidated.activeExerciseIndex,
      activeExerciseAllocatedSec: consolidated.activeExerciseAllocatedSec,
      activeExerciseAccumulatedSec: consolidated.activeExerciseAccumulatedSec,
      isRunning: consolidated.isRunning,
      exercises: List<LiveExerciseExecution>.unmodifiable(updated),
    );

    if (advanceToNext &&
        nextState.activeExerciseIndex + 1 < nextState.exercises.length) {
      return nextState.goToExercise(nextState.activeExerciseIndex + 1, now);
    }
    return nextState;
  }

  Map<String, dynamic> toJsonMap() => {
        'session_id': sessionId,
        'plan_id': planId,
        'plan_snapshot': planSnapshot,
        'plan_title': planTitle,
        if (groupId != null) 'group_id': groupId,
        'group_name': groupName,
        'audience_type': audienceType.id,
        'planned_total_duration_min': plannedTotalDurationMin,
        'participants_count': participantsCount,
        'started_at': startedAt.toIso8601String(),
        if (lastResumedAt != null) 'last_resumed_at': lastResumedAt!.toIso8601String(),
        'accumulated_session_elapsed_sec': accumulatedSessionElapsedSec,
        'active_exercise_index': activeExerciseIndex,
        'active_exercise_allocated_sec': activeExerciseAllocatedSec,
        'active_exercise_accumulated_sec': activeExerciseAccumulatedSec,
        'is_running': isRunning,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  String toJsonString() => jsonEncode(toJsonMap());

  factory LiveSessionState.fromJsonMap(Map<String, dynamic> map) {
    final rawExercises = (map['exercises'] as List?) ?? const [];
    final exercisesList = [
      for (final item in rawExercises)
        if (item is Map) LiveExerciseExecution.fromMap(Map<String, dynamic>.from(item)),
    ];
    final activeIdx = ((map['active_exercise_index'] as num?)?.toInt() ?? 0)
        .clamp(0, exercisesList.isEmpty ? 0 : exercisesList.length - 1);
    final rawSnapshot = map['plan_snapshot'] is Map
        ? Map<String, dynamic>.from(map['plan_snapshot'] as Map)
        : const <String, dynamic>{};

    return LiveSessionState(
      sessionId: (map['session_id'] as String? ?? 'live_recovered').trim(),
      planId: (map['plan_id'] as String? ?? '').trim(),
      planSnapshot: Map<String, dynamic>.unmodifiable(rawSnapshot),
      planTitle: (map['plan_title'] as String? ?? 'Clase en vivo').trim(),
      groupId: (map['group_id'] as String?)?.trim(),
      groupName: (map['group_name'] as String? ?? 'Grupo').trim(),
      audienceType:
          PlannerAudienceType.fromLegacyLevel(map['audience_type']?.toString()),
      plannedTotalDurationMin:
          (map['planned_total_duration_min'] as num?)?.toInt() ?? 60,
      participantsCount: (map['participants_count'] as num?)?.toInt() ?? 10,
      startedAt: DateTime.tryParse(map['started_at']?.toString() ?? '') ??
          DateTime.now(),
      lastResumedAt:
          DateTime.tryParse(map['last_resumed_at']?.toString() ?? ''),
      accumulatedSessionElapsedSec:
          ((map['accumulated_session_elapsed_sec'] as num?)?.toInt() ?? 0)
              .clamp(0, 86400),
      activeExerciseIndex: activeIdx,
      activeExerciseAllocatedSec:
          ((map['active_exercise_allocated_sec'] as num?)?.toInt() ?? 300)
              .clamp(60, 7200),
      activeExerciseAccumulatedSec:
          ((map['active_exercise_accumulated_sec'] as num?)?.toInt() ?? 0)
              .clamp(0, 86400),
      isRunning: map['is_running'] == true,
      exercises: List<LiveExerciseExecution>.unmodifiable(exercisesList),
    );
  }

  static LiveSessionState? tryFromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final state = LiveSessionState.fromJsonMap(
        Map<String, dynamic>.from(decoded),
      );
      if (state.exercises.isEmpty) return null;
      return state;
    } catch (_) {
      return null;
    }
  }

  TaughtSessionRecord toTaughtSessionRecord({
    required DateTime finishedAt,
    required LiveSessionClosureInput closure,
    required Map<String, String> movementNamesById,
  }) {
    final consolidated = snapshotAt(finishedAt);
    final totalSec = consolidated.effectiveTotalElapsedSec(finishedAt);
    final realMin = totalSec <= 0 ? 0 : ((totalSec / 60).round().clamp(1, 300));

    final movementLabels = <String>[];
    for (final id in consolidated.practicedMovementIds) {
      movementLabels.add(movementNamesById[id] ?? id);
    }

    final completedList = <String>[];
    final skippedList = <String>[];
    final pendingList = <String>[];
    final realDurMap = <String, int>{};

    for (final ex in consolidated.exercises) {
      realDurMap[ex.exerciseId] = ex.actualDurationSec;
      switch (ex.status) {
        case LiveExerciseStatus.completed:
          completedList.add(ex.exercise.nombre);
          break;
        case LiveExerciseStatus.skipped:
          skippedList.add(ex.exercise.nombre);
          break;
        case LiveExerciseStatus.pending:
          pendingList.add(ex.exercise.nombre);
          break;
      }
    }

    final taughtIds = consolidated.taughtResourceIds.toList()..sort();

    return TaughtSessionRecord(
      sessionId: consolidated.sessionId,
      planId: consolidated.planId,
      planTitle: consolidated.planTitle,
      groupId: consolidated.groupId,
      groupName: consolidated.groupName,
      audienceType: consolidated.audienceType,
      date: finishedAt,
      durationMin: realMin,
      actualDurationSec: totalSec,
      attendeesCount: closure.attendeesCount,
      completedExercisesCount: completedList.length,
      totalExercisesCount: consolidated.totalExercisesCount,
      practicedMovements: List<String>.unmodifiable(movementLabels),
      summaryNote: closure.teacherObservations.trim(),
      pendingNextSession: closure.continuityProposal.trim(),
      groupResponse: closure.groupResponse.trim(),
      difficulties: closure.difficulties.trim(),
      reinforceContent: closure.reinforceContent.trim(),
      completedExercises: List<String>.unmodifiable(completedList),
      skippedExercises: List<String>.unmodifiable(skippedList),
      pendingExercises: List<String>.unmodifiable(pendingList),
      exerciseRealDurationsSec: Map<String, int>.unmodifiable(realDurMap),
      taughtResourceIds: List<String>.unmodifiable(taughtIds),
      planSnapshot: consolidated.planSnapshot,
      endedEarly: closure.endedEarly,
      isSimulatedFixture: false,
    );
  }
}

/// Formatea una cantidad de segundos a MM:SS o H:MM:SS sin librerías externas.
String formatDurationMmSs(int totalSeconds) {
  final safe = totalSeconds < 0 ? -totalSeconds : totalSeconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final seconds = safe % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss';
  }
  return '$mm:$ss';
}

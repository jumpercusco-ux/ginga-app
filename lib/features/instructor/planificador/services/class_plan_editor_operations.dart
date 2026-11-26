import '../models/class_plan_models.dart';

/// Resumen de tiempos de un bloque individual respecto a la suma de sus ejercicios.
class BlockTimingSummary {
  final String blockId;
  final String fase;
  final int blockDurationMin;
  final int exercisesSumMin;
  final bool hasExerciseDurations;
  final bool hasMismatch;
  final bool isEmpty;

  const BlockTimingSummary({
    required this.blockId,
    required this.fase,
    required this.blockDurationMin,
    required this.exercisesSumMin,
    required this.hasExerciseDurations,
    required this.hasMismatch,
    required this.isEmpty,
  });
}

/// Resumen permanente y no bloqueante del control de tiempos de una clase.
class ClassPlanTimingSummary {
  final int targetMinutes;
  final int plannedMinutes;
  final int deltaMinutes;
  final int remainingMinutes;
  final int excessMinutes;
  final bool isExact;
  final List<BlockTimingSummary> blockSummaries;
  final List<String> warnings;

  const ClassPlanTimingSummary({
    required this.targetMinutes,
    required this.plannedMinutes,
    required this.deltaMinutes,
    required this.remainingMinutes,
    required this.excessMinutes,
    required this.isExact,
    required this.blockSummaries,
    required this.warnings,
  });

  factory ClassPlanTimingSummary.fromPlan(ClassPlanModel plan) {
    final target = plan.duracionTotal;
    final planned = plan.plannedDurationMin;
    final delta = planned - target;
    final remaining = delta < 0 ? -delta : 0;
    final excess = delta > 0 ? delta : 0;

    final warnings = <String>[];
    if (plan.bloques.isEmpty) {
      warnings.add('La clase aún no tiene bloques planificados.');
    }
    if (remaining > 0) {
      warnings.add(
        'Faltan $remaining min para completar la duración objetivo ($target min).',
      );
    } else if (excess > 0) {
      warnings.add(
        'La planificación excede el objetivo por $excess min ($planned/$target min).',
      );
    }

    final blockSummaries = <BlockTimingSummary>[];
    for (final b in plan.bloques) {
      final exSum = b.exercisesTotalDurationMin;
      final hasEntries = b.hasExerciseDurationEntries;
      final mismatch = b.hasDurationMismatch;
      final empty = b.ejercicios.isEmpty;
      blockSummaries.add(
        BlockTimingSummary(
          blockId: b.blockId,
          fase: b.fase,
          blockDurationMin: b.duracionMin,
          exercisesSumMin: exSum,
          hasExerciseDurations: hasEntries,
          hasMismatch: mismatch,
          isEmpty: empty,
        ),
      );
      if (empty) {
        warnings.add("El bloque '${b.fase}' aún no tiene ejercicios.");
      } else if (mismatch) {
        warnings.add(
          "El bloque '${b.fase}' dura ${b.duracionMin} min pero sus ejercicios suman $exSum min.",
        );
      }
    }

    return ClassPlanTimingSummary(
      targetMinutes: target,
      plannedMinutes: planned,
      deltaMinutes: delta,
      remainingMinutes: remaining,
      excessMinutes: excess,
      isExact: delta == 0 && plan.bloques.isNotEmpty,
      blockSummaries: List<BlockTimingSummary>.unmodifiable(blockSummaries),
      warnings: List<String>.unmodifiable(warnings),
    );
  }
}

/// Operaciones puras e inmutables para editar, duplicar y reorganizar clases V1/V2.
/// Garantiza IDs estables, aislamiento entre ejercicios/planes y protección curricular infantil.
class ClassPlanEditorOperations {
  static int _idCounter = 0;

  static String nextId(String prefix, Set<String> existingIds) {
    _idCounter++;
    var candidate = '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
    while (existingIds.contains(candidate)) {
      _idCounter++;
      candidate = '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
    }
    return candidate;
  }

  static Set<String> _allBlockIds(ClassPlanModel plan) =>
      plan.bloques.map((b) => b.blockId).toSet();

  static Set<String> _allExerciseIds(ClassPlanModel plan) => plan.bloques
      .expand((b) => b.ejercicios)
      .map((e) => e.exerciseId)
      .toSet();

  /// Actualiza metadatos de la clase respetando las restricciones curriculares para Infantil/Mixto.
  static ClassPlanModel updateMetadata(
    ClassPlanModel plan, {
    String? titulo,
    List<String>? objetivos,
    int? duracionTotal,
    String? enfoque,
    String? groupName,
    PlannerAudienceType? audienceType,
    PlannerCurriculumScope? curriculumScope,
    String? consejosInstructor,
    bool clearConsejosInstructor = false,
    ClassPlanStatus? planStatus,
  }) {
    final nextAudience = audienceType ?? plan.audienceType;
    var nextScope = curriculumScope ?? plan.curriculumScope;

    // Regla curricular estricta: nunca aplicar currículo Adulto FIU a grupos infantiles o mixtos.
    if (nextAudience == PlannerAudienceType.infantil &&
        nextScope == PlannerCurriculumScope.adultoFiu) {
      nextScope = PlannerCurriculumScope.infantilFiuPending;
    } else if (audienceType != null &&
        audienceType != plan.audienceType &&
        curriculumScope == null) {
      nextScope = PlannerCurriculumScope.suggestedForAudience(nextAudience);
    } else if (nextAudience == PlannerAudienceType.mixto &&
        audienceType != null &&
        curriculumScope == null) {
      nextScope = PlannerCurriculumScope.mixedNoOfficialTrack;
    }

    final cleanObjectives = objetivos != null
        ? objetivos.map((o) => o.trim()).where((o) => o.isNotEmpty).toList()
        : plan.objetivos;
    final joinedObjective = cleanObjectives.isNotEmpty
        ? cleanObjectives.join(' · ')
        : (objetivos != null ? '' : plan.objetivo);

    // Si dejó de ser adultoFiu, evitar retener vínculos automáticos adultos en silencio;
    // se limpian los movementIds si cambió desde adultoFiu hacia infantil.
    var nextBloques = plan.bloques;
    if (nextAudience == PlannerAudienceType.infantil &&
        plan.audienceType != PlannerAudienceType.infantil) {
      nextBloques = plan.bloques
          .map(
            (b) => b.copyWith(
              ejercicios: b.ejercicios
                  .map(
                    (e) => e.curriculumMovementIds.isNotEmpty
                        ? e.copyWith(
                            curriculumMovementIds: const [],
                            contentOrigin: e.contentOrigin ==
                                    ContentOrigin.officialFiuCurriculum
                                ? ContentOrigin.teacherResource
                                : e.contentOrigin,
                          )
                        : e,
                  )
                  .toList(),
            ),
          )
          .toList();
    }

    return plan.copyWith(
      schemaVersion: 2,
      titulo: titulo,
      objetivos: cleanObjectives,
      objetivo: joinedObjective,
      duracionTotal: duracionTotal?.clamp(10, 300),
      enfoque: enfoque,
      groupName: groupName,
      audienceType: nextAudience,
      nivelLabel: nextAudience.label,
      curriculumScope: nextScope,
      consejosInstructor: consejosInstructor,
      clearConsejosInstructor: clearConsejosInstructor,
      planStatus: planStatus,
      bloques: nextBloques,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel addBlock(
    ClassPlanModel plan, {
    required String fase,
    int duracionMin = 10,
  }) {
    final newId = nextId('blk', _allBlockIds(plan));
    final block = ClassPlanBlock(
      blockId: newId,
      fase: fase.trim().isEmpty ? 'Nuevo bloque' : fase.trim(),
      duracionMin: duracionMin.clamp(0, 300),
      ejercicios: const [],
    );
    return plan.copyWith(
      schemaVersion: 2,
      bloques: [...plan.bloques, block],
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel updateBlock(
    ClassPlanModel plan,
    String blockId, {
    String? fase,
    int? duracionMin,
  }) {
    final updated = plan.bloques.map((b) {
      if (b.blockId != blockId) return b;
      return b.copyWith(
        fase: fase != null
            ? (fase.trim().isEmpty ? b.fase : fase.trim())
            : b.fase,
        duracionMin: duracionMin,
      );
    }).toList();
    return plan.copyWith(
      schemaVersion: 2,
      bloques: updated,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel syncBlockDurationFromExercises(
    ClassPlanModel plan,
    String blockId,
  ) {
    final updated = plan.bloques.map((b) {
      if (b.blockId != blockId) return b;
      final sum = b.exercisesTotalDurationMin;
      if (sum <= 0) return b;
      return b.copyWith(duracionMin: sum);
    }).toList();
    return plan.copyWith(
      schemaVersion: 2,
      bloques: updated,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel deleteBlock(ClassPlanModel plan, String blockId) {
    final updated = plan.bloques.where((b) => b.blockId != blockId).toList();
    return plan.copyWith(
      schemaVersion: 2,
      bloques: updated,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel duplicateBlock(ClassPlanModel plan, String blockId) {
    final idx = plan.bloques.indexWhere((b) => b.blockId == blockId);
    if (idx < 0) return plan;

    final orig = plan.bloques[idx];
    final existingBlockIds = _allBlockIds(plan);
    final existingExerciseIds = _allExerciseIds(plan);
    final newBlockId = nextId('blk', existingBlockIds);

    final copiedExercises = <ClassPlanExercise>[];
    for (final ex in orig.ejercicios) {
      final newExId = nextId('ex', existingExerciseIds);
      existingExerciseIds.add(newExId);
      copiedExercises.add(
        ex.copyWith(
          exerciseId: newExId,
        ),
      );
    }

    final copy = ClassPlanBlock(
      blockId: newBlockId,
      fase: '${orig.fase} (Copia)',
      duracionMin: orig.duracionMin,
      ejercicios: copiedExercises,
    );

    final updated = List<ClassPlanBlock>.from(plan.bloques);
    updated.insert(idx + 1, copy);
    return plan.copyWith(
      schemaVersion: 2,
      bloques: updated,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel reorderBlocks(
    ClassPlanModel plan,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < 0 ||
        oldIndex >= plan.bloques.length ||
        newIndex < 0 ||
        newIndex >= plan.bloques.length ||
        oldIndex == newIndex) {
      return plan;
    }
    final list = List<ClassPlanBlock>.from(plan.bloques);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    return plan.copyWith(
      schemaVersion: 2,
      bloques: list,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel addExercise(
    ClassPlanModel plan,
    String blockId,
    ClassPlanExercise exercise,
  ) {
    final existingExerciseIds = _allExerciseIds(plan);
    final resolvedId = existingExerciseIds.contains(exercise.exerciseId) ||
            exercise.exerciseId.trim().isEmpty
        ? nextId('ex', existingExerciseIds)
        : exercise.exerciseId;
    final cleanExercise = exercise.copyWith(exerciseId: resolvedId);

    final updated = plan.bloques.map((b) {
      if (b.blockId != blockId) return b;
      return b.copyWith(ejercicios: [...b.ejercicios, cleanExercise]);
    }).toList();

    return plan.copyWith(
      schemaVersion: 2,
      bloques: updated,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel updateExercise(
    ClassPlanModel plan,
    String blockId,
    ClassPlanExercise updatedExercise,
  ) {
    final updatedBloques = plan.bloques.map((b) {
      if (b.blockId != blockId) return b;
      return b.copyWith(
        ejercicios: b.ejercicios
            .map((e) =>
                e.exerciseId == updatedExercise.exerciseId ? updatedExercise : e)
            .toList(),
      );
    }).toList();
    return plan.copyWith(
      schemaVersion: 2,
      bloques: updatedBloques,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel deleteExercise(
    ClassPlanModel plan,
    String blockId,
    String exerciseId,
  ) {
    final updatedBloques = plan.bloques.map((b) {
      if (b.blockId != blockId) return b;
      return b.copyWith(
        ejercicios: b.ejercicios.where((e) => e.exerciseId != exerciseId).toList(),
      );
    }).toList();
    return plan.copyWith(
      schemaVersion: 2,
      bloques: updatedBloques,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel duplicateExercise(
    ClassPlanModel plan,
    String blockId,
    String exerciseId,
  ) {
    final existingExerciseIds = _allExerciseIds(plan);
    final updatedBloques = plan.bloques.map((b) {
      if (b.blockId != blockId) return b;
      final idx = b.ejercicios.indexWhere((e) => e.exerciseId == exerciseId);
      if (idx < 0) return b;
      final orig = b.ejercicios[idx];
      final newExId = nextId('ex', existingExerciseIds);
      final copy = orig.copyWith(
        exerciseId: newExId,
        nombre: '${orig.nombre} (Copia)',
      );
      final list = List<ClassPlanExercise>.from(b.ejercicios);
      list.insert(idx + 1, copy);
      return b.copyWith(ejercicios: list);
    }).toList();

    return plan.copyWith(
      schemaVersion: 2,
      bloques: updatedBloques,
      updatedAt: DateTime.now(),
    );
  }

  static ClassPlanModel reorderExercises(
    ClassPlanModel plan,
    String blockId,
    int oldIndex,
    int newIndex,
  ) {
    final updatedBloques = plan.bloques.map((b) {
      if (b.blockId != blockId) return b;
      if (oldIndex < 0 ||
          oldIndex >= b.ejercicios.length ||
          newIndex < 0 ||
          newIndex >= b.ejercicios.length ||
          oldIndex == newIndex) {
        return b;
      }
      final list = List<ClassPlanExercise>.from(b.ejercicios);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      return b.copyWith(ejercicios: list);
    }).toList();

    return plan.copyWith(
      schemaVersion: 2,
      bloques: updatedBloques,
      updatedAt: DateTime.now(),
    );
  }

  /// Crea una copia profunda independiente de un plan V1 o V2 sin alterar el original.
  /// Preserva todos los blockId/exerciseId/curriculumMovementIds/linkedResourceIds/orígenes.
  static ClassPlanModel duplicatePlan(
    ClassPlanModel original, {
    String? newId,
    Set<String> existingPlanIds = const {},
  }) {
    final resolvedId = newId ?? nextId('plan_copy', existingPlanIds);
    final copiedBlocks = [
      for (final b in original.bloques)
        ClassPlanBlock(
          blockId: b.blockId,
          fase: b.fase,
          duracionMin: b.duracionMin,
          ejercicios: [
            for (final e in b.ejercicios) e.copyWith(),
          ],
        ),
    ];

    final now = DateTime.now();
    return ClassPlanModel(
      id: resolvedId,
      schemaVersion: 2,
      planStatus: ClassPlanStatus.draft,
      creationMode: original.creationMode,
      titulo: '${original.titulo} (Copia)',
      duracionTotal: original.duracionTotal,
      nivelLabel: original.nivelLabel,
      audienceType: original.audienceType,
      curriculumScope: original.curriculumScope,
      enfoque: original.enfoque,
      objetivo: original.objetivo,
      objetivos: List<String>.unmodifiable(original.objetivos),
      groupName: original.groupName,
      ageMin: original.ageMin,
      ageMax: original.ageMax,
      participantsCount: original.participantsCount,
      experienceDistribution: original.experienceDistribution.copyWith(),
      bloques: List<ClassPlanBlock>.unmodifiable(copiedBlocks),
      consejosInstructor: original.consejosInstructor,
      vecesImpartida: 0,
      createdAt: now,
      updatedAt: now,
      ultimaEjecucion: null,
      duplicatedFromPlanId: original.id,
      rawLegacyMap: const {},
    );
  }
}

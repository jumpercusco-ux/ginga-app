import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/curriculum_models.dart';

enum PlannerHubTab {
  plans('Mis Planes'),
  resources('Pizarra de Recursos'),
  history('Historial');

  final String label;
  const PlannerHubTab(this.label);
}

enum PlannerCreationMode {
  quick('rápida', 'Creación rápida'),
  advanced('avanzada', 'Creación avanzada');

  final String id;
  final String label;
  const PlannerCreationMode(this.id, this.label);

  static PlannerCreationMode fromId(String? value) {
    return PlannerCreationMode.values.firstWhere(
      (m) => m.id == value,
      orElse: () => PlannerCreationMode.quick,
    );
  }
}

enum PlannerGroupSource {
  realClass('real_class', 'Grupo real'),
  manual('manual', 'Configuración manual');

  final String id;
  final String label;
  const PlannerGroupSource(this.id, this.label);
}

enum PlannerAudienceType {
  adultos('adultos', 'Adultos'),
  infantil('infantil', 'Infantil'),
  mixto('mixto', 'Mixto');

  final String id;
  final String label;
  const PlannerAudienceType(this.id, this.label);

  static PlannerAudienceType fromLegacyLevel(String? raw) {
    final norm = (raw ?? '').trim().toLowerCase();
    if (norm.contains('niñ') || norm.contains('kid') || norm.contains('infant')) {
      return PlannerAudienceType.infantil;
    }
    if (norm.contains('mixt') || norm.contains('todos')) {
      return PlannerAudienceType.mixto;
    }
    return PlannerAudienceType.adultos;
  }
}

const List<String> kPlannerFocusOptions = [
  'Técnica',
  'Juegos',
  'Acrobacias',
  'Musicalidad',
  'Secuencias',
  'Roda',
];

const List<String> kPlannerOrganizationOptions = [
  'Todos simultáneamente',
  'Rotación por parejas',
  'Estaciones simultáneas',
  'Turnos',
  'Organización personalizada',
];

/// Alcance curricular explícito. Nunca infiere automáticamente Adulto para Mixto o Infantil.
enum PlannerCurriculumScope {
  adultoFiu(
    'adulto_fiu',
    'Currículo Adulto FIU verificado',
    'Adulto FIU',
  ),
  infantilFiuPending(
    'infantil_fiu_pending',
    'Currículo Infantil FIU (extracción pendiente)',
    'Infantil FIU (en preparación)',
  ),
  mixedNoOfficialTrack(
    'mixed_no_official_track',
    'Grupo mixto (sin pista curricular automática)',
    'Grupo mixto (libre)',
  ),
  noneManual(
    'none_manual',
    'Solo libre / recursos del profesor',
    'Planificación libre',
  );

  final String id;
  final String label;
  final String teacherLabel;
  const PlannerCurriculumScope(this.id, this.label, this.teacherLabel);

  static PlannerCurriculumScope fromId(
    String? value, {
    required PlannerAudienceType fallbackAudience,
  }) {
    if (value != null && value.isNotEmpty) {
      for (final s in PlannerCurriculumScope.values) {
        if (s.id == value) return s;
      }
    }
    return suggestedForAudience(fallbackAudience);
  }

  static PlannerCurriculumScope suggestedForAudience(
      PlannerAudienceType audience) {
    switch (audience) {
      case PlannerAudienceType.adultos:
        return PlannerCurriculumScope.adultoFiu;
      case PlannerAudienceType.infantil:
        return PlannerCurriculumScope.infantilFiuPending;
      case PlannerAudienceType.mixto:
        return PlannerCurriculumScope.mixedNoOfficialTrack;
    }
  }
}

/// Condiciones físicas y humanas del espacio (sin suposiciones por defecto).
class PlannerSpaceContext {
  final String spaceSize; // 'amplio' | 'mediano' | 'reducido' | 'desconocido'
  final String floorType; // 'tatami' | 'madera' | 'cemento' | 'exterior' | 'pasto' | 'desconocido'
  final bool? availableMats; // null = desconocido / sin confirmar
  final int instructorsAvailable;
  final String spaceNotes;

  const PlannerSpaceContext({
    this.spaceSize = 'desconocido',
    this.floorType = 'desconocido',
    this.availableMats,
    this.instructorsAvailable = 1,
    this.spaceNotes = '',
  });

  bool get isConfirmed =>
      spaceSize != 'desconocido' ||
      floorType != 'desconocido' ||
      availableMats != null;

  PlannerSpaceContext copyWith({
    String? spaceSize,
    String? floorType,
    bool? availableMats,
    bool clearAvailableMats = false,
    int? instructorsAvailable,
    String? spaceNotes,
  }) {
    return PlannerSpaceContext(
      spaceSize: spaceSize ?? this.spaceSize,
      floorType: floorType ?? this.floorType,
      availableMats:
          clearAvailableMats ? null : (availableMats ?? this.availableMats),
      instructorsAvailable:
          (instructorsAvailable ?? this.instructorsAvailable).clamp(1, 10),
      spaceNotes: spaceNotes ?? this.spaceNotes,
    );
  }

  Map<String, dynamic> toMap() => {
        'space_size': spaceSize,
        'floor_type': floorType,
        if (availableMats != null) 'available_mats': availableMats,
        'instructors_available': instructorsAvailable,
        if (spaceNotes.trim().isNotEmpty)
          'space_notes': PlannerPiiSanitizer.sanitizeFreeText(spaceNotes),
      };

  factory PlannerSpaceContext.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlannerSpaceContext();
    return PlannerSpaceContext(
      spaceSize: (map['space_size']?.toString() ?? 'desconocido').trim(),
      floorType: (map['floor_type']?.toString() ?? 'desconocido').trim(),
      availableMats:
          map['available_mats'] is bool ? map['available_mats'] as bool : null,
      instructorsAvailable:
          (map['instructors_available'] as num?)?.toInt().clamp(1, 10) ?? 1,
      spaceNotes: (map['space_notes']?.toString() ?? '').trim(),
    );
  }
}

/// Referencia estructurada al Cancionero GINGA sin inventar IDs.
class PlannerSongReference {
  final String songTitle;
  final String rhythm;
  final String audienceFit;
  final String? cantigaId;
  final String lookupHint;

  const PlannerSongReference({
    required this.songTitle,
    required this.rhythm,
    required this.audienceFit,
    this.cantigaId,
    required this.lookupHint,
  });

  Map<String, dynamic> toMap() => {
        'song_title': songTitle,
        'rhythm': rhythm,
        'audience_fit': audienceFit,
        'cantiga_id': cantigaId,
        'lookup_hint': lookupHint,
      };

  factory PlannerSongReference.fromMap(Map<String, dynamic> map) {
    return PlannerSongReference(
      songTitle: (map['song_title']?.toString() ?? '').trim(),
      rhythm: (map['rhythm']?.toString() ?? 'Corrido').trim(),
      audienceFit: (map['audience_fit']?.toString() ?? 'todos').trim(),
      cantigaId: map['cantiga_id']?.toString().trim(),
      lookupHint: (map['lookup_hint']?.toString() ?? '').trim(),
    );
  }
}

/// Metadatos transparentes de generación del Motor V2.
class PlannerGenerationMeta {
  final String engineVersion;
  final String provider;
  final String model;
  final bool isSimulated;
  final int repairAttemptsUsed;
  final List<String> transparencyNotices;
  final String heuristicDisclaimer;
  final String continuityAppliedNote;
  final PlannerSpaceContext? spaceSnapshot;

  const PlannerGenerationMeta({
    required this.engineVersion,
    required this.provider,
    required this.model,
    required this.isSimulated,
    this.repairAttemptsUsed = 0,
    this.transparencyNotices = const [],
    this.heuristicDisclaimer = '',
    this.continuityAppliedNote = '',
    this.spaceSnapshot,
  });

  Map<String, dynamic> toMap() => {
        'engine_version': engineVersion,
        'provider': provider,
        'model': model,
        'is_simulated': isSimulated,
        'repair_attempts_used': repairAttemptsUsed,
        if (transparencyNotices.isNotEmpty)
          'transparency_notices': transparencyNotices,
        if (heuristicDisclaimer.isNotEmpty)
          'heuristic_disclaimer': heuristicDisclaimer,
        if (continuityAppliedNote.isNotEmpty)
          'continuity_applied_note': continuityAppliedNote,
        if (spaceSnapshot != null) 'space_snapshot': spaceSnapshot!.toMap(),
      };

  factory PlannerGenerationMeta.fromMap(Map<String, dynamic> map) {
    return PlannerGenerationMeta(
      engineVersion: (map['engine_version']?.toString() ?? 'planner_v2.1.0').trim(),
      provider: (map['provider']?.toString() ?? 'simulated').trim(),
      model: (map['model']?.toString() ?? 'simulated-planner-v2').trim(),
      isSimulated: map['is_simulated'] != false,
      repairAttemptsUsed:
          (map['repair_attempts_used'] as num?)?.toInt() ?? 0,
      transparencyNotices: ((map['transparency_notices'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      heuristicDisclaimer:
          (map['heuristic_disclaimer']?.toString() ?? '').trim(),
      continuityAppliedNote:
          (map['continuity_applied_note']?.toString() ?? '').trim(),
      spaceSnapshot: map['space_snapshot'] is Map
          ? PlannerSpaceContext.fromMap(
              Map<String, dynamic>.from(map['space_snapshot'] as Map))
          : null,
    );
  }
}

/// Distingue estrictamente los tres orígenes permitidos dentro de un plan.
enum ContentOrigin {
  officialFiuCurriculum('official_fiu_curriculum', 'Currículo oficial FIU'),
  teacherResource('teacher_resource', 'Recurso del profesor'),
  aiComplementaryProposal(
      'ai_complementary_proposal', 'Propuesta complementaria IA');

  final String id;
  final String label;
  const ContentOrigin(this.id, this.label);

  static ContentOrigin fromId(String? value) {
    return ContentOrigin.values.firstWhere(
      (o) => o.id == value,
      orElse: () => ContentOrigin.aiComplementaryProposal,
    );
  }
}

enum ResourcePriority {
  required('required', 'Obligatorio'),
  optional('optional', 'Opcional');

  final String id;
  final String label;
  const ResourcePriority(this.id, this.label);
}

enum ClassPlanStatus {
  draft('draft', 'Borrador'),
  saved('saved', 'Planificada'),
  inProgress('in_progress', 'En ejecución'),
  completed('completed', 'Finalizada'),
  archived('archived', 'Archivada');

  final String id;
  final String label;
  const ClassPlanStatus(this.id, this.label);

  bool canTransitionTo(ClassPlanStatus next) {
    switch (this) {
      case ClassPlanStatus.draft:
        return next == ClassPlanStatus.draft ||
            next == ClassPlanStatus.saved ||
            next == ClassPlanStatus.inProgress ||
            next == ClassPlanStatus.archived;
      case ClassPlanStatus.saved:
        return next == ClassPlanStatus.draft ||
            next == ClassPlanStatus.saved ||
            next == ClassPlanStatus.inProgress ||
            next == ClassPlanStatus.archived;
      case ClassPlanStatus.inProgress:
        return next == ClassPlanStatus.inProgress ||
            next == ClassPlanStatus.completed ||
            next == ClassPlanStatus.saved;
      case ClassPlanStatus.completed:
        return next == ClassPlanStatus.completed ||
            next == ClassPlanStatus.saved ||
            next == ClassPlanStatus.draft ||
            next == ClassPlanStatus.inProgress ||
            next == ClassPlanStatus.archived;
      case ClassPlanStatus.archived:
        return next == ClassPlanStatus.archived ||
            next == ClassPlanStatus.draft ||
            next == ClassPlanStatus.saved;
    }
  }

  static ClassPlanStatus fromId(String? value) {
    final norm = value?.trim().toLowerCase();
    if (norm == 'planned') return ClassPlanStatus.saved;
    return ClassPlanStatus.values.firstWhere(
      (s) => s.id == norm,
      orElse: () => ClassPlanStatus.saved,
    );
  }
}

enum PlannerSyncState {
  idle('idle', 'Sin cambios pendientes'),
  saving('saving', 'Guardando...'),
  synced('synced', 'Sincronizado'),
  pendingOffline('pending_offline', 'Pendiente (sin conexión)'),
  conflict('conflict', 'Conflicto de versión'),
  error('error', 'Error de sincronización');

  final String id;
  final String label;
  const PlannerSyncState(this.id, this.label);
}

class PlannerConcurrencyConflictException implements Exception {
  final String planId;
  final int expectedRevision;
  final int remoteRevision;
  final ClassPlanModel? remotePlan;
  final String message;

  const PlannerConcurrencyConflictException({
    required this.planId,
    required this.expectedRevision,
    required this.remoteRevision,
    this.remotePlan,
    required this.message,
  });

  @override
  String toString() => message;
}

enum PlanCopilotTargetScope {
  wholePlan('whole_plan'),
  block('block'),
  exercise('exercise');

  final String id;
  const PlanCopilotTargetScope(this.id);
}

enum PlanPatchOperationType {
  updateExercise('update_exercise'),
  replaceExercise('replace_exercise'),
  insertExercise('insert_exercise'),
  removeExercise('remove_exercise'),
  updateBlockDuration('update_block_duration'),
  reorderBlocks('reorder_blocks');

  final String id;
  const PlanPatchOperationType(this.id);
}

/// Distribución de experiencia siempre editable; nunca se deduce automáticamente solo desde la corda.
class ExperienceDistribution {
  final int principiantes;
  final int intermedios;
  final int avanzados;
  final bool manuallyConfirmed;

  const ExperienceDistribution({
    this.principiantes = 4,
    this.intermedios = 4,
    this.avanzados = 2,
    this.manuallyConfirmed = false,
  });

  int get total => principiantes + intermedios + avanzados;

  ExperienceDistribution copyWith({
    int? principiantes,
    int? intermedios,
    int? avanzados,
    bool? manuallyConfirmed,
  }) {
    return ExperienceDistribution(
      principiantes: (principiantes ?? this.principiantes).clamp(0, 200),
      intermedios: (intermedios ?? this.intermedios).clamp(0, 200),
      avanzados: (avanzados ?? this.avanzados).clamp(0, 200),
      manuallyConfirmed: manuallyConfirmed ?? this.manuallyConfirmed,
    );
  }

  Map<String, dynamic> toMap() => {
        'principiantes': principiantes,
        'intermedios': intermedios,
        'avanzados': avanzados,
        'manually_confirmed': manuallyConfirmed,
      };

  factory ExperienceDistribution.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ExperienceDistribution();
    return ExperienceDistribution(
      principiantes: (map['principiantes'] as num?)?.toInt() ?? 0,
      intermedios: (map['intermedios'] as num?)?.toInt() ?? 0,
      avanzados: (map['avanzados'] as num?)?.toInt() ?? 0,
      manuallyConfirmed: map['manually_confirmed'] == true,
    );
  }
}

/// Perfil agregado de grupo sin PII (no almacena nombres, fechas de nacimiento ni UIDs de alumnos).
class PlannerGroupProfile {
  final String id;
  final String name;
  final PlannerGroupSource source;
  final PlannerAudienceType audienceType;
  final String scheduleSummary;
  final int ageMin;
  final int ageMax;
  final int participantsCount;
  final Map<String, int> observedCordasSummary;
  final ExperienceDistribution defaultDistribution;
  final int suggestedTargetAdultoCordaIndex;

  const PlannerGroupProfile({
    required this.id,
    required this.name,
    required this.source,
    required this.audienceType,
    required this.scheduleSummary,
    required this.ageMin,
    required this.ageMax,
    required this.participantsCount,
    this.observedCordasSummary = const {},
    this.defaultDistribution = const ExperienceDistribution(),
    this.suggestedTargetAdultoCordaIndex = 1,
  });

  /// Regla explícita: solo sugiere currículo adulto FIU cuando el grupo es Adultos.
  PlannerCurriculumScope get suggestedCurriculumScope =>
      PlannerCurriculumScope.suggestedForAudience(audienceType);

  String get ageRangeLabel => '$ageMin–$ageMax años';
}

enum ResourceMediaKind {
  video('Video', 'video'),
  imagen('Imagen', 'imagen'),
  enlace('Enlace', 'link'),
  nota('Nota', 'nota');

  final String label;
  final String storageType;
  const ResourceMediaKind(this.label, this.storageType);
}

/// Recurso de la pizarra del profesor, vinculado siempre por `resourceId` estable.
class PlannerResourceItem {
  final String resourceId;
  final String title;
  final String type;
  final String category;
  final String audienceLabel;
  final String notes;
  final String url;
  final String? thumbnailUrl;
  final bool hasBeenTaught;
  final int timesUsed;
  final String? instructorId;
  final bool shared;

  const PlannerResourceItem({
    required this.resourceId,
    required this.title,
    required this.type,
    required this.category,
    required this.audienceLabel,
    required this.notes,
    this.url = '',
    this.thumbnailUrl,
    this.hasBeenTaught = false,
    this.timesUsed = 0,
    this.instructorId,
    this.shared = false,
  });

  PlannerResourceItem copyWith({
    String? resourceId,
    String? title,
    String? type,
    String? category,
    String? audienceLabel,
    String? notes,
    String? url,
    String? thumbnailUrl,
    bool? hasBeenTaught,
    int? timesUsed,
    String? instructorId,
    bool? shared,
  }) {
    return PlannerResourceItem(
      resourceId: resourceId ?? this.resourceId,
      title: title ?? this.title,
      type: type ?? this.type,
      category: category ?? this.category,
      audienceLabel: audienceLabel ?? this.audienceLabel,
      notes: notes ?? this.notes,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      hasBeenTaught: hasBeenTaught ?? this.hasBeenTaught,
      timesUsed: timesUsed ?? this.timesUsed,
      instructorId: instructorId ?? this.instructorId,
      shared: shared ?? this.shared,
    );
  }

  ResourceMediaKind get mediaKind {
    final t = type.toLowerCase().trim();
    final u = url.toLowerCase().trim();
    if (t == 'imagen' || t == 'image') return ResourceMediaKind.imagen;
    if (t == 'video' ||
        u.contains('tiktok.com') ||
        u.contains('instagram.com/reel') ||
        u.contains('youtube.com') ||
        u.contains('youtu.be') ||
        u.endsWith('.mp4')) {
      return ResourceMediaKind.video;
    }
    if (t == 'link' || t == 'enlace' || u.isNotEmpty) {
      return ResourceMediaKind.enlace;
    }
    return ResourceMediaKind.nota;
  }

  String get mediaLabel => mediaKind.label;

  String? get resolvedThumbnailUrl {
    final raw = thumbnailUrl?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    if (mediaKind == ResourceMediaKind.imagen && url.trim().isNotEmpty) {
      return url.trim();
    }
    final ytMatch = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|shorts\/|embed\/))([a-zA-Z0-9_-]{11})',
    ).firstMatch(url);
    if (ytMatch != null) {
      return 'https://img.youtube.com/vi/${ytMatch.group(1)}/hqdefault.jpg';
    }
    return null;
  }

  bool get hasExternalVideo =>
      mediaKind == ResourceMediaKind.video || mediaKind == ResourceMediaKind.enlace;

  factory PlannerResourceItem.fromMap(String id, Map<String, dynamic> map) {
    final clUsada = map['clase_usada'] as String?;
    final vUsada = (map['veces_impartida'] as num?)?.toInt() ??
        (map['veces_usada'] as num?)?.toInt() ??
        0;
    final completado = map['completado'] == true;
    final rawPublico = map['publico']?.toString();
    final rawCat = map['categoria']?.toString() ?? 'General';
    final pub = rawPublico ??
        (rawCat == 'Niños'
            ? 'Niños'
            : (rawCat == 'Adultos' ? 'Adultos' : 'Todos'));
    final fase = map['tipo_ejercicio']?.toString() ??
        (rawCat != 'Adultos' && rawCat != 'Niños' ? rawCat : 'General');

    return PlannerResourceItem(
      resourceId: id,
      title: (map['titulo'] as String? ?? 'Recurso sin título').trim(),
      type: (map['tipo'] as String? ?? 'nota').trim(),
      category: fase,
      audienceLabel: pub,
      notes: (map['notas'] as String? ?? '').trim(),
      url: (map['url'] as String? ?? '').trim(),
      thumbnailUrl: map['thumbnail_url'] as String?,
      hasBeenTaught:
          completado || (clUsada != null && clUsada.trim().isNotEmpty) || vUsada > 0,
      timesUsed: vUsada,
      instructorId: (map['instructor_id'] as String?)?.trim(),
      shared: map['shared'] == true,
    );
  }

  Map<String, dynamic> toFirestoreMap({required String instructorUid}) => {
        'titulo': title.trim(),
        'tipo': type.trim(),
        'categoria': category.trim().isNotEmpty ? category.trim() : 'General',
        'tipo_ejercicio': category.trim().isNotEmpty ? category.trim() : 'General',
        'publico': audienceLabel.trim().isNotEmpty ? audienceLabel.trim() : 'Todos',
        'notas': notes.trim(),
        'url': url.trim(),
        if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
          'thumbnail_url': thumbnailUrl!.trim(),
        'completado': hasBeenTaught,
        'veces_impartida': timesUsed,
        'instructor_id': (instructorId != null && instructorId!.isNotEmpty)
            ? instructorId!
            : instructorUid,
        'shared': shared,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

class SelectedCurriculumMovement {
  final CurriculumMovementSelectionItem item;
  final ResourcePriority priority;

  const SelectedCurriculumMovement({
    required this.item,
    this.priority = ResourcePriority.required,
  });

  SelectedCurriculumMovement copyWith({ResourcePriority? priority}) {
    return SelectedCurriculumMovement(
      item: item,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toPlannerMap() => {
        ...item.toPlannerMap(),
        'origin': ContentOrigin.officialFiuCurriculum.id,
        'priority': priority.id,
      };
}

class SelectedTeacherResource {
  final PlannerResourceItem resource;
  final ResourcePriority priority;
  final String usageNote;

  const SelectedTeacherResource({
    required this.resource,
    this.priority = ResourcePriority.required,
    this.usageNote = '',
  });

  SelectedTeacherResource copyWith({
    ResourcePriority? priority,
    String? usageNote,
  }) {
    return SelectedTeacherResource(
      resource: resource,
      priority: priority ?? this.priority,
      usageNote: usageNote ?? this.usageNote,
    );
  }

  Map<String, dynamic> toAiSafeMap() => {
        'resource_id': resource.resourceId,
        'title': PlannerPiiSanitizer.sanitizeFreeText(resource.title),
        'type': resource.type,
        'category': resource.category,
        'notes': PlannerPiiSanitizer.sanitizeFreeText(resource.notes),
        if (usageNote.trim().isNotEmpty)
          'usage_note': PlannerPiiSanitizer.sanitizeFreeText(usageNote),
        'has_external_video': resource.hasExternalVideo,
        'video_visual_inspected': false,
        'origin': ContentOrigin.teacherResource.id,
        'priority': priority.id,
      };
}

/// Contexto pedagógico estructurado transferido desde una sesión impartida
/// hacia la preparación de la siguiente clase (y listo para futuro consumo IA Zero-PII).
class PedagogicalContinuityContext {
  final String? sourceSessionId;
  final DateTime? sourceSessionDate;
  final String? sourcePlanTitle;
  final String? groupId;
  final String groupName;
  final PlannerAudienceType audienceType;
  final List<String> completedExercises;
  final List<String> skippedExercises;
  final List<String> pendingExercises;
  final List<String> practicedMovements;
  final String? groupResponse;
  final String difficulties;
  final String teacherObservations;
  final String reinforceContent;
  final String continuityProposal;

  const PedagogicalContinuityContext({
    this.sourceSessionId,
    this.sourceSessionDate,
    this.sourcePlanTitle,
    this.groupId,
    required this.groupName,
    required this.audienceType,
    this.completedExercises = const [],
    this.skippedExercises = const [],
    this.pendingExercises = const [],
    this.practicedMovements = const [],
    this.groupResponse,
    this.difficulties = '',
    this.teacherObservations = '',
    this.reinforceContent = '',
    this.continuityProposal = '',
  });

  bool get hasContent =>
      completedExercises.isNotEmpty ||
      skippedExercises.isNotEmpty ||
      pendingExercises.isNotEmpty ||
      practicedMovements.isNotEmpty ||
      difficulties.trim().isNotEmpty ||
      teacherObservations.trim().isNotEmpty ||
      reinforceContent.trim().isNotEmpty ||
      continuityProposal.trim().isNotEmpty;

  String get shortHeadline {
    if (continuityProposal.trim().isNotEmpty) {
      return continuityProposal.trim();
    }
    if (reinforceContent.trim().isNotEmpty) {
      return 'Reforzar: ${reinforceContent.trim()}';
    }
    if (teacherObservations.trim().isNotEmpty) {
      return teacherObservations.trim();
    }
    return '${completedExercises.length} realizados · ${skippedExercises.length} omitidos';
  }

  /// Garantiza correspondencia estricta con el grupo seleccionado sin mezclar historiales.
  bool matchesGroup({
    String? groupId,
    required String groupName,
    required PlannerAudienceType audienceType,
  }) {
    final cleanId = groupId?.trim();
    final myId = this.groupId?.trim();
    if (cleanId != null &&
        cleanId.isNotEmpty &&
        myId != null &&
        myId.isNotEmpty) {
      return cleanId == myId;
    }
    return groupName.trim().toLowerCase() ==
            this.groupName.trim().toLowerCase() &&
        audienceType == this.audienceType;
  }

  static TaughtSessionRecord? findLatestSessionForGroup(
    List<TaughtSessionRecord> history, {
    String? groupId,
    required String groupName,
    required PlannerAudienceType audienceType,
  }) {
    final recent = findRecentSessionsForGroup(
      history,
      groupId: groupId,
      groupName: groupName,
      audienceType: audienceType,
      limit: 1,
    );
    return recent.isEmpty ? null : recent.first;
  }

  static List<TaughtSessionRecord> findRecentSessionsForGroup(
    List<TaughtSessionRecord> history, {
    String? groupId,
    required String groupName,
    required PlannerAudienceType audienceType,
    int limit = 3,
  }) {
    final cleanId = groupId?.trim();
    final cleanName = groupName.trim().toLowerCase();
    final matched = <TaughtSessionRecord>[];
    for (final ses in history) {
      final sesId = ses.groupId?.trim();
      final matches = (cleanId != null &&
              cleanId.isNotEmpty &&
              sesId != null &&
              sesId.isNotEmpty)
          ? cleanId == sesId
          : (ses.groupName.trim().toLowerCase() == cleanName &&
              ses.audienceType == audienceType);
      if (matches) matched.add(ses);
    }
    matched.sort((a, b) => b.date.compareTo(a.date));
    return matched.take(limit).toList();
  }

  static PedagogicalContinuityContext? fromGroupHistory(
    List<TaughtSessionRecord> history, {
    String? groupId,
    required String groupName,
    required PlannerAudienceType audienceType,
    int maxSessions = 3,
  }) {
    final recent = findRecentSessionsForGroup(
      history,
      groupId: groupId,
      groupName: groupName,
      audienceType: audienceType,
      limit: maxSessions,
    );
    if (recent.isEmpty) return null;
    final latest = recent.first;
    final base = PedagogicalContinuityContext.fromSession(latest);
    if (recent.length == 1) return base;

    final movements = <String>[];
    final movSeen = <String>{};
    for (final s in recent) {
      for (final m in s.practicedMovements) {
        final key = m.trim().toLowerCase();
        if (key.isNotEmpty && movSeen.add(key)) {
          movements.add(m.trim());
        }
      }
    }

    final extraReinforce = <String>[];
    final refSeen = <String>{};
    for (final s in recent) {
      final r = (s.reinforceContent ?? '').trim();
      if (r.isNotEmpty && refSeen.add(r.toLowerCase())) {
        extraReinforce.add(r);
      }
    }

    final extraPending = <String>[];
    final pendSeen = <String>{};
    for (final s in recent) {
      final p = s.pendingNextSession.trim();
      if (p.isNotEmpty && pendSeen.add(p.toLowerCase())) {
        extraPending.add(p);
      }
    }

    return PedagogicalContinuityContext(
      sourceSessionId: base.sourceSessionId,
      sourceSessionDate: base.sourceSessionDate,
      sourcePlanTitle: base.sourcePlanTitle,
      groupId: base.groupId ?? groupId,
      groupName: base.groupName,
      audienceType: base.audienceType,
      completedExercises: base.completedExercises,
      skippedExercises: base.skippedExercises,
      pendingExercises: base.pendingExercises,
      practicedMovements: List<String>.unmodifiable(movements),
      groupResponse: base.groupResponse,
      difficulties: base.difficulties,
      teacherObservations: base.teacherObservations,
      reinforceContent: extraReinforce.join(' · '),
      continuityProposal: extraPending.join(' · '),
    );
  }

  Map<String, dynamic> toCopilotSummaryMap() => toAiSafeMap();

  factory PedagogicalContinuityContext.fromSession(
    TaughtSessionRecord session,
  ) {
    return PedagogicalContinuityContext(
      sourceSessionId: session.sessionId,
      sourceSessionDate: session.date,
      sourcePlanTitle: session.planTitle,
      groupId: session.groupId,
      groupName: session.groupName,
      audienceType: session.audienceType,
      completedExercises: List<String>.unmodifiable(session.completedExercises),
      skippedExercises: List<String>.unmodifiable(session.skippedExercises),
      pendingExercises: List<String>.unmodifiable(session.pendingExercises),
      practicedMovements: List<String>.unmodifiable(session.practicedMovements),
      groupResponse: session.groupResponse,
      difficulties: session.difficulties ?? '',
      teacherObservations: session.summaryNote,
      reinforceContent: session.reinforceContent ?? '',
      continuityProposal: session.pendingNextSession,
    );
  }

  Map<String, dynamic> toMap() => {
        if (sourceSessionId != null) 'source_session_id': sourceSessionId,
        if (sourceSessionDate != null)
          'source_session_date': sourceSessionDate!.toIso8601String(),
        if (sourcePlanTitle != null) 'source_plan_title': sourcePlanTitle,
        if (groupId != null) 'group_id': groupId,
        'group_name': groupName,
        'audience_type': audienceType.id,
        'completed_exercises': completedExercises,
        'skipped_exercises': skippedExercises,
        if (pendingExercises.isNotEmpty) 'pending_exercises': pendingExercises,
        'practiced_movements': practicedMovements,
        if (groupResponse != null && groupResponse!.trim().isNotEmpty)
          'group_response': groupResponse!.trim(),
        if (difficulties.trim().isNotEmpty) 'difficulties': difficulties.trim(),
        if (teacherObservations.trim().isNotEmpty)
          'teacher_observations': teacherObservations.trim(),
        if (reinforceContent.trim().isNotEmpty)
          'reinforce_content': reinforceContent.trim(),
        if (continuityProposal.trim().isNotEmpty)
          'continuity_proposal': continuityProposal.trim(),
      };

  /// Contrato sanitizado Zero-PII listo para futuro consumo de IA sin datos personales de alumnos.
  Map<String, dynamic> toAiSafeMap() => {
        if (groupId != null) 'clase_id': groupId,
        'group_label': PlannerPiiSanitizer.sanitizeFreeText(groupName),
        'audience_type': audienceType.id,
        'pii_sanitized': true,
        'completed_exercises':
            PlannerPiiSanitizer.sanitizeList(completedExercises),
        'skipped_exercises': PlannerPiiSanitizer.sanitizeList(skippedExercises),
        if (pendingExercises.isNotEmpty)
          'pending_exercises':
              PlannerPiiSanitizer.sanitizeList(pendingExercises),
        'worked_movements':
            PlannerPiiSanitizer.sanitizeList(practicedMovements),
        if (groupResponse != null && groupResponse!.trim().isNotEmpty)
          'group_response': PlannerPiiSanitizer.sanitizeFreeText(groupResponse!),
        if (difficulties.trim().isNotEmpty)
          'difficulties': PlannerPiiSanitizer.sanitizeFreeText(difficulties),
        if (teacherObservations.trim().isNotEmpty)
          'teacher_observations':
              PlannerPiiSanitizer.sanitizeFreeText(teacherObservations),
        if (reinforceContent.trim().isNotEmpty)
          'reinforce_content':
              PlannerPiiSanitizer.sanitizeFreeText(reinforceContent),
        if (continuityProposal.trim().isNotEmpty)
          'continuity_proposal':
              PlannerPiiSanitizer.sanitizeFreeText(continuityProposal),
      };

  factory PedagogicalContinuityContext.fromMap(Map<String, dynamic> map) {
    return PedagogicalContinuityContext(
      sourceSessionId: (map['source_session_id'] as String?)?.trim(),
      sourceSessionDate:
          DateTime.tryParse(map['source_session_date']?.toString() ?? ''),
      sourcePlanTitle: (map['source_plan_title'] as String?)?.trim(),
      groupId: (map['group_id'] as String? ?? map['clase_id'] as String?)?.trim(),
      groupName: (map['group_name'] as String? ??
              map['group_label'] as String? ??
              'Grupo')
          .trim(),
      audienceType:
          PlannerAudienceType.fromLegacyLevel(map['audience_type']?.toString()),
      completedExercises:
          ((map['completed_exercises'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
      skippedExercises:
          ((map['skipped_exercises'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
      pendingExercises:
          ((map['pending_exercises'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
      practicedMovements:
          ((map['practiced_movements'] ?? map['worked_movements']) as List? ??
                  const [])
              .map((e) => e.toString())
              .toList(),
      groupResponse: (map['group_response'] as String?)?.trim(),
      difficulties: (map['difficulties'] as String? ?? '').trim(),
      teacherObservations:
          (map['teacher_observations'] as String? ?? '').trim(),
      reinforceContent: (map['reinforce_content'] as String? ?? '').trim(),
      continuityProposal:
          (map['continuity_proposal'] as String? ?? '').trim(),
    );
  }
}

/// Contrato unificado compartido por Creación Rápida y Creación Avanzada.
class ClassPlanDraftRequest {
  final PlannerCreationMode creationMode;
  final PlannerGroupSource groupSource;
  final String? realClaseId;
  final String groupName;
  final PlannerAudienceType audienceType;
  final PlannerCurriculumScope curriculumScope;
  final int targetAdultoCordaIndex;
  final int ageMin;
  final int ageMax;
  final int participantsCount;
  final ExperienceDistribution experienceDistribution;
  final int durationMin;
  final List<String> focuses;
  final List<String> objectives;
  final List<String> materials;
  final bool includeMusicalityRoda;
  final String freeInstructions;
  final List<SelectedCurriculumMovement> selectedMovements;
  final List<SelectedTeacherResource> selectedResources;
  final bool allowAiComplementaryProposals;
  final String? continuitySummary;
  final PedagogicalContinuityContext? continuityContext;
  final PlannerSpaceContext spaceContext;
  final bool materialsConfirmed;
  final bool participantsConfirmed;

  const ClassPlanDraftRequest({
    required this.creationMode,
    required this.groupSource,
    this.realClaseId,
    required this.groupName,
    required this.audienceType,
    required this.curriculumScope,
    this.targetAdultoCordaIndex = 2,
    required this.ageMin,
    required this.ageMax,
    required this.participantsCount,
    required this.experienceDistribution,
    this.durationMin = 60,
    this.focuses = const ['Técnica'],
    this.objectives = const ['Consolidar base técnica y fluidez sin tiempos muertos'],
    this.materials = const [],
    this.includeMusicalityRoda = true,
    this.freeInstructions = '',
    this.selectedMovements = const [],
    this.selectedResources = const [],
    this.allowAiComplementaryProposals = true,
    this.continuitySummary,
    this.continuityContext,
    this.spaceContext = const PlannerSpaceContext(),
    this.materialsConfirmed = false,
    this.participantsConfirmed = false,
  });

  String get focus => focuses.isNotEmpty ? focuses.join(' · ') : 'Técnica';

  bool get isExperienceDistributionValid =>
      experienceDistribution.total == participantsCount;

  int get experienceDistributionDelta =>
      experienceDistribution.total - participantsCount;

  factory ClassPlanDraftRequest.fromGroup(
    PlannerGroupProfile group, {
    PlannerCreationMode mode = PlannerCreationMode.quick,
  }) {
    final scope = group.suggestedCurriculumScope;
    return ClassPlanDraftRequest(
      creationMode: mode,
      groupSource: group.source,
      realClaseId: group.source == PlannerGroupSource.realClass ? group.id : null,
      groupName: group.name,
      audienceType: group.audienceType,
      curriculumScope: scope,
      targetAdultoCordaIndex: group.suggestedTargetAdultoCordaIndex,
      ageMin: group.ageMin,
      ageMax: group.ageMax,
      participantsCount: group.participantsCount,
      experienceDistribution: group.defaultDistribution,
      durationMin: 60,
      materials: const [],
      materialsConfirmed: false,
      participantsConfirmed: false,
      spaceContext: const PlannerSpaceContext(),
      focuses: group.audienceType == PlannerAudienceType.infantil
          ? const ['Juegos', 'Musicalidad']
          : const ['Técnica', 'Secuencias'],
      objectives: group.audienceType == PlannerAudienceType.infantil
          ? const ['Coordinación lúdica, ritmo y ginga base']
          : const ['Consolidar base técnica y transiciones en parejas'],
    );
  }

  ClassPlanDraftRequest copyWith({
    PlannerCreationMode? creationMode,
    PlannerGroupSource? groupSource,
    String? realClaseId,
    bool clearRealClaseId = false,
    String? groupName,
    PlannerAudienceType? audienceType,
    PlannerCurriculumScope? curriculumScope,
    int? targetAdultoCordaIndex,
    int? ageMin,
    int? ageMax,
    int? participantsCount,
    ExperienceDistribution? experienceDistribution,
    int? durationMin,
    List<String>? focuses,
    List<String>? objectives,
    List<String>? materials,
    bool? includeMusicalityRoda,
    String? freeInstructions,
    List<SelectedCurriculumMovement>? selectedMovements,
    List<SelectedTeacherResource>? selectedResources,
    bool? allowAiComplementaryProposals,
    String? continuitySummary,
    PedagogicalContinuityContext? continuityContext,
    bool clearContinuity = false,
    PlannerSpaceContext? spaceContext,
    bool? materialsConfirmed,
    bool? participantsConfirmed,
  }) {
    return ClassPlanDraftRequest(
      creationMode: creationMode ?? this.creationMode,
      groupSource: groupSource ?? this.groupSource,
      realClaseId: clearRealClaseId ? null : (realClaseId ?? this.realClaseId),
      groupName: groupName ?? this.groupName,
      audienceType: audienceType ?? this.audienceType,
      curriculumScope: curriculumScope ?? this.curriculumScope,
      targetAdultoCordaIndex:
          targetAdultoCordaIndex ?? this.targetAdultoCordaIndex,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      participantsCount: participantsCount ?? this.participantsCount,
      experienceDistribution:
          experienceDistribution ?? this.experienceDistribution,
      durationMin: durationMin ?? this.durationMin,
      focuses: focuses ?? this.focuses,
      objectives: objectives ?? this.objectives,
      materials: materials ?? this.materials,
      includeMusicalityRoda:
          includeMusicalityRoda ?? this.includeMusicalityRoda,
      freeInstructions: freeInstructions ?? this.freeInstructions,
      selectedMovements: selectedMovements ?? this.selectedMovements,
      selectedResources: selectedResources ?? this.selectedResources,
      allowAiComplementaryProposals:
          allowAiComplementaryProposals ?? this.allowAiComplementaryProposals,
      continuitySummary:
          clearContinuity ? null : (continuitySummary ?? this.continuitySummary),
      continuityContext:
          clearContinuity ? null : (continuityContext ?? this.continuityContext),
      spaceContext: spaceContext ?? this.spaceContext,
      materialsConfirmed: materialsConfirmed ?? this.materialsConfirmed,
      participantsConfirmed:
          participantsConfirmed ?? this.participantsConfirmed,
    );
  }

  /// Contrato v2.1.0 sanitizado y alineado con `functions/planner_v2`.
  /// No incluye políticas de proveedor/modelo/cuota desde el cliente.
  Map<String, dynamic> toPlannerV2RequestMap({required String requestId}) => {
        'contract_version': '2.1.0',
        'request_id': requestId,
        'creation_mode': creationMode.id,
        'group_context': {
          'source': groupSource.id,
          if (realClaseId != null) 'clase_id': realClaseId,
          'group_label': PlannerPiiSanitizer.sanitizeFreeText(groupName),
          'audience_type': audienceType.id,
          'age_min': ageMin,
          'age_max': ageMax,
          'estimated_participants': participantsCount,
          'experience_distribution': experienceDistribution.toMap(),
        },
        'curriculum_context': {
          'scope': curriculumScope.id,
          if (curriculumScope == PlannerCurriculumScope.adultoFiu)
            'target_corda_index': targetAdultoCordaIndex,
        },
        'space_context': spaceContext.toMap(),
        'session_config': {
          'duration_min': durationMin,
          'focus': focus,
          'focuses': focuses,
          'objectives': PlannerPiiSanitizer.sanitizeList(objectives),
          if (materialsConfirmed || materials.isNotEmpty) 'materials': materials,
          'include_musicality_roda': includeMusicalityRoda,
          'free_instructions':
              PlannerPiiSanitizer.sanitizeFreeText(freeInstructions),
          'allow_ai_complementary_proposals': allowAiComplementaryProposals,
        },
        'selected_movements':
            selectedMovements.map((m) => m.toPlannerMap()).toList(),
        'selected_resources':
            selectedResources.map((r) => r.toAiSafeMap()).toList(),
        if (continuitySummary != null && continuitySummary!.trim().isNotEmpty)
          'continuity_summary':
              PlannerPiiSanitizer.sanitizeFreeText(continuitySummary!),
        if (continuityContext != null && continuityContext!.hasContent)
          'continuity_context': continuityContext!.toAiSafeMap(),
      };

  /// Payload sanitizado libre de PII para futuros contratos con el backend.
  /// El servidor deberá revalidar permisos y elegibilidad curricular contra sus propias fuentes.
  Map<String, dynamic> toAiSafeRequestMap() => {
        'contract_version': '2.0.0',
        'creation_mode': creationMode.id,
        'server_validation_required': true,
        'content_origins_separated': true,
        'pii_sanitized': true,
        'group_context': {
          'source': groupSource.id,
          if (realClaseId != null) 'clase_id': realClaseId,
          'group_label': PlannerPiiSanitizer.sanitizeFreeText(groupName),
          'audience_type': audienceType.id,
          'age_min': ageMin,
          'age_max': ageMax,
          'estimated_participants': participantsCount,
          'experience_distribution': experienceDistribution.toMap(),
        },
        'curriculum_context': {
          'scope': curriculumScope.id,
          if (curriculumScope == PlannerCurriculumScope.adultoFiu)
            'target_corda_index': targetAdultoCordaIndex,
          'auto_adult_fallback_blocked': true,
        },
        'session_config': {
          'duration_min': durationMin,
          'focus': focus,
          'focuses': focuses,
          'objectives': PlannerPiiSanitizer.sanitizeList(objectives),
          'materials': materials,
          'include_musicality_roda': includeMusicalityRoda,
          'free_instructions':
              PlannerPiiSanitizer.sanitizeFreeText(freeInstructions),
          'allow_ai_complementary_proposals': allowAiComplementaryProposals,
        },
        'selected_movements':
            selectedMovements.map((m) => m.toPlannerMap()).toList(),
        'selected_resources':
            selectedResources.map((r) => r.toAiSafeMap()).toList(),
        if (continuitySummary != null && continuitySummary!.trim().isNotEmpty)
          'continuity_summary':
              PlannerPiiSanitizer.sanitizeFreeText(continuitySummary!),
        if (continuityContext != null && continuityContext!.hasContent)
          'continuity_context': continuityContext!.toAiSafeMap(),
      };
}

class PlannerInternalTiming {
  final String etapa;
  final int minutos;

  const PlannerInternalTiming({
    required this.etapa,
    required this.minutos,
  });

  PlannerInternalTiming copyWith({
    String? etapa,
    int? minutos,
  }) =>
      PlannerInternalTiming(
        etapa: etapa ?? this.etapa,
        minutos: (minutos ?? this.minutos).clamp(1, 180),
      );

  factory PlannerInternalTiming.fromMap(Map<String, dynamic> map) =>
      PlannerInternalTiming(
        etapa: (map['etapa'] ?? '').toString().trim(),
        minutos: ((map['minutos'] as num?)?.toInt() ?? 1).clamp(1, 180),
      );

  Map<String, dynamic> toMap() => {
        'etapa': etapa,
        'minutos': minutos,
      };
}

class ClassPlanExercise {
  final String exerciseId;
  final String nombre;
  final String detalle;
  final int? duracionMin;
  final String? organizacion;
  final List<String> materiales;
  final String? observacionesProfesor;
  final String? aiSuggestions;
  final List<String> technicalMovementRefs;
  final List<PlannerInternalTiming> internalTimings;
  final ContentOrigin contentOrigin;
  final List<String> curriculumMovementIds;
  final List<String> linkedResourceIds;
  final Map<String, String> resourceUsageNotes;
  final String? legacyRecursoRelacionado;
  final String? differentiationBeginner;
  final String? differentiationIntermediate;
  final String? differentiationAdvanced;
  final String? safetyNote;
  final String? videoReferenceNote;
  final PlannerSongReference? cancioneroReference;
  final String? activityAuthoring;
  final List<String> sourceOrigins;

  const ClassPlanExercise({
    required this.exerciseId,
    required this.nombre,
    required this.detalle,
    this.duracionMin,
    this.organizacion,
    this.materiales = const [],
    this.observacionesProfesor,
    this.aiSuggestions,
    this.technicalMovementRefs = const [],
    this.internalTimings = const [],
    this.contentOrigin = ContentOrigin.aiComplementaryProposal,
    this.curriculumMovementIds = const [],
    this.linkedResourceIds = const [],
    this.resourceUsageNotes = const {},
    this.legacyRecursoRelacionado,
    this.differentiationBeginner,
    this.differentiationIntermediate,
    this.differentiationAdvanced,
    this.safetyNote,
    this.videoReferenceNote,
    this.cancioneroReference,
    this.activityAuthoring,
    this.sourceOrigins = const [],
  });

  factory ClassPlanExercise.manualBlank({
    required String exerciseId,
    String nombre = 'Nuevo ejercicio',
    int? duracionMin = 10,
  }) {
    return ClassPlanExercise(
      exerciseId: exerciseId,
      nombre: nombre,
      detalle: '',
      duracionMin: duracionMin,
      contentOrigin: ContentOrigin.teacherResource,
    );
  }

  ClassPlanExercise copyWith({
    String? exerciseId,
    String? nombre,
    String? detalle,
    int? duracionMin,
    bool clearDuracionMin = false,
    String? organizacion,
    bool clearOrganizacion = false,
    List<String>? materiales,
    String? observacionesProfesor,
    bool clearObservacionesProfesor = false,
    String? aiSuggestions,
    bool clearAiSuggestions = false,
    List<String>? technicalMovementRefs,
    List<PlannerInternalTiming>? internalTimings,
    ContentOrigin? contentOrigin,
    List<String>? curriculumMovementIds,
    List<String>? linkedResourceIds,
    Map<String, String>? resourceUsageNotes,
    String? legacyRecursoRelacionado,
    bool clearLegacyRecursoRelacionado = false,
    String? differentiationBeginner,
    bool clearDifferentiationBeginner = false,
    String? differentiationIntermediate,
    bool clearDifferentiationIntermediate = false,
    String? differentiationAdvanced,
    bool clearDifferentiationAdvanced = false,
    String? safetyNote,
    bool clearSafetyNote = false,
    String? videoReferenceNote,
    bool clearVideoReferenceNote = false,
    PlannerSongReference? cancioneroReference,
    bool clearCancioneroReference = false,
    String? activityAuthoring,
    List<String>? sourceOrigins,
  }) {
    return ClassPlanExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      nombre: nombre ?? this.nombre,
      detalle: detalle ?? this.detalle,
      duracionMin:
          clearDuracionMin ? null : (duracionMin ?? this.duracionMin),
      organizacion:
          clearOrganizacion ? null : (organizacion ?? this.organizacion),
      materiales: List<String>.unmodifiable(materiales ?? this.materiales),
      observacionesProfesor: clearObservacionesProfesor
          ? null
          : (observacionesProfesor ?? this.observacionesProfesor),
      aiSuggestions:
          clearAiSuggestions ? null : (aiSuggestions ?? this.aiSuggestions),
      technicalMovementRefs: List<String>.unmodifiable(
          technicalMovementRefs ?? this.technicalMovementRefs),
      internalTimings: List<PlannerInternalTiming>.unmodifiable(
          internalTimings ?? this.internalTimings),
      contentOrigin: contentOrigin ?? this.contentOrigin,
      curriculumMovementIds: List<String>.unmodifiable(
          curriculumMovementIds ?? this.curriculumMovementIds),
      linkedResourceIds:
          List<String>.unmodifiable(linkedResourceIds ?? this.linkedResourceIds),
      resourceUsageNotes:
          Map<String, String>.unmodifiable(resourceUsageNotes ?? this.resourceUsageNotes),
      legacyRecursoRelacionado: clearLegacyRecursoRelacionado
          ? null
          : (legacyRecursoRelacionado ?? this.legacyRecursoRelacionado),
      differentiationBeginner: clearDifferentiationBeginner
          ? null
          : (differentiationBeginner ?? this.differentiationBeginner),
      differentiationIntermediate: clearDifferentiationIntermediate
          ? null
          : (differentiationIntermediate ?? this.differentiationIntermediate),
      differentiationAdvanced: clearDifferentiationAdvanced
          ? null
          : (differentiationAdvanced ?? this.differentiationAdvanced),
      safetyNote: clearSafetyNote ? null : (safetyNote ?? this.safetyNote),
      videoReferenceNote: clearVideoReferenceNote
          ? null
          : (videoReferenceNote ?? this.videoReferenceNote),
      cancioneroReference: clearCancioneroReference
          ? null
          : (cancioneroReference ?? this.cancioneroReference),
      activityAuthoring: activityAuthoring ?? this.activityAuthoring,
      sourceOrigins: List<String>.unmodifiable(
          sourceOrigins ?? this.sourceOrigins),
    );
  }

  factory ClassPlanExercise.fromMap(
    Map<String, dynamic> map, {
    required String fallbackId,
  }) {
    final movIds = ((map['curriculum_movement_ids'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final resIds = ((map['linked_resource_ids'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final matList = ((map['materiales'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final usageNotes = <String, String>{};
    if (map['resource_usage_notes'] is Map) {
      final rawMap = map['resource_usage_notes'] as Map;
      for (final entry in rawMap.entries) {
        final k = entry.key.toString().trim();
        final v = entry.value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) {
          usageNotes[k] = v;
        }
      }
    }
    final legacyRes = map['recurso_relacionado']?.toString();

    final ContentOrigin origin;
    if (map['content_origin'] != null) {
      origin = ContentOrigin.fromId(map['content_origin'].toString());
    } else if (movIds.isNotEmpty) {
      origin = ContentOrigin.officialFiuCurriculum;
    } else if (resIds.isNotEmpty ||
        (legacyRes != null &&
            legacyRes.trim().isNotEmpty &&
            legacyRes.toLowerCase() != 'null')) {
      origin = ContentOrigin.teacherResource;
    } else {
      origin = ContentOrigin.aiComplementaryProposal;
    }

    String? cleanOpt(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
    }

    final techRefs = ((map['technical_movement_refs'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final timings = ((map['tiempos_internos'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => PlannerInternalTiming.fromMap(Map<String, dynamic>.from(e)))
        .where((t) => t.etapa.isNotEmpty)
        .toList();

    return ClassPlanExercise(
      exerciseId: (map['exercise_id'] as String?)?.trim().isNotEmpty == true
          ? map['exercise_id'].toString()
          : fallbackId,
      nombre: (map['nombre'] as String? ?? 'Ejercicio').trim(),
      detalle: (map['detalle_paso_a_paso'] ?? map['detalle'] ?? '').toString(),
      duracionMin: (map['duracion_min'] as num?)?.toInt(),
      organizacion: cleanOpt(map['organizacion']),
      materiales: matList,
      observacionesProfesor: cleanOpt(map['observaciones_profesor']),
      aiSuggestions: cleanOpt(map['sugerencias_ia']),
      technicalMovementRefs: techRefs,
      internalTimings: timings,
      contentOrigin: origin,
      curriculumMovementIds: movIds,
      linkedResourceIds: resIds,
      resourceUsageNotes: usageNotes,
      legacyRecursoRelacionado: legacyRes,
      differentiationBeginner: cleanOpt(map['diferenciacion_principiantes']),
      differentiationIntermediate: cleanOpt(map['diferenciacion_intermedios']),
      differentiationAdvanced: cleanOpt(map['diferenciacion_avanzados']),
      safetyNote: cleanOpt(map['seguridad']),
      videoReferenceNote: cleanOpt(map['video_reference_note']),
      cancioneroReference: map['cancionero_reference'] is Map
          ? PlannerSongReference.fromMap(
              Map<String, dynamic>.from(map['cancionero_reference'] as Map))
          : null,
      activityAuthoring: cleanOpt(map['activity_authoring']),
      sourceOrigins: ((map['source_origins'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'exercise_id': exerciseId,
        'nombre': nombre,
        'detalle': detalle,
        if (duracionMin != null) 'duracion_min': duracionMin,
        if (organizacion != null && organizacion!.trim().isNotEmpty)
          'organizacion': organizacion!.trim(),
        if (materiales.isNotEmpty) 'materiales': materiales,
        if (observacionesProfesor != null &&
            observacionesProfesor!.trim().isNotEmpty)
          'observaciones_profesor': observacionesProfesor!.trim(),
        if (aiSuggestions != null && aiSuggestions!.trim().isNotEmpty)
          'sugerencias_ia': aiSuggestions!.trim(),
        if (technicalMovementRefs.isNotEmpty)
          'technical_movement_refs': technicalMovementRefs,
        if (internalTimings.isNotEmpty)
          'tiempos_internos': internalTimings.map((t) => t.toMap()).toList(),
        'content_origin': contentOrigin.id,
        if (curriculumMovementIds.isNotEmpty)
          'curriculum_movement_ids': curriculumMovementIds,
        if (linkedResourceIds.isNotEmpty)
          'linked_resource_ids': linkedResourceIds,
        if (resourceUsageNotes.isNotEmpty)
          'resource_usage_notes': resourceUsageNotes,
        if (legacyRecursoRelacionado != null)
          'recurso_relacionado': legacyRecursoRelacionado,
        if (differentiationBeginner != null &&
            differentiationBeginner!.trim().isNotEmpty)
          'diferenciacion_principiantes': differentiationBeginner!.trim(),
        if (differentiationIntermediate != null &&
            differentiationIntermediate!.trim().isNotEmpty)
          'diferenciacion_intermedios': differentiationIntermediate!.trim(),
        if (differentiationAdvanced != null &&
            differentiationAdvanced!.trim().isNotEmpty)
          'diferenciacion_avanzados': differentiationAdvanced!.trim(),
        if (safetyNote != null && safetyNote!.trim().isNotEmpty)
          'seguridad': safetyNote!.trim(),
        if (videoReferenceNote != null &&
            videoReferenceNote!.trim().isNotEmpty)
          'video_reference_note': videoReferenceNote!.trim(),
        if (cancioneroReference != null)
          'cancionero_reference': cancioneroReference!.toMap(),
        if (activityAuthoring != null && activityAuthoring!.trim().isNotEmpty)
          'activity_authoring': activityAuthoring!.trim(),
        if (sourceOrigins.isNotEmpty) 'source_origins': sourceOrigins,
      };
}

class ClassPlanBlock {
  final String blockId;
  final String fase;
  final String? faseTipo;
  final int duracionMin;
  final List<ClassPlanExercise> ejercicios;

  const ClassPlanBlock({
    required this.blockId,
    required this.fase,
    this.faseTipo,
    required this.duracionMin,
    required this.ejercicios,
  });

  static String normalizeDisplayFase(
    String rawFase, {
    String? faseTipo,
    String? enfoque,
  }) {
    final trimmed = rawFase.trim();
    final rawLower = trimmed.toLowerCase();
    final typeKey = (faseTipo ?? '').trim().toLowerCase();
    final isRawTechnical = trimmed.isEmpty ||
        RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed) ||
        rawLower == typeKey ||
        RegExp(r'^bloque\s+blk_', caseSensitive: false).hasMatch(trimmed);

    if (!isRawTechnical) return trimmed;

    final key = typeKey.isNotEmpty ? typeKey : rawLower;
    final hasTechFocus =
        (enfoque ?? '').toLowerCase().contains('técnica') ||
            (enfoque ?? '').toLowerCase().contains('tecnica');
    switch (key) {
      case 'calentamiento':
        return 'Calentamiento';
      case 'tecnica':
        return 'Técnica y progresiones';
      case 'juegos':
        return hasTechFocus
            ? 'Técnica y progresiones'
            : 'Juegos y dinámicas de capoeira';
      case 'acrobacias_suelo':
        return 'Acrobacias y movimientos de suelo';
      case 'musicalidad':
        return 'Musicalidad y ritmo';
      case 'roda_musicalidad':
        return 'Roda y musicalidad';
      case 'angola':
        return 'Juego y diálogo de Angola';
      case 'vuelta_calma':
        return 'Vuelta a la calma y cierre';
      case 'recurso_profesor':
        return 'Recursos del profesor';
      default:
        return trimmed.isNotEmpty ? trimmed : 'Bloque de clase';
    }
  }

  int get exercisesTotalDurationMin =>
      ejercicios.fold<int>(0, (acc, e) => acc + (e.duracionMin ?? 0));

  bool get hasExerciseDurationEntries =>
      ejercicios.any((e) => (e.duracionMin ?? 0) > 0);

  int get exerciseDurationDelta => exercisesTotalDurationMin - duracionMin;

  bool get hasDurationMismatch =>
      hasExerciseDurationEntries && exercisesTotalDurationMin != duracionMin;

  ClassPlanBlock copyWith({
    String? blockId,
    String? fase,
    String? faseTipo,
    int? duracionMin,
    List<ClassPlanExercise>? ejercicios,
  }) {
    return ClassPlanBlock(
      blockId: blockId ?? this.blockId,
      fase: fase ?? this.fase,
      faseTipo: faseTipo ?? this.faseTipo,
      duracionMin: (duracionMin ?? this.duracionMin).clamp(0, 300),
      ejercicios: List<ClassPlanExercise>.unmodifiable(
          ejercicios ?? this.ejercicios),
    );
  }

  factory ClassPlanBlock.fromMap(
    Map<String, dynamic> map, {
    required int blockIndex,
    String? enfoque,
  }) {
    final rawEj = map['ejercicios'] as List? ?? const [];
    final rawTipo = map['fase_tipo']?.toString().trim();
    final safeTipo =
        rawTipo != null && rawTipo.isNotEmpty && rawTipo.toLowerCase() != 'null'
            ? rawTipo
            : null;
    final rawFase = (map['fase'] as String? ?? '').trim();
    final displayFase = normalizeDisplayFase(
      rawFase.isNotEmpty ? rawFase : 'Bloque ${blockIndex + 1}',
      faseTipo: safeTipo,
      enfoque: enfoque,
    );
    return ClassPlanBlock(
      blockId: (map['block_id'] as String?)?.trim().isNotEmpty == true
          ? map['block_id'].toString()
          : 'blk_$blockIndex',
      fase: displayFase,
      faseTipo: safeTipo,
      duracionMin: (map['duracion_min'] as num?)?.toInt() ?? 10,
      ejercicios: [
        for (int i = 0; i < rawEj.length; i++)
          if (rawEj[i] is Map)
            ClassPlanExercise.fromMap(
              Map<String, dynamic>.from(rawEj[i] as Map),
              fallbackId: 'ex_${blockIndex}_$i',
            ),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
        'block_id': blockId,
        'fase': fase,
        if (faseTipo != null && faseTipo!.trim().isNotEmpty)
          'fase_tipo': faseTipo!.trim(),
        'duracion_min': duracionMin,
        'ejercicios': ejercicios.map((e) => e.toMap()).toList(),
      };
}

/// Modelo unificado de plan de clase compatible con V1 legacy y V2.
class ClassPlanModel {
  final String id;
  final int schemaVersion;
  final ClassPlanStatus planStatus;
  final PlannerCreationMode creationMode;
  final String titulo;
  final int duracionTotal;
  final String nivelLabel;
  final PlannerAudienceType audienceType;
  final PlannerCurriculumScope curriculumScope;
  final String enfoque;
  final String objetivo;
  final List<String> objetivos;
  final String? groupId;
  final String groupName;
  final int ageMin;
  final int ageMax;
  final int participantsCount;
  final ExperienceDistribution experienceDistribution;
  final List<ClassPlanBlock> bloques;
  final String? consejosInstructor;
  final int vecesImpartida;
  final int revision;
  final String? instructorId;
  final String? updatedByDevice;
  final Map<String, dynamic>? lastCopilotSummary;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? ultimaEjecucion;
  final String? duplicatedFromPlanId;
  final PedagogicalContinuityContext? continuityContext;
  final PlannerGenerationMeta? generationMeta;
  final PlannerSpaceContext? spaceSnapshot;
  final Map<String, dynamic> rawLegacyMap;

  const ClassPlanModel({
    required this.id,
    required this.schemaVersion,
    required this.planStatus,
    required this.creationMode,
    required this.titulo,
    required this.duracionTotal,
    required this.nivelLabel,
    required this.audienceType,
    required this.curriculumScope,
    required this.enfoque,
    required this.objetivo,
    this.objetivos = const [],
    this.groupId,
    required this.groupName,
    required this.ageMin,
    required this.ageMax,
    required this.participantsCount,
    required this.experienceDistribution,
    required this.bloques,
    this.consejosInstructor,
    this.vecesImpartida = 0,
    this.revision = 1,
    this.instructorId,
    this.updatedByDevice,
    this.lastCopilotSummary,
    this.createdAt,
    this.updatedAt,
    this.ultimaEjecucion,
    this.duplicatedFromPlanId,
    this.continuityContext,
    this.generationMeta,
    this.spaceSnapshot,
    this.rawLegacyMap = const {},
  });

  bool get isLegacyV1 => schemaVersion < 2;

  int get plannedDurationMin =>
      bloques.fold<int>(0, (acc, b) => acc + b.duracionMin);

  int get durationDeltaMin => plannedDurationMin - duracionTotal;

  int get remainingDurationMin =>
      durationDeltaMin < 0 ? -durationDeltaMin : 0;

  int get excessDurationMin => durationDeltaMin > 0 ? durationDeltaMin : 0;

  List<String> get allExerciseMaterials => bloques
      .expand((b) => b.ejercicios)
      .expand((e) => e.materiales)
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty)
      .toSet()
      .toList();

  Set<ContentOrigin> get detectedOrigins {
    final origins = <ContentOrigin>{};
    for (final b in bloques) {
      for (final e in b.ejercicios) {
        origins.add(e.contentOrigin);
      }
    }
    return origins;
  }

  int get totalLinkedMovementsCount => bloques
      .expand((b) => b.ejercicios)
      .expand((e) => e.curriculumMovementIds)
      .toSet()
      .length;

  int get totalLinkedResourcesCount => bloques
      .expand((b) => b.ejercicios)
      .where((e) =>
          e.linkedResourceIds.isNotEmpty ||
          (e.legacyRecursoRelacionado != null &&
              e.legacyRecursoRelacionado!.trim().isNotEmpty &&
              e.legacyRecursoRelacionado!.toLowerCase() != 'null'))
      .length;

  ClassPlanModel copyWith({
    String? id,
    int? schemaVersion,
    ClassPlanStatus? planStatus,
    PlannerCreationMode? creationMode,
    String? titulo,
    int? duracionTotal,
    String? nivelLabel,
    PlannerAudienceType? audienceType,
    PlannerCurriculumScope? curriculumScope,
    String? enfoque,
    String? objetivo,
    List<String>? objetivos,
    String? groupId,
    bool clearGroupId = false,
    String? groupName,
    int? ageMin,
    int? ageMax,
    int? participantsCount,
    ExperienceDistribution? experienceDistribution,
    List<ClassPlanBlock>? bloques,
    String? consejosInstructor,
    bool clearConsejosInstructor = false,
    int? vecesImpartida,
    int? revision,
    String? instructorId,
    String? updatedByDevice,
    Map<String, dynamic>? lastCopilotSummary,
    bool clearLastCopilotSummary = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? ultimaEjecucion,
    bool clearUltimaEjecucion = false,
    String? duplicatedFromPlanId,
    bool clearDuplicatedFromPlanId = false,
    PedagogicalContinuityContext? continuityContext,
    bool clearContinuityContext = false,
    PlannerGenerationMeta? generationMeta,
    PlannerSpaceContext? spaceSnapshot,
    Map<String, dynamic>? rawLegacyMap,
  }) {
    final nextObjetivos =
        List<String>.unmodifiable(objetivos ?? this.objetivos);
    final nextObjetivo = objetivo ??
        (objetivos != null ? nextObjetivos.join(' · ') : this.objetivo);
    return ClassPlanModel(
      id: id ?? this.id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      planStatus: planStatus ?? this.planStatus,
      creationMode: creationMode ?? this.creationMode,
      titulo: titulo ?? this.titulo,
      duracionTotal: (duracionTotal ?? this.duracionTotal).clamp(10, 300),
      nivelLabel: nivelLabel ?? this.nivelLabel,
      audienceType: audienceType ?? this.audienceType,
      curriculumScope: curriculumScope ?? this.curriculumScope,
      enfoque: enfoque ?? this.enfoque,
      objetivo: nextObjetivo,
      objetivos: nextObjetivos,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      groupName: groupName ?? this.groupName,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      participantsCount: participantsCount ?? this.participantsCount,
      experienceDistribution:
          experienceDistribution ?? this.experienceDistribution,
      bloques: List<ClassPlanBlock>.unmodifiable(bloques ?? this.bloques),
      consejosInstructor: clearConsejosInstructor
          ? null
          : (consejosInstructor ?? this.consejosInstructor),
      vecesImpartida: vecesImpartida ?? this.vecesImpartida,
      revision: (revision ?? this.revision).clamp(1, 1000000),
      instructorId: instructorId ?? this.instructorId,
      updatedByDevice: updatedByDevice ?? this.updatedByDevice,
      lastCopilotSummary: clearLastCopilotSummary
          ? null
          : (lastCopilotSummary ?? this.lastCopilotSummary),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ultimaEjecucion: clearUltimaEjecucion
          ? null
          : (ultimaEjecucion ?? this.ultimaEjecucion),
      duplicatedFromPlanId: clearDuplicatedFromPlanId
          ? null
          : (duplicatedFromPlanId ?? this.duplicatedFromPlanId),
      continuityContext: clearContinuityContext
          ? null
          : (continuityContext ?? this.continuityContext),
      generationMeta: generationMeta ?? this.generationMeta,
      spaceSnapshot: spaceSnapshot ?? this.spaceSnapshot,
      rawLegacyMap: rawLegacyMap ?? this.rawLegacyMap,
    );
  }

  /// Serialización V2 completa y libre de PII de alumnos.
  Map<String, dynamic> toMap() => {
        'id': id,
        'schema_version': schemaVersion,
        'plan_status': planStatus.id,
        'creation_mode': creationMode.id,
        'titulo': titulo,
        'duracion_total': duracionTotal,
        'nivel': nivelLabel,
        'audience_type': audienceType.id,
        'curriculum_scope': curriculumScope.id,
        'enfoque': enfoque,
        'objetivo': objetivo,
        if (objetivos.isNotEmpty) 'objetivos': objetivos,
        if (groupId != null && groupId!.trim().isNotEmpty)
          'clase_id': groupId!.trim(),
        'group_snapshot': {
          if (groupId != null && groupId!.trim().isNotEmpty)
            'clase_id': groupId!.trim(),
          'group_name': groupName,
          'age_min': ageMin,
          'age_max': ageMax,
          'participants': participantsCount,
          'experience_distribution': experienceDistribution.toMap(),
        },
        if (spaceSnapshot != null) 'space_snapshot': spaceSnapshot!.toMap(),
        'bloques': bloques.map((b) => b.toMap()).toList(),
        if (consejosInstructor != null &&
            consejosInstructor!.trim().isNotEmpty)
          'consejos_instructor': consejosInstructor!.trim(),
        'veces_impartida': vecesImpartida,
        'revision': revision,
        if (instructorId != null && instructorId!.trim().isNotEmpty)
          'instructor_id': instructorId!.trim(),
        if (updatedByDevice != null && updatedByDevice!.trim().isNotEmpty)
          'updated_by_device': updatedByDevice!.trim(),
        if (lastCopilotSummary != null && lastCopilotSummary!.isNotEmpty)
          'last_copilot_summary': lastCopilotSummary,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (ultimaEjecucion != null)
          'ultima_ejecucion': ultimaEjecucion!.toIso8601String(),
        if (duplicatedFromPlanId != null)
          'duplicated_from_plan_id': duplicatedFromPlanId,
        if (continuityContext != null && continuityContext!.hasContent)
          'continuity_context': continuityContext!.toMap(),
        if (generationMeta != null) 'generation_meta': generationMeta!.toMap(),
      };

  /// Serialización lista para Firestore (`instructor_planes_clase`) conservando compatibilidad V1+V2.
  Map<String, dynamic> toFirestoreMap({
    required String instructorUid,
    String? deviceId,
    DateTime? now,
  }) {
    final ts = (now ?? DateTime.now()).toIso8601String();
    final map = toMap();
    map['schema_version'] = schemaVersion < 2 ? 2 : schemaVersion;
    map['instructor_id'] = instructorUid;
    map['revision'] = revision;
    map['plan_status'] = planStatus.id;
    map['updated_at'] = ts;
    map['created_at'] = (createdAt ?? (now ?? DateTime.now())).toIso8601String();
    if (groupId != null && groupId!.trim().isNotEmpty) {
      map['clase_id'] = groupId!.trim();
    }
    final effDevice = (deviceId ?? updatedByDevice)?.trim();
    if (effDevice != null && effDevice.isNotEmpty) {
      map['updated_by_device'] = effDevice;
    }
    return map;
  }

  factory ClassPlanModel.fromMap(String id, Map<String, dynamic> map) {
    final schemaVersion = (map['schema_version'] as num?)?.toInt() ?? 1;
    final nivelStr = (map['nivel'] as String? ?? 'Adultos').trim();
    final audience = map['audience_type'] != null
        ? PlannerAudienceType.fromLegacyLevel(map['audience_type'].toString())
        : PlannerAudienceType.fromLegacyLevel(nivelStr);
    final scope = PlannerCurriculumScope.fromId(
      map['curriculum_scope']?.toString(),
      fallbackAudience: audience,
    );
    final rawBloques = map['bloques'] as List? ?? const [];
    final groupSnapshot = map['group_snapshot'] is Map
        ? Map<String, dynamic>.from(map['group_snapshot'] as Map)
        : const <String, dynamic>{};

    final rawObjetivo = (map['objetivo'] as String? ?? '').trim();
    final rawObjetivos = ((map['objetivos'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final effectiveObjetivos = rawObjetivos.isNotEmpty
        ? rawObjetivos
        : (rawObjetivo.isNotEmpty ? [rawObjetivo] : const <String>[]);
    final effectiveObjetivo = rawObjetivo.isNotEmpty
        ? rawObjetivo
        : effectiveObjetivos.join(' · ');

    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ClassPlanModel(
      id: id,
      schemaVersion: schemaVersion,
      planStatus: ClassPlanStatus.fromId(map['plan_status']?.toString()),
      creationMode: PlannerCreationMode.fromId(map['creation_mode']?.toString()),
      titulo: (map['titulo'] as String? ?? 'Clase de Capoeira').trim(),
      duracionTotal: (map['duracion_total'] as num?)?.toInt() ?? 60,
      nivelLabel: nivelStr,
      audienceType: audience,
      curriculumScope: scope,
      enfoque: (map['enfoque'] as String? ?? 'Técnica & Movilidad').trim(),
      objetivo: effectiveObjetivo,
      objetivos: effectiveObjetivos,
      groupId: (map['clase_id'] as String? ??
              groupSnapshot['clase_id'] as String?)
          ?.trim(),
      groupName: (groupSnapshot['group_name'] ??
              map['group_name'] ??
              nivelStr)
          .toString(),
      ageMin: (groupSnapshot['age_min'] as num?)?.toInt() ??
          (audience == PlannerAudienceType.infantil ? 6 : 16),
      ageMax: (groupSnapshot['age_max'] as num?)?.toInt() ??
          (audience == PlannerAudienceType.infantil ? 12 : 40),
      participantsCount:
          (groupSnapshot['participants'] as num?)?.toInt() ?? 10,
      experienceDistribution: ExperienceDistribution.fromMap(
        groupSnapshot['experience_distribution'] is Map
            ? Map<String, dynamic>.from(
                groupSnapshot['experience_distribution'] as Map)
            : null,
      ),
      bloques: [
        for (int i = 0; i < rawBloques.length; i++)
          if (rawBloques[i] is Map)
            ClassPlanBlock.fromMap(
              Map<String, dynamic>.from(rawBloques[i] as Map),
              blockIndex: i,
              enfoque: (map['enfoque'] as String? ?? '').trim(),
            ),
      ],
      consejosInstructor: map['consejos_instructor']?.toString(),
      vecesImpartida: (map['veces_impartida'] as num?)?.toInt() ?? 0,
      revision: ((map['revision'] as num?)?.toInt() ?? 1).clamp(1, 1000000),
      instructorId: (map['instructor_id'] as String?)?.trim(),
      updatedByDevice: (map['updated_by_device'] as String?)?.trim(),
      lastCopilotSummary: map['last_copilot_summary'] is Map
          ? Map<String, dynamic>.from(map['last_copilot_summary'] as Map)
          : null,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      ultimaEjecucion: parseDate(map['ultima_ejecucion']),
      duplicatedFromPlanId: map['duplicated_from_plan_id']?.toString(),
      continuityContext: map['continuity_context'] is Map
          ? PedagogicalContinuityContext.fromMap(
              Map<String, dynamic>.from(map['continuity_context'] as Map),
            )
          : null,
      generationMeta: map['generation_meta'] is Map
          ? PlannerGenerationMeta.fromMap(
              Map<String, dynamic>.from(map['generation_meta'] as Map),
            )
          : null,
      spaceSnapshot: map['space_snapshot'] is Map
          ? PlannerSpaceContext.fromMap(
              Map<String, dynamic>.from(map['space_snapshot'] as Map),
            )
          : null,
      rawLegacyMap: Map<String, dynamic>.from(map),
    );
  }

  /// Crea una clase V2 manual vacía desde cero sin contenido etiquetado como IA.
  factory ClassPlanModel.emptyManual({
    PlannerGroupProfile? group,
    String? customId,
  }) {
    final audience = group?.audienceType ?? PlannerAudienceType.adultos;
    final scope = PlannerCurriculumScope.suggestedForAudience(audience);
    final now = DateTime.now();
    return ClassPlanModel(
      id: customId ?? 'manual_plan_${now.microsecondsSinceEpoch}',
      schemaVersion: 2,
      planStatus: ClassPlanStatus.draft,
      creationMode: PlannerCreationMode.advanced,
      titulo: 'Nueva clase manual',
      duracionTotal: 60,
      nivelLabel: audience.label,
      audienceType: audience,
      curriculumScope: scope,
      enfoque: audience == PlannerAudienceType.infantil
          ? 'Juegos · Musicalidad'
          : 'Técnica',
      objetivo: '',
      objetivos: const [],
      groupId: group?.source == PlannerGroupSource.realClass ? group?.id : null,
      groupName: group?.name ?? 'Grupo ${audience.label}',
      ageMin: group?.ageMin ??
          (audience == PlannerAudienceType.infantil ? 6 : 16),
      ageMax: group?.ageMax ??
          (audience == PlannerAudienceType.infantil ? 12 : 40),
      participantsCount: group?.participantsCount ?? 12,
      experienceDistribution:
          group?.defaultDistribution ?? const ExperienceDistribution(),
      bloques: const [
        ClassPlanBlock(
          blockId: 'blk_manual_0',
          fase: 'Calentamiento & Activación',
          duracionMin: 10,
          ejercicios: [],
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Crea un borrador local estructurado en 5 bloques sin usar llamadas IA de pago.
  factory ClassPlanModel.fromLocalDraftRequest(ClassPlanDraftRequest req) {
    final total = req.durationMin;
    final warmupMin = (total * 0.17).round().clamp(5, 15);
    const calmMin = 5;
    final rodaMin = req.includeMusicalityRoda
        ? (total * 0.20).round().clamp(8, 20)
        : 0;
    final sueloMin = (total * 0.18).round().clamp(8, 18);
    final techMin = (total - warmupMin - calmMin - rodaMin - sueloMin)
        .clamp(10, total);

    final techCount =
        req.selectedMovements.length + req.selectedResources.length;
    final effectiveCount = techCount > 0 ? techCount : 1;
    final techBase = techMin ~/ effectiveCount;
    var techRemainder = techMin % effectiveCount;
    int nextTechDuration() {
      final extra = techRemainder > 0 ? 1 : 0;
      if (techRemainder > 0) techRemainder--;
      return techBase + extra;
    }

    final techExercises = <ClassPlanExercise>[
      for (int i = 0; i < req.selectedMovements.length; i++)
        ClassPlanExercise(
          exerciseId: 'ex_fiu_$i',
          nombre:
              '${req.selectedMovements[i].item.canonicalName} (${req.selectedMovements[i].priority.label})',
          detalle:
              'Progresión técnica en parejas simultáneas (${req.experienceDistribution.principiantes} principiantes, '
              '${req.experienceDistribution.intermedios} intermedios, ${req.experienceDistribution.avanzados} avanzados).',
          duracionMin: nextTechDuration(),
          organizacion: 'Parejas simultáneas',
          contentOrigin: ContentOrigin.officialFiuCurriculum,
          curriculumMovementIds: [req.selectedMovements[i].item.movementId],
          differentiationBeginner:
              'Base estable y ritmo controlado sin perder postura.',
          differentiationAdvanced:
              'Conectar salida continua y lectura de tiempo con compañero.',
        ),
      for (int i = 0; i < req.selectedResources.length; i++)
        ClassPlanExercise(
          exerciseId: 'ex_res_$i',
          nombre:
              '${req.selectedResources[i].resource.title} (${req.selectedResources[i].priority.label})',
          detalle: [
            if (req.selectedResources[i].usageNote.trim().isNotEmpty)
              'Uso en clase: ${req.selectedResources[i].usageNote.trim()}',
            if (req.selectedResources[i].resource.notes.isNotEmpty)
              req.selectedResources[i].resource.notes
            else if (req.selectedResources[i].usageNote.trim().isEmpty)
              'Recurso seleccionado desde la Pizarra del profesor.',
          ].join(' · '),
          duracionMin: nextTechDuration(),
          organizacion: 'Estaciones simultáneas',
          contentOrigin: ContentOrigin.teacherResource,
          linkedResourceIds: [req.selectedResources[i].resource.resourceId],
          resourceUsageNotes: req.selectedResources[i].usageNote.trim().isNotEmpty
              ? {
                  req.selectedResources[i].resource.resourceId:
                      req.selectedResources[i].usageNote.trim(),
                }
              : const {},
          videoReferenceNote: req.selectedResources[i].resource.hasExternalVideo
              ? 'Video externo: el borrador usa título y notas escritas; la IA no inspecciona el video.'
              : null,
        ),
    ];

    if (techExercises.isEmpty) {
      techExercises.add(
        ClassPlanExercise(
          exerciseId: 'ex_tech_manual_0',
          nombre: req.audienceType == PlannerAudienceType.infantil
              ? 'Circuito motriz con ginga y esquiva lúdica'
              : 'Secuencia base en parejas sin tiempos muertos',
          detalle: req.freeInstructions.trim().isNotEmpty
              ? 'Instrucción del profesor: ${req.freeInstructions.trim()}'
              : 'Definir progresión técnica para el grupo ${req.groupName}.',
          duracionMin: nextTechDuration(),
          organizacion: 'Rotación por parejas',
          contentOrigin: ContentOrigin.teacherResource,
        ),
      );
    }

    final blocks = <ClassPlanBlock>[
      ClassPlanBlock(
        blockId: 'blk_warmup',
        fase: req.audienceType == PlannerAudienceType.infantil
            ? 'Calentamiento Lúdico & Juegos Motores'
            : 'Movilidad Articular & Activación',
        duracionMin: warmupMin,
        ejercicios: [
          ClassPlanExercise(
            exerciseId: 'ex_warmup_0',
            nombre: req.audienceType == PlannerAudienceType.infantil
                ? 'Juego de reacción con animales de capoeira'
                : 'Activación articular + ginga progresiva simultánea',
            detalle:
                'Todo el grupo (${req.participantsCount} alumnos, ${req.ageMin}–${req.ageMax} años) trabaja en paralelo.',
            duracionMin: warmupMin,
            organizacion: 'Todos simultáneamente',
            contentOrigin: ContentOrigin.teacherResource,
            safetyNote: 'Verificar espacio libre de al menos 2m por alumno.',
          ),
        ],
      ),
      ClassPlanBlock(
        blockId: 'blk_tech',
        fase: 'Técnica & Progresiones',
        duracionMin: techMin,
        ejercicios: techExercises,
      ),
      ClassPlanBlock(
        blockId: 'blk_solo',
        fase: req.audienceType == PlannerAudienceType.infantil
            ? 'Acrobacias & Floreios Adaptados'
            : 'Movimientos de Suelo & Floreios',
        duracionMin: sueloMin,
        ejercicios: [
          ClassPlanExercise(
            exerciseId: 'ex_solo_0',
            nombre: 'Estaciones progresivas de control en suelo',
            detalle:
                'Alternar apoyos bajos y desplazamientos laterales en parejas.',
            duracionMin: sueloMin,
            organizacion: 'Estaciones en parejas',
            materiales: req.materials.contains('Colchonetas')
                ? const ['Colchonetas']
                : const [],
            contentOrigin: ContentOrigin.teacherResource,
          ),
        ],
      ),
      if (rodaMin > 0)
        ClassPlanBlock(
          blockId: 'blk_roda',
          fase: 'Roda & Musicalidad',
          duracionMin: rodaMin,
          ejercicios: [
            ClassPlanExercise(
              exerciseId: 'ex_roda_0',
              nombre: 'Coro, palmas y juego rotativo guiado',
              detalle:
                  'Rotación continua cada 60 segundos aplicando el objetivo del día.',
              duracionMin: rodaMin,
              organizacion: 'Roda única rotativa',
              materiales: req.materials
                  .where((m) =>
                      m == 'Berimbau' || m == 'Pandeiro' || m == 'Atabaque')
                  .toList(),
              contentOrigin: ContentOrigin.teacherResource,
            ),
          ],
        ),
      const ClassPlanBlock(
        blockId: 'blk_calm',
        fase: 'Vuelta a la Calma & Cierre',
        duracionMin: calmMin,
        ejercicios: [
          ClassPlanExercise(
            exerciseId: 'ex_calm_0',
            nombre: 'Estiramiento y feedback del grupo',
            detalle: 'Respiración, descarga de muñecas/caderas y cierre técnico.',
            duracionMin: calmMin,
            organizacion: 'Círculo grupal',
            contentOrigin: ContentOrigin.teacherResource,
          ),
        ],
      ),
    ];

    final now = DateTime.now();
    return ClassPlanModel(
      id: 'local_draft_${now.millisecondsSinceEpoch}',
      schemaVersion: 2,
      planStatus: ClassPlanStatus.draft,
      creationMode: req.creationMode,
      titulo: '${req.focus} · ${req.groupName}',
      duracionTotal: total,
      nivelLabel: req.audienceType.label,
      audienceType: req.audienceType,
      curriculumScope: req.curriculumScope,
      enfoque: req.focus,
      objetivo: req.objectives.isNotEmpty
          ? req.objectives.join(' · ')
          : 'Sesión planificada para ${req.groupName}',
      objetivos: List<String>.unmodifiable(req.objectives),
      groupId: req.realClaseId,
      groupName: req.groupName,
      ageMin: req.ageMin,
      ageMax: req.ageMax,
      participantsCount: req.participantsCount,
      experienceDistribution: req.experienceDistribution,
      bloques: blocks,
      consejosInstructor: req.curriculumScope ==
              PlannerCurriculumScope.mixedNoOfficialTrack
          ? 'Grupo mixto: ajustar intensidad y consignas manualmente entre jóvenes y adultos.'
          : (req.curriculumScope == PlannerCurriculumScope.infantilFiuPending
              ? 'Currículo Infantil en extracción: evitar usar secuencias adultas automáticamente.'
              : 'Diferenciar consigna base y progresión sin detener la fluidez del grupo.'),
      createdAt: now,
      updatedAt: now,
      continuityContext: req.continuityContext,
    );
  }
}

/// Sesión impartida real para Historial y Continuidad.
class TaughtSessionRecord {
  final String sessionId;
  final String planId;
  final String planTitle;
  final String? groupId;
  final String groupName;
  final PlannerAudienceType audienceType;
  final DateTime date;
  final int durationMin;
  final int? actualDurationSec;
  final int attendeesCount;
  final int completedExercisesCount;
  final int totalExercisesCount;
  final List<String> practicedMovements;
  final String summaryNote;
  final String pendingNextSession;
  final String? groupResponse;
  final String? difficulties;
  final String? reinforceContent;
  final List<String> completedExercises;
  final List<String> skippedExercises;
  final List<String> pendingExercises;
  final Map<String, int> exerciseRealDurationsSec;
  final List<String> taughtResourceIds;
  final Map<String, dynamic>? planSnapshot;
  final bool endedEarly;
  final bool isSimulatedFixture;

  const TaughtSessionRecord({
    required this.sessionId,
    required this.planId,
    required this.planTitle,
    this.groupId,
    required this.groupName,
    required this.audienceType,
    required this.date,
    required this.durationMin,
    this.actualDurationSec,
    required this.attendeesCount,
    required this.completedExercisesCount,
    required this.totalExercisesCount,
    this.practicedMovements = const [],
    required this.summaryNote,
    required this.pendingNextSession,
    this.groupResponse,
    this.difficulties,
    this.reinforceContent,
    this.completedExercises = const [],
    this.skippedExercises = const [],
    this.pendingExercises = const [],
    this.exerciseRealDurationsSec = const {},
    this.taughtResourceIds = const [],
    this.planSnapshot,
    this.endedEarly = false,
    this.isSimulatedFixture = false,
  });

  Map<String, dynamic> toMap() => {
        'session_id': sessionId,
        'plan_id': planId,
        'plan_titulo_snapshot': planTitle,
        if (groupId != null) 'clase_id': groupId,
        'grupo_nombre_snapshot': groupName,
        'track_id': audienceType.id,
        'ended_at': date.toIso8601String(),
        'duracion_real_min': durationMin,
        if (actualDurationSec != null) 'duracion_real_seg': actualDurationSec,
        'asistentes_count': attendeesCount,
        'completed_exercises_count': completedExercisesCount,
        'total_exercises_count': totalExercisesCount,
        if (practicedMovements.isNotEmpty)
          'practiced_movements': practicedMovements,
        'notas_post_clase': summaryNote,
        'pendiente_proxima_sesion': pendingNextSession,
        if (groupResponse != null && groupResponse!.trim().isNotEmpty)
          'respuesta_grupo': groupResponse!.trim(),
        if (difficulties != null && difficulties!.trim().isNotEmpty)
          'dificultades': difficulties!.trim(),
        if (reinforceContent != null && reinforceContent!.trim().isNotEmpty)
          'contenido_reforzar': reinforceContent!.trim(),
        if (completedExercises.isNotEmpty)
          'ejercicios_completados': completedExercises,
        if (skippedExercises.isNotEmpty) 'ejercicios_omitidos': skippedExercises,
        if (pendingExercises.isNotEmpty) 'ejercicios_pendientes': pendingExercises,
        if (exerciseRealDurationsSec.isNotEmpty)
          'ejercicios_duracion_real_seg': exerciseRealDurationsSec,
        if (taughtResourceIds.isNotEmpty)
          'taught_resource_ids': taughtResourceIds,
        if (planSnapshot != null) 'plan_snapshot': planSnapshot,
        'ended_early': endedEarly,
        'is_simulated_fixture': isSimulatedFixture,
      };

  factory TaughtSessionRecord.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['ended_at'] ?? map['started_at'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? parsedDate;
    }

    final estados = map['ejercicios_estado'] is Map
        ? Map<String, dynamic>.from(map['ejercicios_estado'] as Map)
        : const <String, dynamic>{};
    final completed =
        estados.values.where((v) => v?.toString() == 'completed').length;
    final rawMovs = (map['practiced_movements'] ?? map['movement_ids_impartidos'])
        as List?;
    final realSec = (map['duracion_real_seg'] as num?)?.toInt();
    final realDurMap = <String, int>{};
    if (map['ejercicios_duracion_real_seg'] is Map) {
      for (final e
          in (map['ejercicios_duracion_real_seg'] as Map).entries) {
        final v = (e.value as num?)?.toInt();
        if (v != null) realDurMap[e.key.toString()] = v;
      }
    }

    return TaughtSessionRecord(
      sessionId: id,
      planId: (map['plan_id'] as String? ?? '').trim(),
      planTitle: (map['plan_titulo_snapshot'] as String? ?? 'Sesión impartida')
          .trim(),
      groupId: (map['clase_id'] as String?)?.trim(),
      groupName: (map['grupo_nombre_snapshot'] as String? ?? 'Grupo').trim(),
      audienceType:
          PlannerAudienceType.fromLegacyLevel(map['track_id']?.toString()),
      date: parsedDate,
      durationMin: (map['duracion_real_min'] as num?)?.toInt() ??
          ((realSec ?? 3600) ~/ 60),
      actualDurationSec: realSec,
      attendeesCount: (map['asistentes_count'] as num?)?.toInt() ?? 0,
      completedExercisesCount: (map['completed_exercises_count'] as num?)?.toInt() ??
          completed,
      totalExercisesCount: (map['total_exercises_count'] as num?)?.toInt() ??
          estados.length,
      practicedMovements: (rawMovs ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      summaryNote: (map['notas_post_clase'] as String? ?? '').trim(),
      pendingNextSession:
          (map['pendiente_proxima_sesion'] as String? ?? '').trim(),
      groupResponse: (map['respuesta_grupo'] as String?)?.trim(),
      difficulties: (map['dificultades'] as String?)?.trim(),
      reinforceContent: (map['contenido_reforzar'] as String?)?.trim(),
      completedExercises: ((map['ejercicios_completados'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      skippedExercises: ((map['ejercicios_omitidos'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      pendingExercises: ((map['ejercicios_pendientes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      exerciseRealDurationsSec: realDurMap,
      taughtResourceIds: ((map['taught_resource_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      planSnapshot: map['plan_snapshot'] is Map
          ? Map<String, dynamic>.from(map['plan_snapshot'] as Map)
          : null,
      endedEarly: map['ended_early'] == true,
      isSimulatedFixture: map['is_simulated_fixture'] == true,
    );
  }
}

/// Sanitizador determinista de texto libre antes de construir payloads hacia IA (`Zero-PII`).
/// Preserva terminología técnica de Capoeira/FIU y redacta nombres, teléfonos, correos, fechas e IDs.
class PlannerPiiSanitizer {
  static const Set<String> _safeCapitalizedTerms = {
    'Adultos',
    'Angola',
    'Armada',
    'Atabaque',
    'Avanzado',
    'Avanzados',
    'Aú',
    'Base',
    'Benguela',
    'Bento',
    'Berimbau',
    'Bloque',
    'Bênção',
    'Cabecada',
    'Cabeçada',
    'Calentamiento',
    'Capoeira',
    'Clase',
    'Cocorinha',
    'Cru',
    'Crua',
    'Domingo',
    'Ejercicio',
    'Entreno',
    'Esquiva',
    'Estaciones',
    'FIU',
    'Frente',
    'GINGA',
    'Ginga',
    'Grande',
    'Grupo',
    'Infantil',
    'Intermedio',
    'Intermedios',
    'Iúna',
    'Juego',
    'Juegos',
    'Jueves',
    'Kids',
    'Laranja',
    'Lua',
    'Lunes',
    'Macaco',
    'Martelo',
    'Martes',
    'Meia',
    'Miércoles',
    'Mixto',
    'Movilidad',
    'Musicalidad',
    'Negativa',
    'Niños',
    'Pandeiro',
    'Parejas',
    'Pizarra',
    'Plan',
    'Ponte',
    'Principiante',
    'Principiantes',
    'Queixada',
    'Roda',
    'Rolê',
    'Secuencias',
    'Sábado',
    'São',
    'Terreiro',
    'Todos',
    'Técnica',
    'Verde',
    'Viernes',
    'Vuelta',
  };

  static final RegExp _emailRe = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );
  static final RegExp _handleRe = RegExp(r'(?<!\w)@[A-Za-z0-9_.-]{2,}');
  static final RegExp _explicitIdRe = RegExp(
    r'\b(?:uid|user_id|alumno_id|dni|ce|pasaporte|doc(?:umento)?)\s*[:=#]?\s*[A-Za-z0-9_-]{4,}\b',
    caseSensitive: false,
  );
  static final RegExp _dateRe = RegExp(
    r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',
  );
  static final RegExp _phoneRe = RegExp(r'(?:\+?\d[\d\s().-]{6,}\d)');
  static final RegExp _roleNamedPersonRe = RegExp(
    r'\b(el\s+alumno|la\s+alumna|alumno|alumna|estudiante|niño|niña|menor|chico|chica|hijo|hija|mamá|papá|madre|padre|apoderado|tutor|sr\.?|sra\.?)\s+(?:de\s+)?([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}(?:\s+[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}){0,2})',
    caseSensitive: false,
  );
  static final RegExp _multiWordCapRe = RegExp(
    r'\b([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}(?:\s+(?:de|del|la|y)\s+)?(?:\s+[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}){1,2})\b',
  );
  static final RegExp _prepSingleNameRe = RegExp(
    r'\b(con|para|sobre|junto\s+a)\s+([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{2,})\b',
    caseSensitive: false,
  );
  static final RegExp _subjectVerbNameRe = RegExp(
    r'\b([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{2,})\s+(necesita|tuvo|mejoró|avanzó|logró|presentó|faltó|mostró|mantuvo|perdió|debe|pidió|llegó|tiene|está|hizo|entrenó)\b',
  );

  static String sanitizeFreeText(String raw) {
    var out = raw.trim();
    if (out.isEmpty) return '';

    out = out.replaceAll(_emailRe, '[correo_omitido]');
    out = out.replaceAll(_handleRe, '[cuenta_omitida]');
    out = out.replaceAll(_explicitIdRe, '[id_omitido]');
    out = out.replaceAll(_dateRe, '[fecha_omitida]');
    out = out.replaceAllMapped(_phoneRe, (m) {
      final token = m.group(0) ?? '';
      final digitCount = RegExp(r'\d').allMatches(token).length;
      return digitCount >= 7 ? '[telefono_omitido]' : token;
    });

    out = out.replaceAllMapped(_roleNamedPersonRe, (m) {
      final role = m.group(1) ?? '';
      final name = m.group(2) ?? '';
      final firstToken = name.split(RegExp(r'\s+')).first;
      if (_safeCapitalizedTerms.contains(firstToken)) return m.group(0)!;
      return '$role [participante]';
    });

    out = out.replaceAllMapped(_multiWordCapRe, (m) {
      final phrase = m.group(1) ?? '';
      final capWords = RegExp(r'[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}')
          .allMatches(phrase)
          .map((e) => e.group(0)!)
          .toList();
      if (capWords.length < 2) return phrase;
      final unsafeCount =
          capWords.where((w) => !_safeCapitalizedTerms.contains(w)).length;
      return unsafeCount >= 2 ? '[participante]' : phrase;
    });

    out = out.replaceAllMapped(_prepSingleNameRe, (m) {
      final prep = m.group(1) ?? '';
      final word = m.group(2) ?? '';
      if (_safeCapitalizedTerms.contains(word)) return m.group(0)!;
      return '$prep [participante]';
    });

    out = out.replaceAllMapped(_subjectVerbNameRe, (m) {
      final word = m.group(1) ?? '';
      final verb = m.group(2) ?? '';
      if (_safeCapitalizedTerms.contains(word)) return m.group(0)!;
      return '[participante] $verb';
    });

    return out;
  }

  static List<String> sanitizeList(List<String> items) =>
      items.map(sanitizeFreeText).where((e) => e.isNotEmpty).toList();
}

/// Contrato tipado para el futuro Copiloto Conversacional (edición incremental sin regenerar toda la clase).
class PlanPatchOperation {
  final PlanPatchOperationType operationType;
  final String targetBlockId;
  final String? targetExerciseId;
  final Map<String, dynamic> patchPayload;

  const PlanPatchOperation({
    required this.operationType,
    required this.targetBlockId,
    this.targetExerciseId,
    required this.patchPayload,
  });

  Map<String, dynamic> toMap() => {
        'operation_type': operationType.id,
        'target_block_id': targetBlockId,
        if (targetExerciseId != null) 'target_exercise_id': targetExerciseId,
        'patch_payload': patchPayload,
      };
}

class PlanCopilotRequest {
  final String planId;
  final PlanCopilotTargetScope targetScope;
  final String? targetBlockId;
  final String? targetExerciseId;
  final String instruction;
  final PlannerCurriculumScope curriculumScope;
  final bool preserveUntouchedBlocks;

  const PlanCopilotRequest({
    required this.planId,
    required this.targetScope,
    this.targetBlockId,
    this.targetExerciseId,
    required this.instruction,
    required this.curriculumScope,
    this.preserveUntouchedBlocks = true,
  });

  Map<String, dynamic> toAiSafeMap() => {
        'plan_id': planId,
        'target_scope': targetScope.id,
        if (targetBlockId != null) 'target_block_id': targetBlockId,
        if (targetExerciseId != null) 'target_exercise_id': targetExerciseId,
        'instruction': instruction.trim(),
        'curriculum_scope': curriculumScope.id,
        'preserve_untouched_blocks': preserveUntouchedBlocks,
        'server_validation_required': true,
      };
}

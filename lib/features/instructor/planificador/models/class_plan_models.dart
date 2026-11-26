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
  saved('saved', 'Guardado'),
  archived('archived', 'Archivado');

  final String id;
  final String label;
  const ClassPlanStatus(this.id, this.label);

  static ClassPlanStatus fromId(String? value) {
    return ClassPlanStatus.values.firstWhere(
      (s) => s.id == value,
      orElse: () => ClassPlanStatus.saved,
    );
  }
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
  });

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
    );
  }
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
        'title': resource.title,
        'type': resource.type,
        'category': resource.category,
        'notes': resource.notes,
        if (usageNote.trim().isNotEmpty) 'usage_note': usageNote.trim(),
        'has_external_video': resource.hasExternalVideo,
        'video_visual_inspected': false,
        'origin': ContentOrigin.teacherResource.id,
        'priority': priority.id,
      };
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
    this.materials = const ['Berimbau', 'Pandeiro'],
    this.includeMusicalityRoda = true,
    this.freeInstructions = '',
    this.selectedMovements = const [],
    this.selectedResources = const [],
    this.allowAiComplementaryProposals = true,
    this.continuitySummary,
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
    bool clearContinuity = false,
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
    );
  }

  /// Payload sanitizado libre de PII para futuros contratos con el backend.
  /// El servidor deberá revalidar permisos y elegibilidad curricular contra sus propias fuentes.
  Map<String, dynamic> toAiSafeRequestMap() => {
        'contract_version': '2.0.0',
        'creation_mode': creationMode.id,
        'server_validation_required': true,
        'content_origins_separated': true,
        'group_context': {
          'source': groupSource.id,
          if (realClaseId != null) 'clase_id': realClaseId,
          'group_label': groupName,
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
          'objectives': objectives,
          'materials': materials,
          'include_musicality_roda': includeMusicalityRoda,
          'free_instructions': freeInstructions.trim(),
          'allow_ai_complementary_proposals': allowAiComplementaryProposals,
        },
        'selected_movements':
            selectedMovements.map((m) => m.toPlannerMap()).toList(),
        'selected_resources':
            selectedResources.map((r) => r.toAiSafeMap()).toList(),
        if (continuitySummary != null && continuitySummary!.trim().isNotEmpty)
          'continuity_summary': continuitySummary!.trim(),
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

  const ClassPlanExercise({
    required this.exerciseId,
    required this.nombre,
    required this.detalle,
    this.duracionMin,
    this.organizacion,
    this.materiales = const [],
    this.observacionesProfesor,
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
      };
}

class ClassPlanBlock {
  final String blockId;
  final String fase;
  final int duracionMin;
  final List<ClassPlanExercise> ejercicios;

  const ClassPlanBlock({
    required this.blockId,
    required this.fase,
    required this.duracionMin,
    required this.ejercicios,
  });

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
    int? duracionMin,
    List<ClassPlanExercise>? ejercicios,
  }) {
    return ClassPlanBlock(
      blockId: blockId ?? this.blockId,
      fase: fase ?? this.fase,
      duracionMin: (duracionMin ?? this.duracionMin).clamp(0, 300),
      ejercicios: List<ClassPlanExercise>.unmodifiable(
          ejercicios ?? this.ejercicios),
    );
  }

  factory ClassPlanBlock.fromMap(
    Map<String, dynamic> map, {
    required int blockIndex,
  }) {
    final rawEj = map['ejercicios'] as List? ?? const [];
    return ClassPlanBlock(
      blockId: (map['block_id'] as String?)?.trim().isNotEmpty == true
          ? map['block_id'].toString()
          : 'blk_$blockIndex',
      fase: (map['fase'] as String? ?? 'Bloque ${blockIndex + 1}').trim(),
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
  final String groupName;
  final int ageMin;
  final int ageMax;
  final int participantsCount;
  final ExperienceDistribution experienceDistribution;
  final List<ClassPlanBlock> bloques;
  final String? consejosInstructor;
  final int vecesImpartida;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? ultimaEjecucion;
  final String? duplicatedFromPlanId;
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
    required this.groupName,
    required this.ageMin,
    required this.ageMax,
    required this.participantsCount,
    required this.experienceDistribution,
    required this.bloques,
    this.consejosInstructor,
    this.vecesImpartida = 0,
    this.createdAt,
    this.updatedAt,
    this.ultimaEjecucion,
    this.duplicatedFromPlanId,
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
    String? groupName,
    int? ageMin,
    int? ageMax,
    int? participantsCount,
    ExperienceDistribution? experienceDistribution,
    List<ClassPlanBlock>? bloques,
    String? consejosInstructor,
    bool clearConsejosInstructor = false,
    int? vecesImpartida,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? ultimaEjecucion,
    bool clearUltimaEjecucion = false,
    String? duplicatedFromPlanId,
    bool clearDuplicatedFromPlanId = false,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ultimaEjecucion: clearUltimaEjecucion
          ? null
          : (ultimaEjecucion ?? this.ultimaEjecucion),
      duplicatedFromPlanId: clearDuplicatedFromPlanId
          ? null
          : (duplicatedFromPlanId ?? this.duplicatedFromPlanId),
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
        'group_snapshot': {
          'group_name': groupName,
          'age_min': ageMin,
          'age_max': ageMax,
          'participants': participantsCount,
          'experience_distribution': experienceDistribution.toMap(),
        },
        'bloques': bloques.map((b) => b.toMap()).toList(),
        if (consejosInstructor != null &&
            consejosInstructor!.trim().isNotEmpty)
          'consejos_instructor': consejosInstructor!.trim(),
        'veces_impartida': vecesImpartida,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (ultimaEjecucion != null)
          'ultima_ejecucion': ultimaEjecucion!.toIso8601String(),
        if (duplicatedFromPlanId != null)
          'duplicated_from_plan_id': duplicatedFromPlanId,
      };

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
            ),
      ],
      consejosInstructor: map['consejos_instructor']?.toString(),
      vecesImpartida: (map['veces_impartida'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      ultimaEjecucion: parseDate(map['ultima_ejecucion']),
      duplicatedFromPlanId: map['duplicated_from_plan_id']?.toString(),
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
  final int attendeesCount;
  final int completedExercisesCount;
  final int totalExercisesCount;
  final List<String> practicedMovements;
  final String summaryNote;
  final String pendingNextSession;
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
    required this.attendeesCount,
    required this.completedExercisesCount,
    required this.totalExercisesCount,
    this.practicedMovements = const [],
    required this.summaryNote,
    required this.pendingNextSession,
    this.isSimulatedFixture = false,
  });

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
      durationMin: ((map['duracion_real_seg'] as num?)?.toInt() ?? 3600) ~/ 60,
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
      isSimulatedFixture: map['is_simulated_fixture'] == true,
    );
  }
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

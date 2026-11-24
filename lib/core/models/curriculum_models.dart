/// Modelos tipados del currículo oficial FIU (Adulto e Infantil).
library;

enum CurriculumTrack {
  adulto('adulto', 'adulto_', 'Graduação Adulto FIU'),
  infantil('infantil', 'infantil_', 'Graduação Infantil FIU');

  final String id;
  final String idPrefix;
  final String displayName;

  const CurriculumTrack(this.id, this.idPrefix, this.displayName);

  static CurriculumTrack fromId(String? value) {
    return CurriculumTrack.values.firstWhere(
      (t) => t.id == value,
      orElse: () => CurriculumTrack.adulto,
    );
  }
}

enum TechnicalCategory {
  fundamento('fundamento', 'Fundamento / Base'),
  golpeDeAtaque('golpe_de_ataque', 'Golpes de Ataque'),
  saidaEsquiva('saida_esquiva', 'Saídas y Esquivas'),
  movimentoDeSolo('movimento_de_solo', 'Movimentos de Solo y Floreios'),
  golpeDesequilibrante('golpe_desequilibrante', 'Golpes Desequilibrantes');

  final String id;
  final String labelEs;

  const TechnicalCategory(this.id, this.labelEs);

  static TechnicalCategory fromId(String? value) {
    return TechnicalCategory.values.firstWhere(
      (c) => c.id == value,
      orElse: () => throw ArgumentError('Categoría técnica desconocida: $value'),
    );
  }

  static TechnicalCategory? fromLegacyTutorialCategory(String? legacy) {
    switch ((legacy ?? '').trim().toLowerCase()) {
      case 'fundamentos':
        return TechnicalCategory.fundamento;
      case 'ataques':
        return TechnicalCategory.golpeDeAtaque;
      case 'esquivas':
        return TechnicalCategory.saidaEsquiva;
      case 'floreos':
        return TechnicalCategory.movimentoDeSolo;
      case 'defensas':
        return TechnicalCategory.golpeDesequilibrante;
      default:
        return null;
    }
  }
}

enum MovementEntryKind {
  movimientoBase('movimiento_base'),
  movimiento('movimiento'),
  combinacaoSolo('combinacao_solo');

  final String id;
  const MovementEntryKind(this.id);

  static MovementEntryKind fromId(String? value) {
    return MovementEntryKind.values.firstWhere(
      (k) => k.id == value,
      orElse: () => MovementEntryKind.movimiento,
    );
  }
}

enum CurriculumReviewStatus {
  approved('approved'),
  pendingTechnicalReview('pending_technical_review');

  final String id;
  const CurriculumReviewStatus(this.id);

  static CurriculumReviewStatus fromId(String? value) {
    return CurriculumReviewStatus.values.firstWhere(
      (s) => s.id == value,
      orElse: () => CurriculumReviewStatus.pendingTechnicalReview,
    );
  }
}

class ManualPageRef {
  final int printedPage;
  final int pdfPage;

  const ManualPageRef({
    required this.printedPage,
    required this.pdfPage,
  });

  factory ManualPageRef.fromMap(Map<String, dynamic> map) {
    return ManualPageRef(
      printedPage: (map['printed_page'] as num?)?.toInt() ?? 0,
      pdfPage: (map['pdf_page'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'printed_page': printedPage,
        'pdf_page': pdfPage,
      };
}

class MovementAppearance {
  final String cordaId;
  final String? blockId;
  final String moduleOrSection;
  final int listPosition;
  final String rawNameInManual;
  final ManualPageRef pageRef;
  final int? duplicateOfSlot;

  const MovementAppearance({
    required this.cordaId,
    this.blockId,
    required this.moduleOrSection,
    required this.listPosition,
    required this.rawNameInManual,
    required this.pageRef,
    this.duplicateOfSlot,
  });

  factory MovementAppearance.fromMap(Map<String, dynamic> map) {
    return MovementAppearance(
      cordaId: map['corda_id'] as String? ?? '',
      blockId: map['block_id'] as String?,
      moduleOrSection: map['module_or_section'] as String? ?? '',
      listPosition: (map['list_position'] as num?)?.toInt() ?? 0,
      rawNameInManual: map['raw_name_in_manual'] as String? ?? '',
      pageRef: ManualPageRef.fromMap(map),
      duplicateOfSlot: (map['duplicate_of_slot'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'corda_id': cordaId,
        'block_id': blockId,
        'module_or_section': moduleOrSection,
        'list_position': listPosition,
        'raw_name_in_manual': rawNameInManual,
        ...pageRef.toMap(),
        if (duplicateOfSlot != null) 'duplicate_of_slot': duplicateOfSlot,
      };
}

class UnconfirmedEquivalence {
  final String term;
  final String track;
  final String status;
  final String note;

  const UnconfirmedEquivalence({
    required this.term,
    required this.track,
    required this.status,
    required this.note,
  });

  factory UnconfirmedEquivalence.fromMap(Map<String, dynamic> map) {
    return UnconfirmedEquivalence(
      term: map['term'] as String? ?? '',
      track: map['track'] as String? ?? '',
      status: map['status'] as String? ?? 'unconfirmed',
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'term': term,
        'track': track,
        'status': status,
        'note': note,
      };
}

class CurriculumMovement {
  final String movementId;
  final String canonicalName;
  final TechnicalCategory category;
  final MovementEntryKind entryKind;
  final List<String> componentMovementIds;
  final List<String> aliases;
  final List<UnconfirmedEquivalence> unconfirmedEquivalences;
  final CurriculumReviewStatus reviewStatus;
  final bool isAmbiguous;
  final bool aiPlannerEligible;
  final String firstIntroducedAdulto;
  final List<MovementAppearance> appearsInAdultoCordas;
  final List<CurriculumTrack> tracksSupported;
  final String? notes;

  const CurriculumMovement({
    required this.movementId,
    required this.canonicalName,
    required this.category,
    required this.entryKind,
    this.componentMovementIds = const [],
    this.aliases = const [],
    this.unconfirmedEquivalences = const [],
    required this.reviewStatus,
    required this.isAmbiguous,
    required this.aiPlannerEligible,
    required this.firstIntroducedAdulto,
    this.appearsInAdultoCordas = const [],
    this.tracksSupported = const [CurriculumTrack.adulto],
    this.notes,
  });

  bool get isCombination => entryKind == MovementEntryKind.combinacaoSolo;

  bool get isSelectableForAiPlanner =>
      aiPlannerEligible &&
      !isAmbiguous &&
      reviewStatus == CurriculumReviewStatus.approved;

  List<String> get cordaIdsAdulto {
    final seen = <String>{};
    final result = <String>[];
    for (final app in appearsInAdultoCordas) {
      if (seen.add(app.cordaId)) {
        result.add(app.cordaId);
      }
    }
    return result;
  }

  factory CurriculumMovement.fromMap(Map<String, dynamic> map) {
    return CurriculumMovement(
      movementId: map['movement_id'] as String? ?? '',
      canonicalName: map['canonical_name'] as String? ?? '',
      category: TechnicalCategory.fromId(map['category_id'] as String?),
      entryKind: MovementEntryKind.fromId(map['entry_kind'] as String?),
      componentMovementIds:
          List<String>.from(map['component_movement_ids'] ?? const []),
      aliases: List<String>.from(map['aliases'] ?? const []),
      unconfirmedEquivalences: ((map['unconfirmed_equivalences'] as List?) ??
              const [])
          .map((e) => UnconfirmedEquivalence.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      reviewStatus:
          CurriculumReviewStatus.fromId(map['review_status'] as String?),
      isAmbiguous: map['is_ambiguous'] as bool? ?? false,
      aiPlannerEligible: map['ai_planner_eligible'] as bool? ?? false,
      firstIntroducedAdulto: map['first_introduced_adulto'] as String? ?? '',
      appearsInAdultoCordas:
          ((map['appears_in_adulto_cordas'] as List?) ?? const [])
              .map((a) => MovementAppearance.fromMap(Map<String, dynamic>.from(a)))
              .toList(),
      tracksSupported: ((map['tracks_supported'] as List?) ?? const ['adulto'])
          .map((t) => CurriculumTrack.fromId(t as String?))
          .toList(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'movement_id': movementId,
        'canonical_name': canonicalName,
        'category_id': category.id,
        'entry_kind': entryKind.id,
        if (componentMovementIds.isNotEmpty)
          'component_movement_ids': componentMovementIds,
        'aliases': aliases,
        'unconfirmed_equivalences':
            unconfirmedEquivalences.map((e) => e.toMap()).toList(),
        'review_status': reviewStatus.id,
        'is_ambiguous': isAmbiguous,
        'ai_planner_eligible': aiPlannerEligible,
        'first_introduced_adulto': firstIntroducedAdulto,
        'appears_in_adulto_cordas':
            appearsInAdultoCordas.map((a) => a.toMap()).toList(),
        'tracks_supported': tracksSupported.map((t) => t.id).toList(),
        if (notes != null) 'notes': notes,
      };
}

class CurriculumRequirementItem {
  final int pos;
  final String movementId;
  final String raw;
  final ManualPageRef pageRef;
  final int? duplicateOfSlot;

  const CurriculumRequirementItem({
    required this.pos,
    required this.movementId,
    required this.raw,
    required this.pageRef,
    this.duplicateOfSlot,
  });

  factory CurriculumRequirementItem.fromMap(Map<String, dynamic> map) {
    return CurriculumRequirementItem(
      pos: (map['pos'] as num?)?.toInt() ?? 0,
      movementId: map['movement_id'] as String? ?? '',
      raw: map['raw'] as String? ?? '',
      pageRef: ManualPageRef.fromMap(map),
      duplicateOfSlot: (map['duplicate_of_slot'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'pos': pos,
        'movement_id': movementId,
        'raw': raw,
        ...pageRef.toMap(),
        if (duplicateOfSlot != null) 'duplicate_of_slot': duplicateOfSlot,
      };
}

Map<String, List<CurriculumRequirementItem>> _parseRequirementSections(
    Map<String, dynamic>? rawSections) {
  if (rawSections == null) return const {};
  final parsed = <String, List<CurriculumRequirementItem>>{};
  for (final entry in rawSections.entries) {
    if (entry.value is List) {
      parsed[entry.key] = (entry.value as List)
          .map((item) =>
              CurriculumRequirementItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
  }
  return parsed;
}

Map<String, dynamic> _serializeRequirementSections(
    Map<String, List<CurriculumRequirementItem>> sections) {
  return {
    for (final entry in sections.entries)
      entry.key: entry.value.map((i) => i.toMap()).toList(),
  };
}

class CurriculumModule {
  final String moduleId;
  final String nombre;
  final String duracaoTexto;
  final String? prerequisitoRaw;
  final String? notaPedagogica;
  final String? descripcionRaw;
  final List<String> movementIds;
  final Map<String, List<CurriculumRequirementItem>> sections;
  final String? repeticoesMinimas;

  const CurriculumModule({
    required this.moduleId,
    required this.nombre,
    required this.duracaoTexto,
    this.prerequisitoRaw,
    this.notaPedagogica,
    this.descripcionRaw,
    this.movementIds = const [],
    this.sections = const {},
    this.repeticoesMinimas,
  });

  Set<String> get allMovementIds {
    final ids = <String>{...movementIds};
    for (final list in sections.values) {
      for (final item in list) {
        ids.add(item.movementId);
      }
    }
    return ids;
  }

  factory CurriculumModule.fromMap(Map<String, dynamic> map) {
    return CurriculumModule(
      moduleId: map['module_id'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      duracaoTexto: map['duracao_texto'] as String? ?? '',
      prerequisitoRaw: map['prerequisito_raw'] as String?,
      notaPedagogica: map['nota_pedagogica'] as String?,
      descripcionRaw: map['descripcion_raw'] as String?,
      movementIds: List<String>.from(map['movement_ids'] ?? const []),
      sections: _parseRequirementSections(
          map['sections'] != null ? Map<String, dynamic>.from(map['sections']) : null),
      repeticoesMinimas: map['repeticoes_minimas'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'module_id': moduleId,
        'nombre': nombre,
        'duracao_texto': duracaoTexto,
        if (prerequisitoRaw != null) 'prerequisito_raw': prerequisitoRaw,
        if (notaPedagogica != null) 'nota_pedagogica': notaPedagogica,
        if (descripcionRaw != null) 'descripcion_raw': descripcionRaw,
        if (movementIds.isNotEmpty) 'movement_ids': movementIds,
        if (sections.isNotEmpty) 'sections': _serializeRequirementSections(sections),
        if (repeticoesMinimas != null) 'repeticoes_minimas': repeticoesMinimas,
      };
}

class CurriculumSequence {
  final String nombre;
  final String raw;
  final List<String> movementIds;
  final List<String> unresolvedTermsInSequence;
  final ManualPageRef pageRef;

  const CurriculumSequence({
    required this.nombre,
    required this.raw,
    this.movementIds = const [],
    this.unresolvedTermsInSequence = const [],
    required this.pageRef,
  });

  factory CurriculumSequence.fromMap(Map<String, dynamic> map) {
    return CurriculumSequence(
      nombre: map['nombre'] as String? ?? '',
      raw: map['raw'] as String? ?? '',
      movementIds: List<String>.from(map['movement_ids'] ?? const []),
      unresolvedTermsInSequence:
          List<String>.from(map['unresolved_terms_in_sequence'] ?? const []),
      pageRef: ManualPageRef.fromMap(map),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'raw': raw,
        'movement_ids': movementIds,
        if (unresolvedTermsInSequence.isNotEmpty)
          'unresolved_terms_in_sequence': unresolvedTermsInSequence,
        ...pageRef.toMap(),
      };
}

class WeeklySchedule {
  final List<int> printedPages;
  final List<int> pdfPages;
  final String repeticoesMinimas;
  final List<String> treino1;
  final List<String> treino2;
  final List<String> treino3;

  const WeeklySchedule({
    this.printedPages = const [],
    this.pdfPages = const [],
    required this.repeticoesMinimas,
    this.treino1 = const [],
    this.treino2 = const [],
    this.treino3 = const [],
  });

  factory WeeklySchedule.fromMap(Map<String, dynamic> map) {
    return WeeklySchedule(
      printedPages: List<int>.from(
          ((map['printed_pages'] as List?) ?? const []).map((e) => (e as num).toInt())),
      pdfPages: List<int>.from(
          ((map['pdf_pages'] as List?) ?? const []).map((e) => (e as num).toInt())),
      repeticoesMinimas: map['repeticoes_minimas'] as String? ?? '',
      treino1: List<String>.from(map['treino_1'] ?? const []),
      treino2: List<String>.from(map['treino_2'] ?? const []),
      treino3: List<String>.from(map['treino_3'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'printed_pages': printedPages,
        'pdf_pages': pdfPages,
        'repeticoes_minimas': repeticoesMinimas,
        'treino_1': treino1,
        'treino_2': treino2,
        'treino_3': treino3,
      };
}

class CordaMusicality {
  final String raw;
  final List<String> instrumentos;
  final List<String> cantosObrigatorios;
  final bool regraAcumulativa;
  final String? especificoCorda;
  final ManualPageRef pageRef;

  const CordaMusicality({
    required this.raw,
    this.instrumentos = const [],
    this.cantosObrigatorios = const [],
    this.regraAcumulativa = false,
    this.especificoCorda,
    required this.pageRef,
  });

  factory CordaMusicality.fromMap(Map<String, dynamic> map) {
    return CordaMusicality(
      raw: map['raw'] as String? ?? '',
      instrumentos: List<String>.from(map['instrumentos'] ?? const []),
      cantosObrigatorios:
          List<String>.from(map['cantos_obrigatorios'] ?? const []),
      regraAcumulativa: map['regra_acumulativa'] as bool? ?? false,
      especificoCorda: map['especifico_corda'] as String?,
      pageRef: ManualPageRef.fromMap(map),
    );
  }

  Map<String, dynamic> toMap() => {
        'raw': raw,
        if (instrumentos.isNotEmpty) 'instrumentos': instrumentos,
        if (cantosObrigatorios.isNotEmpty)
          'cantos_obrigatorios': cantosObrigatorios,
        if (regraAcumulativa) 'regra_acumulativa': regraAcumulativa,
        if (especificoCorda != null) 'especifico_corda': especificoCorda,
        ...pageRef.toMap(),
      };
}

class CordaEvaluation {
  final String raw;
  final Map<String, dynamic> fisico;
  final List<String> musical;
  final ManualPageRef pageRef;

  const CordaEvaluation({
    required this.raw,
    this.fisico = const {},
    this.musical = const [],
    required this.pageRef,
  });

  factory CordaEvaluation.fromMap(Map<String, dynamic> map) {
    return CordaEvaluation(
      raw: map['raw'] as String? ?? '',
      fisico: Map<String, dynamic>.from(map['fisico'] ?? const {}),
      musical: List<String>.from(map['musical'] ?? const []),
      pageRef: ManualPageRef.fromMap(map),
    );
  }

  Map<String, dynamic> toMap() => {
        'raw': raw,
        'fisico': fisico,
        'musical': musical,
        ...pageRef.toMap(),
      };
}

class DrillOnlyMention {
  final String rawTerm;
  final String location;
  final String note;

  const DrillOnlyMention({
    required this.rawTerm,
    required this.location,
    required this.note,
  });

  factory DrillOnlyMention.fromMap(Map<String, dynamic> map) {
    return DrillOnlyMention(
      rawTerm: map['raw_term'] as String? ?? '',
      location: map['location'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'raw_term': rawTerm,
        'location': location,
        'note': note,
      };
}

class CurriculumBlock {
  final String blockId;
  final CurriculumTrack track;
  final List<String> cordaIds;
  final String titleInManual;
  final String duracaoTexto;
  final List<int> printedPages;
  final List<int> pdfPages;
  final String groupingRule;
  final Map<String, List<CurriculumRequirementItem>> sections;
  final String musicalidadeBloqueRaw;
  final WeeklySchedule? cronogramaSemanal;
  final List<DrillOnlyMention> drillOnlyMentions;
  final List<String> sourceAnomalies;

  const CurriculumBlock({
    required this.blockId,
    required this.track,
    this.cordaIds = const [],
    required this.titleInManual,
    required this.duracaoTexto,
    this.printedPages = const [],
    this.pdfPages = const [],
    required this.groupingRule,
    this.sections = const {},
    required this.musicalidadeBloqueRaw,
    this.cronogramaSemanal,
    this.drillOnlyMentions = const [],
    this.sourceAnomalies = const [],
  });

  Set<String> get allMovementIds {
    final ids = <String>{};
    for (final list in sections.values) {
      for (final item in list) {
        ids.add(item.movementId);
      }
    }
    return ids;
  }

  factory CurriculumBlock.fromMap(Map<String, dynamic> map) {
    final sourcePages =
        Map<String, dynamic>.from(map['source_pages'] ?? const {});
    return CurriculumBlock(
      blockId: map['block_id'] as String? ?? '',
      track: CurriculumTrack.fromId(map['track_id'] as String?),
      cordaIds: List<String>.from(map['corda_ids'] ?? const []),
      titleInManual: map['title_in_manual'] as String? ?? '',
      duracaoTexto: map['duracao_texto'] as String? ?? '',
      printedPages: List<int>.from(
          ((sourcePages['printed_pages'] as List?) ?? const [])
              .map((e) => (e as num).toInt())),
      pdfPages: List<int>.from(
          ((sourcePages['pdf_pages'] as List?) ?? const [])
              .map((e) => (e as num).toInt())),
      groupingRule: map['grouping_rule'] as String? ?? '',
      sections: _parseRequirementSections(
          map['sections'] != null ? Map<String, dynamic>.from(map['sections']) : null),
      musicalidadeBloqueRaw: map['musicalidade_bloque_raw'] as String? ?? '',
      cronogramaSemanal: map['cronograma_semanal'] != null
          ? WeeklySchedule.fromMap(
              Map<String, dynamic>.from(map['cronograma_semanal']))
          : null,
      drillOnlyMentions: ((map['drill_only_mentions'] as List?) ?? const [])
          .map((d) => DrillOnlyMention.fromMap(Map<String, dynamic>.from(d)))
          .toList(),
      sourceAnomalies: List<String>.from(map['source_anomalies'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'block_id': blockId,
        'track_id': track.id,
        'corda_ids': cordaIds,
        'title_in_manual': titleInManual,
        'duracao_texto': duracaoTexto,
        'source_pages': {
          'printed_pages': printedPages,
          'pdf_pages': pdfPages,
        },
        'grouping_rule': groupingRule,
        'sections': _serializeRequirementSections(sections),
        'musicalidade_bloque_raw': musicalidadeBloqueRaw,
        if (cronogramaSemanal != null)
          'cronograma_semanal': cronogramaSemanal!.toMap(),
        'drill_only_mentions':
            drillOnlyMentions.map((d) => d.toMap()).toList(),
        'source_anomalies': sourceAnomalies,
      };
}

class CurriculumCorda {
  final String cordaId;
  final CurriculumTrack track;
  final int index;
  final String nombreManual;
  final String nombreApp;
  final String? nombreTreinamento;
  final String? simbolismoManual;
  final String? sharedBlockId;
  final List<String> inheritsFromCordaIds;
  final String? inheritanceNoteRaw;
  final String? duracaoTexto;
  final List<CurriculumModule> modules;
  final Map<String, List<CurriculumRequirementItem>> sections;
  final List<CurriculumSequence> sequencias;
  final CordaMusicality? musicalidade;
  final WeeklySchedule? cronogramaSemanal;
  final CordaEvaluation? avaliacao;
  final String? sabedoriaMestreNatal;
  final Map<String, dynamic> sourcePages;
  final List<String> sourceAnomalies;
  final String? edadReferencia;
  final String contentStatus;

  const CurriculumCorda({
    required this.cordaId,
    required this.track,
    required this.index,
    required this.nombreManual,
    required this.nombreApp,
    this.nombreTreinamento,
    this.simbolismoManual,
    this.sharedBlockId,
    this.inheritsFromCordaIds = const [],
    this.inheritanceNoteRaw,
    this.duracaoTexto,
    this.modules = const [],
    this.sections = const {},
    this.sequencias = const [],
    this.musicalidade,
    this.cronogramaSemanal,
    this.avaliacao,
    this.sabedoriaMestreNatal,
    this.sourcePages = const {},
    this.sourceAnomalies = const [],
    this.edadReferencia,
    this.contentStatus = 'extracted_v1',
  });

  bool get usesSharedBlock => sharedBlockId != null && sharedBlockId!.isNotEmpty;

  factory CurriculumCorda.fromMap(Map<String, dynamic> map) {
    return CurriculumCorda(
      cordaId: map['corda_id'] as String? ?? '',
      track: CurriculumTrack.fromId(map['track_id'] as String?),
      index: (map['index'] as num?)?.toInt() ?? 0,
      nombreManual: map['nombre_manual'] as String? ?? '',
      nombreApp: map['nombre_app'] as String? ??
          (map['nombre_manual'] as String? ?? ''),
      nombreTreinamento: map['nombre_treinamento'] as String?,
      simbolismoManual: map['simbolismo_manual'] as String?,
      sharedBlockId: map['shared_block_id'] as String?,
      inheritsFromCordaIds:
          List<String>.from(map['inherits_from_corda_ids'] ?? const []),
      inheritanceNoteRaw: map['inheritance_note_raw'] as String?,
      duracaoTexto: map['duracao_texto'] as String?,
      modules: ((map['modules'] as List?) ?? const [])
          .map((m) => CurriculumModule.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      sections: _parseRequirementSections(
          map['sections'] != null ? Map<String, dynamic>.from(map['sections']) : null),
      sequencias: ((map['sequencias'] as List?) ?? const [])
          .map((s) => CurriculumSequence.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      musicalidade: map['musicalidade'] != null
          ? CordaMusicality.fromMap(
              Map<String, dynamic>.from(map['musicalidade']))
          : null,
      cronogramaSemanal: map['cronograma_semanal'] != null
          ? WeeklySchedule.fromMap(
              Map<String, dynamic>.from(map['cronograma_semanal']))
          : null,
      avaliacao: map['avaliacao'] != null
          ? CordaEvaluation.fromMap(Map<String, dynamic>.from(map['avaliacao']))
          : null,
      sabedoriaMestreNatal: map['sabedoria_mestre_natal'] as String?,
      sourcePages: Map<String, dynamic>.from(map['source_pages'] ?? const {}),
      sourceAnomalies: List<String>.from(map['source_anomalies'] ?? const []),
      edadReferencia: map['edad_referencia'] as String?,
      contentStatus: map['content_status'] as String? ?? 'extracted_v1',
    );
  }

  Map<String, dynamic> toMap() => {
        'corda_id': cordaId,
        'track_id': track.id,
        'index': index,
        'nombre_manual': nombreManual,
        'nombre_app': nombreApp,
        if (nombreTreinamento != null) 'nombre_treinamento': nombreTreinamento,
        if (simbolismoManual != null) 'simbolismo_manual': simbolismoManual,
        'shared_block_id': sharedBlockId,
        'inherits_from_corda_ids': inheritsFromCordaIds,
        if (inheritanceNoteRaw != null)
          'inheritance_note_raw': inheritanceNoteRaw,
        if (duracaoTexto != null) 'duracao_texto': duracaoTexto,
        if (modules.isNotEmpty)
          'modules': modules.map((m) => m.toMap()).toList(),
        if (sections.isNotEmpty)
          'sections': _serializeRequirementSections(sections),
        if (sequencias.isNotEmpty)
          'sequencias': sequencias.map((s) => s.toMap()).toList(),
        if (musicalidade != null) 'musicalidade': musicalidade!.toMap(),
        if (cronogramaSemanal != null)
          'cronograma_semanal': cronogramaSemanal!.toMap(),
        if (avaliacao != null) 'avaliacao': avaliacao!.toMap(),
        if (sabedoriaMestreNatal != null)
          'sabedoria_mestre_natal': sabedoriaMestreNatal,
        'source_pages': sourcePages,
        if (sourceAnomalies.isNotEmpty) 'source_anomalies': sourceAnomalies,
        if (edadReferencia != null) 'edad_referencia': edadReferencia,
        'content_status': contentStatus,
      };
}

class TutorialCurriculumLink {
  final String tutorialDocId;
  final String tituloProd;
  final String categoriaProd;
  final String? nivelProd;
  final String legacyCordaProd;
  final bool hasRealVideo;
  final String? duracaoProd;
  final List<String> movementIds;
  final String primaryMovementId;
  final List<String> pendingMovementIds;
  final List<String> curriculumCordaIds;
  final String matchStatus;
  final bool requiresOwnerReview;
  final bool preserveLegacyPermissions;
  final String? reviewNote;

  const TutorialCurriculumLink({
    required this.tutorialDocId,
    required this.tituloProd,
    required this.categoriaProd,
    this.nivelProd,
    required this.legacyCordaProd,
    required this.hasRealVideo,
    this.duracaoProd,
    required this.movementIds,
    required this.primaryMovementId,
    this.pendingMovementIds = const [],
    this.curriculumCordaIds = const [],
    required this.matchStatus,
    required this.requiresOwnerReview,
    this.preserveLegacyPermissions = true,
    this.reviewNote,
  });

  factory TutorialCurriculumLink.fromMap(Map<String, dynamic> map) {
    final ids = List<String>.from(map['movement_ids'] ?? const []);
    final primary = (map['primary_movement_id'] as String?) ??
        (map['mapped_movement_id'] as String?) ??
        (ids.isNotEmpty ? ids.first : '');
    return TutorialCurriculumLink(
      tutorialDocId: map['tutorial_doc_id'] as String? ?? '',
      tituloProd: map['titulo_prod'] as String? ?? '',
      categoriaProd: map['categoria_prod'] as String? ?? '',
      nivelProd: map['nivel_prod'] as String?,
      legacyCordaProd: (map['legacy_corda_prod'] as String?) ??
          (map['corda_prod'] as String?) ??
          '',
      hasRealVideo: map['has_real_video'] as bool? ?? false,
      duracaoProd: map['duracao_prod'] as String?,
      movementIds: ids,
      primaryMovementId: primary,
      pendingMovementIds:
          List<String>.from(map['pending_movement_ids'] ?? const []),
      curriculumCordaIds:
          List<String>.from(map['curriculum_corda_ids'] ?? const []),
      matchStatus: map['match_status'] as String? ?? '',
      requiresOwnerReview: map['requires_owner_review'] as bool? ?? false,
      preserveLegacyPermissions:
          map['preserve_legacy_permissions'] as bool? ?? true,
      reviewNote: map['review_note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'tutorial_doc_id': tutorialDocId,
        'titulo_prod': tituloProd,
        'categoria_prod': categoriaProd,
        'nivel_prod': nivelProd,
        'corda_prod': legacyCordaProd,
        'legacy_corda_prod': legacyCordaProd,
        'has_real_video': hasRealVideo,
        if (duracaoProd != null) 'duracao_prod': duracaoProd,
        'movement_ids': movementIds,
        'primary_movement_id': primaryMovementId,
        'mapped_movement_id': primaryMovementId,
        'pending_movement_ids': pendingMovementIds,
        'curriculum_corda_ids': curriculumCordaIds,
        'match_status': matchStatus,
        'requires_owner_review': requiresOwnerReview,
        'preserve_legacy_permissions': preserveLegacyPermissions,
        if (reviewNote != null) 'review_note': reviewNote,
      };
}

class GlossaryCrosswalkEntry {
  final String terminoGlosario;
  final String categoriaGlosario;
  final String entryKind;
  final List<String> movementIds;
  final List<String> relatedVariantMovementIds;
  final bool isGenericTerm;
  final String matchStatus;
  final bool requiresOwnerReview;
  final String? reviewNote;

  const GlossaryCrosswalkEntry({
    required this.terminoGlosario,
    required this.categoriaGlosario,
    required this.entryKind,
    this.movementIds = const [],
    this.relatedVariantMovementIds = const [],
    this.isGenericTerm = false,
    required this.matchStatus,
    this.requiresOwnerReview = false,
    this.reviewNote,
  });

  bool matchesMovement(String movementId) =>
      movementIds.contains(movementId) ||
      relatedVariantMovementIds.contains(movementId);

  factory GlossaryCrosswalkEntry.fromMap(Map<String, dynamic> map) {
    return GlossaryCrosswalkEntry(
      terminoGlosario: map['termino_glosario'] as String? ?? '',
      categoriaGlosario: map['categoria_glosario'] as String? ?? '',
      entryKind: map['entry_kind'] as String? ?? '',
      movementIds: List<String>.from(map['movement_ids'] ?? const []),
      relatedVariantMovementIds: List<String>.from(
          map['related_variant_movement_ids'] ?? const []),
      isGenericTerm: map['is_generic_term'] as bool? ?? false,
      matchStatus: map['match_status'] as String? ?? '',
      requiresOwnerReview: map['requires_owner_review'] as bool? ?? false,
      reviewNote: map['review_note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'termino_glosario': terminoGlosario,
        'categoria_glosario': categoriaGlosario,
        'entry_kind': entryKind,
        'movement_ids': movementIds,
        'related_variant_movement_ids': relatedVariantMovementIds,
        'is_generic_term': isGenericTerm,
        'match_status': matchStatus,
        'requires_owner_review': requiresOwnerReview,
        if (reviewNote != null) 'review_note': reviewNote,
      };
}

class CordaCurriculumView {
  final CurriculumCorda corda;
  final CurriculumBlock? sharedBlock;
  final List<CurriculumMovement> directMovements;
  final List<TutorialCurriculumLink> linkedTutorials;

  const CordaCurriculumView({
    required this.corda,
    this.sharedBlock,
    required this.directMovements,
    required this.linkedTutorials,
  });

  Map<String, List<CurriculumRequirementItem>> get effectiveSections {
    if (sharedBlock != null) return sharedBlock!.sections;
    if (corda.sections.isNotEmpty) return corda.sections;
    final merged = <String, List<CurriculumRequirementItem>>{};
    for (final mod in corda.modules) {
      for (final entry in mod.sections.entries) {
        merged.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }
    return merged;
  }

  WeeklySchedule? get effectiveWeeklySchedule =>
      sharedBlock?.cronogramaSemanal ?? corda.cronogramaSemanal;

  List<DrillOnlyMention> get effectiveDrillOnlyMentions =>
      sharedBlock?.drillOnlyMentions ?? const [];
}

class AccumulatedRepertoire {
  final CurriculumTrack track;
  final int upToCordaIndex;
  final List<CurriculumCorda> includedCordas;
  final List<CurriculumMovement> uniqueMovements;
  final Map<TechnicalCategory, List<CurriculumMovement>> movementsByCategory;
  final List<CurriculumMovement> combinations;
  final List<CurriculumMovement> aiEligibleMovements;
  final List<CurriculumMovement> excludedAmbiguousMovements;
  final List<TutorialCurriculumLink> linkedTutorials;

  const AccumulatedRepertoire({
    required this.track,
    required this.upToCordaIndex,
    required this.includedCordas,
    required this.uniqueMovements,
    required this.movementsByCategory,
    required this.combinations,
    required this.aiEligibleMovements,
    required this.excludedAmbiguousMovements,
    required this.linkedTutorials,
  });
}

/// Elemento serializable entregado por el contrato de selección curricular (PED-03B-FINAL).
class CurriculumMovementSelectionItem {
  final String movementId;
  final String canonicalName;
  final TechnicalCategory category;
  final String? firstIntroducedAdulto;
  final bool isCombination;
  final bool isSelectableForAiPlanner;
  final bool hasRealVideo;

  const CurriculumMovementSelectionItem({
    required this.movementId,
    required this.canonicalName,
    required this.category,
    required this.firstIntroducedAdulto,
    required this.isCombination,
    required this.isSelectableForAiPlanner,
    this.hasRealVideo = false,
  });

  factory CurriculumMovementSelectionItem.fromMovement(
    CurriculumMovement movement, {
    bool hasRealVideo = false,
  }) {
    return CurriculumMovementSelectionItem(
      movementId: movement.movementId,
      canonicalName: movement.canonicalName,
      category: movement.category,
      firstIntroducedAdulto: movement.firstIntroducedAdulto,
      isCombination: movement.isCombination,
      isSelectableForAiPlanner: movement.isSelectableForAiPlanner,
      hasRealVideo: hasRealVideo,
    );
  }

  Map<String, dynamic> toPlannerMap() => {
        'movement_id': movementId,
        'canonical_name': canonicalName,
        'category': category.id,
        if (firstIntroducedAdulto != null)
          'first_introduced_adulto': firstIntroducedAdulto,
        'is_combination': isCombination,
        'selectable_for_ai_planner': isSelectableForAiPlanner,
        'has_real_video': hasRealVideo,
      };
}

typedef CurriculumSelectionCallback = void Function(
  List<CurriculumMovementSelectionItem> selectedItems,
);

/// Contrato opt-in para conectar la Biblioteca Curricular con el futuro planificador de clases (sin IA).
class CurriculumSelectionContract {
  final bool enabled;
  final Set<String> initialSelectedMovementIds;
  final bool excludePendingTechnicalReview;
  final String confirmLabel;
  final CurriculumSelectionCallback? onSelectionChanged;
  final CurriculumSelectionCallback? onConfirmSelection;

  const CurriculumSelectionContract({
    this.enabled = true,
    this.initialSelectedMovementIds = const {},
    this.excludePendingTechnicalReview = true,
    this.confirmLabel = 'Usar en planificador',
    this.onSelectionChanged,
    this.onConfirmSelection,
  });
}

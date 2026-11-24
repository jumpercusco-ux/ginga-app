import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/curriculum_models.dart';

/// Fuente de datos abstracta para consultar el currículo FIU desde memoria/asset o Firestore.
abstract class CurriculumDataSource {
  Future<List<CurriculumMovement>> loadMovements();
  Future<List<CurriculumCorda>> loadCordas();
  Future<List<CurriculumBlock>> loadBlocks();
  Future<List<TutorialCurriculumLink>> loadTutorialLinks();
  Future<List<GlossaryCrosswalkEntry>> loadGlossaryCrosswalk();
}

/// Fuente de datos en memoria respaldada por `data/curriculum/fiu_adulto_v1.json`.
class InMemoryCurriculumDataSource implements CurriculumDataSource {
  final List<CurriculumMovement> _movements;
  final List<CurriculumCorda> _cordas;
  final List<CurriculumBlock> _blocks;
  final List<TutorialCurriculumLink> _tutorialLinks;
  final List<GlossaryCrosswalkEntry> _glossary;

  InMemoryCurriculumDataSource._({
    required List<CurriculumMovement> movements,
    required List<CurriculumCorda> cordas,
    required List<CurriculumBlock> blocks,
    required List<TutorialCurriculumLink> tutorialLinks,
    required List<GlossaryCrosswalkEntry> glossary,
  })  : _movements = movements,
        _cordas = cordas,
        _blocks = blocks,
        _tutorialLinks = tutorialLinks,
        _glossary = glossary;

  factory InMemoryCurriculumDataSource.fromCatalogJson(
      Map<String, dynamic> json) {
    final movements = ((json['movements'] as List?) ?? const [])
        .map((m) => CurriculumMovement.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final adultCordas = ((json['cordas'] as List?) ?? const [])
        .map((c) => CurriculumCorda.fromMap({
              ...Map<String, dynamic>.from(c),
              'content_status': 'extracted_v1',
            }))
        .toList();

    final tracks = Map<String, dynamic>.from(json['tracks'] ?? const {});
    final infantilTrack =
        Map<String, dynamic>.from(tracks['infantil'] ?? const {});
    final infantilCordas = ((infantilTrack['cordas'] as List?) ?? const [])
        .map((c) {
          final m = Map<String, dynamic>.from(c);
          return CurriculumCorda.fromMap({
            ...m,
            'track_id': CurriculumTrack.infantil.id,
            'nombre_app': m['nombre_manual'] ?? '',
            'content_status': 'structure_only_pending_extraction',
            'source_pages': {
              'printed_pages': m['printed_pages'] ?? const [],
              'pdf_pages': m['pdf_pages'] ?? const [],
            },
          });
        })
        .toList();

    final blocks = ((json['curriculum_blocks'] as List?) ?? const [])
        .map((b) => CurriculumBlock.fromMap(Map<String, dynamic>.from(b)))
        .toList();

    final tutorialLinks = ((json['tutorial_mapping'] as List?) ?? const [])
        .map((t) => TutorialCurriculumLink.fromMap(Map<String, dynamic>.from(t)))
        .toList();

    final glossary = ((json['glossary_crosswalk'] as List?) ?? const [])
        .map((g) => GlossaryCrosswalkEntry.fromMap(Map<String, dynamic>.from(g)))
        .toList();

    return InMemoryCurriculumDataSource._(
      movements: movements,
      cordas: [...adultCordas, ...infantilCordas],
      blocks: blocks,
      tutorialLinks: tutorialLinks,
      glossary: glossary,
    );
  }

  factory InMemoryCurriculumDataSource.fromJsonString(String rawJson) {
    return InMemoryCurriculumDataSource.fromCatalogJson(
      json.decode(rawJson) as Map<String, dynamic>,
    );
  }

  static Future<InMemoryCurriculumDataSource> fromFlutterAsset({
    String assetPath = 'data/curriculum/fiu_adulto_v1.json',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    return InMemoryCurriculumDataSource.fromJsonString(raw);
  }

  @override
  Future<List<CurriculumMovement>> loadMovements() async => _movements;

  @override
  Future<List<CurriculumCorda>> loadCordas() async => _cordas;

  @override
  Future<List<CurriculumBlock>> loadBlocks() async => _blocks;

  @override
  Future<List<TutorialCurriculumLink>> loadTutorialLinks() async =>
      _tutorialLinks;

  @override
  Future<List<GlossaryCrosswalkEntry>> loadGlossaryCrosswalk() async =>
      _glossary;
}

/// Fuente de datos conectada a las colecciones `curriculum_*` en Firestore.
class FirestoreCurriculumDataSource implements CurriculumDataSource {
  final FirebaseFirestore _firestore;

  FirestoreCurriculumDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<CurriculumMovement>> loadMovements() async {
    final snap = await _firestore.collection('curriculum_movements').get();
    return snap.docs
        .map((doc) => CurriculumMovement.fromMap({
              ...doc.data(),
              'movement_id': doc.data()['movement_id'] ?? doc.id,
            }))
        .toList();
  }

  @override
  Future<List<CurriculumCorda>> loadCordas() async {
    final snap = await _firestore
        .collection('curriculum_cordas')
        .orderBy('index')
        .get();
    return snap.docs
        .map((doc) => CurriculumCorda.fromMap({
              ...doc.data(),
              'corda_id': doc.data()['corda_id'] ?? doc.id,
            }))
        .toList();
  }

  @override
  Future<List<CurriculumBlock>> loadBlocks() async {
    final snap = await _firestore.collection('curriculum_blocks').get();
    return snap.docs
        .map((doc) => CurriculumBlock.fromMap({
              ...doc.data(),
              'block_id': doc.data()['block_id'] ?? doc.id,
            }))
        .toList();
  }

  @override
  Future<List<TutorialCurriculumLink>> loadTutorialLinks() async {
    final snap =
        await _firestore.collection('curriculum_tutorial_links').get();
    return snap.docs
        .map((doc) => TutorialCurriculumLink.fromMap({
              ...doc.data(),
              'tutorial_doc_id': doc.data()['tutorial_doc_id'] ?? doc.id,
            }))
        .toList();
  }

  @override
  Future<List<GlossaryCrosswalkEntry>> loadGlossaryCrosswalk() async {
    final snap =
        await _firestore.collection('curriculum_glossary_links').get();
    return snap.docs
        .map((doc) => GlossaryCrosswalkEntry.fromMap(doc.data()))
        .toList();
  }
}

/// Repositorio reutilizable para Biblioteca y futuro Planificador IA FIU.
class CurriculumRepository {
  final CurriculumDataSource _dataSource;

  List<CurriculumMovement>? _movementsCache;
  List<CurriculumCorda>? _cordasCache;
  List<CurriculumBlock>? _blocksCache;
  List<TutorialCurriculumLink>? _tutorialsCache;
  List<GlossaryCrosswalkEntry>? _glossaryCache;

  CurriculumRepository({CurriculumDataSource? dataSource})
      : _dataSource = dataSource ?? FirestoreCurriculumDataSource();

  void invalidateCache() {
    _movementsCache = null;
    _cordasCache = null;
    _blocksCache = null;
    _tutorialsCache = null;
    _glossaryCache = null;
  }

  Future<List<CurriculumMovement>> _movements() async =>
      _movementsCache ??= await _dataSource.loadMovements();

  Future<List<CurriculumCorda>> _cordas() async =>
      _cordasCache ??= await _dataSource.loadCordas();

  Future<List<CurriculumBlock>> _blocks() async =>
      _blocksCache ??= await _dataSource.loadBlocks();

  Future<List<TutorialCurriculumLink>> _tutorials() async =>
      _tutorialsCache ??= await _dataSource.loadTutorialLinks();

  Future<List<GlossaryCrosswalkEntry>> _glossary() async =>
      _glossaryCache ??= await _dataSource.loadGlossaryCrosswalk();

  /// Lista las cordas de un único sistema (Adulto o Infantil), ordenadas por `index`.
  Future<List<CurriculumCorda>> getCordasByTrack(CurriculumTrack track) async {
    final all = await _cordas();
    final filtered = all.where((c) => c.track == track).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return filtered;
  }

  Future<CurriculumCorda?> getCordaById(String cordaId) async {
    final all = await _cordas();
    for (final c in all) {
      if (c.cordaId == cordaId) return c;
    }
    return null;
  }

  Future<CurriculumCorda?> getCordaByTrackAndIndex(
      CurriculumTrack track, int index) async {
    final trackCordas = await getCordasByTrack(track);
    for (final c in trackCordas) {
      if (c.index == index) return c;
    }
    return null;
  }

  Future<CurriculumBlock?> getBlockById(String blockId) async {
    final all = await _blocks();
    for (final b in all) {
      if (b.blockId == blockId) return b;
    }
    return null;
  }

  Future<CurriculumMovement?> getMovementById(String movementId) async {
    final all = await _movements();
    for (final m in all) {
      if (m.movementId == movementId) return m;
    }
    return null;
  }

  /// Extrae todos los movement_ids directos de una corda, resolviendo su bloque compartido si existe.
  Future<Set<String>> _directMovementIdsForCorda(CurriculumCorda corda) async {
    final ids = <String>{};
    if (corda.usesSharedBlock) {
      final block = await getBlockById(corda.sharedBlockId!);
      if (block != null) {
        ids.addAll(block.allMovementIds);
      }
      return ids;
    }
    for (final mod in corda.modules) {
      ids.addAll(mod.allMovementIds);
    }
    for (final list in corda.sections.values) {
      for (final item in list) {
        ids.add(item.movementId);
      }
    }
    return ids;
  }

  /// Resuelve la vista completa de una corda (incluyendo `sharedBlock` en Cordas 5 y 6).
  Future<CordaCurriculumView?> getResolvedCordaView(String cordaId) async {
    final corda = await getCordaById(cordaId);
    if (corda == null) return null;

    final sharedBlock = corda.usesSharedBlock
        ? await getBlockById(corda.sharedBlockId!)
        : null;
    final directIds = await _directMovementIdsForCorda(corda);
    final allMovements = await _movements();
    final movById = {for (final m in allMovements) m.movementId: m};

    final directMovements = <CurriculumMovement>[];
    for (final id in directIds) {
      final mov = movById[id];
      if (mov != null) directMovements.add(mov);
    }

    final tutorials = await getTutorialsForCorda(cordaId);

    return CordaCurriculumView(
      corda: corda,
      sharedBlock: sharedBlock,
      directMovements: directMovements,
      linkedTutorials: tutorials,
    );
  }

  /// Consulta movimientos por sistema, categoría, corda, elegibilidad IA o texto.
  Future<List<CurriculumMovement>> queryMovements({
    CurriculumTrack? track,
    TechnicalCategory? category,
    String? cordaId,
    bool aiPlannerEligibleOnly = false,
    bool includeCombinations = true,
    String? searchQuery,
  }) async {
    final all = await _movements();

    Set<String>? cordaMovementIds;
    if (cordaId != null && cordaId.isNotEmpty) {
      final corda = await getCordaById(cordaId);
      if (corda == null) return const [];
      if (track != null && corda.track != track) return const [];
      cordaMovementIds = await _directMovementIdsForCorda(corda);
    }

    final normalizedQuery = (searchQuery ?? '').trim().toLowerCase();

    return all.where((mov) {
      if (track != null && !mov.tracksSupported.contains(track)) return false;
      if (category != null && mov.category != category) return false;
      if (aiPlannerEligibleOnly && !mov.isSelectableForAiPlanner) return false;
      if (!includeCombinations && mov.isCombination) return false;
      if (cordaMovementIds != null &&
          !cordaMovementIds.contains(mov.movementId)) {
        return false;
      }
      if (normalizedQuery.isNotEmpty) {
        final inCanonical =
            mov.canonicalName.toLowerCase().contains(normalizedQuery);
        final inAliases = mov.aliases
            .any((a) => a.toLowerCase().contains(normalizedQuery));
        final inId = mov.movementId.toLowerCase().contains(normalizedQuery);
        if (!inCanonical && !inAliases && !inId) return false;
      }
      return true;
    }).toList();
  }

  /// Consulta acumulativa hasta `upToCordaIndex` dentro de un único sistema (`adulto` o `infantil`).
  Future<AccumulatedRepertoire> getAccumulatedRepertoire({
    required CurriculumTrack track,
    required int upToCordaIndex,
    bool aiPlannerEligibleOnly = false,
  }) async {
    final trackCordas = await getCordasByTrack(track);
    final includedCordas = trackCordas
        .where((c) => c.index >= 1 && c.index <= upToCordaIndex)
        .toList();

    final seenIds = <String>{};
    for (final corda in includedCordas) {
      seenIds.addAll(await _directMovementIdsForCorda(corda));
    }

    final allMovements = await _movements();
    final movById = {for (final m in allMovements) m.movementId: m};

    final allIncludedMovements = <CurriculumMovement>[];
    for (final id in seenIds) {
      final mov = movById[id];
      if (mov != null && mov.tracksSupported.contains(track)) {
        allIncludedMovements.add(mov);
      }
    }

    final aiEligible = allIncludedMovements
        .where((m) => m.isSelectableForAiPlanner)
        .toList();
    final excludedAmbiguous = allIncludedMovements
        .where((m) => !m.isSelectableForAiPlanner)
        .toList();

    final exposedMovements =
        aiPlannerEligibleOnly ? aiEligible : allIncludedMovements;

    final byCategory = <TechnicalCategory, List<CurriculumMovement>>{
      for (final cat in TechnicalCategory.values) cat: [],
    };
    for (final mov in exposedMovements) {
      byCategory[mov.category]!.add(mov);
    }

    final combinations =
        exposedMovements.where((m) => m.isCombination).toList();

    final includedCordaIds = includedCordas.map((c) => c.cordaId).toSet();
    final allTutorials = await _tutorials();
    final linkedTutorials = allTutorials
        .where((t) =>
            t.curriculumCordaIds.any((cid) => includedCordaIds.contains(cid)))
        .toList();

    return AccumulatedRepertoire(
      track: track,
      upToCordaIndex: upToCordaIndex,
      includedCordas: includedCordas,
      uniqueMovements: exposedMovements,
      movementsByCategory: byCategory,
      combinations: combinations,
      aiEligibleMovements: aiEligible,
      excludedAmbiguousMovements: excludedAmbiguous,
      linkedTutorials: linkedTutorials,
    );
  }

  /// Obtiene todos los tutoriales vinculados a un movimiento mediante `movementIds`.
  Future<List<TutorialCurriculumLink>> getTutorialsForMovement(
    String movementId, {
    bool includePending = false,
  }) async {
    final all = await _tutorials();
    return all.where((t) {
      if (t.movementIds.contains(movementId)) return true;
      if (includePending && t.pendingMovementIds.contains(movementId)) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Obtiene tutoriales vinculados curricularmente a una corda (o acumulativamente hasta ella).
  Future<List<TutorialCurriculumLink>> getTutorialsForCorda(
    String cordaId, {
    bool cumulative = false,
  }) async {
    final all = await _tutorials();
    if (!cumulative) {
      return all
          .where((t) => t.curriculumCordaIds.contains(cordaId))
          .toList();
    }
    final corda = await getCordaById(cordaId);
    if (corda == null) return const [];
    final trackCordas = await getCordasByTrack(corda.track);
    final allowedCordaIds = trackCordas
        .where((c) => c.index <= corda.index)
        .map((c) => c.cordaId)
        .toSet();
    return all
        .where(
            (t) => t.curriculumCordaIds.any((cid) => allowedCordaIds.contains(cid)))
        .toList();
  }

  /// Obtiene entradas del glosario asociadas a un movimiento (directas o variantes genéricas).
  Future<List<GlossaryCrosswalkEntry>> getGlossaryEntriesForMovement(
      String movementId) async {
    final all = await _glossary();
    return all.where((g) => g.matchesMovement(movementId)).toList();
  }

  /// Contrato estructurado y seguro para el futuro Planificador IA (`generarPlanClaseIA`).
  /// Excluye automáticamente entradas ambiguas o pendientes de revisión técnica.
  Future<Map<String, dynamic>> buildAiPlannerCurriculumPayload({
    required CurriculumTrack track,
    required int upToCordaIndex,
  }) async {
    final repertoire = await getAccumulatedRepertoire(
      track: track,
      upToCordaIndex: upToCordaIndex,
      aiPlannerEligibleOnly: true,
    );
    final targetCorda = await getCordaByTrackAndIndex(track, upToCordaIndex);
    final sharedBlock = (targetCorda != null && targetCorda.usesSharedBlock)
        ? await getBlockById(targetCorda.sharedBlockId!)
        : null;

    return {
      'contract_version': '1.0.0',
      'track_id': track.id,
      'target_corda_id': targetCorda?.cordaId,
      'target_corda_index': upToCordaIndex,
      'shared_block_id': sharedBlock?.blockId,
      'eligible_movements_count': repertoire.aiEligibleMovements.length,
      'excluded_ambiguous_ids': repertoire.excludedAmbiguousMovements
          .map((m) => m.movementId)
          .toList(),
      'movements_by_category': {
        for (final entry in repertoire.movementsByCategory.entries)
          entry.key.id: entry.value
              .map((m) => {
                    'movement_id': m.movementId,
                    'canonical_name': m.canonicalName,
                    'entry_kind': m.entryKind.id,
                    if (m.componentMovementIds.isNotEmpty)
                      'component_movement_ids': m.componentMovementIds,
                  })
              .toList(),
      },
      if (targetCorda?.sequencias.isNotEmpty ?? false)
        'target_sequences':
            targetCorda!.sequencias.map((s) => s.toMap()).toList(),
      if (sharedBlock?.cronogramaSemanal != null ||
          targetCorda?.cronogramaSemanal != null)
        'target_weekly_schedule':
            (sharedBlock?.cronogramaSemanal ?? targetCorda?.cronogramaSemanal)
                ?.toMap(),
      if (targetCorda?.musicalidade != null)
        'target_musicality': targetCorda!.musicalidade!.toMap(),
      if (targetCorda?.avaliacao != null)
        'target_evaluation': targetCorda!.avaliacao!.toMap(),
    };
  }
}

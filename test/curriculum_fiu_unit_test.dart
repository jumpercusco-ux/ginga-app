import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/models/curriculum_models.dart';
import 'package:ginga_app/core/services/curriculum_repository.dart';
import 'package:ginga_app/core/services/tutoriales_service.dart';

void main() {
  late Map<String, dynamic> catalogJson;
  late InMemoryCurriculumDataSource dataSource;
  late CurriculumRepository repository;

  setUpAll(() {
    final file = File('data/curriculum/fiu_adulto_v1.json');
    expect(file.existsSync(), isTrue, reason: 'Debe existir data/curriculum/fiu_adulto_v1.json');
    catalogJson = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    dataSource = InMemoryCurriculumDataSource.fromCatalogJson(catalogJson);
    repository = CurriculumRepository(dataSource: dataSource);
  });

  group('Integridad del catálogo FIU consolidado', () {
    test('97 movimientos únicos sin duplicados, 5 categorías y páginas válidas', () async {
      final movements = await dataSource.loadMovements();
      expect(movements.length, 97);

      final ids = movements.map((m) => m.movementId).toSet();
      expect(ids.length, 97, reason: 'Todos los movement_id deben ser únicos');

      expect(TechnicalCategory.values.length, 5);

      for (final mov in movements) {
        expect(mov.appearsInAdultoCordas, isNotEmpty);
        for (final app in mov.appearsInAdultoCordas) {
          if (app.pageRef.printedPage >= 2) {
            expect(app.pageRef.pdfPage, app.pageRef.printedPage + 1);
          }
        }
      }
    });

    test('REV-01: Negativa consolidado como movimiento único preservando sus 2 apariciones originales', () async {
      final negativa = await repository.getMovementById('negativa');
      expect(negativa, isNotNull);

      final mod2SaidasApps = negativa!.appearsInAdultoCordas
          .where((a) =>
              a.cordaId == 'adulto_corda_01' &&
              a.moduleOrSection.contains('B. SAIDAS'))
          .toList();
      expect(mod2SaidasApps.length, 2);
      expect(mod2SaidasApps.any((a) => a.duplicateOfSlot == 3), isTrue);
    });

    test('REV-02 y REV-10: Ambiguos pendientes excluidos de IA y sin equivalencias no confirmadas', () async {
      const expectedAmbiguous = ['desequilibrante', 'espelho_cruz', 'au_chibata_pulado'];

      for (final id in expectedAmbiguous) {
        final mov = await repository.getMovementById(id);
        expect(mov, isNotNull);
        expect(mov!.reviewStatus, CurriculumReviewStatus.pendingTechnicalReview);
        expect(mov.isAmbiguous, isTrue);
        expect(mov.aiPlannerEligible, isFalse);
        expect(mov.isSelectableForAiPlanner, isFalse);
      }

      final flick = await repository.getMovementById('flick');
      expect(flick, isNotNull);
      expect(flick!.aliases.any((a) => a.toLowerCase() == 'flip'), isFalse);
      expect(flick.unconfirmedEquivalences.any((e) => e.term == 'Flip' && e.status == 'unconfirmed'), isTrue);

      final espelhoCruz = await repository.getMovementById('espelho_cruz');
      expect(espelhoCruz, isNotNull);
      expect(espelhoCruz!.aliases.any((a) => a == 'Espelho' || a == 'Cruz'), isFalse);
      expect(espelhoCruz.unconfirmedEquivalences.length, 2);
    });

    test('Diferenciación entre movimiento_base, movimiento y combinacao_solo', () async {
      final ginga = await repository.getMovementById('ginga');
      final combo = await repository.getMovementById('au_com_negativa_e_rolamento_na_ginga');
      final bencao = await repository.getMovementById('bencao');

      expect(ginga!.entryKind, MovementEntryKind.movimientoBase);
      expect(bencao!.entryKind, MovementEntryKind.movimiento);
      expect(combo!.entryKind, MovementEntryKind.combinacaoSolo);
      expect(combo.isCombination, isTrue);
      expect(combo.componentMovementIds, ['au', 'negativa', 'rolamento_na_ginga']);
    });
  });

  group('Separación Adulto/Infantil, bloque compartido 5-6 y consultas acumuladas', () {
    test('Separación estricta de currículos adulto (6 extraídas) e infantil (12 estructurales)', () async {
      final adulto = await repository.getCordasByTrack(CurriculumTrack.adulto);
      final infantil = await repository.getCordasByTrack(CurriculumTrack.infantil);

      expect(adulto.length, 6);
      expect(infantil.length, 12);
      expect(adulto.every((c) => c.cordaId.startsWith('adulto_corda_')), isTrue);
      expect(infantil.every((c) => c.cordaId.startsWith('infantil_corda_')), isTrue);
      expect(infantil.first.contentStatus, 'structure_only_pending_extraction');

      final infRepertoire = await repository.getAccumulatedRepertoire(
        track: CurriculumTrack.infantil,
        upToCordaIndex: 3,
      );
      expect(infRepertoire.includedCordas.length, 3);
      expect(infRepertoire.uniqueMovements, isEmpty);
    });

    test('Bloque compartido adulto_bloque_05_06 resuelto para Cordas 5 y 6 con evaluaciones distintas', () async {
      final view5 = await repository.getResolvedCordaView('adulto_corda_05');
      final view6 = await repository.getResolvedCordaView('adulto_corda_06');

      expect(view5, isNotNull);
      expect(view6, isNotNull);
      expect(view5!.sharedBlock?.blockId, 'adulto_bloque_05_06');
      expect(view6!.sharedBlock?.blockId, 'adulto_bloque_05_06');
      expect(view5.directMovements.length, 30);
      expect(view6.directMovements.length, 30);

      // Diferenciación física/musical preservada
      expect(view5.corda.avaliacao!.fisico['parada_de_mao_voltas_na_roda'], 2);
      expect(view6.corda.avaliacao!.fisico['parada_de_mao_voltas_na_roda'], 3);
      expect(view6.corda.avaliacao!.fisico['flexoes_tipo'], 'mãos fechadas');
      expect(view5.corda.musicalidade!.especificoCorda, contains('envergar'));
      expect(view6.corda.musicalidade!.especificoCorda, contains('afinar'));
    });

    test('Consulta acumulativa de Cordas 1 a 6 sin pérdida ni mezcla', () async {
      final r1 = await repository.getAccumulatedRepertoire(track: CurriculumTrack.adulto, upToCordaIndex: 1);
      final r2 = await repository.getAccumulatedRepertoire(track: CurriculumTrack.adulto, upToCordaIndex: 2);
      final r3 = await repository.getAccumulatedRepertoire(track: CurriculumTrack.adulto, upToCordaIndex: 3);
      final r4 = await repository.getAccumulatedRepertoire(track: CurriculumTrack.adulto, upToCordaIndex: 4);
      final r5 = await repository.getAccumulatedRepertoire(track: CurriculumTrack.adulto, upToCordaIndex: 5);
      final r6 = await repository.getAccumulatedRepertoire(track: CurriculumTrack.adulto, upToCordaIndex: 6);

      expect(r1.uniqueMovements.length, 19);
      expect(r2.uniqueMovements.length, 31);
      expect(r3.uniqueMovements.length, 48);
      expect(r4.uniqueMovements.length, 72);
      expect(r5.uniqueMovements.length, 97);
      expect(r6.uniqueMovements.length, 97);

      expect(r6.aiEligibleMovements.length, 94);
      expect(r6.excludedAmbiguousMovements.length, 3);
    });

    test('Filtro por categoría técnica funciona en consulta directa', () async {
      final desequilibrantes = await repository.queryMovements(
        track: CurriculumTrack.adulto,
        category: TechnicalCategory.golpeDesequilibrante,
        aiPlannerEligibleOnly: true,
      );
      // 19 totales menos 2 ambiguos (desequilibrante, espelho_cruz) = 17
      expect(desequilibrantes.length, 17);
    });
  });

  group('Relaciones múltiples, compatibilidad legacy y contrato IA', () {
    test('Los 21 tutoriales y 5 videos reales preservan compatibilidad y relaciones múltiples', () async {
      final allLinks = await dataSource.loadTutorialLinks();
      expect(allLinks.length, 21);
      expect(allLinks.where((t) => t.hasRealVideo).length, 5);
      expect(allLinks.every((t) => t.preserveLegacyPermissions), isTrue);

      // REV-04: Cocorinha + base asociado a cocorinha, pendiente ginga
      final cocorinhaTuts = await repository.getTutorialsForMovement('cocorinha');
      expect(cocorinhaTuts.any((t) => t.tutorialDocId == 'WH4bG3SQ3CSd8ozb1619'), isTrue);

      final gingaConfirmedTuts = await repository.getTutorialsForMovement('ginga');
      expect(gingaConfirmedTuts.map((t) => t.tutorialDocId), ['zU1Yy0dvgbZsw0eVTZHL']);

      final gingaWithPendingTuts = await repository.getTutorialsForMovement('ginga', includePending: true);
      expect(gingaWithPendingTuts.length, 2);

      // REV-05: Ginga, Passape y Martelo en Corda Crua preservando legacy_corda_prod = ''
      final corda1Tuts = await repository.getTutorialsForCorda('adulto_corda_01');
      final corda1Ids = corda1Tuts.map((t) => t.tutorialDocId).toSet();
      expect(corda1Ids.containsAll(['zU1Yy0dvgbZsw0eVTZHL', '9rPLVAirz74XNwLRcKsc', 'IoTCEDVpKXD1kYKnbPly', 'WH4bG3SQ3CSd8ozb1619', 'YCl6qjc3PEN2qARrMop6']), isTrue);
      for (final id in ['zU1Yy0dvgbZsw0eVTZHL', '9rPLVAirz74XNwLRcKsc', 'IoTCEDVpKXD1kYKnbPly']) {
        final link = corda1Tuts.firstWhere((t) => t.tutorialDocId == id);
        expect(link.legacyCordaProd, '');
      }
    });

    test('REV-08: Términos genéricos del glosario conservan relación con sus variantes', () async {
      final chapeuEntries = await repository.getGlossaryEntriesForMovement('chapeu_de_couro_em_pe');
      expect(chapeuEntries.length, 1);
      expect(chapeuEntries.first.terminoGlosario, 'Chapéu de couro');
      expect(chapeuEntries.first.isGenericTerm, isTrue);
      expect(chapeuEntries.first.relatedVariantMovementIds, ['chapeu_de_couro_em_pe', 'chapeu_de_couro_no_chao']);

      final rasteiraEntries = await repository.getGlossaryEntriesForMovement('rasteira_paulista');
      expect(rasteiraEntries.length, 1);
      expect(rasteiraEntries.first.terminoGlosario, 'Rasteira');
      expect(rasteiraEntries.first.relatedVariantMovementIds.length, 5);
    });

    test('Contrato para Planificador IA excluye entradas ambiguas y expone repertorio limpio', () async {
      final payload = await repository.buildAiPlannerCurriculumPayload(
        track: CurriculumTrack.adulto,
        upToCordaIndex: 6,
      );

      expect(payload['track_id'], 'adulto');
      expect(payload['shared_block_id'], 'adulto_bloque_05_06');
      expect(payload['eligible_movements_count'], 94);
      expect(
        payload['excluded_ambiguous_ids'],
        containsAll(['desequilibrante', 'espelho_cruz', 'au_chibata_pulado']),
      );

      final byCategory = payload['movements_by_category'] as Map<String, dynamic>;
      final allExposedIds = byCategory.values
          .expand((list) => (list as List).map((m) => (m as Map)['movement_id']))
          .toSet();
      expect(allExposedIds.length, 94);
      expect(allExposedIds.contains('desequilibrante'), isFalse);
      expect(allExposedIds.contains('espelho_cruz'), isFalse);
      expect(allExposedIds.contains('au_chibata_pulado'), isFalse);
    });

    test('REV-07: Deprecación segura de TutorialesService.legacyMockSeedEnabled = false', () {
      expect(TutorialesService.legacyMockSeedEnabled, isFalse);
    });
  });
}

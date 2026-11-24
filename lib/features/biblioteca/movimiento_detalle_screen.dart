import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/cuerdas_fiu.dart';
import '../../core/models/curriculum_models.dart';
import '../../core/services/curriculum_repository.dart';
import '../../core/theme/ginga_theme.dart';
import 'glosario_screen.dart';
import 'graduaciones_screen.dart';
import 'tutor_detail_screen.dart';
import 'widgets/biblioteca_user_context.dart';

/// Pantalla independiente para consultar la ficha técnica de un movimiento en móvil/tablet.
class MovimientoDetalleScreen extends StatelessWidget {
  final CurriculumMovement movement;
  final CurriculumRepository repository;
  final BibliotecaUserContext userContext;
  final ValueChanged<CurriculumMovement>? onSelectMovement;
  final VoidCallback? onOpenPizarra;
  final bool selectionEnabled;
  final bool isSelectedForPlanner;
  final VoidCallback? onTogglePlannerSelection;

  const MovimientoDetalleScreen({
    super.key,
    required this.movement,
    required this.repository,
    required this.userContext,
    this.onSelectMovement,
    this.onOpenPizarra,
    this.selectionEnabled = false,
    this.isSelectedForPlanner = false,
    this.onTogglePlannerSelection,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? GingaColors.backgroundDark : const Color(0xFFFFFFFF);
    final textColor = isDark ? GingaColors.textWhite : const Color(0xFF111814);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          movement.canonicalName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: MovimientoDetallePanel(
                    movement: movement,
                    repository: repository,
                    userContext: userContext,
                    onSelectMovement: (nextMov) {
                      if (onSelectMovement != null) {
                        onSelectMovement!(nextMov);
                        return;
                      }
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => MovimientoDetalleScreen(
                            movement: nextMov,
                            repository: repository,
                            userContext: userContext,
                            onOpenPizarra: onOpenPizarra,
                            selectionEnabled: selectionEnabled,
                            isSelectedForPlanner: isSelectedForPlanner,
                            onTogglePlannerSelection: onTogglePlannerSelection,
                          ),
                        ),
                      );
                    },
                    onOpenPizarra: onOpenPizarra,
                    selectionEnabled: selectionEnabled,
                    isSelectedForPlanner: isSelectedForPlanner,
                    onTogglePlannerSelection: onTogglePlannerSelection,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MovimientoDetailData {
  final List<CurriculumCorda> allAdultCordas;
  final List<TutorialCurriculumLink> tutorials;
  final List<GlossaryCrosswalkEntry> glossaryLinks;
  final List<_MatchedSequence> sequences;

  const _MovimientoDetailData({
    required this.allAdultCordas,
    required this.tutorials,
    required this.glossaryLinks,
    required this.sequences,
  });
}

class _MatchedSequence {
  final CurriculumCorda corda;
  final CurriculumSequence sequence;

  const _MatchedSequence({
    required this.corda,
    required this.sequence,
  });
}

/// Panel reutilizable con toda la ficha curricular de un movimiento FIU.
/// Embebible en el panel derecho de escritorio o dentro de `MovimientoDetalleScreen`.
class MovimientoDetallePanel extends StatefulWidget {
  final CurriculumMovement movement;
  final CurriculumRepository repository;
  final BibliotecaUserContext userContext;
  final ValueChanged<CurriculumMovement>? onSelectMovement;
  final VoidCallback? onOpenPizarra;
  final bool selectionEnabled;
  final bool isSelectedForPlanner;
  final VoidCallback? onTogglePlannerSelection;

  const MovimientoDetallePanel({
    super.key,
    required this.movement,
    required this.repository,
    required this.userContext,
    this.onSelectMovement,
    this.onOpenPizarra,
    this.selectionEnabled = false,
    this.isSelectedForPlanner = false,
    this.onTogglePlannerSelection,
  });

  static String _normalizeAliasForDisplay(String raw) {
    return raw
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Filtra alias visualmente idénticos al nombre canónico o duplicados entre sí sin alterar el catálogo.
  static List<String> visibleAliasesForDisplay(CurriculumMovement movement) {
    final canonicalNorm = _normalizeAliasForDisplay(movement.canonicalName);
    final seen = <String>{canonicalNorm};
    final visible = <String>[];
    for (final alias in movement.aliases) {
      final trimmed = alias.trim();
      if (trimmed.isEmpty) continue;
      final norm = _normalizeAliasForDisplay(trimmed);
      if (seen.add(norm)) {
        visible.add(trimmed);
      }
    }
    return visible;
  }

  @override
  State<MovimientoDetallePanel> createState() => _MovimientoDetallePanelState();
}

class _MovimientoDetallePanelState extends State<MovimientoDetallePanel> {
  late Future<_MovimientoDetailData> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetails();
  }

  @override
  void didUpdateWidget(covariant MovimientoDetallePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movement.movementId != widget.movement.movementId) {
      _detailFuture = _loadDetails();
    }
  }

  Future<_MovimientoDetailData> _loadDetails() async {
    final cordas = await widget.repository.getCordasByTrack(CurriculumTrack.adulto);
    final tutorials = await widget.repository.getTutorialsForMovement(
      widget.movement.movementId,
      includePending: true,
    );
    final glossaryLinks = await widget.repository
        .getGlossaryEntriesForMovement(widget.movement.movementId);

    final matchedSequences = <_MatchedSequence>[];
    for (final corda in cordas) {
      for (final seq in corda.sequencias) {
        if (seq.movementIds.contains(widget.movement.movementId)) {
          matchedSequences.add(_MatchedSequence(corda: corda, sequence: seq));
        }
      }
    }

    return _MovimientoDetailData(
      allAdultCordas: cordas,
      tutorials: tutorials,
      glossaryLinks: glossaryLinks,
      sequences: matchedSequences,
    );
  }

  Color _categoryColor(TechnicalCategory category, {required bool isDark}) {
    switch (category) {
      case TechnicalCategory.fundamento:
        return isDark ? Colors.teal.shade300 : const Color(0xFF00897B);
      case TechnicalCategory.golpeDeAtaque:
        return isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
      case TechnicalCategory.saidaEsquiva:
        return isDark ? Colors.purple.shade200 : Colors.deepPurple;
      case TechnicalCategory.movimentoDeSolo:
        return isDark ? Colors.deepOrange.shade300 : Colors.deepOrange;
      case TechnicalCategory.golpeDesequilibrante:
        return isDark ? Colors.lightBlue.shade300 : Colors.blue.shade700;
    }
  }

  String _entryKindLabel(MovementEntryKind kind) {
    switch (kind) {
      case MovementEntryKind.movimientoBase:
        return 'Fundamento base';
      case MovementEntryKind.movimiento:
        return 'Movimiento individual';
      case MovementEntryKind.combinacaoSolo:
        return 'Combinación de solo';
    }
  }

  CordaFIU _resolveCordaFIU(
    String cordaId,
    List<CurriculumCorda> cordas,
  ) {
    for (final c in cordas) {
      if (c.cordaId == cordaId) {
        return CuerdasFIU.encontrarCordaFIU(c.nombreApp) ??
            CuerdasFIU.lista[(c.index - 1).clamp(0, CuerdasFIU.lista.length - 1)];
      }
    }
    return CuerdasFIU.lista.first;
  }

  void _showLockedTutorialDialog(
    BuildContext context,
    String titulo,
    String legacyCordaProd,
  ) {
    final cordaReq =
        CuerdasFIU.encontrarCordaFIU(legacyCordaProd) ?? CuerdasFIU.lista.first;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? GingaColors.surfaceDark : Colors.white;
        final textColor =
            isDark ? GingaColors.textWhite : const Color(0xFF111814);
        final subColor =
            isDark ? GingaColors.textMuted : const Color(0xFF5F6368);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: Colors.orange, size: 36),
              const SizedBox(height: 12),
              Text(
                'Tutorial sujeto a graduación',
                style: GoogleFonts.montserrat(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El tutorial "$titulo" conserva el permiso actual para Cuerda ${cordaReq.nombre} o superior. Puedes seguir consultando su ficha curricular aquí.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: subColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              CordaRibbonBar(corda: cordaReq, width: 180, height: 10),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GraduacionesScreen(),
                          ),
                        );
                      },
                      child: const Text('Ver Graduaciones'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Entendido'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTutorial(BuildContext context, TutorialCurriculumLink link) {
    final locked = widget.userContext.isTutorialLocked(link.legacyCordaProd);
    if (locked) {
      _showLockedTutorialDialog(context, link.tituloProd, link.legacyCordaProd);
      return;
    }

    if (Firebase.apps.isEmpty) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        link.hasRealVideo
                            ? Icons.play_circle_filled_rounded
                            : Icons.menu_book_rounded,
                        color: link.hasRealVideo
                            ? GingaColors.brandGreen
                            : GingaColors.accentAmber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          link.tituloProd,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(link.categoriaProd),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          link.hasRealVideo
                              ? 'Video real grabado${link.duracaoProd != null ? ' · ${link.duracaoProd}' : ''}'
                              : 'Sin video grabado aún',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          link.legacyCordaProd.isEmpty
                              ? 'Acceso libre'
                              : 'Corda requerida: ${link.legacyCordaProd}',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (link.curriculumCordaIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Cordas curriculares: ${link.curriculumCordaIds.join(', ')}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if ((link.reviewNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      link.reviewNote!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Vista previa local aislada sin sesión Firebase ni reproducción remota. '
                    'En la app conectada, esta acción abre TutorialDetailLoader (${link.tutorialDocId}).',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TutorialDetailLoader(tutorialId: link.tutorialDocId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);
    final textColor = isDark ? GingaColors.textWhite : const Color(0xFF111814);
    final subtitleColor =
        isDark ? GingaColors.textMuted : const Color(0xFF5F6368);
    final mov = widget.movement;
    final catColor = _categoryColor(mov.category, isDark: isDark);
    final visibleAliases =
        MovimientoDetallePanel.visibleAliasesForDisplay(mov);

    return FutureBuilder<_MovimientoDetailData>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            ),
          );
        }

        final details = snapshot.data!;
        final firstCorda = _resolveCordaFIU(
          mov.firstIntroducedAdulto,
          details.allAdultCordas,
        );

        // Resolver entradas de glosario (directas y genéricas) sin inventar texto.
        final glossaryItems = <({GlosarioTermino term, bool isGeneric})>[];
        for (final g in details.glossaryLinks) {
          final found = GlosarioScreen.buscarPorTermino(g.terminoGlosario);
          if (found != null) {
            glossaryItems.add((term: found, isGeneric: g.isGenericTerm));
          }
        }
        if (glossaryItems.isEmpty) {
          final direct = GlosarioScreen.buscarPorTermino(mov.canonicalName);
          if (direct != null) {
            glossaryItems.add((term: direct, isGeneric: false));
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado del movimiento
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _BadgePill(
                          label: mov.category.labelEs,
                          color: catColor,
                        ),
                        _BadgePill(
                          label: _entryKindLabel(mov.entryKind),
                          color: subtitleColor,
                        ),
                        if (mov.reviewStatus ==
                            CurriculumReviewStatus.pendingTechnicalReview)
                          const _BadgePill(
                            label: 'Pendiente revisión técnica',
                            color: Colors.orange,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mov.canonicalName,
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: CordaRibbonBar(corda: firstCorda, height: 8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Introducido en Corda ${firstCorda.nombre}',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.selectionEnabled) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (btnCtx) {
                          final canSelect = mov.isSelectableForAiPlanner;
                          return OutlinedButton.icon(
                            onPressed: canSelect
                                ? widget.onTogglePlannerSelection
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: widget.isSelectedForPlanner
                                  ? Colors.white
                                  : accentGreen,
                              backgroundColor: widget.isSelectedForPlanner
                                  ? GingaColors.brandGreen
                                  : Colors.transparent,
                              side: BorderSide(
                                color: canSelect
                                    ? (widget.isSelectedForPlanner
                                        ? GingaColors.brandGreen
                                        : accentGreen)
                                    : borderColor,
                                width: 1.4,
                              ),
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  GingaRadius.md,
                                ),
                              ),
                              textStyle: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: Icon(
                              widget.isSelectedForPlanner
                                  ? Icons.check_circle_rounded
                                  : (canSelect
                                      ? Icons.add_circle_outline_rounded
                                      : Icons.block_rounded),
                              size: 17,
                            ),
                            label: Text(
                              !canSelect
                                  ? 'No elegible para selección automática'
                                  : (widget.isSelectedForPlanner
                                      ? 'Seleccionado para planificador'
                                      : 'Seleccionar para planificador'),
                            ),
                          );
                        },
                      ),
                    ],
                    if (visibleAliases.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Alias confirmados: ${visibleAliases.join(' · ')}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Banner para entradas pendientes o ambiguas (REV-02 / REV-10)
              if (mov.reviewStatus ==
                      CurriculumReviewStatus.pendingTechnicalReview ||
                  mov.unconfirmedEquivalences.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.pending_actions_rounded,
                            color: isDark
                                ? Colors.orange.shade300
                                : Colors.orange.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mov.isAmbiguous
                                  ? 'Pendiente de revisión técnica'
                                  : 'Equivalencias sin confirmar',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.orange.shade300
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (mov.notes != null && mov.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          mov.notes!,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (!mov.isSelectableForAiPlanner) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Excluido de la selección automática del planificador IA hasta confirmación pedagógica.',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                      if (mov.unconfirmedEquivalences.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final eq in mov.unconfirmedEquivalences)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• "${eq.term}" (${eq.track}): no confirmada — ${eq.note}',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: textColor,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],

              // Componentes si es Combinación de solo
              if (mov.isCombination && mov.componentMovementIds.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SectionCardBlock(
                  title: 'Componentes de esta combinación',
                  icon: Icons.account_tree_outlined,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mov.componentMovementIds.map((compId) {
                      return FutureBuilder<CurriculumMovement?>(
                        future: widget.repository.getMovementById(compId),
                        builder: (context, snap) {
                          final comp = snap.data;
                          return ActionChip(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF3F6F4),
                            side: BorderSide(color: borderColor),
                            avatar: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: GingaColors.brandGreen,
                            ),
                            label: Text(
                              comp?.canonicalName ?? compId,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            onPressed: comp != null
                                ? () => widget.onSelectMovement?.call(comp)
                                : null,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Tutoriales multimedia vinculados (relaciones múltiples)
              const SizedBox(height: 14),
              _SectionCardBlock(
                title: 'Tutoriales y Videos Vinculados',
                icon: Icons.play_circle_outline_rounded,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                child: details.tutorials.isEmpty
                    ? Text(
                        'Pendiente de digitalización: aún no existe video o ficha multimedia vinculada para este movimiento.',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: subtitleColor,
                          height: 1.4,
                        ),
                      )
                    : Column(
                        children: details.tutorials.map((tut) {
                          final isPendingLink = tut.pendingMovementIds
                              .contains(mov.movementId);
                          final isLocked = widget.userContext
                              .isTutorialLocked(tut.legacyCordaProd);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFE8F5E9)
                                      .withValues(alpha: 0.45),
                              borderRadius:
                                  BorderRadius.circular(GingaRadius.md),
                              border: Border.all(
                                color: tut.hasRealVideo
                                    ? accentGreen.withValues(alpha: 0.45)
                                    : borderColor,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isLocked
                                    ? Colors.orange.withValues(alpha: 0.16)
                                    : (tut.hasRealVideo
                                        ? GingaColors.brandGreen
                                        : Colors.grey.shade500),
                                child: Icon(
                                  isLocked
                                      ? Icons.lock_outline_rounded
                                      : (tut.hasRealVideo
                                          ? Icons.play_arrow_rounded
                                          : Icons.description_outlined),
                                  color: isLocked
                                      ? (isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade800)
                                      : Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                tut.tituloProd,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              subtitle: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _BadgePill(
                                    label: tut.hasRealVideo
                                        ? 'Video real'
                                        : 'Sin video grabado aún',
                                    color: tut.hasRealVideo
                                        ? accentGreen
                                        : subtitleColor,
                                  ),
                                  if (tut.duracaoProd != null)
                                    Text(
                                      tut.duracaoProd!,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  if (isPendingLink)
                                    _BadgePill(
                                      label: 'Relación pendiente revisión video',
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade700,
                                    ),
                                  if (isLocked)
                                    _BadgePill(
                                      label:
                                          'Permiso actual: ${tut.legacyCordaProd}',
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade700,
                                    ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: subtitleColor,
                              ),
                              onTap: () => _openTutorial(context, tut),
                            ),
                          );
                        }).toList(),
                      ),
              ),

              // Definición del Glosario FIU (sin inventar)
              const SizedBox(height: 14),
              _SectionCardBlock(
                title: 'Referencia en Glosario FIU',
                icon: Icons.translate_rounded,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                child: glossaryItems.isEmpty
                    ? Text(
                        'Descripción técnica detallada pendiente de digitalización en el glosario oficial.',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: subtitleColor,
                          height: 1.4,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: glossaryItems.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      entry.term.termino,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      entry.term.pronunciacion,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: subtitleColor,
                                      ),
                                    ),
                                    if (entry.isGeneric)
                                      const _BadgePill(
                                        label: 'Término genérico de familia',
                                        color: Colors.amber,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  entry.term.significado,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.5,
                                    color: textColor,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: GingaColors.brandGreen
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(
                                        GingaRadius.sm),
                                  ),
                                  child: Text(
                                    'Tip del Mestre: ${entry.term.consejo}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11.5,
                                      color: subtitleColor,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),

              // Apariciones oficiales en el manual
              const SizedBox(height: 14),
              _SectionCardBlock(
                title: 'Presencia en Manual FIU (2020)',
                icon: Icons.menu_book_rounded,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                child: Column(
                  children: mov.appearsInAdultoCordas.map((app) {
                    final cordaFiu = _resolveCordaFIU(
                      app.cordaId,
                      details.allAdultCordas,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 34,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: CordaRibbonBar(corda: cordaFiu, height: 7),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Corda ${cordaFiu.nombre} · ${app.moduleOrSection}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Impreso como "${app.rawNameInManual}" (ítem #${app.listPosition}) · p. ${app.pageRef.printedPage} / PDF ${app.pageRef.pdfPage}'
                                  '${app.duplicateOfSlot != null ? ' · Duplicado literal de #${app.duplicateOfSlot} (REV-01)' : ''}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Secuencias oficiales
              if (details.sequences.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SectionCardBlock(
                  title: 'Secuencias oficiales',
                  icon: Icons.timeline_rounded,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: details.sequences.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '• ${item.corda.nombreManual} (p. ${item.sequence.pageRef.printedPage}/PDF ${item.sequence.pageRef.pdfPage}): ${item.sequence.raw}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Punto de preparación para Pizarra (solo profesores, sin alterar IA)
              if (widget.userContext.isTeacher) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenPizarra ??
                        () {
                          if (Firebase.apps.isNotEmpty) {
                            context.push('/instructor-pizarra');
                          }
                        },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentGreen,
                      side: BorderSide(color: accentGreen, width: 1.4),
                      minimumSize: const Size(double.infinity, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                      textStyle: GoogleFonts.montserrat(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Abrir Pizarra y Planificador'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionCardBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Widget child;

  const _SectionCardBlock({
    required this.title,
    required this.icon,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accentGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgePill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.6),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

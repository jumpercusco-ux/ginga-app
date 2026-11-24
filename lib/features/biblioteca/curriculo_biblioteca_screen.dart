import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/cuerdas_fiu.dart';
import '../../core/models/curriculum_models.dart';
import '../../core/services/curriculum_repository.dart';
import '../../core/theme/ginga_theme.dart';
import 'movimiento_detalle_screen.dart';
import 'widgets/biblioteca_user_context.dart';

/// Workspace curricular unificado de la Biblioteca FIU (Alumnos y Profesores).
/// Soporta diseño responsive para Móvil (<720px), Tablet (720-1099px) y Escritorio (>=1100px).
class CurriculoBibliotecaScreen extends StatefulWidget {
  final CurriculumRepository? repository;
  final BibliotecaUserContext? overrideUserContext;
  final CurriculumTrack initialTrack;
  final int? initialCordaIndex;
  final bool initialCumulativeMode;
  final bool initialOnlyWithRealVideo;
  final String? initialMovementId;
  final VoidCallback? onOpenManageTutorials;
  final VoidCallback? onOpenPizarra;
  final CurriculumSelectionContract? selectionContract;

  const CurriculoBibliotecaScreen({
    super.key,
    this.repository,
    this.overrideUserContext,
    this.initialTrack = CurriculumTrack.adulto,
    this.initialCordaIndex,
    this.initialCumulativeMode = false,
    this.initialOnlyWithRealVideo = false,
    this.initialMovementId,
    this.onOpenManageTutorials,
    this.onOpenPizarra,
    this.selectionContract,
  });

  @override
  State<CurriculoBibliotecaScreen> createState() =>
      _CurriculoBibliotecaScreenState();
}

class _CurriculoBibliotecaScreenState extends State<CurriculoBibliotecaScreen>
    with SingleTickerProviderStateMixin {
  CurriculumRepository? _repository;
  bool _loadingRepo = true;
  String? _loadError;

  late CurriculumTrack _selectedTrack;
  late int _selectedAdultIndex;
  late int _selectedInfantilIndex;
  late bool _cumulativeMode;
  late bool _onlyWithRealVideo;
  TechnicalCategory? _selectedCategory;
  String _searchQuery = '';
  String? _selectedMovementId;
  int _realVideoCountInScope = 0;

  late Set<String> _selectedPlannerMovementIds;
  final Map<String, CurriculumMovement> _knownMovementsById = {};
  final Map<String, bool> _knownMovementHasRealVideo = {};

  List<CurriculumCorda> _adultCordas = const [];
  List<CurriculumCorda> _infantilCordas = const [];
  CordaCurriculumView? _resolvedAdultView;
  AccumulatedRepertoire? _accumulatedAdultRepertoire;
  List<CurriculumMovement> _visibleMovements = const [];
  Map<String, List<TutorialCurriculumLink>> _tutorialsByMovement = const {};

  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedTrack = widget.initialTrack;
    _selectedAdultIndex = (widget.initialCordaIndex ?? 1).clamp(1, 6);
    _selectedInfantilIndex = 1;
    _cumulativeMode = widget.initialCumulativeMode;
    _onlyWithRealVideo = widget.initialOnlyWithRealVideo;
    _selectedMovementId = widget.initialMovementId;
    _selectedPlannerMovementIds = Set<String>.from(
      widget.selectionContract?.initialSelectedMovementIds ?? const <String>{},
    );
    _tabController = TabController(length: 3, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      CurriculumRepository repo;
      if (widget.repository != null) {
        repo = widget.repository!;
      } else {
        final ds = await InMemoryCurriculumDataSource.fromFlutterAsset();
        repo = CurriculumRepository(dataSource: ds);
      }

      final adultCordas = await repo.getCordasByTrack(CurriculumTrack.adulto);
      final infantilCordas =
          await repo.getCordasByTrack(CurriculumTrack.infantil);

      if (!mounted) return;
      _repository = repo;
      _adultCordas = adultCordas;
      _infantilCordas = infantilCordas;
      await _refreshAdultSelection();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRepo = false;
        _loadError = 'No se pudo cargar el currículo local: $e';
      });
    }
  }

  Future<void> _refreshAdultSelection() async {
    final repo = _repository;
    if (repo == null) return;

    final targetCordaId =
        'adulto_corda_${_selectedAdultIndex.toString().padLeft(2, '0')}';
    final view = await repo.getResolvedCordaView(targetCordaId);
    final accumulated = await repo.getAccumulatedRepertoire(
      track: CurriculumTrack.adulto,
      upToCordaIndex: _selectedAdultIndex,
    );

    final baseList =
        _cumulativeMode ? accumulated.uniqueMovements : (view?.directMovements ?? const []);

    // Aplicar filtro de categoría y buscador usando la misma lógica confirmada del repositorio.
    final queryMatches = await repo.queryMovements(
      track: CurriculumTrack.adulto,
      category: _selectedCategory,
      cordaId: _cumulativeMode ? null : targetCordaId,
      searchQuery: _searchQuery,
    );
    final allowedIds = queryMatches.map((m) => m.movementId).toSet();
    final scopedList =
        baseList.where((m) => allowedIds.contains(m.movementId)).toList();

    final tutMap = <String, List<TutorialCurriculumLink>>{};
    int realVideoCount = 0;
    for (final m in scopedList) {
      _knownMovementsById[m.movementId] = m;
      final tuts = await repo.getTutorialsForMovement(
        m.movementId,
        includePending: true,
      );
      tutMap[m.movementId] = tuts;
      final hasReal = tuts.any((t) => t.hasRealVideo);
      _knownMovementHasRealVideo[m.movementId] = hasReal;
      if (hasReal) realVideoCount++;
    }

    final filtered = _onlyWithRealVideo
        ? scopedList
            .where((m) =>
                (tutMap[m.movementId] ?? const []).any((t) => t.hasRealVideo))
            .toList()
        : scopedList;

    String? nextSelectedId = _selectedMovementId;
    if (filtered.isEmpty) {
      nextSelectedId = null;
    } else if (nextSelectedId == null ||
        !filtered.any((m) => m.movementId == nextSelectedId)) {
      nextSelectedId = filtered.first.movementId;
    }

    if (!mounted) return;
    setState(() {
      _resolvedAdultView = view;
      _accumulatedAdultRepertoire = accumulated;
      _visibleMovements = filtered;
      _tutorialsByMovement = tutMap;
      _realVideoCountInScope = realVideoCount;
      _selectedMovementId = nextSelectedId;
      _loadingRepo = false;
    });
  }

  CurriculumMovement? get _activeDesktopMovement {
    if (_visibleMovements.isEmpty) return null;
    for (final m in _visibleMovements) {
      if (m.movementId == _selectedMovementId) return m;
    }
    return _visibleMovements.first;
  }

  bool get _plannerSelectionEnabled => widget.selectionContract?.enabled == true;

  List<CurriculumMovementSelectionItem> _buildSelectedPlannerItems() {
    final items = <CurriculumMovementSelectionItem>[];
    for (final id in _selectedPlannerMovementIds) {
      final mov = _knownMovementsById[id];
      if (mov == null) continue;
      items.add(
        CurriculumMovementSelectionItem.fromMovement(
          mov,
          hasRealVideo: _knownMovementHasRealVideo[id] ?? false,
        ),
      );
    }
    return items;
  }

  void _togglePlannerSelection(
    BuildContext context,
    CurriculumMovement movement,
  ) {
    final contract = widget.selectionContract;
    if (contract == null || !contract.enabled) return;

    if (contract.excludePendingTechnicalReview &&
        !movement.isSelectableForAiPlanner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${movement.canonicalName}" está pendiente de revisión técnica y no puede seleccionarse automáticamente para el planificador.',
          ),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedPlannerMovementIds.contains(movement.movementId)) {
        _selectedPlannerMovementIds.remove(movement.movementId);
      } else {
        _knownMovementsById[movement.movementId] = movement;
        _selectedPlannerMovementIds.add(movement.movementId);
      }
    });
    contract.onSelectionChanged?.call(_buildSelectedPlannerItems());
  }

  void _clearPlannerSelection() {
    final contract = widget.selectionContract;
    setState(() {
      _selectedPlannerMovementIds.clear();
    });
    contract?.onSelectionChanged?.call(const []);
  }

  CordaFIU _resolveIntroCorda(String? cordaId) {
    if (cordaId != null) {
      for (final c in _adultCordas) {
        if (c.cordaId == cordaId) {
          return _cordaFIUForIndex(c.index);
        }
      }
    }
    return _cordaFIUForIndex(1);
  }

  void _openMovement(
    BuildContext context,
    CurriculumMovement movement,
    BibliotecaUserContext userContext,
    bool isDesktop,
  ) {
    setState(() {
      _selectedMovementId = movement.movementId;
    });

    if (!isDesktop && _repository != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatefulBuilder(
            builder: (routeCtx, setRouteState) => MovimientoDetalleScreen(
              movement: movement,
              repository: _repository!,
              userContext: userContext,
              onOpenPizarra: widget.onOpenPizarra,
              selectionEnabled: _plannerSelectionEnabled,
              isSelectedForPlanner:
                  _selectedPlannerMovementIds.contains(movement.movementId),
              onTogglePlannerSelection: _plannerSelectionEnabled
                  ? () {
                      _togglePlannerSelection(routeCtx, movement);
                      setRouteState(() {});
                    }
                  : null,
            ),
          ),
        ),
      );
    }
  }

  CordaFIU _cordaFIUForIndex(int index) {
    return CuerdasFIU.lista[(index - 1).clamp(0, CuerdasFIU.lista.length - 1)];
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

  @override
  Widget build(BuildContext context) {
    return BibliotecaUserContextProvider(
      overrideContext: widget.overrideUserContext,
      builder: (context, userContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor =
            isDark ? GingaColors.backgroundDark : const Color(0xFFFFFFFF);
        final panelBg = isDark ? GingaColors.surfaceDark : Colors.white;
        final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);
        final textColor =
            isDark ? GingaColors.textWhite : const Color(0xFF111814);
        final subtitleColor =
            isDark ? GingaColors.textMuted : const Color(0xFF5F6368);

        return Scaffold(
          backgroundColor: bgColor,
          bottomNavigationBar: _plannerSelectionEnabled
              ? _buildPlannerSelectionBar(
                  context,
                  panelBg: panelBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                )
              : null,
          body: SafeArea(
            child: _loadingRepo
                ? const Center(
                    child: CircularProgressIndicator(
                        color: GingaColors.brandGreen),
                  )
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _loadError!,
                            style: GoogleFonts.montserrat(color: Colors.red),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final isDesktop = width >= 1100;
                          final isTablet = width >= 720 && width < 1100;

                          return Column(
                            children: [
                              _buildTopBar(
                                context,
                                userContext,
                                textColor,
                                subtitleColor,
                                isDesktop,
                              ),
                              Expanded(
                                child: _selectedTrack ==
                                        CurriculumTrack.infantil
                                    ? _buildInfantilWorkspace(
                                        context,
                                        isDesktop,
                                        isTablet,
                                        textColor,
                                        subtitleColor,
                                      )
                                    : isDesktop
                                        ? _buildDesktopAdultWorkspace(
                                            context,
                                            userContext,
                                            textColor,
                                            subtitleColor,
                                          )
                                        : _buildCompactAdultWorkspace(
                                            context,
                                            userContext,
                                            isTablet,
                                            textColor,
                                            subtitleColor,
                                          ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    BibliotecaUserContext userContext,
    Color textColor,
    Color subtitleColor,
    bool isDesktop,
  ) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 6),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currículo Oficial FIU',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                Text(
                  '${userContext.roleLabel} · Tu corda: ${userContext.cordaFIU.nombre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildTrackSegmentedControl(context, subtitleColor),
        ],
      ),
    );
  }

  Widget _buildTrackSegmentedControl(
    BuildContext context,
    Color subtitleColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? GingaColors.surfaceDark : const Color(0xFFF1F3F4);

    Widget chip(CurriculumTrack track, String label) {
      final selected = _selectedTrack == track;
      return InkWell(
        onTap: () {
          setState(() {
            _selectedTrack = track;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? GingaColors.brandGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : subtitleColor,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip(CurriculumTrack.adulto, 'Adulto'),
          chip(CurriculumTrack.infantil, 'Infantil'),
        ],
      ),
    );
  }

  Widget _buildDesktopAdultWorkspace(
    BuildContext context,
    BibliotecaUserContext userContext,
    Color textColor,
    Color subtitleColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? GingaColors.backgroundDark : const Color(0xFFFFFFFF);
    final panelBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);
    final activeMov = _activeDesktopMovement;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Columna izquierda: Navegación por graduaciones + accesos docente
        Container(
          width: 275,
          decoration: BoxDecoration(
            color: panelBg,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: _buildDesktopGraduationRail(
            context,
            userContext,
            textColor,
            subtitleColor,
          ),
        ),
        // Zona central: Filtros + pestañas + contenido curricular
        Expanded(
          child: _buildAdultCenterContent(
            context,
            userContext,
            isDesktop: true,
            isTablet: false,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
        // Panel derecho: Ficha detallada en vivo
        Container(
          width: 390,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(left: BorderSide(color: borderColor)),
          ),
          child: activeMov == null || _repository == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Selecciona un movimiento para ver su ficha curricular, referencias del manual y tutoriales vinculados.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                )
              : MovimientoDetallePanel(
                  movement: activeMov,
                  repository: _repository!,
                  userContext: userContext,
                  onSelectMovement: (next) {
                    setState(() {
                      _selectedMovementId = next.movementId;
                    });
                  },
                  onOpenPizarra: widget.onOpenPizarra,
                  selectionEnabled: _plannerSelectionEnabled,
                  isSelectedForPlanner:
                      _selectedPlannerMovementIds.contains(activeMov.movementId),
                  onTogglePlannerSelection: _plannerSelectionEnabled
                      ? () => _togglePlannerSelection(context, activeMov)
                      : null,
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopGraduationRail(
    BuildContext context,
    BibliotecaUserContext userContext,
    Color textColor,
    Color subtitleColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'GRADUACIONES ADULTO FIU',
          style: GoogleFonts.montserrat(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: subtitleColor,
          ),
        ),
        const SizedBox(height: 8),
        for (final corda in _adultCordas)
          _buildRailCordaTile(corda, userContext, textColor, subtitleColor),
        const SizedBox(height: 14),
        Text(
          'PRÓXIMAS GRADUACIONES (7–17)',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: subtitleColor,
          ),
        ),
        const SizedBox(height: 6),
        for (final cordaFiu in CuerdasFIU.lista.where((c) => c.index >= 7))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: CordaRibbonBar(corda: cordaFiu, height: 7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${cordaFiu.index}. ${cordaFiu.nombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: cordaFiu.index == userContext.adultCordaIndex
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: cordaFiu.index == userContext.adultCordaIndex
                          ? accentGreen
                          : subtitleColor,
                    ),
                  ),
                ),
                Text(
                  cordaFiu.index == userContext.adultCordaIndex
                      ? 'Tu corda'
                      : 'Pendiente',
                  style: GoogleFonts.montserrat(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: cordaFiu.index == userContext.adultCordaIndex
                        ? accentGreen
                        : subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        if (userContext.isTeacher) ...[
          const Divider(height: 28),
          Text(
            'HERRAMIENTAS DEL PROFESOR',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onOpenManageTutorials ??
                () {
                  if (Firebase.apps.isNotEmpty) {
                    context.push('/instructor-tutoriales');
                  }
                },
            style: OutlinedButton.styleFrom(
              foregroundColor: accentGreen,
              side: BorderSide(color: accentGreen, width: 1.4),
              minimumSize: const Size(double.infinity, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              textStyle: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.video_library_outlined, size: 17),
            label: const Text('Gestionar Tutoriales'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onOpenPizarra ??
                () {
                  if (Firebase.apps.isNotEmpty) {
                    context.push('/instructor-pizarra');
                  }
                },
            style: OutlinedButton.styleFrom(
              foregroundColor: accentGreen,
              side: BorderSide(color: accentGreen, width: 1.4),
              minimumSize: const Size(double.infinity, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              textStyle: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 17),
            label: const Text('Pizarra y Planificador'),
          ),
        ],
      ],
    );
  }

  Widget _buildRailCordaTile(
    CurriculumCorda corda,
    BibliotecaUserContext userContext,
    Color textColor,
    Color subtitleColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
    final isSelected = corda.index == _selectedAdultIndex;
    final isUserCorda = corda.index == userContext.adultCordaIndex;
    final isNext = corda.index == userContext.adultCordaIndex + 1;
    final cordaFiu = _cordaFIUForIndex(corda.index);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedAdultIndex = corda.index;
        });
        _refreshAdultSelection();
      },
      borderRadius: BorderRadius.circular(GingaRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentGreen.withValues(alpha: isDark ? 0.14 : 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(
            color: isSelected ? accentGreen : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: CordaRibbonBar(corda: cordaFiu, height: 8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${corda.index}. ${corda.nombreApp}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? accentGreen : textColor,
                    ),
                  ),
                  if (corda.usesSharedBlock || isUserCorda || isNext)
                    Text(
                      [
                        if (isUserCorda) 'Tu corda',
                        if (isNext) 'Próxima',
                        if (corda.usesSharedBlock) 'Bloque 5–6',
                      ].join(' · '),
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isUserCorda ? accentGreen : subtitleColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAdultWorkspace(
    BuildContext context,
    BibliotecaUserContext userContext,
    bool isTablet,
    Color textColor,
    Color subtitleColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F6F4);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);

    Widget buildUpcomingButton({bool compact = false}) => ActionChip(
          backgroundColor: chipBg,
          side: BorderSide(color: borderColor),
          visualDensity: VisualDensity.compact,
          avatar: Icon(
            Icons.hourglass_bottom_rounded,
            size: 14,
            color: subtitleColor,
          ),
          label: Text(
            compact ? '7–17' : 'Cordas 7–17 (Pend.)',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          onPressed: () => _showUpcomingCordasSheet(
            context,
            userContext,
            textColor,
            subtitleColor,
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            // Navegación por Cordas 1..6 + acceso directo a Cordas 7..17 sin recorte en tablet/web
            if (isTablet)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final corda in _adultCordas)
                        _buildCompactCordaChip(
                          corda,
                          userContext,
                          textColor,
                          subtitleColor,
                        ),
                      buildUpcomingButton(),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                        children: [
                          for (final corda in _adultCordas)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildCompactCordaChip(
                                corda,
                                userContext,
                                textColor,
                                subtitleColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: buildUpcomingButton(compact: true),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildAdultCenterContent(
                context,
                userContext,
                isDesktop: false,
                isTablet: isTablet,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCordaChip(
    CurriculumCorda corda,
    BibliotecaUserContext userContext,
    Color textColor,
    Color subtitleColor,
  ) {
    final isSelected = corda.index == _selectedAdultIndex;
    final isUser = corda.index == userContext.adultCordaIndex;
    final cordaFiu = _cordaFIUForIndex(corda.index);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedAdultIndex = corda.index;
        });
        _refreshAdultSelection();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? GingaColors.brandGreen : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? GingaColors.brandGreen
                : (isUser
                    ? GingaColors.brandGreen.withValues(alpha: 0.5)
                    : borderColor),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              child: CordaRibbonBar(corda: cordaFiu, height: 6),
            ),
            const SizedBox(width: 6),
            Text(
              '${corda.index}. ${corda.nombreApp}',
              style: GoogleFonts.montserrat(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : textColor,
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.star_rounded,
                size: 13,
                color: isSelected ? Colors.white : GingaColors.brandGreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUpcomingCordasSheet(
    BuildContext context,
    BibliotecaUserContext userContext,
    Color textColor,
    Color subtitleColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Graduaciones 7 a 17 · Digitalización futura',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'El catálogo estructurado actual cubre las Cordas 1 a 6 del manual oficial. Las cordas superiores están registradas por rango y quedan pendientes de digitalización.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 14),
            for (final c in CuerdasFIU.lista.where((e) => e.index >= 7))
              ListTile(
                dense: true,
                leading: SizedBox(
                  width: 40,
                  child: CordaRibbonBar(corda: c, height: 9),
                ),
                title: Text(
                  '${c.index}. Corda ${c.nombre} (${c.rango})',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  c.index == userContext.adultCordaIndex
                      ? 'Tu graduación actual · Contenido detallado pendiente'
                      : 'Contenido técnico pendiente de digitalización',
                  style: GoogleFonts.montserrat(fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAdultCenterContent(
    BuildContext context,
    BibliotecaUserContext userContext, {
    required bool isDesktop,
    required bool isTablet,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final view = _resolvedAdultView;
    final acc = _accumulatedAdultRepertoire;
    if (view == null || acc == null) return const SizedBox.shrink();

    final corda = view.corda;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);
    final chipBg =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F6F4);
    final cordaFiu = _cordaFIUForIndex(corda.index);

    final filterPills = <Widget>[
      _buildVideoFilterChip(
        cardBg: cardBg,
        borderColor: borderColor,
        subtitleColor: subtitleColor,
        accentGreen: accentGreen,
      ),
      _buildCategoryFilterChip(
        null,
        'Todos',
        cardBg,
        borderColor,
        subtitleColor,
      ),
      for (final cat in TechnicalCategory.values)
        _buildCategoryFilterChip(
          cat,
          cat.labelEs,
          cardBg,
          borderColor,
          subtitleColor,
        ),
    ];

    return Column(
      children: [
        // Encabezado compacto + toggle Acumulado + buscador + filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta resumen de la corda seleccionada
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: CordaRibbonBar(corda: cordaFiu, height: 10),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${corda.index}. ${corda.nombreManual}',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),
                        // Toggle Solo esta corda vs Acumulado 1..N
                        FilterChip(
                          selected: _cumulativeMode,
                          backgroundColor: chipBg,
                          selectedColor:
                              accentGreen.withValues(alpha: isDark ? 0.22 : 0.16),
                          checkmarkColor: accentGreen,
                          side: BorderSide(
                            color: _cumulativeMode ? accentGreen : borderColor,
                          ),
                          label: Text(
                            _cumulativeMode
                                ? 'Acumulado 1–${corda.index} (${acc.uniqueMovements.length})'
                                : 'Solo corda (${view.directMovements.length})',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _cumulativeMode ? accentGreen : textColor,
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              _cumulativeMode = val;
                            });
                            _refreshAdultSelection();
                          },
                        ),
                      ],
                    ),
                    if (corda.usesSharedBlock) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          'Bloque técnico compartido: Corda Laranja y Laranja e Amarelo comparten movimientos y cronograma semanal (pp. 42–44). Los requisitos físicos y de berimbau se mantienen diferenciados por corda.',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Buscador por nombre o alias confirmado
              TextField(
                controller: _searchController,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: textColor,
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _refreshAdultSelection();
                },
                decoration: InputDecoration(
                  hintText:
                      'Buscar por nombre o alias confirmado (ej. Passape, Benção)...',
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                  prefixIcon: Icon(Icons.search, color: subtitleColor, size: 19),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _refreshAdultSelection();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cardBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: BorderSide(color: accentGreen, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Filtros: "Con video" + las 5 categorías técnicas aprobadas (Wrap sin recorte en tablet/escritorio)
              if (isDesktop || isTablet)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: filterPills,
                )
              else
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final pill in filterPills)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: pill,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Pestañas de contenido oficial
        TabBar(
          controller: _tabController,
          isScrollable: !isDesktop && !isTablet,
          tabAlignment: (!isDesktop && !isTablet)
              ? TabAlignment.start
              : TabAlignment.fill,
          labelColor: accentGreen,
          unselectedLabelColor: subtitleColor,
          indicatorColor: accentGreen,
          labelStyle: GoogleFonts.montserrat(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
          tabs: [
            Tab(text: 'Movimientos (${_visibleMovements.length})'),
            const Tab(text: 'Secuencias y Cronograma'),
            const Tab(text: 'Musicalidad y Eval.'),
          ],
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMovementsTab(
                context,
                userContext,
                isDesktop: isDesktop,
                isTablet: isTablet,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
              _buildSequencesAndScheduleTab(
                view,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
              _buildMusicalityAndEvalTab(
                view,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoFilterChip({
    required Color cardBg,
    required Color borderColor,
    required Color subtitleColor,
    required Color accentGreen,
  }) {
    final selected = _onlyWithRealVideo;
    return InkWell(
      onTap: () {
        _onlyWithRealVideo = !_onlyWithRealVideo;
        _refreshAdultSelection();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? GingaColors.brandGreen : cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? GingaColors.brandGreen : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_filled_rounded,
              size: 14,
              color: selected ? Colors.white : accentGreen,
            ),
            const SizedBox(width: 5),
            Text(
              'Con video ($_realVideoCountInScope)',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? Colors.white : subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(
    TechnicalCategory? category,
    String label,
    Color cardBg,
    Color borderColor,
    Color subtitleColor,
  ) {
    final selected = _selectedCategory == category;
    return InkWell(
      onTap: () {
        _selectedCategory = category;
        _refreshAdultSelection();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? GingaColors.brandGreen : cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? GingaColors.brandGreen : borderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : subtitleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMovementsTab(
    BuildContext context,
    BibliotecaUserContext userContext, {
    required bool isDesktop,
    required bool isTablet,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    if (_visibleMovements.isEmpty) {
      final hasFilters = _onlyWithRealVideo ||
          _selectedCategory != null ||
          _searchQuery.isNotEmpty;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final accentGreen =
          isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _onlyWithRealVideo
                    ? 'No hay movimientos con video real en esta corda o filtro actual.'
                    : 'No hay movimientos que coincidan con el filtro o búsqueda actual.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 13, color: subtitleColor),
              ),
              if (hasFilters) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _onlyWithRealVideo = false;
                      _selectedCategory = null;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _refreshAdultSelection();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentGreen,
                    side: BorderSide(color: accentGreen, width: 1.4),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                    ),
                    textStyle: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Mostrar todos'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final useGrid = isDesktop || isTablet;
    if (!useGrid) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: _visibleMovements.length,
        itemBuilder: (context, index) {
          final mov = _visibleMovements[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildMovementCard(
              context,
              mov,
              userContext,
              isDesktop: false,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 104,
      ),
      itemCount: _visibleMovements.length,
      itemBuilder: (context, index) {
        final mov = _visibleMovements[index];
        return _buildMovementCard(
          context,
          mov,
          userContext,
          isDesktop: isDesktop,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
        );
      },
    );
  }

  Widget _buildMovementCard(
    BuildContext context,
    CurriculumMovement mov,
    BibliotecaUserContext userContext, {
    required bool isDesktop,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
    final isFocused = isDesktop && mov.movementId == _selectedMovementId;
    final isCheckedForPlanner =
        _plannerSelectionEnabled && _selectedPlannerMovementIds.contains(mov.movementId);
    final catColor = _categoryColor(mov.category, isDark: isDark);
    final introCorda = _resolveIntroCorda(mov.firstIntroducedAdulto);
    final tuts = _tutorialsByMovement[mov.movementId] ?? const [];
    final hasRealVideo = tuts.any((t) => t.hasRealVideo);
    final hasAnyTut = tuts.isNotEmpty;

    return InkWell(
      onTap: () => _openMovement(context, mov, userContext, isDesktop),
      borderRadius: BorderRadius.circular(GingaRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: (isFocused || isCheckedForPlanner)
              ? accentGreen.withValues(alpha: isDark ? 0.14 : 0.08)
              : cardBg,
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(
            color: (isFocused || isCheckedForPlanner) ? accentGreen : borderColor,
            width: (isFocused || isCheckedForPlanner) ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mov.canonicalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                if (_plannerSelectionEnabled)
                  InkWell(
                    onTap: () => _togglePlannerSelection(context, mov),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        isCheckedForPlanner
                            ? Icons.check_circle_rounded
                            : (mov.isSelectableForAiPlanner
                                ? Icons.add_circle_outline_rounded
                                : Icons.block_rounded),
                        size: 19,
                        color: isCheckedForPlanner
                            ? accentGreen
                            : (mov.isSelectableForAiPlanner
                                ? subtitleColor
                                : Colors.orange.shade300),
                      ),
                    ),
                  )
                else if (hasRealVideo)
                  Icon(
                    Icons.play_circle_filled_rounded,
                    size: 17,
                    color: accentGreen,
                  )
                else if (mov.isAmbiguous)
                  Icon(
                    Icons.pending_actions_rounded,
                    size: 16,
                    color: isDark ? Colors.orange.shade300 : Colors.orange,
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: subtitleColor,
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  child: CordaRibbonBar(corda: introCorda, height: 5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Desde ${introCorda.index}ª · ${introCorda.nombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 3,
              children: [
                _MiniTag(label: mov.category.labelEs, color: catColor),
                if (mov.isCombination)
                  _MiniTag(
                    label: 'Combinación',
                    color: isDark ? Colors.indigo.shade200 : Colors.indigo,
                  ),
                if (hasRealVideo)
                  _MiniTag(
                    label: 'Video real',
                    color: accentGreen,
                  )
                else if (hasAnyTut)
                  _MiniTag(
                    label: 'Ficha tutorial',
                    color: subtitleColor,
                  )
                else
                  _MiniTag(
                    label: 'Sin video',
                    color: subtitleColor,
                  ),
                if (mov.isAmbiguous)
                  _MiniTag(
                    label: 'En revisión',
                    color: isDark ? Colors.orange.shade300 : Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannerSelectionBar(
    BuildContext context, {
    required Color panelBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final contract = widget.selectionContract!;
    final selectedItems = _buildSelectedPlannerItems();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: panelBg,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedItems.isEmpty
                    ? 'Selecciona movimientos para el planificador'
                    : '${selectedItems.length} movimiento(s) seleccionado(s)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            if (selectedItems.isNotEmpty) ...[
              TextButton(
                onPressed: _clearPlannerSelection,
                style: TextButton.styleFrom(
                  foregroundColor: subtitleColor,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  'Limpiar',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            ElevatedButton.icon(
              onPressed: selectedItems.isEmpty
                  ? null
                  : () => contract.onConfirmSelection?.call(selectedItems),
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                textStyle: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 17),
              label: Text(contract.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequencesAndScheduleTab(
    CordaCurriculumView view, {
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final corda = view.corda;
    final schedule = view.effectiveWeeklySchedule;
    final drillMentions = view.effectiveDrillOnlyMentions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (corda.sequencias.isNotEmpty) ...[
          _InfoCard(
            title: 'Secuencias oficiales',
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            children: [
              for (final s in corda.sequencias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${s.raw} (p. ${s.pageRef.printedPage}/PDF ${s.pageRef.pdfPage})',
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (schedule == null)
          _InfoCard(
            title: 'Cronograma semanal',
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            children: [
              Text(
                'Corda Crua no define cronograma semanal Treino 1/2/3 en el manual; sus repeticiones mínimas son 10 veces por cada lado (pp. 31–32 / PDF 32–33).',
                style: GoogleFonts.montserrat(
                  fontSize: 12.5,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
            ],
          )
        else ...[
          _InfoCard(
            title:
                'Cronograma semanal · Mínimo ${schedule.repeticoesMinimas}',
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            children: [
              _buildTreinoBlock('Treino 1 da semana', schedule.treino1, textColor),
              const SizedBox(height: 10),
              _buildTreinoBlock('Treino 2 da semana', schedule.treino2, textColor),
              const SizedBox(height: 10),
              _buildTreinoBlock('Treino 3 da semana', schedule.treino3, textColor),
            ],
          ),
          if (drillMentions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Menciones solo en cronograma (sin asignación curricular)',
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              children: [
                for (final d in drillMentions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${d.rawTerm} (${d.location}): ${d.note}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: subtitleColor,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTreinoBlock(
    String title,
    List<String> items,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: GingaColors.brandGreen,
          ),
        ),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              item,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMusicalityAndEvalTab(
    CordaCurriculumView view, {
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final corda = view.corda;
    final musicality = corda.musicalidade;
    final eval = corda.avaliacao;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (corda.inheritanceNoteRaw != null) ...[
          _InfoCard(
            title: 'Continuidad técnica',
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            children: [
              Text(
                corda.inheritanceNoteRaw!,
                style: GoogleFonts.montserrat(
                  fontSize: 12.5,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (musicality != null) ...[
          _InfoCard(
            title:
                'Musicalidad oficial (p. ${musicality.pageRef.printedPage}/PDF ${musicality.pageRef.pdfPage})',
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            children: [
              Text(
                musicality.raw,
                style: GoogleFonts.montserrat(
                  fontSize: 12.5,
                  color: textColor,
                  height: 1.45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (eval != null) ...[
          _InfoCard(
            title:
                'Evaluación oficial de esta corda (p. ${eval.pageRef.printedPage}/PDF ${eval.pageRef.pdfPage})',
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            children: [
              Text(
                eval.raw,
                style: GoogleFonts.montserrat(
                  fontSize: 12.5,
                  color: textColor,
                  height: 1.45,
                ),
              ),
              if (eval.fisico.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: eval.fisico.entries.map((e) {
                    return _MiniTag(
                      label: '${e.key.replaceAll('_', ' ')}: ${e.value}',
                      color: GingaColors.brandGreen,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (corda.sabedoriaMestreNatal != null)
          _InfoCard(
            title: 'Sabedoria do Mestre Natal',
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            children: [
              Text(
                '"${corda.sabedoriaMestreNatal!}"',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfantilWorkspace(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    Color textColor,
    Color subtitleColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);

    final selected = _infantilCordas.firstWhere(
      (c) => c.index == _selectedInfantilIndex,
      orElse: () => _infantilCordas.first,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(GingaRadius.md),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sistema Infantil FIU (12 cordas claras · Separado de Adulto)',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estructura oficial mapeada (3 a 14 años, transición a Adulto cerca de los 15 años · pp. 13–25). El listado detallado de movimientos infantiles está pendiente de digitalización en una fase posterior.',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 94,
              ),
              itemCount: _infantilCordas.length,
              itemBuilder: (context, index) {
                final c = _infantilCordas[index];
                final isSel = c.index == selected.index;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedInfantilIndex = c.index;
                    });
                  },
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSel
                          ? GingaColors.brandGreen.withValues(alpha: 0.08)
                          : cardBg,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(
                        color: isSel ? GingaColors.brandGreen : borderColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${c.index}. ${c.nombreManual}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: _MiniTag(
                                label: c.edadReferencia ?? 'Infantil',
                                color: GingaColors.brandGreen,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Treinamento: ${c.nombreTreinamento ?? c.nombreManual} · Pendiente de digitalización',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.montserrat(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

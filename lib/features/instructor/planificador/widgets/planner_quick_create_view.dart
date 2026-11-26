import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/curriculum_models.dart';
import '../../../../core/services/curriculum_repository.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../../../biblioteca/curriculo_biblioteca_screen.dart';
import '../../../biblioteca/widgets/biblioteca_user_context.dart';
import '../models/class_plan_models.dart';
import '../theme/planner_palette.dart';
import 'planner_shared_widgets.dart';

/// Modalidad 1: Creación Rápida con el mínimo número de interacciones.
/// Comparte exactamente el mismo [ClassPlanDraftRequest] con Creación Avanzada.
class PlannerQuickCreateView extends StatefulWidget {
  final List<PlannerGroupProfile> groups;
  final List<PlannerResourceItem> resources;
  final List<TaughtSessionRecord> history;
  final CurriculumRepository? curriculumRepository;
  final ClassPlanDraftRequest initialRequest;
  final ValueChanged<ClassPlanDraftRequest> onCreateLocalDraft;
  final ValueChanged<ClassPlanDraftRequest> onSwitchToAdvanced;
  final VoidCallback onCancel;

  const PlannerQuickCreateView({
    super.key,
    required this.groups,
    this.resources = const [],
    this.history = const [],
    this.curriculumRepository,
    required this.initialRequest,
    required this.onCreateLocalDraft,
    required this.onSwitchToAdvanced,
    required this.onCancel,
  });

  @override
  State<PlannerQuickCreateView> createState() => _PlannerQuickCreateViewState();
}

class _PlannerQuickCreateViewState extends State<PlannerQuickCreateView> {
  late ClassPlanDraftRequest _request;
  late TextEditingController _instructionsCtrl;
  bool _showOptionalSelection = false;

  static const List<int> _quickDurations = [45, 60, 75, 90];

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest.copyWith(
      creationMode: PlannerCreationMode.quick,
    );
    _instructionsCtrl = TextEditingController(text: _request.freeInstructions);
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _selectRealGroup(PlannerGroupProfile group) {
    final existingCtx = _request.continuityContext;
    final keepExisting = existingCtx != null &&
        existingCtx.matchesGroup(
          groupId: group.id,
          groupName: group.name,
          audienceType: group.audienceType,
        );
    final matchedSession = keepExisting
        ? null
        : PedagogicalContinuityContext.findLatestSessionForGroup(
            widget.history,
            groupId: group.id,
            groupName: group.name,
            audienceType: group.audienceType,
          );
    final nextContext = keepExisting
        ? existingCtx
        : (matchedSession != null
            ? PedagogicalContinuityContext.fromSession(matchedSession)
            : null);
    final nextSummary = keepExisting
        ? _request.continuitySummary
        : nextContext?.shortHeadline;

    setState(() {
      _request = ClassPlanDraftRequest.fromGroup(
        group,
        mode: PlannerCreationMode.quick,
      ).copyWith(
        durationMin: _request.durationMin,
        focuses: _request.focuses,
        freeInstructions: _instructionsCtrl.text,
        selectedMovements: group.audienceType == PlannerAudienceType.adultos
            ? _request.selectedMovements
            : const [],
        selectedResources: _request.selectedResources,
        continuityContext: nextContext,
        continuitySummary: nextSummary,
        clearContinuity: nextContext == null && nextSummary == null,
      );
    });
  }

  void _selectManualAudience(PlannerAudienceType audience) {
    final defaultAgeMin = audience == PlannerAudienceType.infantil
        ? 5
        : (audience == PlannerAudienceType.mixto ? 8 : 16);
    final defaultAgeMax = audience == PlannerAudienceType.infantil ? 12 : 40;
    setState(() {
      _request = _request.copyWith(
        groupSource: PlannerGroupSource.manual,
        clearRealClaseId: true,
        clearContinuity: true,
        groupName: 'Grupo ${audience.label} manual',
        audienceType: audience,
        curriculumScope: PlannerCurriculumScope.suggestedForAudience(audience),
        ageMin: defaultAgeMin,
        ageMax: defaultAgeMax,
        selectedMovements: audience == PlannerAudienceType.adultos
            ? _request.selectedMovements
            : const [],
      );
    });
  }

  void _toggleFocus(String focus) {
    final next = List<String>.from(_request.focuses);
    if (next.contains(focus)) {
      if (next.length > 1) {
        next.remove(focus);
      }
    } else {
      next.add(focus);
    }
    setState(() {
      _request = _request.copyWith(focuses: next);
    });
  }

  Future<void> _openOptionalCurriculumPicker() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CurriculoBibliotecaScreen(
          repository: widget.curriculumRepository,
          overrideUserContext: const BibliotecaUserContext(
            role: 'profesor',
            cordaName: 'Azul',
            displayName: 'Modo Planificador',
          ),
          initialTrack: CurriculumTrack.adulto,
          initialCordaIndex: _request.targetAdultoCordaIndex.clamp(1, 6),
          initialCumulativeMode: true,
          selectionContract: CurriculumSelectionContract(
            enabled: true,
            initialSelectedMovementIds: _request.selectedMovements
                .map((m) => m.item.movementId)
                .toSet(),
            excludePendingTechnicalReview: true,
            confirmLabel: 'Usar en planificador',
            onConfirmSelection: (items) {
              if (!mounted) return;
              final existingPriority = {
                for (final m in _request.selectedMovements)
                  m.item.movementId: m.priority,
              };
              setState(() {
                _request = _request.copyWith(
                  selectedMovements: items
                      .map((item) => SelectedCurriculumMovement(
                            item: item,
                            priority: existingPriority[item.movementId] ??
                                ResourcePriority.required,
                          ))
                      .toList(),
                );
              });
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _toggleOptionalResource(PlannerResourceItem resource) {
    final updated = List<SelectedTeacherResource>.from(_request.selectedResources);
    final idx =
        updated.indexWhere((r) => r.resource.resourceId == resource.resourceId);
    if (idx >= 0) {
      updated.removeAt(idx);
    } else {
      updated.add(SelectedTeacherResource(resource: resource));
    }
    setState(() {
      _request = _request.copyWith(selectedResources: updated);
    });
  }

  ClassPlanDraftRequest _currentRequest() {
    return _request.copyWith(
      creationMode: PlannerCreationMode.quick,
      freeInstructions: _instructionsCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 820;
    final canPickAdultoFiu =
        _request.curriculumScope == PlannerCurriculumScope.adultoFiu;
    final totalSelectedItems =
        _request.selectedMovements.length + _request.selectedResources.length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 24 : 16,
        16,
        isWide ? 24 : 16,
        28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado compacto con salto directo a Avanzada
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlannerBadge(
                        label: 'Modalidad rápida',
                        color: pal.accent,
                        icon: Icons.flash_on_rounded,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Preparación Rápida de Clase',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    key: const Key('quick_to_advanced_button'),
                    onPressed: () =>
                        widget.onSwitchToAdvanced(_currentRequest()),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: pal.border),
                      foregroundColor: pal.textPrimary,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 17),
                    label: Text(
                      'Personalizar en avanzada',
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if ((_request.continuityContext != null &&
                      _request.continuityContext!.hasContent) ||
                  (_request.continuitySummary != null &&
                      _request.continuitySummary!.trim().isNotEmpty)) ...[
                PlannerContinuityContextCard(
                  contextData: _request.continuityContext,
                  fallbackSummary: _request.continuitySummary,
                  onClear: () => setState(() {
                    _request = _request.copyWith(clearContinuity: true);
                  }),
                ),
                const SizedBox(height: 14),
              ],

              // Bloque 1: Grupo real o manual en 1 toque
              _QuickCard(
                title: '1. Elige el grupo o público',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in widget.groups)
                          _SelectablePill(
                            key: Key('quick_group_${g.id}'),
                            label:
                                '${g.name} (${g.participantsCount} · ${g.ageRangeLabel})',
                            selected: _request.groupSource ==
                                    PlannerGroupSource.realClass &&
                                _request.realClaseId == g.id,
                            onTap: () => _selectRealGroup(g),
                          ),
                        _SelectablePill(
                          key: const Key('quick_group_manual'),
                          label: 'Configurar manual',
                          icon: Icons.edit_outlined,
                          selected:
                              _request.groupSource == PlannerGroupSource.manual,
                          onTap: () =>
                              _selectManualAudience(_request.audienceType),
                        ),
                      ],
                    ),
                    if (_request.groupSource == PlannerGroupSource.manual) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final aud in PlannerAudienceType.values)
                            _SelectablePill(
                              key: Key('quick_manual_audience_${aud.id}'),
                              label: aud.label,
                              selected: _request.audienceType == aud,
                              onTap: () => _selectManualAudience(aud),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        PlannerBadge(
                          label: '${_request.participantsCount} alumnos',
                          color: pal.infoBlue,
                          backgroundColor: pal.infoBlueBg,
                        ),
                        PlannerBadge(
                          label: '${_request.ageMin}–${_request.ageMax} años',
                          color: pal.textSecondary,
                        ),
                        PlannerBadge(
                          label: _request.curriculumScope.teacherLabel,
                          color: _request.curriculumScope ==
                                  PlannerCurriculumScope.adultoFiu
                              ? pal.accent
                              : pal.amber,
                        ),
                      ],
                    ),
                    if (_request.audienceType == PlannerAudienceType.mixto) ...[
                      const SizedBox(height: 10),
                      PlannerNoticeBanner(
                        title: 'Grupo mixto sin pista curricular automática',
                        message:
                            'Por seguridad pedagógica no se asume que un grupo mixto pertenezca al currículo adulto FIU. Puedes ajustarlo en modo avanzado.',
                        color: pal.amber,
                        backgroundColor: pal.amberBg,
                      ),
                    ] else if (_request.audienceType ==
                        PlannerAudienceType.infantil) ...[
                      const SizedBox(height: 10),
                      PlannerNoticeBanner(
                        title: 'Currículo Infantil FIU en preparación',
                        message:
                            'No se utilizará el currículo adulto de forma automática. El borrador prioriza dinámicas por edad (${_request.ageMin}–${_request.ageMax} años) y tus recursos.',
                        color: pal.amber,
                        backgroundColor: pal.amberBg,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bloque 2: Duración + Múltiples enfoques
              _QuickCard(
                title: '2. Duración y enfoques',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duración total',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final min in _quickDurations)
                          _SelectablePill(
                            key: Key('quick_duration_$min'),
                            label: '$min min',
                            selected: _request.durationMin == min,
                            onTap: () => setState(() {
                              _request = _request.copyWith(durationMin: min);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Enfoques de la sesión (puedes elegir varios)',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final focus in kPlannerFocusOptions)
                          _SelectablePill(
                            key: Key('quick_focus_$focus'),
                            label: focus,
                            selected: _request.focuses.contains(focus),
                            onTap: () => _toggleFocus(focus),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bloque 3: ¿Qué quieres trabajar hoy?
              _QuickCard(
                title: '3. ¿Qué quieres trabajar hoy?',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('quick_free_instructions_field'),
                      controller: _instructionsCtrl,
                      maxLines: 3,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: pal.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Ej. Esquivas bajas en parejas sin filas, fluidez con rolê y 10 min de roda...',
                        hintStyle: GoogleFonts.montserrat(
                          fontSize: 12.5,
                          color: pal.textSecondary,
                        ),
                        filled: true,
                        fillColor: pal.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: BorderSide(color: pal.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: BorderSide(color: pal.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PlannerChoicePill(
                          key: const Key('quick_toggle_optional_picker'),
                          label: totalSelectedItems > 0
                              ? 'Movimientos y recursos ($totalSelectedItems seleccionados)'
                              : 'Añadir movimientos o recursos (opcional)',
                          icon: Icons.playlist_add_outlined,
                          selected:
                              _showOptionalSelection || totalSelectedItems > 0,
                          onTap: () => setState(() {
                            _showOptionalSelection = !_showOptionalSelection;
                          }),
                        ),
                        if (_request.selectedMovements.isNotEmpty)
                          PlannerBadge(
                            label:
                                '${_request.selectedMovements.length} FIU',
                            color: pal.accent,
                          ),
                        if (_request.selectedResources.isNotEmpty)
                          PlannerBadge(
                            label:
                                '${_request.selectedResources.length} de Pizarra',
                            color: pal.infoBlue,
                            backgroundColor: pal.infoBlueBg,
                          ),
                      ],
                    ),
                    if (_showOptionalSelection ||
                        totalSelectedItems > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pal.background,
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: pal.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (canPickAdultoFiu)
                                  OutlinedButton.icon(
                                    key: const Key('quick_open_fiu_picker'),
                                    onPressed: _openOptionalCurriculumPicker,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      side: BorderSide(color: pal.accent),
                                      foregroundColor: pal.accent,
                                    ),
                                    icon: const Icon(
                                        Icons.menu_book_outlined,
                                        size: 16),
                                    label: Text(
                                      'Elegir movimientos FIU',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_request.selectedMovements.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final m in _request.selectedMovements)
                                    PlannerBadge(
                                      label: m.item.canonicalName,
                                      color: pal.accent,
                                    ),
                                ],
                              ),
                            ],
                            if (widget.resources.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Recursos rápidos de tu Pizarra:',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final res in widget.resources)
                                    PlannerChoicePill(
                                      key: Key(
                                          'quick_res_${res.resourceId}'),
                                      label: res.title,
                                      selected: _request.selectedResources.any(
                                          (r) =>
                                              r.resource.resourceId ==
                                              res.resourceId),
                                      onTap: () =>
                                          _toggleOptionalResource(res),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Barra final de acciones
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: pal.textSecondary,
                    ),
                    child: Text(
                      'Volver al Hub',
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget.onSwitchToAdvanced(_currentRequest()),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          side: BorderSide(color: pal.accent),
                          foregroundColor: pal.accent,
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          'Abrir en avanzada',
                          style: GoogleFonts.montserrat(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      ElevatedButton.icon(
                        key: const Key('quick_create_draft_button'),
                        onPressed: () =>
                            widget.onCreateLocalDraft(_currentRequest()),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          backgroundColor: pal.accent,
                          foregroundColor: pal.onAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          'Crear borrador',
                          style: GoogleFonts.montserrat(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _QuickCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SelectablePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GingaRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? pal.accent : pal.background,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(
            color: selected ? pal.accent : pal.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? pal.onAccent : pal.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? pal.onAccent : pal.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

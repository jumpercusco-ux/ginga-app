import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/curriculum_models.dart';
import '../../../../core/services/curriculum_repository.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../../../biblioteca/curriculo_biblioteca_screen.dart';
import '../../../biblioteca/widgets/biblioteca_user_context.dart';
import '../models/class_plan_models.dart';
import '../services/planner_v2_engine_client.dart';
import '../theme/planner_palette.dart';
import 'planner_shared_widgets.dart';

/// Modalidad 2: Creación Avanzada responsive (2 columnas en escritorio/tablet, 1 columna en móvil).
/// Valida distribución de alumnos, permite múltiples enfoques, objetivos personalizados,
/// búsqueda/filtros de recursos con nota de uso y oculta referencias técnicas internas.
class PlannerAdvancedCreateView extends StatefulWidget {
  final List<PlannerGroupProfile> groups;
  final List<PlannerResourceItem> resources;
  final List<TaughtSessionRecord> history;
  final ClassPlanDraftRequest initialRequest;
  final CurriculumRepository? curriculumRepository;
  final ValueChanged<ClassPlanDraftRequest> onCreateLocalDraft;
  final Future<void> Function(ClassPlanDraftRequest)? onGenerateWithEngine;
  final bool isGenerating;
  final String? generationError;
  final PlannerV2EngineStatus? engineStatus;
  final bool forceSimulated;
  final ValueChanged<bool>? onToggleForceSimulated;
  final ValueChanged<ClassPlanDraftRequest> onSwitchToQuick;
  final VoidCallback onCancel;

  const PlannerAdvancedCreateView({
    super.key,
    required this.groups,
    required this.resources,
    this.history = const [],
    required this.initialRequest,
    this.curriculumRepository,
    required this.onCreateLocalDraft,
    this.onGenerateWithEngine,
    this.isGenerating = false,
    this.generationError,
    this.engineStatus,
    this.forceSimulated = false,
    this.onToggleForceSimulated,
    required this.onSwitchToQuick,
    required this.onCancel,
  });

  @override
  State<PlannerAdvancedCreateView> createState() =>
      _PlannerAdvancedCreateViewState();
}

class _PlannerAdvancedCreateViewState extends State<PlannerAdvancedCreateView> {
  late ClassPlanDraftRequest _request;
  late TextEditingController _groupNameCtrl;
  late TextEditingController _instructionsCtrl;
  late TextEditingController _customDurationCtrl;
  final TextEditingController _customObjectiveCtrl = TextEditingController();
  final TextEditingController _resourcesSearchCtrl = TextEditingController();
  final Map<String, TextEditingController> _usageCtrls = {};

  String _resourcesSearchQuery = '';
  String _resourcesMediaFilter = 'Todos';
  String _resourcesCategoryFilter = 'Todas';

  static const List<int> _presetDurations = [45, 60, 75, 90];
  static const List<String> _suggestedObjectives = [
    'Base y equilibrio en ginga',
    'Esquivas bajas y salidas fluidas',
    'Progresiones sin tiempos muertos',
    'Control de acrobacias / floreios',
    'Musicalidad y juego en roda',
    'Coordinación lúdica por estaciones',
  ];
  static const List<String> _availableMaterials = [
    'Berimbau',
    'Pandeiro',
    'Atabaque',
    'Conos',
    'Colchonetas',
    'Aros',
  ];

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest.copyWith(
      creationMode: PlannerCreationMode.advanced,
    );
    _groupNameCtrl = TextEditingController(text: _request.groupName);
    _instructionsCtrl = TextEditingController(text: _request.freeInstructions);
    _customDurationCtrl =
        TextEditingController(text: _request.durationMin.toString());
    for (final res in _request.selectedResources) {
      _usageCtrls[res.resource.resourceId] =
          TextEditingController(text: res.usageNote);
    }
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _instructionsCtrl.dispose();
    _customDurationCtrl.dispose();
    _customObjectiveCtrl.dispose();
    _resourcesSearchCtrl.dispose();
    for (final ctrl in _usageCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _usageCtrlFor(SelectedTeacherResource sel) {
    return _usageCtrls.putIfAbsent(
      sel.resource.resourceId,
      () => TextEditingController(text: sel.usageNote),
    );
  }

  PlannerGroupProfile? get _selectedRealGroup {
    if (_request.groupSource != PlannerGroupSource.realClass ||
        _request.realClaseId == null) {
      return null;
    }
    for (final g in widget.groups) {
      if (g.id == _request.realClaseId) return g;
    }
    return null;
  }

  void _applyGroup(PlannerGroupProfile group) {
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
        mode: PlannerCreationMode.advanced,
      ).copyWith(
        durationMin: _request.durationMin,
        focuses: _request.focuses,
        freeInstructions: _instructionsCtrl.text,
        selectedMovements: group.audienceType == PlannerAudienceType.adultos
            ? _request.selectedMovements
            : const [],
        selectedResources: _request.selectedResources,
        materials: _request.materials,
        materialsConfirmed: _request.materialsConfirmed,
        spaceContext: _request.spaceContext,
        includeMusicalityRoda: _request.includeMusicalityRoda,
        allowAiComplementaryProposals: _request.allowAiComplementaryProposals,
        continuityContext: nextContext,
        continuitySummary: nextSummary,
        clearContinuity: nextContext == null && nextSummary == null,
      );
      _groupNameCtrl.text = _request.groupName;
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

  void _addCustomObjective() {
    final text = _customObjectiveCtrl.text.trim();
    if (text.isEmpty) return;
    if (!_request.objectives.contains(text)) {
      setState(() {
        _request = _request.copyWith(
          objectives: [..._request.objectives, text],
        );
      });
    }
    _customObjectiveCtrl.clear();
  }

  void _adjustDistributionToTotal() {
    final total = _request.participantsCount;
    final p = (total * 0.4).round();
    final i = (total * 0.4).round();
    final a = (total - p - i).clamp(0, total);
    setState(() {
      _request = _request.copyWith(
        experienceDistribution: ExperienceDistribution(
          principiantes: p,
          intermedios: i,
          avanzados: a,
          manuallyConfirmed: true,
        ),
      );
    });
  }

  Future<void> _openCurriculumSelector() async {
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

  void _toggleResource(PlannerResourceItem resource) {
    final existingIndex = _request.selectedResources
        .indexWhere((r) => r.resource.resourceId == resource.resourceId);
    final updated = List<SelectedTeacherResource>.from(_request.selectedResources);
    if (existingIndex >= 0) {
      updated.removeAt(existingIndex);
    } else {
      updated.add(SelectedTeacherResource(resource: resource));
    }
    setState(() {
      _request = _request.copyWith(selectedResources: updated);
    });
  }

  void _toggleResourcePriority(String resourceId, ResourcePriority priority) {
    final updated = _request.selectedResources
        .map((r) => r.resource.resourceId == resourceId
            ? r.copyWith(priority: priority)
            : r)
        .toList();
    setState(() {
      _request = _request.copyWith(selectedResources: updated);
    });
  }

  void _updateResourceUsageNote(String resourceId, String usageNote) {
    final updated = _request.selectedResources
        .map((r) => r.resource.resourceId == resourceId
            ? r.copyWith(usageNote: usageNote)
            : r)
        .toList();
    _request = _request.copyWith(selectedResources: updated);
  }

  void _toggleMovementPriority(String movementId, ResourcePriority priority) {
    final updated = _request.selectedMovements
        .map((m) => m.item.movementId == movementId
            ? m.copyWith(priority: priority)
            : m)
        .toList();
    setState(() {
      _request = _request.copyWith(selectedMovements: updated);
    });
  }

  ClassPlanDraftRequest _currentRequest() {
    final parsedDur =
        int.tryParse(_customDurationCtrl.text.trim()) ?? _request.durationMin;
    return _request.copyWith(
      creationMode: PlannerCreationMode.advanced,
      groupName: _groupNameCtrl.text.trim().isNotEmpty
          ? _groupNameCtrl.text.trim()
          : _request.groupName,
      durationMin: parsedDur.clamp(20, 180),
      freeInstructions: _instructionsCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 960;
    final distributionValid = _request.isExperienceDistributionValid;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 24 : 16,
        16,
        isWide ? 24 : 16,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          PlannerBadge(
                            label: 'Modalidad avanzada · Control completo',
                            color: pal.infoBlue,
                            backgroundColor: pal.infoBlueBg,
                            icon: Icons.tune_rounded,
                          ),
                          if (widget.onGenerateWithEngine != null) ...[
                            PlannerBadge(
                              key: const Key('adv_simulated_mode_badge'),
                              label: (widget.engineStatus?.realProviderEnabled ==
                                          true &&
                                      !widget.forceSimulated)
                                  ? 'Motor V2 · OpenAI (${widget.engineStatus!.primaryModel}) · Local'
                                  : 'Motor V2 · Modo simulado offline',
                              color: (widget.engineStatus?.realProviderEnabled ==
                                          true &&
                                      !widget.forceSimulated)
                                  ? pal.accent
                                  : pal.infoBlue,
                              backgroundColor:
                                  (widget.engineStatus?.realProviderEnabled ==
                                              true &&
                                          !widget.forceSimulated)
                                      ? null
                                      : pal.infoBlueBg,
                              icon: Icons.auto_awesome_outlined,
                            ),
                            if (widget.engineStatus?.realProviderEnabled ==
                                    true &&
                                widget.onToggleForceSimulated != null)
                              PlannerChoicePill(
                                key: const Key('adv_toggle_simulated_pill'),
                                label: widget.forceSimulated
                                    ? 'Usar OpenAI real'
                                    : 'Cambiar a simulado',
                                selected: widget.forceSimulated,
                                onTap: () => widget.onToggleForceSimulated!(
                                    !widget.forceSimulated),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Planificación Pedagógica Detallada',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    key: const Key('advanced_to_quick_button'),
                    onPressed: () =>
                        widget.onSwitchToQuick(_currentRequest()),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: pal.border),
                      foregroundColor: pal.textPrimary,
                    ),
                    icon: const Icon(Icons.flash_on_outlined, size: 17),
                    label: Text(
                      'Modo rápido',
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                const SizedBox(height: 16),
              ],

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildLeftColumn(pal)),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: _buildRightColumn(pal)),
                  ],
                )
              else ...[
                _buildLeftColumn(pal),
                const SizedBox(height: 16),
                _buildRightColumn(pal),
              ],

              const SizedBox(height: 20),
              if (widget.generationError != null &&
                  widget.generationError!.trim().isNotEmpty) ...[
                PlannerNoticeBanner(
                  key: const Key('adv_generation_error_banner'),
                  title:
                      'No se pudo generar la propuesta (tu configuración sigue protegida)',
                  message: widget.generationError!,
                  icon: Icons.error_outline,
                  color: Colors.redAccent,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 12),
              ],
              // Footer acciones
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.surface,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(
                    color: distributionValid ? pal.border : pal.amber,
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: widget.isGenerating ? null : widget.onCancel,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: pal.textSecondary,
                      ),
                      child: Text(
                        'Cancelar y volver',
                        style: GoogleFonts.montserrat(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!distributionValid)
                          PlannerBadge(
                            label:
                                'Ajusta la distribución de niveles al total (${_request.participantsCount})',
                            color: pal.amber,
                            backgroundColor: pal.amberBg,
                            icon: Icons.warning_amber_rounded,
                          )
                        else
                          PlannerBadge(
                            label:
                                '${_request.selectedMovements.length} movimientos FIU · ${_request.selectedResources.length} recursos',
                            color: pal.textSecondary,
                          ),
                        if (widget.onGenerateWithEngine != null) ...[
                          OutlinedButton.icon(
                            key: const Key('advanced_create_draft_button'),
                            onPressed: (distributionValid && !widget.isGenerating)
                                ? () =>
                                    widget.onCreateLocalDraft(_currentRequest())
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              side: BorderSide(color: pal.border),
                              foregroundColor: pal.textPrimary,
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              'Borrador manual',
                              style: GoogleFonts.montserrat(
                                  fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          ElevatedButton.icon(
                            key: const Key('advanced_generate_v2_button'),
                            onPressed:
                                (distributionValid && !widget.isGenerating)
                                    ? () => widget.onGenerateWithEngine!(
                                          _currentRequest(),
                                        )
                                    : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              backgroundColor: pal.accent,
                              foregroundColor: pal.onAccent,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            icon: widget.isGenerating
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: pal.onAccent,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(
                              widget.isGenerating
                                  ? 'Generando propuesta...'
                                  : (widget.generationError != null
                                      ? 'Reintentar generación'
                                      : 'Generar propuesta'),
                              style: GoogleFonts.montserrat(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ] else
                          ElevatedButton.icon(
                            key: const Key('advanced_create_draft_button'),
                            onPressed: distributionValid
                                ? () =>
                                    widget.onCreateLocalDraft(_currentRequest())
                                : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              backgroundColor: pal.accent,
                              foregroundColor: pal.onAccent,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn(PlannerPalette pal) {
    final realGroup = _selectedRealGroup;
    final exp = _request.experienceDistribution;
    final delta = _request.experienceDistributionDelta;
    final distributionValid = _request.isExperienceDistributionValid;
    final customObjectives = _request.objectives
        .where((o) => !_suggestedObjectives.contains(o))
        .toList();

    return Column(
      children: [
        _AdvSection(
          title: '1. Grupo, edades y niveles reales',
          icon: Icons.groups_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PlannerChoicePill(
                    label: 'Grupo real',
                    icon: Icons.class_outlined,
                    selected:
                        _request.groupSource == PlannerGroupSource.realClass,
                    onTap: () {
                      if (widget.groups.isNotEmpty) {
                        _applyGroup(realGroup ?? widget.groups.first);
                      }
                    },
                  ),
                  PlannerChoicePill(
                    label: 'Configuración manual',
                    icon: Icons.edit_note,
                    selected:
                        _request.groupSource == PlannerGroupSource.manual,
                    onTap: () => setState(() {
                      _request = _request.copyWith(
                        groupSource: PlannerGroupSource.manual,
                        clearRealClaseId: true,
                        clearContinuity: true,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_request.groupSource == PlannerGroupSource.realClass &&
                  widget.groups.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in widget.groups)
                      PlannerChoicePill(
                        key: Key('adv_group_${g.id}'),
                        label: '${g.name} (${g.scheduleSummary})',
                        selected: _request.realClaseId == g.id,
                        onTap: () => _applyGroup(g),
                      ),
                  ],
                ),
                if (realGroup != null &&
                    realGroup.observedCordasSummary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Cordas informativas del grupo (solo referencia, no determinan nivel técnico):',
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5,
                      color: pal.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry
                          in realGroup.observedCordasSummary.entries)
                        PlannerBadge(
                          label: '${entry.key}: ${entry.value}',
                          color: pal.textSecondary,
                        ),
                    ],
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _groupNameCtrl,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: pal.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Nombre del grupo',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final aud in PlannerAudienceType.values)
                      PlannerChoicePill(
                        key: Key('adv_audience_${aud.id}'),
                        label: aud.label,
                        selected: _request.audienceType == aud,
                        onTap: () {
                          setState(() {
                            _request = _request.copyWith(
                              audienceType: aud,
                              curriculumScope:
                                  PlannerCurriculumScope.suggestedForAudience(
                                      aud),
                            );
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  PlannerStepperField(
                    label: 'Edad mín.',
                    value: _request.ageMin,
                    suffix: 'a',
                    min: 3,
                    max: 80,
                    onChanged: (v) => setState(() {
                      _request = _request.copyWith(
                        ageMin: v,
                        ageMax: _request.ageMax < v ? v : _request.ageMax,
                      );
                    }),
                  ),
                  PlannerStepperField(
                    label: 'Edad máx.',
                    value: _request.ageMax,
                    suffix: 'a',
                    min: _request.ageMin,
                    max: 90,
                    onChanged: (v) => setState(() {
                      _request = _request.copyWith(ageMax: v);
                    }),
                  ),
                  PlannerStepperField(
                    key: const Key('adv_participants_stepper'),
                    label: 'Alumnos',
                    value: _request.participantsCount,
                    min: 1,
                    max: 60,
                    onChanged: (v) => setState(() {
                      _request = _request.copyWith(participantsCount: v);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Distribución de experiencia (debe sumar ${_request.participantsCount} alumnos)',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  PlannerBadge(
                    key: const Key('adv_distribution_status_badge'),
                    label: distributionValid
                        ? 'Suma exacta: ${exp.total} / ${_request.participantsCount}'
                        : (delta < 0
                            ? 'Faltan ${delta.abs()} alumnos (${exp.total}/${_request.participantsCount})'
                            : 'Sobran $delta alumnos (${exp.total}/${_request.participantsCount})'),
                    color: distributionValid ? pal.accent : pal.amber,
                    backgroundColor:
                        distributionValid ? null : pal.amberBg,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  PlannerStepperField(
                    key: const Key('adv_exp_principiantes'),
                    label: 'Principiantes',
                    value: exp.principiantes,
                    onChanged: (v) => setState(() {
                      _request = _request.copyWith(
                        experienceDistribution: exp.copyWith(
                            principiantes: v, manuallyConfirmed: true),
                      );
                    }),
                  ),
                  PlannerStepperField(
                    key: const Key('adv_exp_intermedios'),
                    label: 'Intermedios',
                    value: exp.intermedios,
                    onChanged: (v) => setState(() {
                      _request = _request.copyWith(
                        experienceDistribution: exp.copyWith(
                            intermedios: v, manuallyConfirmed: true),
                      );
                    }),
                  ),
                  PlannerStepperField(
                    key: const Key('adv_exp_avanzados'),
                    label: 'Avanzados',
                    value: exp.avanzados,
                    onChanged: (v) => setState(() {
                      _request = _request.copyWith(
                        experienceDistribution: exp.copyWith(
                            avanzados: v, manuallyConfirmed: true),
                      );
                    }),
                  ),
                ],
              ),
              if (!distributionValid) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('adv_adjust_distribution_button'),
                  onPressed: _adjustDistributionToTotal,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    side: BorderSide(color: pal.amber),
                    foregroundColor: pal.amber,
                  ),
                  icon: const Icon(Icons.balance_outlined, size: 16),
                  label: Text(
                    'Ajustar al total (${_request.participantsCount})',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Programa o enfoque curricular',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final scope in PlannerCurriculumScope.values)
                    PlannerChoicePill(
                      key: Key('adv_scope_${scope.id}'),
                      label: scope.teacherLabel,
                      selected: _request.curriculumScope == scope,
                      onTap: () {
                        setState(() {
                          _request = _request.copyWith(
                            curriculumScope: scope,
                            selectedMovements:
                                scope == PlannerCurriculumScope.adultoFiu
                                    ? _request.selectedMovements
                                    : const [],
                          );
                        });
                      },
                    ),
                ],
              ),
              if (_request.curriculumScope ==
                  PlannerCurriculumScope.adultoFiu) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Corda de referencia (1–6):',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pal.textSecondary,
                      ),
                    ),
                    for (int idx = 1; idx <= 6; idx++)
                      PlannerChoicePill(
                        label: '$idxª',
                        selected: _request.targetAdultoCordaIndex == idx,
                        onTap: () => setState(() {
                          _request =
                              _request.copyWith(targetAdultoCordaIndex: idx);
                        }),
                      ),
                  ],
                ),
              ] else if (_request.curriculumScope ==
                  PlannerCurriculumScope.mixedNoOfficialTrack) ...[
                const SizedBox(height: 10),
                PlannerNoticeBanner(
                  title: 'Grupo mixto: sin asignación automática a Adulto FIU',
                  message:
                      'Las clases mixtas combinan edades distintas y no aplican automáticamente el currículo adulto.',
                  color: pal.amber,
                  backgroundColor: pal.amberBg,
                ),
              ] else if (_request.curriculumScope ==
                  PlannerCurriculumScope.infantilFiuPending) ...[
                const SizedBox(height: 10),
                PlannerNoticeBanner(
                  title: 'Programa Infantil en preparación',
                  message:
                      'No se usarán técnicas adultas de forma automática. La clase se enfoca en juegos, ritmo por edad y tus recursos.',
                  color: pal.amber,
                  backgroundColor: pal.amberBg,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        _AdvSection(
          title: '2. Duración, enfoques, objetivos e instrucciones',
          icon: Icons.timer_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final d in _presetDurations)
                    PlannerChoicePill(
                      label: '$d min',
                      selected: _request.durationMin == d,
                      onTap: () {
                        setState(() {
                          _request = _request.copyWith(durationMin: d);
                          _customDurationCtrl.text = d.toString();
                        });
                      },
                    ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _customDurationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final n = int.tryParse(val);
                        if (n != null && n >= 20 && n <= 180) {
                          setState(() {
                            _request = _request.copyWith(durationMin: n);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Enfoques de la sesión (múltiples)',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in kPlannerFocusOptions)
                    PlannerChoicePill(
                      key: Key('adv_focus_$f'),
                      label: f,
                      selected: _request.focuses.contains(f),
                      onTap: () => _toggleFocus(f),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Objetivos pedagógicos de la sesión',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final obj in _suggestedObjectives)
                    PlannerChoicePill(
                      label: obj,
                      selected: _request.objectives.contains(obj),
                      onTap: () {
                        final next = List<String>.from(_request.objectives);
                        if (!next.contains(obj)) {
                          next.add(obj);
                        } else if (next.length > 1) {
                          next.remove(obj);
                        }
                        setState(() {
                          _request = _request.copyWith(objectives: next);
                        });
                      },
                    ),
                  for (final custom in customObjectives)
                    PlannerChoicePill(
                      label: '$custom ×',
                      selected: true,
                      onTap: () {
                        final next = List<String>.from(_request.objectives);
                        if (next.length > 1) {
                          next.remove(custom);
                          setState(() {
                            _request = _request.copyWith(objectives: next);
                          });
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('adv_custom_objective_field'),
                      controller: _customObjectiveCtrl,
                      onSubmitted: (_) => _addCustomObjective(),
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, color: pal.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Añadir objetivo personalizado',
                        hintText: 'Ej. Conectar meia lua con salida lateral',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('adv_add_objective_button'),
                    onPressed: _addCustomObjective,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      backgroundColor: pal.accent,
                      foregroundColor: pal.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      'Añadir',
                      style: GoogleFonts.montserrat(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Materiales confirmados y musicalidad (no se asumen si no los marcas)',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mat in _availableMaterials)
                    PlannerChoicePill(
                      label: mat,
                      selected: _request.materials.contains(mat),
                      onTap: () {
                        final next = List<String>.from(_request.materials);
                        if (!next.contains(mat)) {
                          next.add(mat);
                        } else {
                          next.remove(mat);
                        }
                        setState(() {
                          _request = _request.copyWith(
                            materials: next,
                            materialsConfirmed: true,
                          );
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Condiciones del espacio e instructores',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sz in const ['desconocido', 'amplio', 'mediano', 'reducido'])
                    PlannerChoicePill(
                      key: Key('adv_space_size_$sz'),
                      label: sz == 'desconocido' ? 'Espacio sin confirmar' : 'Espacio $sz',
                      selected: _request.spaceContext.spaceSize == sz,
                      onTap: () => setState(() {
                        _request = _request.copyWith(
                          spaceContext: _request.spaceContext.copyWith(spaceSize: sz),
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final fl in const ['desconocido', 'tatami', 'madera', 'cemento'])
                    PlannerChoicePill(
                      key: Key('adv_space_floor_$fl'),
                      label: fl == 'desconocido' ? 'Piso sin confirmar' : 'Piso: $fl',
                      selected: _request.spaceContext.floorType == fl,
                      onTap: () => setState(() {
                        _request = _request.copyWith(
                          spaceContext: _request.spaceContext.copyWith(floorType: fl),
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlannerChoicePill(
                    key: const Key('adv_mats_unknown'),
                    label: 'Colchonetas: sin confirmar',
                    selected: _request.spaceContext.availableMats == null,
                    onTap: () => setState(() {
                      _request = _request.copyWith(
                        spaceContext: _request.spaceContext.copyWith(clearAvailableMats: true),
                      );
                    }),
                  ),
                  PlannerChoicePill(
                    key: const Key('adv_mats_yes'),
                    label: 'Colchonetas: Sí',
                    selected: _request.spaceContext.availableMats == true,
                    onTap: () => setState(() {
                      _request = _request.copyWith(
                        spaceContext: _request.spaceContext.copyWith(availableMats: true),
                      );
                    }),
                  ),
                  PlannerChoicePill(
                    key: const Key('adv_mats_no'),
                    label: 'Colchonetas: No',
                    selected: _request.spaceContext.availableMats == false,
                    onTap: () => setState(() {
                      _request = _request.copyWith(
                        spaceContext: _request.spaceContext.copyWith(availableMats: false),
                      );
                    }),
                  ),
                  PlannerStepperField(
                    key: const Key('adv_instructors_stepper'),
                    label: 'Instructores',
                    value: _request.spaceContext.instructorsAvailable,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() {
                      _request = _request.copyWith(
                        spaceContext:
                            _request.spaceContext.copyWith(instructorsAvailable: v),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _request.includeMusicalityRoda,
                onChanged: (v) => setState(() {
                  _request = _request.copyWith(includeMusicalityRoda: v);
                }),
                title: Text(
                  'Incluir bloque de Musicalidad y Roda',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Instrucciones libres destacadas y bien visibles
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.surfaceTint,
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  border: Border.all(color: pal.accent.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note_rounded,
                            size: 18, color: pal.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Instrucciones y contexto para la clase',
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: pal.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('adv_free_instructions_field'),
                      controller: _instructionsCtrl,
                      maxLines: 4,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: pal.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Describe qué quieres priorizar hoy, cuidados de seguridad, ritmo de la sesión o dinámica de parejas...',
                        filled: true,
                        fillColor: pal.background,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(PlannerPalette pal) {
    final canPickAdultoFiu =
        _request.curriculumScope == PlannerCurriculumScope.adultoFiu;
    final categories = <String>{
      'Todas',
      ...widget.resources.map((r) => r.category),
    }.toList();

    final filteredResources = widget.resources.where((res) {
      final q = _resourcesSearchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          res.title.toLowerCase().contains(q) ||
          res.notes.toLowerCase().contains(q) ||
          res.category.toLowerCase().contains(q);
      final matchMedia = _resourcesMediaFilter == 'Todos' ||
          res.mediaLabel == _resourcesMediaFilter;
      final matchCategory = _resourcesCategoryFilter == 'Todas' ||
          res.category == _resourcesCategoryFilter;
      return matchQuery && matchMedia && matchCategory;
    }).toList();

    return Column(
      children: [
        // Origen 1: Currículo Oficial FIU
        _AdvSection(
          title: '3. Contenido curricular FIU verificado',
          icon: Icons.verified_outlined,
          trailing: const PlannerOriginBadge(
              origin: ContentOrigin.officialFiuCurriculum),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('adv_open_curriculum_picker'),
                  onPressed: canPickAdultoFiu ? _openCurriculumSelector : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: pal.accent,
                    foregroundColor: pal.onAccent,
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(
                    canPickAdultoFiu
                        ? 'Seleccionar movimientos en Biblioteca FIU'
                        : 'Disponible al elegir alcance Adulto FIU',
                    style: GoogleFonts.montserrat(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_request.selectedMovements.isEmpty)
                Text(
                  'Ningún movimiento curricular fijado manualmente aún.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: pal.textSecondary,
                  ),
                )
              else
                for (final mov in _request.selectedMovements)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: pal.background,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(color: pal.border),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mov.item.canonicalName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                              Text(
                                mov.item.category.labelEs,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            PlannerChoicePill(
                              label: 'Obligatorio',
                              selected:
                                  mov.priority == ResourcePriority.required,
                              onTap: () => _toggleMovementPriority(
                                  mov.item.movementId,
                                  ResourcePriority.required),
                            ),
                            PlannerChoicePill(
                              label: 'Opcional',
                              selected:
                                  mov.priority == ResourcePriority.optional,
                              onTap: () => _toggleMovementPriority(
                                  mov.item.movementId,
                                  ResourcePriority.optional),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Origen 2: Recursos de mi Pizarra
        _AdvSection(
          title: '4. Recursos de mi Pizarra',
          icon: Icons.video_library_outlined,
          trailing: const PlannerOriginBadge(
              origin: ContentOrigin.teacherResource),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('adv_resources_search_field'),
                controller: _resourcesSearchCtrl,
                onChanged: (v) => setState(() => _resourcesSearchQuery = v),
                style: GoogleFonts.montserrat(
                    fontSize: 12.5, color: pal.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: pal.textSecondary),
                  hintText: 'Buscar por título, nota o categoría...',
                  isDense: true,
                  suffixIcon: _resourcesSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _resourcesSearchCtrl.clear();
                            setState(() => _resourcesSearchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final media in const [
                    'Todos',
                    'Video',
                    'Imagen',
                    'Enlace',
                    'Nota',
                  ])
                    PlannerChoicePill(
                      key: Key('adv_res_media_$media'),
                      label: media,
                      selected: _resourcesMediaFilter == media,
                      onTap: () =>
                          setState(() => _resourcesMediaFilter = media),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final cat in categories)
                    PlannerChoicePill(
                      label: cat,
                      selected: _resourcesCategoryFilter == cat,
                      onTap: () =>
                          setState(() => _resourcesCategoryFilter = cat),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (filteredResources.isEmpty)
                Text(
                  'Ningún recurso coincide con la búsqueda.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: pal.textSecondary,
                  ),
                )
              else
                for (final res in filteredResources) ...[
                  Builder(
                    builder: (_) {
                      final selected = _request.selectedResources
                          .where((r) => r.resource.resourceId == res.resourceId)
                          .firstOrNull;
                      final isSelected = selected != null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? pal.surfaceTint : pal.background,
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(
                            color: isSelected ? pal.accent : pal.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  key: Key('adv_resource_${res.resourceId}'),
                                  value: isSelected,
                                  activeColor: pal.accent,
                                  onChanged: (_) => _toggleResource(res),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        res.title,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: pal.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${res.mediaLabel} · ${res.category} · ${res.audienceLabel}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: pal.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  PlannerChoicePill(
                                    key: Key(
                                        'adv_res_req_${res.resourceId}'),
                                    label: 'Obligatorio',
                                    selected: selected.priority ==
                                        ResourcePriority.required,
                                    onTap: () => _toggleResourcePriority(
                                      res.resourceId,
                                      ResourcePriority.required,
                                    ),
                                  ),
                                  PlannerChoicePill(
                                    key: Key(
                                        'adv_res_opt_${res.resourceId}'),
                                    label: 'Opcional',
                                    selected: selected.priority ==
                                        ResourcePriority.optional,
                                    onTap: () => _toggleResourcePriority(
                                      res.resourceId,
                                      ResourcePriority.optional,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: Key(
                                    'adv_resource_usage_${res.resourceId}'),
                                controller: _usageCtrlFor(selected),
                                onChanged: (val) => _updateResourceUsageNote(
                                    res.resourceId, val),
                                style: GoogleFonts.montserrat(
                                    fontSize: 12, color: pal.textPrimary),
                                decoration: const InputDecoration(
                                  labelText:
                                      '¿Cómo quieres usar este recurso en clase?',
                                  hintText:
                                      'Ej. Usarlo como calentamiento en parejas de 5 min',
                                  isDense: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Origen 3: Propuestas complementarias IA
        _AdvSection(
          title: '5. Propuestas complementarias y privacidad',
          icon: Icons.auto_awesome_outlined,
          trailing: const PlannerOriginBadge(
              origin: ContentOrigin.aiComplementaryProposal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _request.allowAiComplementaryProposals,
                onChanged: (v) => setState(() {
                  _request =
                      _request.copyWith(allowAiComplementaryProposals: v);
                }),
                title: Text(
                  'Permitir ejercicios complementarios sugeridos por IA',
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Se mostrarán diferenciados del currículo oficial FIU y de tus recursos.',
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    color: pal.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PlannerNoticeBanner(
                title: 'Privacidad del grupo protegida',
                message:
                    'No se envían nombres, fechas de nacimiento ni datos personales de tus alumnos. Cuando se active la asistencia IA, los permisos y el currículo oficial se validarán de forma segura.',
                icon: Icons.shield_outlined,
                color: pal.infoBlue,
                backgroundColor: pal.infoBlueBg,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;

  const _AdvSection({
    required this.title,
    required this.icon,
    this.trailing,
    required this.child,
  });

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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: pal.accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

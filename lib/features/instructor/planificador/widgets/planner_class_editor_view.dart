import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/curriculum_repository.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../models/class_plan_models.dart';
import '../models/copilot_models.dart';
import '../services/class_plan_editor_operations.dart';
import '../services/copilot_operation_applier.dart';
import '../services/planner_copilot_client.dart';
import '../theme/planner_palette.dart';
import 'planner_copilot_panel.dart';
import 'planner_exercise_editor_panel.dart';
import 'planner_shared_widgets.dart';

/// Editor Pedagógico de Clases V2 (PED-04B2 / PED-04C3).
/// Soporta clases creadas desde cero, borradores V2 y planes V1 heredados,
/// con control permanente de tiempos, edición contextual y Copiloto IA.
class PlannerClassEditorView extends StatefulWidget {
  final ClassPlanModel initialPlan;
  final bool isDuplicateCopy;
  final List<PlannerResourceItem> resources;
  final CurriculumRepository? curriculumRepository;
  final Map<String, String> movementNamesById;
  final PlannerCopilotClient? copilotClient;
  final Future<PlannerResourceItem?> Function()? onCreateLocalResource;
  final ValueChanged<PlannerResourceItem>? onOpenResource;
  final ValueChanged<ClassPlanModel> onSavePlan;
  final VoidCallback onCancel;

  const PlannerClassEditorView({
    super.key,
    required this.initialPlan,
    this.isDuplicateCopy = false,
    this.resources = const [],
    this.curriculumRepository,
    this.movementNamesById = const {},
    this.copilotClient,
    this.onCreateLocalResource,
    this.onOpenResource,
    required this.onSavePlan,
    required this.onCancel,
  });

  @override
  State<PlannerClassEditorView> createState() => _PlannerClassEditorViewState();
}

class _PlannerClassEditorViewState extends State<PlannerClassEditorView> {
  late ClassPlanModel _plan;
  late bool _isDuplicateCopy;
  late TextEditingController _titleCtrl;
  late TextEditingController _enfoqueCtrl;
  late TextEditingController _groupNameCtrl;
  late TextEditingController _consejosCtrl;
  final TextEditingController _objectiveInputCtrl = TextEditingController();
  final Map<String, TextEditingController> _blockNameCtrls = {};

  String? _selectedBlockId;
  String? _selectedExerciseId;
  bool _metadataExpanded = false;
  bool _showTimingWarnings = false;
  final Set<String> _collapsedBlockIds = {};

  bool _copilotOpen = false;
  List<CopilotChatMessage> _copilotMessages = const [];
  final List<ClassPlanModel> _copilotUndoStack = [];
  final ValueNotifier<int> _copilotSheetTick = ValueNotifier<int>(0);

  late Map<String, String> _movementNamesById;
  late List<PlannerResourceItem> _resources;

  static const List<int> _presetDurations = [45, 60, 75, 90];
  static const List<String> _suggestedPhases = [
    'Calentamiento',
    'Técnica y progresiones',
    'Acrobacias y movimientos de suelo',
    'Juegos y dinámicas de capoeira',
    'Roda y musicalidad',
    'Vuelta a la calma y cierre',
  ];

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _isDuplicateCopy = widget.isDuplicateCopy;
    _movementNamesById = Map<String, String>.from(widget.movementNamesById);
    _resources = List<PlannerResourceItem>.from(widget.resources);

    final totalExercises =
        _plan.bloques.fold<int>(0, (acc, b) => acc + b.ejercicios.length);
    _metadataExpanded = totalExercises == 0;

    _titleCtrl = TextEditingController(text: _plan.titulo);
    _enfoqueCtrl = TextEditingController(text: _plan.enfoque);
    _groupNameCtrl = TextEditingController(text: _plan.groupName);
    _consejosCtrl = TextEditingController(text: _plan.consejosInstructor ?? '');
    _syncBlockControllers();
    _loadCurriculumNames();
    _loadSavedCopilotSessionIfDemo();
  }

  Future<void> _loadSavedCopilotSessionIfDemo() async {
    final client = widget.copilotClient;
    if (client == null || _plan.id != 'v2_plan_infantil_8of8_demo') return;
    final saved = await client.fetchSavedPreviewSession(plan: _plan);
    if (!mounted || saved.isEmpty || _copilotMessages.isNotEmpty) return;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    setState(() {
      _copilotMessages = saved;
      if (isDesktop) {
        _copilotOpen = true;
      }
      _copilotSheetTick.value++;
    });
  }

  @override
  void didUpdateWidget(covariant PlannerClassEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPlan.id != widget.initialPlan.id) {
      _plan = widget.initialPlan;
      _isDuplicateCopy = widget.isDuplicateCopy;
      _selectedBlockId = null;
      _selectedExerciseId = null;
      _titleCtrl.text = _plan.titulo;
      _enfoqueCtrl.text = _plan.enfoque;
      _groupNameCtrl.text = _plan.groupName;
      _consejosCtrl.text = _plan.consejosInstructor ?? '';
      _syncBlockControllers();
    }
  }

  Future<void> _loadCurriculumNames() async {
    final repo = widget.curriculumRepository;
    if (repo == null) return;
    try {
      final movements = await repo.queryMovements();
      if (!mounted) return;
      setState(() {
        for (final m in movements) {
          _movementNamesById[m.movementId] = m.canonicalName;
        }
      });
    } catch (_) {
      // Tolerante si se usa sin repositorio cargado
    }
  }

  void _syncBlockControllers() {
    final activeIds = _plan.bloques.map((b) => b.blockId).toSet();
    _blockNameCtrls.removeWhere((id, ctrl) {
      if (!activeIds.contains(id)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });
    for (final b in _plan.bloques) {
      final existing = _blockNameCtrls[b.blockId];
      if (existing == null) {
        _blockNameCtrls[b.blockId] = TextEditingController(text: b.fase);
      } else if (existing.text != b.fase) {
        existing.text = b.fase;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _enfoqueCtrl.dispose();
    _groupNameCtrl.dispose();
    _consejosCtrl.dispose();
    _objectiveInputCtrl.dispose();
    _copilotSheetTick.dispose();
    for (final ctrl in _blockNameCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  PlannerCopilotClient get _effectiveCopilotClient =>
      widget.copilotClient ?? OfflineSimulatedPlannerCopilotClient();

  void _syncMetadataControllers(ClassPlanModel plan) {
    _titleCtrl.text = plan.titulo;
    _enfoqueCtrl.text = plan.enfoque;
    _groupNameCtrl.text = plan.groupName;
    _consejosCtrl.text = plan.consejosInstructor ?? '';
  }

  void _applyCopilotProposal(CopilotChatMessage msg) {
    final proposal = msg.response;
    if (proposal == null) return;
    try {
      final applied = CopilotOperationApplier.applyProposal(
        currentPlan: _plan,
        proposal: proposal,
        availableResources: _resources,
      );
      setState(() {
        _copilotUndoStack.add(_plan);
        _plan = applied;
        _syncMetadataControllers(applied);
        _syncBlockControllers();
        _copilotMessages = [
          for (final m in _copilotMessages)
            if (m.id == msg.id)
              m.copyWith(resolution: CopilotProposalResolution.applied)
            else
              m,
        ];
        _copilotSheetTick.value++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Cambios del Copiloto aplicados al borrador (puedes usar Deshacer IA).',
          ),
          backgroundColor: PlannerPalette.of(context).accent,
        ),
      );
    } on CopilotDraftConflictException catch (e) {
      setState(() {
        _copilotMessages = [
          for (final m in _copilotMessages)
            if (m.id == msg.id)
              m.copyWith(
                resolution: CopilotProposalResolution.staleConflict,
                conflictNotice: e.message,
              )
            else
              m,
        ];
        _copilotSheetTick.value++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: PlannerPalette.of(context).amber,
        ),
      );
    }
  }

  void _undoLastCopilotApply() {
    if (_copilotUndoStack.isEmpty) return;
    final previous = _copilotUndoStack.removeLast();
    setState(() {
      _plan = previous;
      _syncMetadataControllers(previous);
      _syncBlockControllers();
      var marked = false;
      final reversed = _copilotMessages.reversed.toList();
      for (var i = 0; i < reversed.length; i++) {
        if (!marked &&
            reversed[i].resolution == CopilotProposalResolution.applied) {
          reversed[i] = reversed[i].copyWith(
            resolution: CopilotProposalResolution.undone,
          );
          marked = true;
        }
      }
      _copilotMessages = reversed.reversed.toList();
      _copilotSheetTick.value++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Último cambio del Copiloto revertido.'),
        backgroundColor: PlannerPalette.of(context).infoBlue,
      ),
    );
  }

  Future<void> _toggleOrOpenCopilot() async {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    if (isDesktop) {
      setState(() {
        _copilotOpen = !_copilotOpen;
      });
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: ValueListenableBuilder<int>(
          valueListenable: _copilotSheetTick,
          builder: (_, __, ___) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: PlannerCopilotPanel(
              currentPlan: _plan,
              currentDraftVersion: computeDraftVersion(_plan),
              selectedBlock: _selectedPair?.block,
              selectedExercise: _selectedPair?.exercise,
              availableResources: _resources,
              copilotClient: _effectiveCopilotClient,
              messages: _copilotMessages,
              onMessagesChanged: (next) {
                setState(() {
                  _copilotMessages = next;
                  _copilotSheetTick.value++;
                });
              },
              onApplyProposal: _applyCopilotProposal,
              canUndo: _copilotUndoStack.isNotEmpty,
              onUndoLastApply: _undoLastCopilotApply,
              onClose: () => Navigator.of(sheetCtx).pop(),
            ),
          ),
        ),
      ),
    );
  }

  void _applyPlanUpdate(ClassPlanModel nextPlan) {
    setState(() {
      _plan = nextPlan;
      _syncBlockControllers();
      if (_selectedBlockId != null && _selectedExerciseId != null) {
        final stillExists = _plan.bloques.any(
          (b) =>
              b.blockId == _selectedBlockId &&
              b.ejercicios.any((e) => e.exerciseId == _selectedExerciseId),
        );
        if (!stillExists) {
          _selectedBlockId = null;
          _selectedExerciseId = null;
        }
      }
    });
  }

  void _addObjective() {
    final text = _objectiveInputCtrl.text.trim();
    if (text.isEmpty) return;
    if (!_plan.objetivos.contains(text)) {
      _applyPlanUpdate(
        ClassPlanEditorOperations.updateMetadata(
          _plan,
          objetivos: [..._plan.objetivos, text],
        ),
      );
    }
    _objectiveInputCtrl.clear();
  }

  void _removeObjective(String objective) {
    final next = _plan.objetivos.where((o) => o != objective).toList();
    _applyPlanUpdate(
      ClassPlanEditorOperations.updateMetadata(_plan, objetivos: next),
    );
  }

  void _duplicateWholeClassInEditor() {
    final copy = ClassPlanEditorOperations.duplicatePlan(_plan);
    setState(() {
      _plan = copy;
      _isDuplicateCopy = true;
      _titleCtrl.text = copy.titulo;
      _enfoqueCtrl.text = copy.enfoque;
      _groupNameCtrl.text = copy.groupName;
      _consejosCtrl.text = copy.consejosInstructor ?? '';
      _selectedBlockId = null;
      _selectedExerciseId = null;
      _syncBlockControllers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Copia independiente creada. El plan original permanece intacto.',
        ),
        backgroundColor: PlannerPalette.of(context).accent,
      ),
    );
  }

  Future<void> _openExerciseEditor(
    ClassPlanBlock block,
    ClassPlanExercise exercise,
  ) async {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    if (isDesktop) {
      setState(() {
        _selectedBlockId = block.blockId;
        _selectedExerciseId = exercise.exerciseId;
        _copilotOpen = false;
      });
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PlannerExerciseEditorPanel(
          exercise: exercise,
          blockTitle: block.fase,
          audienceType: _plan.audienceType,
          curriculumScope: _plan.curriculumScope,
          curriculumRepository: widget.curriculumRepository,
          movementNamesById: _movementNamesById,
          resources: _resources,
          onCreateLocalResource: _handleCreateResourceInEditor,
          onOpenResource: widget.onOpenResource,
          onApply: (updated) {
            _applyPlanUpdate(
              ClassPlanEditorOperations.updateExercise(
                _plan,
                block.blockId,
                updated,
              ),
            );
            Navigator.of(sheetCtx).pop();
          },
          onCancel: () => Navigator.of(sheetCtx).pop(),
        ),
      ),
    );
  }

  Future<PlannerResourceItem?> _handleCreateResourceInEditor() async {
    if (widget.onCreateLocalResource == null) return null;
    final created = await widget.onCreateLocalResource!();
    if (created != null && mounted) {
      setState(() {
        _resources = [
          created,
          ..._resources.where((r) => r.resourceId != created.resourceId),
        ];
      });
    }
    return created;
  }

  void _addExerciseToBlock(ClassPlanBlock block) {
    final existingIds = _plan.bloques
        .expand((b) => b.ejercicios)
        .map((e) => e.exerciseId)
        .toSet();
    final newId = ClassPlanEditorOperations.nextId('ex_manual', existingIds);
    final blank = ClassPlanExercise.manualBlank(
      exerciseId: newId,
      nombre: 'Nuevo ejercicio',
      duracionMin: 10,
    );
    final updatedPlan =
        ClassPlanEditorOperations.addExercise(_plan, block.blockId, blank);
    _applyPlanUpdate(updatedPlan);
    final updatedBlock = updatedPlan.bloques
        .firstWhere((b) => b.blockId == block.blockId);
    _openExerciseEditor(updatedBlock, blank);
  }

  ({ClassPlanBlock block, ClassPlanExercise exercise})? get _selectedPair {
    if (_selectedBlockId == null || _selectedExerciseId == null) return null;
    for (final b in _plan.bloques) {
      if (b.blockId == _selectedBlockId) {
        for (final e in b.ejercicios) {
          if (e.exerciseId == _selectedExerciseId) {
            return (block: b, exercise: e);
          }
        }
      }
    }
    return null;
  }

  String _movementLabel(String id) {
    final found = _movementNamesById[id];
    if (found != null && found.isNotEmpty) return found;
    return id
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  PlannerResourceItem? _findResource(String id) {
    for (final r in _resources) {
      if (r.resourceId == id) return r;
    }
    return null;
  }

  void _saveCurrentPlan() {
    final cleanTitle = _titleCtrl.text.trim();
    final cleanEnfoque = _enfoqueCtrl.text.trim();
    final cleanGroup = _groupNameCtrl.text.trim();
    final cleanConsejos = _consejosCtrl.text.trim();

    final finalPlan = ClassPlanEditorOperations.updateMetadata(
      _plan,
      titulo: cleanTitle.isNotEmpty ? cleanTitle : 'Clase sin título',
      enfoque: cleanEnfoque.isNotEmpty ? cleanEnfoque : _plan.enfoque,
      groupName: cleanGroup.isNotEmpty ? cleanGroup : _plan.groupName,
      consejosInstructor: cleanConsejos.isNotEmpty ? cleanConsejos : null,
      clearConsejosInstructor: cleanConsejos.isEmpty,
    );
    widget.onSavePlan(finalPlan);
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final leftFlex = width >= 1200 ? 60 : 58;
    final rightFlex = width >= 1200 ? 40 : 42;
    final timing = ClassPlanTimingSummary.fromPlan(_plan);

    return Column(
      children: [
        _buildTopHeader(pal),
        _buildTimingBar(pal, timing),
        Expanded(
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: leftFlex,
                      child: _buildMainScrollColumn(pal, timing, 16),
                    ),
                    Container(width: 1, color: pal.border),
                    Expanded(
                      flex: rightFlex,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: _buildDesktopSidePanel(pal, timing),
                      ),
                    ),
                  ],
                )
              : _buildMainScrollColumn(pal, timing, 14),
        ),
      ],
    );
  }

  Widget _buildTopHeader(PlannerPalette pal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(bottom: BorderSide(color: pal.border)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('editor_back_button'),
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(color: pal.border),
                  foregroundColor: pal.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(
                  'Volver',
                  style: GoogleFonts.montserrat(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              PlannerChoicePill(
                key: const Key('editor_status_toggle'),
                label: _plan.planStatus == ClassPlanStatus.draft
                    ? 'Estado: Borrador'
                    : 'Estado: Guardado',
                icon: _plan.planStatus == ClassPlanStatus.draft
                    ? Icons.edit_note_rounded
                    : Icons.check_circle_outline,
                selected: _plan.planStatus == ClassPlanStatus.saved,
                onTap: () {
                  final nextStatus = _plan.planStatus == ClassPlanStatus.draft
                      ? ClassPlanStatus.saved
                      : ClassPlanStatus.draft;
                  _applyPlanUpdate(
                    ClassPlanEditorOperations.updateMetadata(
                      _plan,
                      planStatus: nextStatus,
                    ),
                  );
                },
              ),
              if (_isDuplicateCopy)
                PlannerBadge(
                  label: 'Copia independiente',
                  color: pal.infoBlue,
                  backgroundColor: pal.infoBlueBg,
                  icon: Icons.copy_all_outlined,
                ),
              PlannerBadge(
                label: _plan.curriculumScope.teacherLabel,
                color: _plan.curriculumScope == PlannerCurriculumScope.adultoFiu
                    ? pal.accent
                    : pal.amber,
                backgroundColor:
                    _plan.curriculumScope == PlannerCurriculumScope.adultoFiu
                        ? null
                        : pal.amberBg,
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('editor_copilot_toggle_button'),
                onPressed: _toggleOrOpenCopilot,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  side: BorderSide(
                    color: _copilotOpen ? pal.accent : pal.border,
                  ),
                  backgroundColor:
                      _copilotOpen ? pal.accent.withValues(alpha: 0.12) : null,
                  foregroundColor:
                      _copilotOpen ? pal.accent : pal.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: Text(
                  'Copiloto IA',
                  style: GoogleFonts.montserrat(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              if (_copilotUndoStack.isNotEmpty)
                OutlinedButton.icon(
                  key: const Key('editor_copilot_undo_button'),
                  onPressed: _undoLastCopilotApply,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    side: BorderSide(color: pal.infoBlue),
                    foregroundColor: pal.infoBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text(
                    'Deshacer IA',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              OutlinedButton.icon(
                key: const Key('editor_duplicate_plan_button'),
                onPressed: _duplicateWholeClassInEditor,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  side: BorderSide(color: pal.border),
                  foregroundColor: pal.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                label: Text(
                  'Duplicar clase',
                  style: GoogleFonts.montserrat(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('editor_save_button'),
                onPressed: _saveCurrentPlan,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: pal.accent,
                  foregroundColor: pal.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.save_outlined, size: 17),
                label: Text(
                  _plan.planStatus == ClassPlanStatus.draft
                      ? 'Guardar borrador'
                      : 'Guardar clase',
                  style: GoogleFonts.montserrat(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimingBar(PlannerPalette pal, ClassPlanTimingSummary timing) {
    final Color statusColor;
    final Color statusBg;
    final String deltaLabel;
    if (timing.remainingMinutes > 0) {
      statusColor = pal.amber;
      statusBg = pal.amberBg;
      deltaLabel = 'Faltan ${timing.remainingMinutes} min';
    } else if (timing.excessMinutes > 0) {
      statusColor = Colors.redAccent;
      statusBg = Colors.redAccent.withValues(alpha: 0.14);
      deltaLabel = 'Excede +${timing.excessMinutes} min';
    } else {
      statusColor = pal.accent;
      statusBg = pal.surfaceTint;
      deltaLabel = 'Tiempo exacto';
    }

    final ratio = timing.targetMinutes > 0
        ? (timing.plannedMinutes / timing.targetMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      key: const Key('editor_timing_bar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: pal.surfaceTint,
        border: Border(bottom: BorderSide(color: pal.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlannerBadge(
                    key: const Key('timing_target_badge'),
                    label: 'Objetivo: ${timing.targetMinutes} min',
                    color: pal.textPrimary,
                    backgroundColor: pal.background,
                    icon: Icons.flag_outlined,
                  ),
                  PlannerBadge(
                    key: const Key('timing_planned_badge'),
                    label: 'Planificado: ${timing.plannedMinutes} min',
                    color: pal.infoBlue,
                    backgroundColor: pal.infoBlueBg,
                    icon: Icons.schedule_outlined,
                  ),
                  PlannerBadge(
                    key: const Key('timing_delta_badge'),
                    label: deltaLabel,
                    color: statusColor,
                    backgroundColor: statusBg,
                    icon: timing.isExact
                        ? Icons.check_circle_outline
                        : Icons.timelapse_outlined,
                  ),
                ],
              ),
              if (timing.warnings.isNotEmpty)
                InkWell(
                  key: const Key('timing_warnings_toggle'),
                  onTap: () => setState(
                      () => _showTimingWarnings = !_showTimingWarnings),
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: pal.amberBg,
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                      border:
                          Border.all(color: pal.amber.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: pal.amber),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${timing.warnings.length} aviso(s) de tiempo (no bloquea guardado)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: pal.amber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showTimingWarnings
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: pal.amber,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.full),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: pal.border.withValues(alpha: 0.55),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          if (_showTimingWarnings && timing.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pal.background,
                borderRadius: BorderRadius.circular(GingaRadius.md),
                border: Border.all(color: pal.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in timing.warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• $w',
                        style: GoogleFonts.montserrat(
                          fontSize: 11.5,
                          color: pal.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainScrollColumn(
    PlannerPalette pal,
    ClassPlanTimingSummary timing,
    double pad,
  ) {
    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        _buildMetadataCard(pal),
        const SizedBox(height: 14),
        if (_plan.continuityContext != null &&
            _plan.continuityContext!.hasContent) ...[
          PlannerContinuityContextCard(
            contextData: _plan.continuityContext,
          ),
          const SizedBox(height: 14),
        ],
        if (_plan.generationMeta != null) ...[
          PlannerNoticeBanner(
            key: const Key('editor_generated_mode_banner'),
            title: _plan.generationMeta!.isSimulated
                ? 'Propuesta generada · Modo simulado offline (Motor V2)'
                : 'Propuesta generada · Proveedor ${_plan.generationMeta!.provider.toUpperCase()} (${_plan.generationMeta!.model})${_plan.generationMeta!.repairAttemptsUsed > 0 ? ' · ${_plan.generationMeta!.repairAttemptsUsed} reparación' : ''}',
            message: [
              ..._plan.generationMeta!.transparencyNotices,
              if (_plan.generationMeta!.continuityAppliedNote.isNotEmpty)
                _plan.generationMeta!.continuityAppliedNote,
            ].join(' · '),
            icon: Icons.auto_awesome_outlined,
            color: pal.infoBlue,
            backgroundColor: pal.infoBlueBg,
          ),
          const SizedBox(height: 12),
        ],
        if (_plan.audienceType == PlannerAudienceType.infantil) ...[
          PlannerNoticeBanner(
            title: 'Protección Curricular Infantil activa',
            message:
                'No se utiliza el currículo adulto FIU automáticamente en clases infantiles. Puedes usar dinámicas por edad y recursos de tu Pizarra.',
            icon: Icons.child_care_outlined,
            color: pal.amber,
            backgroundColor: pal.amberBg,
          ),
          const SizedBox(height: 12),
        ] else if (_plan.audienceType == PlannerAudienceType.mixto) ...[
          PlannerNoticeBanner(
            title: 'Grupo mixto sin asignación automática adulta',
            message:
                'Las clases mixtas no aplican el currículo Adulto FIU por defecto para proteger niveles e edades mixtas.',
            color: pal.amber,
            backgroundColor: pal.amberBg,
          ),
          const SizedBox(height: 12),
        ],

        // Lista de bloques editables y expandibles
        for (int bIndex = 0; bIndex < _plan.bloques.length; bIndex++)
          _buildBlockCard(pal, _plan.bloques[bIndex], bIndex),

        const SizedBox(height: 6),
        // Acciones para añadir nuevo bloque a ancho completo
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Añadir bloque a la clase',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('editor_add_block_button'),
                    onPressed: () => _applyPlanUpdate(
                      ClassPlanEditorOperations.addBlock(
                        _plan,
                        fase: 'Bloque ${_plan.bloques.length + 1}',
                        duracionMin: 10,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: pal.accent,
                      foregroundColor: pal.onAccent,
                    ),
                    icon: const Icon(Icons.add, size: 17),
                    label: Text(
                      'Añadir bloque',
                      style: GoogleFonts.montserrat(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final phase in _suggestedPhases)
                    PlannerChoicePill(
                      label: '+ $phase',
                      selected: false,
                      onTap: () => _applyPlanUpdate(
                        ClassPlanEditorOperations.addBlock(
                          _plan,
                          fase: phase,
                          duracionMin: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(PlannerPalette pal) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('editor_metadata_toggle'),
            onTap: () =>
                setState(() => _metadataExpanded = !_metadataExpanded),
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _plan.titulo,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_plan.groupName} · ${_plan.audienceType.label} · ${_plan.duracionTotal} min objetivo · ${_plan.objetivos.length} objetivo(s)',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: _metadataExpanded
                        ? 'Contraer datos de la clase'
                        : 'Editar datos de la clase',
                    child: Icon(
                      _metadataExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: pal.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_metadataExpanded) ...[
            Divider(height: 1, color: pal.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PlannerFieldLabel('Título de la clase'),
                  TextField(
                    key: const Key('editor_title_field'),
                    controller: _titleCtrl,
                    onChanged: (v) => _applyPlanUpdate(
                      ClassPlanEditorOperations.updateMetadata(
                        _plan,
                        titulo: v,
                      ),
                    ),
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText: 'Nombre o tema central de la clase',
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final groupField = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PlannerFieldLabel('Grupo'),
                          TextField(
                            controller: _groupNameCtrl,
                            onChanged: (v) => _applyPlanUpdate(
                              ClassPlanEditorOperations.updateMetadata(
                                _plan,
                                groupName: v,
                              ),
                            ),
                            style: GoogleFonts.montserrat(
                                fontSize: 13, color: pal.textPrimary),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Ej. Adultos M/J 19:00',
                              isDense: true,
                            ),
                          ),
                        ],
                      );
                      final enfoqueField = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PlannerFieldLabel('Enfoque'),
                          TextField(
                            controller: _enfoqueCtrl,
                            onChanged: (v) => _applyPlanUpdate(
                              ClassPlanEditorOperations.updateMetadata(
                                _plan,
                                enfoque: v,
                              ),
                            ),
                            style: GoogleFonts.montserrat(
                                fontSize: 13, color: pal.textPrimary),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Ej. Técnica · Secuencias',
                              isDense: true,
                            ),
                          ),
                        ],
                      );
                      if (constraints.maxWidth >= 520) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: groupField),
                            const SizedBox(width: 12),
                            Expanded(child: enfoqueField),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          groupField,
                          const SizedBox(height: 10),
                          enfoqueField,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const PlannerFieldLabel('Público objetivo'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final aud in PlannerAudienceType.values)
                        PlannerChoicePill(
                          key: Key('editor_audience_${aud.id}'),
                          label: aud.label,
                          selected: _plan.audienceType == aud,
                          onTap: () => _applyPlanUpdate(
                            ClassPlanEditorOperations.updateMetadata(
                              _plan,
                              audienceType: aud,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const PlannerFieldLabel('Duración objetivo de la clase'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PlannerStepperField(
                        key: const Key('editor_target_duration_stepper'),
                        label: 'Objetivo',
                        value: _plan.duracionTotal,
                        suffix: 'min',
                        min: 10,
                        max: 240,
                        onChanged: (v) => _applyPlanUpdate(
                          ClassPlanEditorOperations.updateMetadata(
                            _plan,
                            duracionTotal: v,
                          ),
                        ),
                      ),
                      for (final d in _presetDurations)
                        PlannerChoicePill(
                          key: Key('editor_target_dur_$d'),
                          label: '$d min',
                          selected: _plan.duracionTotal == d,
                          onTap: () => _applyPlanUpdate(
                            ClassPlanEditorOperations.updateMetadata(
                              _plan,
                              duracionTotal: d,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const PlannerFieldLabel('Objetivos pedagógicos', optional: true),
                  if (_plan.objetivos.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final obj in _plan.objetivos)
                          Chip(
                            label: Text(
                              obj,
                              style: GoogleFonts.montserrat(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: pal.textPrimary,
                              ),
                            ),
                            backgroundColor: pal.background,
                            side: BorderSide(color: pal.border),
                            onDeleted: () => _removeObjective(obj),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('editor_objective_input'),
                          controller: _objectiveInputCtrl,
                          onSubmitted: (_) => _addObjective(),
                          style: GoogleFonts.montserrat(
                              fontSize: 12.5, color: pal.textPrimary),
                          decoration: plannerInputDecoration(
                            pal,
                            hintText: 'Añadir objetivo pedagógico...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: const Key('editor_add_objective_button'),
                        onPressed: _addObjective,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          side: BorderSide(color: pal.accent),
                          foregroundColor: pal.accent,
                        ),
                        child: const Text('Añadir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const PlannerFieldLabel(
                    'Indicaciones generales del profesor',
                    optional: true,
                  ),
                  TextField(
                    controller: _consejosCtrl,
                    maxLines: 2,
                    onChanged: (v) => _applyPlanUpdate(
                      ClassPlanEditorOperations.updateMetadata(
                        _plan,
                        consejosInstructor: v.trim().isNotEmpty ? v : null,
                        clearConsejosInstructor: v.trim().isEmpty,
                      ),
                    ),
                    style: GoogleFonts.montserrat(
                        fontSize: 12.5, color: pal.textPrimary),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText: 'Recordatorios generales o pautas para todo el grupo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockCard(
    PlannerPalette pal,
    ClassPlanBlock block,
    int blockIndex,
  ) {
    final isCollapsed = _collapsedBlockIds.contains(block.blockId);
    final nameCtrl = _blockNameCtrls.putIfAbsent(
      block.blockId,
      () => TextEditingController(text: block.fase),
    );

    return Container(
      key: Key('editor_block_${block.blockId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(
          color: block.hasDurationMismatch ? pal.amber : pal.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del bloque a ancho completo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: pal.surfaceAlt,
              borderRadius: isCollapsed
                  ? BorderRadius.circular(GingaRadius.lg)
                  : const BorderRadius.vertical(
                      top: Radius.circular(GingaRadius.lg),
                    ),
              border: isCollapsed
                  ? null
                  : Border(bottom: BorderSide(color: pal.border)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tooltip(
                  message:
                      isCollapsed ? 'Expandir bloque' : 'Contraer bloque',
                  child: InkWell(
                    onTap: () => setState(() {
                      if (isCollapsed) {
                        _collapsedBlockIds.remove(block.blockId);
                      } else {
                        _collapsedBlockIds.add(block.blockId);
                      }
                    }),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          isCollapsed
                              ? Icons.chevron_right
                              : Icons.expand_more,
                          color: pal.textPrimary,
                          size: 20,
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${blockIndex + 1}',
                            style: GoogleFonts.montserrat(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: pal.onAccent,
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            block.fase,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: pal.textPrimary,
                            ),
                          ),
                        ),
                        PlannerBadge(
                          label: '${block.duracionMin} min',
                          color: pal.accent,
                        ),
                        if (block.ejercicios.isEmpty)
                          PlannerBadge(
                            label: '0 ej. · 0/${block.duracionMin} min',
                            color: pal.textSecondary,
                          )
                        else if (block.hasExerciseDurationEntries)
                          PlannerBadge(
                            label:
                                'Ejercicios: ${block.exercisesTotalDurationMin}/${block.duracionMin} min',
                            color: block.hasDurationMismatch
                                ? pal.amber
                                : pal.accent,
                            backgroundColor:
                                block.hasDurationMismatch ? pal.amberBg : null,
                          )
                        else
                          PlannerBadge(
                            label:
                                '${block.ejercicios.length} ej. (sin tiempo individual)',
                            color: pal.textSecondary,
                          ),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  spacing: 0,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (block.hasDurationMismatch)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message:
                              'Ajustar duración del bloque a la suma de sus ejercicios',
                          child: TextButton.icon(
                            key: Key('block_sync_dur_${block.blockId}'),
                            onPressed: () => _applyPlanUpdate(
                              ClassPlanEditorOperations
                                  .syncBlockDurationFromExercises(
                                _plan,
                                block.blockId,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: pal.amber,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: const Icon(Icons.sync, size: 14),
                            label: Text(
                              'Ajustar a ${block.exercisesTotalDurationMin}m',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      key: Key('block_up_${block.blockId}'),
                      icon: const Icon(Icons.arrow_upward, size: 17),
                      color: blockIndex > 0
                          ? pal.textPrimary
                          : pal.textSecondary.withValues(alpha: 0.35),
                      onPressed: blockIndex > 0
                          ? () => _applyPlanUpdate(
                                ClassPlanEditorOperations.reorderBlocks(
                                  _plan,
                                  blockIndex,
                                  blockIndex - 1,
                                ),
                              )
                          : null,
                      tooltip: 'Subir bloque',
                    ),
                    IconButton(
                      key: Key('block_down_${block.blockId}'),
                      icon: const Icon(Icons.arrow_downward, size: 17),
                      color: blockIndex < _plan.bloques.length - 1
                          ? pal.textPrimary
                          : pal.textSecondary.withValues(alpha: 0.35),
                      onPressed: blockIndex < _plan.bloques.length - 1
                          ? () => _applyPlanUpdate(
                                ClassPlanEditorOperations.reorderBlocks(
                                  _plan,
                                  blockIndex,
                                  blockIndex + 1,
                                ),
                              )
                          : null,
                      tooltip: 'Bajar bloque',
                    ),
                    IconButton(
                      key: Key('block_dup_${block.blockId}'),
                      icon: const Icon(Icons.copy_outlined, size: 17),
                      color: pal.textPrimary,
                      onPressed: () => _applyPlanUpdate(
                        ClassPlanEditorOperations.duplicateBlock(
                          _plan,
                          block.blockId,
                        ),
                      ),
                      tooltip: 'Duplicar bloque',
                    ),
                    IconButton(
                      key: Key('block_del_${block.blockId}'),
                      icon: const Icon(Icons.delete_outline, size: 17),
                      color: Colors.redAccent,
                      onPressed: () => _applyPlanUpdate(
                        ClassPlanEditorOperations.deleteBlock(
                          _plan,
                          block.blockId,
                        ),
                      ),
                      tooltip: 'Eliminar bloque',
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final blockNameField = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PlannerFieldLabel('Nombre del bloque'),
                          TextField(
                            key: Key('block_name_${block.blockId}'),
                            controller: nameCtrl,
                            onChanged: (v) => _applyPlanUpdate(
                              ClassPlanEditorOperations.updateBlock(
                                _plan,
                                block.blockId,
                                fase: v,
                              ),
                            ),
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Nombre o fase del bloque',
                              isDense: true,
                            ),
                          ),
                        ],
                      );
                      final blockDurationField = PlannerStepperField(
                        key: Key('block_dur_${block.blockId}'),
                        label: 'Duración del bloque',
                        value: block.duracionMin,
                        suffix: 'min',
                        min: 0,
                        max: 180,
                        onChanged: (v) => _applyPlanUpdate(
                          ClassPlanEditorOperations.updateBlock(
                            _plan,
                            block.blockId,
                            duracionMin: v,
                          ),
                        ),
                      );
                      if (constraints.maxWidth >= 520) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: blockNameField),
                            const SizedBox(width: 12),
                            blockDurationField,
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          blockNameField,
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: blockDurationField,
                          ),
                        ],
                      );
                    },
                  ),
                  if (block.hasDurationMismatch) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: Key('block_mismatch_banner_${block.blockId}'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: pal.amberBg,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border:
                            Border.all(color: pal.amber.withValues(alpha: 0.45)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Bloque: ${block.duracionMin} min · Suma de ejercicios: ${block.exercisesTotalDurationMin} min (${block.exerciseDurationDelta > 0 ? '+${block.exerciseDurationDelta}' : '${block.exerciseDurationDelta}'} min)',
                            style: GoogleFonts.montserrat(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: pal.amber,
                            ),
                          ),
                          Text(
                            'No modifica otros ejercicios',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (block.ejercicios.isEmpty)
                    PlannerNoticeBanner(
                      title: 'Bloque sin ejercicios aún',
                      message:
                          'Pulsa "Añadir ejercicio" para agregar actividades a este bloque.',
                      color: pal.infoBlue,
                      backgroundColor: pal.infoBlueBg,
                    )
                  else
                    for (int eIdx = 0; eIdx < block.ejercicios.length; eIdx++)
                      _buildExerciseRow(
                        pal,
                        block,
                        block.ejercicios[eIdx],
                        eIdx,
                      ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: Key('block_add_ex_${block.blockId}'),
                      onPressed: () => _addExerciseToBlock(block),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        side: BorderSide(color: pal.accent),
                        foregroundColor: pal.accent,
                      ),
                      icon: const Icon(Icons.add, size: 17),
                      label: Text(
                        'Añadir ejercicio',
                        style: GoogleFonts.montserrat(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
    PlannerPalette pal,
    ClassPlanBlock block,
    ClassPlanExercise ex,
    int exIndex,
  ) {
    final isSelected = _selectedBlockId == block.blockId &&
        _selectedExerciseId == ex.exerciseId;

    return Container(
      key: Key('editor_ex_${ex.exerciseId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? pal.surfaceTint : pal.background,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(
          color: isSelected ? pal.accent : pal.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlannerOriginBadge(origin: ex.contentOrigin),
                  PlannerBadge(
                    label: ex.duracionMin != null
                        ? '${ex.duracionMin} min'
                        : 'Sin tiempo',
                    color: ex.duracionMin != null
                        ? pal.accent
                        : pal.textSecondary,
                  ),
                  if (ex.organizacion != null && ex.organizacion!.isNotEmpty)
                    PlannerBadge(
                      label: ex.organizacion!,
                      color: pal.infoBlue,
                      backgroundColor: pal.infoBlueBg,
                      icon: Icons.groups_outlined,
                    ),
                ],
              ),
              Wrap(
                spacing: 0,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    key: Key('ex_edit_${ex.exerciseId}'),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    color: pal.accent,
                    onPressed: () => _openExerciseEditor(block, ex),
                    tooltip: 'Editar ejercicio',
                  ),
                  IconButton(
                    key: Key('ex_up_${ex.exerciseId}'),
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    color: exIndex > 0
                        ? pal.textPrimary
                        : pal.textSecondary.withValues(alpha: 0.35),
                    onPressed: exIndex > 0
                        ? () => _applyPlanUpdate(
                              ClassPlanEditorOperations.reorderExercises(
                                _plan,
                                block.blockId,
                                exIndex,
                                exIndex - 1,
                              ),
                            )
                        : null,
                    tooltip: 'Subir ejercicio',
                  ),
                  IconButton(
                    key: Key('ex_down_${ex.exerciseId}'),
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    color: exIndex < block.ejercicios.length - 1
                        ? pal.textPrimary
                        : pal.textSecondary.withValues(alpha: 0.35),
                    onPressed: exIndex < block.ejercicios.length - 1
                        ? () => _applyPlanUpdate(
                              ClassPlanEditorOperations.reorderExercises(
                                _plan,
                                block.blockId,
                                exIndex,
                                exIndex + 1,
                              ),
                            )
                        : null,
                    tooltip: 'Bajar ejercicio',
                  ),
                  IconButton(
                    key: Key('ex_dup_${ex.exerciseId}'),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    color: pal.textPrimary,
                    onPressed: () => _applyPlanUpdate(
                      ClassPlanEditorOperations.duplicateExercise(
                        _plan,
                        block.blockId,
                        ex.exerciseId,
                      ),
                    ),
                    tooltip: 'Duplicar ejercicio',
                  ),
                  IconButton(
                    key: Key('ex_del_${ex.exerciseId}'),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.redAccent,
                    onPressed: () => _applyPlanUpdate(
                      ClassPlanEditorOperations.deleteExercise(
                        _plan,
                        block.blockId,
                        ex.exerciseId,
                      ),
                    ),
                    tooltip: 'Eliminar ejercicio',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _openExerciseEditor(block, ex),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.nombre,
                  style: GoogleFonts.montserrat(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
                if (ex.detalle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ex.detalle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: pal.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (ex.curriculumMovementIds.isNotEmpty ||
              ex.technicalMovementRefs.isNotEmpty ||
              ex.internalTimings.isNotEmpty ||
              ex.linkedResourceIds.isNotEmpty ||
              ex.materiales.isNotEmpty ||
              ex.cancioneroReference != null ||
              ex.safetyNote != null ||
              ex.differentiationBeginner != null ||
              ex.differentiationIntermediate != null ||
              ex.differentiationAdvanced != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final movId in ex.curriculumMovementIds)
                  PlannerBadge(
                    label: 'FIU: ${_movementLabel(movId)}',
                    color: pal.accent,
                    icon: Icons.verified_outlined,
                  ),
                for (final tech in ex.technicalMovementRefs)
                  PlannerBadge(
                    label: 'Capoeira: $tech',
                    color: pal.textPrimary,
                    icon: Icons.sports_martial_arts_outlined,
                  ),
                if (ex.internalTimings.isNotEmpty)
                  PlannerBadge(
                    label:
                        'Etapas: ${ex.internalTimings.map((t) => '${t.minutos}m').join(' + ')}',
                    color: pal.textSecondary,
                    icon: Icons.timelapse_outlined,
                  ),
                for (final resId in ex.linkedResourceIds)
                  Builder(
                    builder: (_) {
                      final res = _findResource(resId);
                      final usageNote = ex.resourceUsageNotes[resId];
                      final badge = PlannerBadge(
                        label: usageNote != null && usageNote.isNotEmpty
                            ? '${res?.title ?? resId} · Con nota de uso'
                            : (res?.title ?? resId),
                        color: pal.infoBlue,
                        backgroundColor: pal.infoBlueBg,
                        icon: Icons.open_in_new_rounded,
                      );
                      if (res == null) return badge;
                      return Tooltip(
                        message: 'Abrir recurso: ${res.title}',
                        child: InkWell(
                          key: Key('ex_row_open_res_${ex.exerciseId}_$resId'),
                          onTap: () {
                            if (widget.onOpenResource != null) {
                              widget.onOpenResource!(res);
                            } else {
                              _openExerciseEditor(block, ex);
                            }
                          },
                          borderRadius:
                              BorderRadius.circular(GingaRadius.full),
                          child: badge,
                        ),
                      );
                    },
                  ),
                if (ex.materiales.isNotEmpty)
                  PlannerBadge(
                    label: 'Mat: ${ex.materiales.join(", ")}',
                    color: pal.textSecondary,
                  ),
                if (ex.differentiationBeginner != null ||
                    ex.differentiationIntermediate != null ||
                    ex.differentiationAdvanced != null)
                  PlannerBadge(
                    label: [
                      if (ex.differentiationBeginner != null) 'Principiantes',
                      if (ex.differentiationIntermediate != null) 'Intermedios',
                      if (ex.differentiationAdvanced != null) 'Avanzados',
                    ].join(' · '),
                    color: pal.accent,
                  ),
                if (ex.cancioneroReference != null)
                  PlannerBadge(
                    label: 'Canción: ${ex.cancioneroReference!.songTitle} (${ex.cancioneroReference!.rhythm})',
                    color: pal.infoBlue,
                    backgroundColor: pal.infoBlueBg,
                    icon: Icons.music_note_outlined,
                  ),
                if (ex.safetyNote != null)
                  PlannerBadge(
                    label: 'Seguridad',
                    color: pal.amber,
                    backgroundColor: pal.amberBg,
                    icon: Icons.health_and_safety_outlined,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopSidePanel(
    PlannerPalette pal,
    ClassPlanTimingSummary timing,
  ) {
    if (_copilotOpen) {
      return PlannerCopilotPanel(
        currentPlan: _plan,
        currentDraftVersion: computeDraftVersion(_plan),
        selectedBlock: _selectedPair?.block,
        selectedExercise: _selectedPair?.exercise,
        availableResources: _resources,
        copilotClient: _effectiveCopilotClient,
        messages: _copilotMessages,
        onMessagesChanged: (next) {
          setState(() {
            _copilotMessages = next;
            _copilotSheetTick.value++;
          });
        },
        onApplyProposal: _applyCopilotProposal,
        canUndo: _copilotUndoStack.isNotEmpty,
        onUndoLastApply: _undoLastCopilotApply,
        onClose: () => setState(() => _copilotOpen = false),
      );
    }

    final pair = _selectedPair;
    if (pair != null) {
      return PlannerExerciseEditorPanel(
        exercise: pair.exercise,
        blockTitle: pair.block.fase,
        audienceType: _plan.audienceType,
        curriculumScope: _plan.curriculumScope,
        curriculumRepository: widget.curriculumRepository,
        movementNamesById: _movementNamesById,
        resources: _resources,
        onCreateLocalResource: _handleCreateResourceInEditor,
        onOpenResource: widget.onOpenResource,
        onApply: (updated) {
          _applyPlanUpdate(
            ClassPlanEditorOperations.updateExercise(
              _plan,
              pair.block.blockId,
              updated,
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ejercicio "${updated.nombre}" actualizado.'),
              backgroundColor: pal.accent,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onCancel: () => setState(() {
          _selectedBlockId = null;
          _selectedExerciseId = null;
        }),
      );
    }

    final origins = _plan.detectedOrigins;
    final allMaterials = _plan.allExerciseMaterials;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.border),
      ),
      child: SingleChildScrollView(
        primary: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          PlannerBadge(
            label: 'Resumen contextual del editor',
            color: pal.infoBlue,
            backgroundColor: pal.infoBlueBg,
            icon: Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 10),
          Text(
            'Selecciona cualquier ejercicio para editar sus detalles',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cada bloque se organiza por fases y cada ejercicio conserva sus propios tiempos, variantes por nivel, movimientos FIU y recursos sin afectar a los demás.',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: pal.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Distribución por bloques',
            style: GoogleFonts.montserrat(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final b in timing.blockSummaries)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pal.background,
                borderRadius: BorderRadius.circular(GingaRadius.md),
                border: Border.all(
                  color: b.hasMismatch ? pal.amber : pal.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.fase,
                          style: GoogleFonts.montserrat(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          b.hasExerciseDurations
                              ? 'Bloque: ${b.blockDurationMin} min · Ejercicios: ${b.exercisesSumMin} min'
                              : 'Bloque: ${b.blockDurationMin} min',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            color: b.hasMismatch ? pal.amber : pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (b.hasMismatch)
                    TextButton(
                      onPressed: () => _applyPlanUpdate(
                        ClassPlanEditorOperations
                            .syncBlockDurationFromExercises(
                          _plan,
                          b.blockId,
                        ),
                      ),
                      child: const Text('Igualar'),
                    ),
                ],
              ),
            ),
          if (origins.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Orígenes presentes en la clase',
              style: GoogleFonts.montserrat(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: pal.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in origins) PlannerOriginBadge(origin: o),
              ],
            ),
          ],
          if (allMaterials.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Materiales de la sesión',
              style: GoogleFonts.montserrat(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: pal.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in allMaterials)
                  PlannerBadge(label: m, color: pal.textSecondary),
              ],
            ),
          ],
          ],
        ),
      ),
    );
  }
}

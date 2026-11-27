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

/// Panel contextual para editar todos los campos pedagógicos de un único ejercicio
/// sin alterar los demás ejercicios ni marcar recursos de Pizarra como utilizados.
class PlannerExerciseEditorPanel extends StatefulWidget {
  final ClassPlanExercise exercise;
  final String blockTitle;
  final PlannerAudienceType audienceType;
  final PlannerCurriculumScope curriculumScope;
  final int targetAdultoCordaIndex;
  final CurriculumRepository? curriculumRepository;
  final Map<String, String> movementNamesById;
  final List<PlannerResourceItem> resources;
  final Future<PlannerResourceItem?> Function()? onCreateLocalResource;
  final ValueChanged<PlannerResourceItem>? onOpenResource;
  final ValueChanged<ClassPlanExercise> onApply;
  final VoidCallback onCancel;

  const PlannerExerciseEditorPanel({
    super.key,
    required this.exercise,
    required this.blockTitle,
    required this.audienceType,
    required this.curriculumScope,
    this.targetAdultoCordaIndex = 3,
    this.curriculumRepository,
    this.movementNamesById = const {},
    this.resources = const [],
    this.onCreateLocalResource,
    this.onOpenResource,
    required this.onApply,
    required this.onCancel,
  });

  @override
  State<PlannerExerciseEditorPanel> createState() =>
      _PlannerExerciseEditorPanelState();
}

class _PlannerExerciseEditorPanelState
    extends State<PlannerExerciseEditorPanel> {
  late ClassPlanExercise _draft;
  late TextEditingController _nameCtrl;
  late TextEditingController _detailCtrl;
  late TextEditingController _orgCtrl;
  late TextEditingController _beginnerCtrl;
  late TextEditingController _intermediateCtrl;
  late TextEditingController _advancedCtrl;
  late TextEditingController _safetyCtrl;
  late TextEditingController _notesCtrl;
  final TextEditingController _customMaterialCtrl = TextEditingController();
  final TextEditingController _customTechRefCtrl = TextEditingController();
  final List<TextEditingController> _timingLabelCtrls = [];
  final Map<String, TextEditingController> _resourceNoteCtrls = {};
  bool _customOrgSelected = false;

  late Map<String, String> _resolvedMovementNames;
  late List<PlannerResourceItem> _availableResources;

  static const List<int> _quickDurations = [5, 8, 10, 12, 15, 20];
  static const List<String> _quickInfantilTechRefs = [
    'Ginga',
    'Cocorinha',
    'Esquiva lateral',
    'Armada',
    'Aú',
    'Rolê',
    'Meia-lua de frente',
  ];
  static const List<String> _standardOrgOptions = [
    'Todos simultáneamente',
    'Rotación por parejas',
    'Estaciones simultáneas',
    'Turnos',
  ];
  static const List<String> _commonMaterials = [
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
    _resolvedMovementNames = Map<String, String>.from(widget.movementNamesById);
    _availableResources = List<PlannerResourceItem>.from(widget.resources);
    _nameCtrl = TextEditingController();
    _detailCtrl = TextEditingController();
    _orgCtrl = TextEditingController();
    _beginnerCtrl = TextEditingController();
    _intermediateCtrl = TextEditingController();
    _advancedCtrl = TextEditingController();
    _safetyCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _syncFromWidgetExercise(widget.exercise);
  }

  @override
  void didUpdateWidget(covariant PlannerExerciseEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movementNamesById != widget.movementNamesById) {
      _resolvedMovementNames.addAll(widget.movementNamesById);
    }
    if (oldWidget.resources != widget.resources) {
      _availableResources = List<PlannerResourceItem>.from(widget.resources);
    }
    if (oldWidget.exercise.exerciseId != widget.exercise.exerciseId) {
      _syncFromWidgetExercise(widget.exercise);
    }
  }

  void _syncFromWidgetExercise(ClassPlanExercise ex) {
    _draft = ex.copyWith();
    _nameCtrl.text = ex.nombre;
    _detailCtrl.text = ex.detalle;
    _orgCtrl.text = ex.organizacion ?? '';
    _customOrgSelected = _orgCtrl.text.trim().isNotEmpty &&
        !_standardOrgOptions.contains(_orgCtrl.text.trim());
    _beginnerCtrl.text = ex.differentiationBeginner ?? '';
    _intermediateCtrl.text = ex.differentiationIntermediate ?? '';
    _advancedCtrl.text = ex.differentiationAdvanced ?? '';
    _safetyCtrl.text = ex.safetyNote ?? '';
    _notesCtrl.text = ex.observacionesProfesor ?? '';
    _syncTimingControllers(ex.internalTimings);
    _syncResourceNoteControllers(resetText: true);
  }

  void _syncTimingControllers(List<PlannerInternalTiming> timings) {
    for (final ctrl in _timingLabelCtrls) {
      ctrl.dispose();
    }
    _timingLabelCtrls.clear();
    for (final t in timings) {
      _timingLabelCtrls.add(TextEditingController(text: t.etapa));
    }
  }

  void _addTimingStage() {
    setState(() {
      final used = _draft.internalTimings.fold<int>(0, (acc, t) => acc + t.minutos);
      final target = _draft.duracionMin ?? 6;
      final suggested = (target - used) > 0 ? (target - used) : 2;
      final stage = PlannerInternalTiming(
        etapa: _draft.internalTimings.isEmpty
            ? 'Preparación y demostración'
            : 'Ejecución por rondas',
        minutos: suggested,
      );
      _draft = _draft.copyWith(
        internalTimings: [..._draft.internalTimings, stage],
      );
      _timingLabelCtrls.add(TextEditingController(text: stage.etapa));
    });
  }

  void _updateTimingMinutes(int index, int nextMinutes) {
    if (index < 0 || index >= _draft.internalTimings.length) return;
    setState(() {
      final list = List<PlannerInternalTiming>.from(_draft.internalTimings);
      list[index] = list[index].copyWith(minutos: nextMinutes);
      _draft = _draft.copyWith(internalTimings: list);
    });
  }

  void _removeTimingStage(int index) {
    if (index < 0 || index >= _draft.internalTimings.length) return;
    setState(() {
      final list = List<PlannerInternalTiming>.from(_draft.internalTimings)
        ..removeAt(index);
      final removedCtrl = _timingLabelCtrls.removeAt(index);
      removedCtrl.dispose();
      _draft = _draft.copyWith(internalTimings: list);
    });
  }

  void _toggleTechRef(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final list = List<String>.from(_draft.technicalMovementRefs);
    if (list.contains(clean)) {
      list.remove(clean);
    } else {
      list.add(clean);
    }
    setState(() {
      _draft = _draft.copyWith(technicalMovementRefs: list);
    });
  }

  void _addCustomTechRef() {
    final clean = _customTechRefCtrl.text.trim();
    if (clean.isEmpty) return;
    if (!_draft.technicalMovementRefs.contains(clean)) {
      setState(() {
        _draft = _draft.copyWith(
          technicalMovementRefs: [..._draft.technicalMovementRefs, clean],
        );
      });
    }
    _customTechRefCtrl.clear();
  }

  void _syncResourceNoteControllers({bool resetText = false}) {
    final activeIds = _draft.linkedResourceIds.toSet();
    _resourceNoteCtrls.removeWhere((id, ctrl) {
      if (!activeIds.contains(id)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });
    for (final resId in _draft.linkedResourceIds) {
      final note = _draft.resourceUsageNotes[resId] ?? '';
      final existing = _resourceNoteCtrls[resId];
      if (existing == null) {
        _resourceNoteCtrls[resId] = TextEditingController(text: note);
      } else if (resetText) {
        existing.text = note;
      }
    }
  }

  TextEditingController _resourceNoteCtrlFor(String resId) {
    return _resourceNoteCtrls.putIfAbsent(
      resId,
      () => TextEditingController(text: _draft.resourceUsageNotes[resId] ?? ''),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailCtrl.dispose();
    _orgCtrl.dispose();
    _beginnerCtrl.dispose();
    _intermediateCtrl.dispose();
    _advancedCtrl.dispose();
    _safetyCtrl.dispose();
    _notesCtrl.dispose();
    _customMaterialCtrl.dispose();
    _customTechRefCtrl.dispose();
    for (final ctrl in _timingLabelCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _resourceNoteCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  bool get _canPickAdultFiu =>
      widget.curriculumScope == PlannerCurriculumScope.adultoFiu &&
      widget.audienceType != PlannerAudienceType.infantil;

  String _movementLabel(String movementId) {
    final found = _resolvedMovementNames[movementId];
    if (found != null && found.isNotEmpty) return found;
    return movementId
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  PlannerResourceItem? _findResource(String id) {
    for (final r in _availableResources) {
      if (r.resourceId == id) return r;
    }
    return null;
  }

  IconData _iconForMedia(ResourceMediaKind kind) {
    switch (kind) {
      case ResourceMediaKind.video:
        return Icons.play_circle_outline_rounded;
      case ResourceMediaKind.imagen:
        return Icons.image_outlined;
      case ResourceMediaKind.enlace:
        return Icons.link_rounded;
      case ResourceMediaKind.nota:
        return Icons.notes_rounded;
    }
  }

  void _openLinkedResource(PlannerResourceItem res) {
    if (widget.onOpenResource != null) {
      widget.onOpenResource!(res);
      return;
    }
    final pal = PlannerPalette.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          side: BorderSide(color: pal.border),
        ),
        title: Text(
          res.title,
          style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800, color: pal.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PlannerBadge(
                  label: res.mediaLabel,
                  color: pal.amber,
                  backgroundColor: pal.amberBg,
                ),
                PlannerBadge(
                  label: res.category,
                  color: pal.infoBlue,
                  backgroundColor: pal.infoBlueBg,
                ),
              ],
            ),
            if (res.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                res.notes,
                style: GoogleFonts.montserrat(
                    fontSize: 12.5, color: pal.textSecondary, height: 1.4),
              ),
            ],
            if (res.url.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Enlace: ${res.url}',
                style: GoogleFonts.montserrat(
                    fontSize: 11.5, color: pal.infoBlue),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cerrar',
              style: GoogleFonts.montserrat(color: pal.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCurriculumPicker() async {
    if (!_canPickAdultFiu) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CurriculoBibliotecaScreen(
          repository: widget.curriculumRepository,
          overrideUserContext: const BibliotecaUserContext(
            role: 'profesor',
            cordaName: 'Azul',
            displayName: 'Editor de Clase',
          ),
          initialTrack: CurriculumTrack.adulto,
          initialCordaIndex: widget.targetAdultoCordaIndex.clamp(1, 6),
          initialCumulativeMode: true,
          selectionContract: CurriculumSelectionContract(
            enabled: true,
            initialSelectedMovementIds: _draft.curriculumMovementIds.toSet(),
            excludePendingTechnicalReview: true,
            confirmLabel: 'Vincular al ejercicio',
            onConfirmSelection: (items) {
              if (!mounted) return;
              for (final item in items) {
                _resolvedMovementNames[item.movementId] = item.canonicalName;
              }
              final nextIds = items.map((e) => e.movementId).toList();
              setState(() {
                // Respeta el origen del ejercicio sin sobrescribirlo automáticamente.
                _draft = _draft.copyWith(
                  curriculumMovementIds: nextIds,
                );
              });
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openResourcePicker() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: PlannerResourcePickerSheet(
          resources: _availableResources,
          initialSelectedIds: _draft.linkedResourceIds.toSet(),
          onCreateLocalResource: widget.onCreateLocalResource == null
              ? null
              : () async {
                  final created = await widget.onCreateLocalResource!();
                  if (created != null && mounted) {
                    setState(() {
                      _availableResources = [
                        created,
                        ..._availableResources
                            .where((r) => r.resourceId != created.resourceId),
                      ];
                    });
                  }
                  return created;
                },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final hasExternalVideo = result.any((id) {
          final res = _findResource(id);
          return res?.hasExternalVideo ?? false;
        });
        final nextNotes = <String, String>{};
        for (final id in result) {
          final existing = _resourceNoteCtrls[id]?.text.trim() ??
              _draft.resourceUsageNotes[id] ??
              '';
          if (existing.isNotEmpty) {
            nextNotes[id] = existing;
          }
        }
        // Vincular recursos nunca altera el origen del ejercicio.
        _draft = _draft.copyWith(
          linkedResourceIds: result,
          resourceUsageNotes: nextNotes,
          videoReferenceNote: hasExternalVideo &&
                  (_draft.videoReferenceNote == null ||
                      _draft.videoReferenceNote!.trim().isEmpty)
              ? 'Recurso multimedia de Pizarra vinculado manualmente.'
              : _draft.videoReferenceNote,
        );
        _syncResourceNoteControllers();
      });
    }
  }

  void _removeLinkedResource(String resId) {
    setState(() {
      final nextIds = List<String>.from(_draft.linkedResourceIds)
        ..remove(resId);
      final nextNotes = Map<String, String>.from(_draft.resourceUsageNotes)
        ..remove(resId);
      _draft = _draft.copyWith(
        linkedResourceIds: nextIds,
        resourceUsageNotes: nextNotes,
      );
      _syncResourceNoteControllers();
    });
  }

  void _toggleMaterial(String material) {
    final clean = material.trim();
    if (clean.isEmpty) return;
    final list = List<String>.from(_draft.materiales);
    if (list.contains(clean)) {
      list.remove(clean);
    } else {
      list.add(clean);
    }
    setState(() {
      _draft = _draft.copyWith(materiales: list);
    });
  }

  void _addCustomMaterial() {
    final text = _customMaterialCtrl.text.trim();
    if (text.isEmpty) return;
    if (!_draft.materiales.contains(text)) {
      setState(() {
        _draft = _draft.copyWith(materiales: [..._draft.materiales, text]);
      });
    }
    _customMaterialCtrl.clear();
  }

  ClassPlanExercise _buildUpdatedExercise() {
    final cleanName = _nameCtrl.text.trim();
    final cleanOrg = _orgCtrl.text.trim();
    final cleanBeginner = _beginnerCtrl.text.trim();
    final cleanIntermediate = _intermediateCtrl.text.trim();
    final cleanAdvanced = _advancedCtrl.text.trim();
    final cleanSafety = _safetyCtrl.text.trim();
    final cleanNotes = _notesCtrl.text.trim();

    final collectedResNotes = <String, String>{};
    for (final resId in _draft.linkedResourceIds) {
      final note = _resourceNoteCtrls[resId]?.text.trim() ??
          _draft.resourceUsageNotes[resId] ??
          '';
      if (note.isNotEmpty) {
        collectedResNotes[resId] = note;
      }
    }

    final collectedTimings = <PlannerInternalTiming>[];
    for (int i = 0; i < _draft.internalTimings.length; i++) {
      final label = i < _timingLabelCtrls.length
          ? _timingLabelCtrls[i].text.trim()
          : _draft.internalTimings[i].etapa;
      if (label.isNotEmpty) {
        collectedTimings.add(
          PlannerInternalTiming(
            etapa: label,
            minutos: _draft.internalTimings[i].minutos,
          ),
        );
      }
    }

    return _draft.copyWith(
      nombre: cleanName.isNotEmpty ? cleanName : 'Ejercicio sin título',
      detalle: _detailCtrl.text.trim(),
      organizacion: cleanOrg.isNotEmpty ? cleanOrg : null,
      clearOrganizacion: cleanOrg.isEmpty,
      internalTimings: collectedTimings,
      resourceUsageNotes: collectedResNotes,
      differentiationBeginner: cleanBeginner.isNotEmpty ? cleanBeginner : null,
      clearDifferentiationBeginner: cleanBeginner.isEmpty,
      differentiationIntermediate:
          cleanIntermediate.isNotEmpty ? cleanIntermediate : null,
      clearDifferentiationIntermediate: cleanIntermediate.isEmpty,
      differentiationAdvanced: cleanAdvanced.isNotEmpty ? cleanAdvanced : null,
      clearDifferentiationAdvanced: cleanAdvanced.isEmpty,
      safetyNote: cleanSafety.isNotEmpty ? cleanSafety : null,
      clearSafetyNote: cleanSafety.isEmpty,
      observacionesProfesor: cleanNotes.isNotEmpty ? cleanNotes : null,
      clearObservacionesProfesor: cleanNotes.isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final hasVariants = _beginnerCtrl.text.trim().isNotEmpty ||
        _intermediateCtrl.text.trim().isNotEmpty ||
        _advancedCtrl.text.trim().isNotEmpty;
    final hasExtras = _draft.materiales.isNotEmpty ||
        _safetyCtrl.text.trim().isNotEmpty ||
        _notesCtrl.text.trim().isNotEmpty;

    final currentOrg = _orgCtrl.text.trim();
    final selectedOrgOption = _standardOrgOptions.contains(currentOrg) &&
            !_customOrgSelected
        ? currentOrg
        : ((_customOrgSelected || currentOrg.isNotEmpty)
            ? 'Organización personalizada'
            : null);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          // Header del panel contextual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(
              color: pal.surfaceAlt,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(GingaRadius.lg),
              ),
              border: Border(bottom: BorderSide(color: pal.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PlannerBadge(
                            label: widget.blockTitle,
                            color: pal.accent,
                          ),
                          PlannerOriginBadge(origin: _draft.contentOrigin),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Editar ejercicio',
                        style: GoogleFonts.montserrat(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: Icon(Icons.close, color: pal.textSecondary),
                  tooltip: 'Cerrar editor de ejercicio',
                ),
              ],
            ),
          ),

          // Cuerpo scrollable a ancho completo
          Expanded(
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PlannerFieldLabel('Nombre del ejercicio'),
                  TextField(
                    key: const Key('ex_editor_name_field'),
                    controller: _nameCtrl,
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText: 'Ej. Cocorinha + salida en rolê',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Duración del ejercicio
                  const PlannerFieldLabel('Duración del ejercicio', optional: true),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PlannerStepperField(
                        key: const Key('ex_editor_duration_stepper'),
                        label: 'Minutos',
                        value: _draft.duracionMin ?? 0,
                        suffix: 'min',
                        min: 0,
                        max: 120,
                        onChanged: (v) => setState(() {
                          _draft = _draft.copyWith(
                            duracionMin: v == 0 ? null : v,
                            clearDuracionMin: v == 0,
                          );
                        }),
                      ),
                      for (final m in _quickDurations)
                        PlannerChoicePill(
                          label: '$m min',
                          selected: _draft.duracionMin == m,
                          onTap: () => setState(() {
                            _draft = _draft.copyWith(duracionMin: m);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tiempos internos por etapa (estructurado y retrocompatible)
                  _buildInternalTimingsSection(pal),
                  const SizedBox(height: 14),

                  // Descripción paso a paso
                  const PlannerFieldLabel(
                    'Descripción detallada y ejecución paso a paso',
                  ),
                  TextField(
                    key: const Key('ex_editor_detail_field'),
                    controller: _detailCtrl,
                    maxLines: 4,
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      color: pal.textPrimary,
                      height: 1.45,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText:
                          'Describe progresión, ritmo, consignas y transiciones...',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Organización de participantes
                  const PlannerFieldLabel(
                    'Organización pedagógica de los participantes',
                    optional: true,
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < kPlannerOrganizationOptions.length; i++)
                        PlannerChoicePill(
                          key: Key('ex_editor_org_opt_$i'),
                          label: kPlannerOrganizationOptions[i],
                          selected: selectedOrgOption ==
                              kPlannerOrganizationOptions[i],
                          onTap: () {
                            final opt = kPlannerOrganizationOptions[i];
                            setState(() {
                              if (opt == 'Organización personalizada') {
                                _customOrgSelected = true;
                                if (_standardOrgOptions
                                    .contains(_orgCtrl.text.trim())) {
                                  _orgCtrl.clear();
                                }
                              } else {
                                _customOrgSelected = false;
                                _orgCtrl.text = opt;
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('ex_editor_org_field'),
                    controller: _orgCtrl,
                    onChanged: (v) {
                      final trimmed = v.trim();
                      setState(() {
                        _customOrgSelected = trimmed.isNotEmpty &&
                            !_standardOrgOptions.contains(trimmed);
                      });
                    },
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      color: pal.textPrimary,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText:
                          'Escribe o personaliza la organización (ej. 3 estaciones de 4 min)...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Origen del ejercicio (separado de los recursos vinculados)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pal.background,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(color: pal.border),
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
                            Text(
                              'Origen del ejercicio',
                              style: GoogleFonts.montserrat(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: pal.textPrimary,
                              ),
                            ),
                            PlannerOriginBadge(origin: _draft.contentOrigin),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Identifica la fuente propia del ejercicio; es independiente de los recursos de apoyo o movimientos vinculados.',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        if (_draft.contentOrigin !=
                            ContentOrigin.aiComplementaryProposal) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              PlannerChoicePill(
                                key: const Key('ex_editor_origin_teacher'),
                                label: 'Recurso Profesor (Manual)',
                                selected: _draft.contentOrigin ==
                                    ContentOrigin.teacherResource,
                                onTap: () => setState(() {
                                  _draft = _draft.copyWith(
                                    contentOrigin:
                                        ContentOrigin.teacherResource,
                                  );
                                }),
                              ),
                              if (_draft.curriculumMovementIds.isNotEmpty)
                                PlannerChoicePill(
                                  key: const Key('ex_editor_origin_fiu'),
                                  label: 'Currículo FIU',
                                  selected: _draft.contentOrigin ==
                                      ContentOrigin.officialFiuCurriculum,
                                  onTap: () => setState(() {
                                    _draft = _draft.copyWith(
                                      contentOrigin:
                                          ContentOrigin.officialFiuCurriculum,
                                    );
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Integración curricular y Pizarra a ancho completo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pal.background,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(color: pal.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Movimientos FIU y Recursos de Pizarra',
                          style: GoogleFonts.montserrat(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Puedes trabajar contenido manual libre sin vincular currículo, o asociar varios movimientos y recursos con su instrucción de uso.',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_canPickAdultFiu) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const Key('ex_editor_pick_fiu_button'),
                              onPressed: _openCurriculumPicker,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 42),
                                side: BorderSide(color: pal.accent),
                                foregroundColor: pal.accent,
                              ),
                              icon: const Icon(Icons.menu_book_outlined,
                                  size: 16),
                              label: Text(
                                'Elegir movimientos FIU (${_draft.curriculumMovementIds.length})',
                                style: GoogleFonts.montserrat(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ] else ...[
                          PlannerNoticeBanner(
                            title: widget.audienceType ==
                                    PlannerAudienceType.infantil
                                ? 'Currículo Adulto FIU bloqueado en clase Infantil'
                                : 'Sin pista Adulto FIU automática',
                            message:
                                'No se aplica automáticamente el currículo adulto a clases infantiles o mixtas.',
                            color: pal.amber,
                            backgroundColor: pal.amberBg,
                          ),
                          const SizedBox(height: 10),
                          _buildNonCurricularTechRefsSection(pal),
                        ],

                        if (_draft.curriculumMovementIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final id in _draft.curriculumMovementIds)
                                Chip(
                                  key: Key('ex_editor_mov_chip_$id'),
                                  label: Text(
                                    _movementLabel(id),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: pal.accent,
                                    ),
                                  ),
                                  backgroundColor: pal.surfaceTint,
                                  side: BorderSide(
                                      color: pal.accent.withValues(alpha: 0.4)),
                                  deleteIconColor: pal.accent,
                                  onDeleted: () => setState(() {
                                    final next = List<String>.from(
                                        _draft.curriculumMovementIds)
                                      ..remove(id);
                                    _draft = _draft.copyWith(
                                      curriculumMovementIds: next,
                                    );
                                  }),
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('ex_editor_pick_resource_button'),
                            onPressed: _openResourcePicker,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 42),
                              side: BorderSide(color: pal.infoBlue),
                              foregroundColor: pal.infoBlue,
                            ),
                            icon: const Icon(Icons.video_library_outlined,
                                size: 16),
                            label: Text(
                              'Vincular recurso de Pizarra (${_draft.linkedResourceIds.length})',
                              style: GoogleFonts.montserrat(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),

                        if (_draft.linkedResourceIds.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final resId in _draft.linkedResourceIds)
                            _buildLinkedResourceCard(pal, resId),
                        ],

                        if (_draft.legacyRecursoRelacionado != null &&
                            _draft.legacyRecursoRelacionado!
                                .trim()
                                .isNotEmpty &&
                            _draft.legacyRecursoRelacionado!.toLowerCase() !=
                                'null') ...[
                          const SizedBox(height: 8),
                          PlannerBadge(
                            label:
                                'Referencia heredada: ${_draft.legacyRecursoRelacionado}',
                            color: pal.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sección expandible: Variantes pedagógicas por 3 niveles
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: pal.background,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: pal.border),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: hasVariants,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        title: Text(
                          'Variantes pedagógicas por nivel (opcional)',
                          style: GoogleFonts.montserrat(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Ajusta progresiones según la experiencia real del grupo, sin inferir nivel técnico solo por la corda.',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: pal.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: PlannerFieldLabel('Principiantes', optional: true),
                          ),
                          TextField(
                            key: const Key('ex_editor_beginner_field'),
                            controller: _beginnerCtrl,
                            maxLines: 2,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              color: pal.textPrimary,
                            ),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Ej. Pausa breve verificando apoyo y postura...',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: PlannerFieldLabel('Intermedios', optional: true),
                          ),
                          TextField(
                            key: const Key('ex_editor_intermediate_field'),
                            controller: _intermediateCtrl,
                            maxLines: 2,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              color: pal.textPrimary,
                            ),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Ej. Mantener ritmo continuo sin pausas...',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: PlannerFieldLabel('Avanzados', optional: true),
                          ),
                          TextField(
                            key: const Key('ex_editor_advanced_field'),
                            controller: _advancedCtrl,
                            maxLines: 2,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              color: pal.textPrimary,
                            ),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Ej. Enlazar salida con contraataque o floreio...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sección expandible: Materiales, seguridad y observaciones
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: pal.background,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: pal.border),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: hasExtras,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        title: Text(
                          'Materiales, seguridad y observaciones (opcional)',
                          style: GoogleFonts.montserrat(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: PlannerFieldLabel('Materiales necesarios', optional: true),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final mat in _commonMaterials)
                                  PlannerChoicePill(
                                    label: mat,
                                    selected: _draft.materiales.contains(mat),
                                    onTap: () => _toggleMaterial(mat),
                                  ),
                              ],
                            ),
                          ),
                          if (_draft.materiales
                              .any((m) => !_commonMaterials.contains(m))) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final m in _draft.materiales.where(
                                      (x) => !_commonMaterials.contains(x)))
                                    Chip(
                                      label: Text(
                                        m,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: pal.textPrimary,
                                        ),
                                      ),
                                      backgroundColor: pal.surface,
                                      onDeleted: () => _toggleMaterial(m),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('ex_editor_custom_material_field'),
                                  controller: _customMaterialCtrl,
                                  onSubmitted: (_) => _addCustomMaterial(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.5,
                                    color: pal.textPrimary,
                                  ),
                                  decoration: plannerInputDecoration(
                                    pal,
                                    hintText: 'Otro material (ej. Cuerda, Escaleras)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                key: const Key('ex_editor_add_material_button'),
                                onPressed: _addCustomMaterial,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  side: BorderSide(color: pal.border),
                                  foregroundColor: pal.textPrimary,
                                ),
                                child: const Text('Añadir'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: PlannerFieldLabel('Indicaciones de seguridad', optional: true),
                          ),
                          TextField(
                            key: const Key('ex_editor_safety_field'),
                            controller: _safetyCtrl,
                            maxLines: 2,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              color: pal.textPrimary,
                            ),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Espacio mínimo, colchonetas, control articular...',
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_draft.aiSuggestions != null &&
                              _draft.aiSuggestions!.trim().isNotEmpty) ...[
                            Container(
                              key: const Key('ex_editor_ai_suggestions_box'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: pal.infoBlueBg,
                                borderRadius:
                                    BorderRadius.circular(GingaRadius.md),
                                border: Border.all(
                                    color:
                                        pal.infoBlue.withValues(alpha: 0.35)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome_outlined,
                                          size: 15, color: pal.infoBlue),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Sugerencia pedagógica IA',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: pal.infoBlue,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: const Key(
                                            'ex_editor_clear_ai_suggestion_btn'),
                                        tooltip: 'Ocultar sugerencia IA',
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.close,
                                            size: 15, color: pal.textSecondary),
                                        onPressed: () => setState(() {
                                          _draft = _draft.copyWith(
                                              clearAiSuggestions: true);
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _draft.aiSuggestions!.trim(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: pal.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: PlannerFieldLabel(
                              'Observaciones del profesor (propias)',
                              optional: true,
                            ),
                          ),
                          TextField(
                            key: const Key('ex_editor_teacher_notes_field'),
                            controller: _notesCtrl,
                            maxLines: 2,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              color: pal.textPrimary,
                            ),
                            decoration: plannerInputDecoration(
                              pal,
                              hintText: 'Recordatorios de corrección o foco técnico...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer fijo de acciones del ejercicio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.surfaceAlt,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(GingaRadius.lg),
              ),
              border: Border(top: BorderSide(color: pal.border)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const Key('ex_editor_cancel_button'),
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    foregroundColor: pal.textSecondary,
                  ),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.montserrat(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('ex_editor_apply_button'),
                  onPressed: () => widget.onApply(_buildUpdatedExercise()),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    backgroundColor: pal.accent,
                    foregroundColor: pal.onAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(Icons.check, size: 17),
                  label: Text(
                    'Aplicar cambios',
                    style: GoogleFonts.montserrat(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternalTimingsSection(PlannerPalette pal) {
    final totalStagesMin =
        _draft.internalTimings.fold<int>(0, (acc, t) => acc + t.minutos);
    final targetMin = _draft.duracionMin;
    final hasMismatch = _draft.internalTimings.isNotEmpty &&
        targetMin != null &&
        totalStagesMin != targetMin;

    return Container(
      key: const Key('ex_editor_internal_timings_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(
          color: hasMismatch ? pal.amber.withValues(alpha: 0.6) : pal.border,
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
              Text(
                'Tiempos internos por etapa',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: pal.textPrimary,
                ),
              ),
              if (_draft.internalTimings.isNotEmpty)
                PlannerBadge(
                  label: targetMin != null
                      ? 'Suma: $totalStagesMin/$targetMin min'
                      : 'Suma: $totalStagesMin min',
                  color: hasMismatch ? pal.amber : pal.accent,
                  backgroundColor: hasMismatch ? pal.amberBg : pal.surfaceTint,
                ),
            ],
          ),
          if (_draft.internalTimings.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Opcional: divide la ejecución en etapas reales (ej. Preparación, Progresión, Rondas).',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: pal.textSecondary,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (int i = 0; i < _draft.internalTimings.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: Key('ex_editor_timing_label_$i'),
                      controller: i < _timingLabelCtrls.length
                          ? _timingLabelCtrls[i]
                          : null,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: pal.textPrimary,
                      ),
                      decoration: plannerInputDecoration(
                        pal,
                        hintText: 'Nombre de etapa',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PlannerStepperField(
                    key: Key('ex_editor_timing_min_$i'),
                    label: 'Min',
                    value: _draft.internalTimings[i].minutos,
                    suffix: 'm',
                    min: 1,
                    max: 90,
                    onChanged: (v) => _updateTimingMinutes(i, v),
                  ),
                  IconButton(
                    key: Key('ex_editor_timing_del_$i'),
                    icon: const Icon(Icons.close, size: 16),
                    color: pal.textSecondary,
                    tooltip: 'Quitar etapa',
                    onPressed: () => _removeTimingStage(i),
                  ),
                ],
              ),
              if (i < _draft.internalTimings.length - 1)
                const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('ex_editor_add_timing_stage_btn'),
              onPressed: _addTimingStage,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                side: BorderSide(color: pal.border),
                foregroundColor: pal.textPrimary,
              ),
              icon: const Icon(Icons.add, size: 15),
              label: Text(
                'Añadir etapa interna',
                style: GoogleFonts.montserrat(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonCurricularTechRefsSection(PlannerPalette pal) {
    return Container(
      key: const Key('ex_editor_tech_refs_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Referencias técnicas de Capoeira (no curriculares)',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Permite anotar técnicas reales apropiadas para niños sin desbloquear el currículo adulto oficial ni inventar cordas.',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: pal.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final mov in _quickInfantilTechRefs)
                PlannerChoicePill(
                  key: Key('ex_editor_tech_pill_$mov'),
                  label: mov,
                  selected: _draft.technicalMovementRefs.contains(mov),
                  onTap: () => _toggleTechRef(mov),
                ),
            ],
          ),
          if (_draft.technicalMovementRefs
              .any((m) => !_quickInfantilTechRefs.contains(m))) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final extra in _draft.technicalMovementRefs
                    .where((x) => !_quickInfantilTechRefs.contains(x)))
                  Chip(
                    label: Text(
                      extra,
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: pal.textPrimary,
                      ),
                    ),
                    backgroundColor: pal.background,
                    onDeleted: () => _toggleTechRef(extra),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ex_editor_custom_tech_ref_field'),
                  controller: _customTechRefCtrl,
                  onSubmitted: (_) => _addCustomTechRef(),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: pal.textPrimary,
                  ),
                  decoration: plannerInputDecoration(
                    pal,
                    hintText: 'Otro movimiento (ej. Esquiva baixa)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('ex_editor_add_tech_ref_btn'),
                onPressed: _addCustomTechRef,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(color: pal.border),
                  foregroundColor: pal.textPrimary,
                ),
                child: const Text('Añadir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedResourceCard(PlannerPalette pal, String resId) {
    final res = _findResource(resId);
    final kind = res?.mediaKind ?? ResourceMediaKind.nota;
    final title = res?.title ?? resId;
    final noteCtrl = _resourceNoteCtrlFor(resId);

    return Container(
      key: Key('ex_editor_res_chip_$resId'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: pal.infoBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconForMedia(kind), size: 18, color: pal.infoBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    if (res != null && res.notes.isNotEmpty)
                      Text(
                        res.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: pal.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (res != null)
                IconButton(
                  key: Key('ex_editor_open_res_$resId'),
                  onPressed: () => _openLinkedResource(res),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  color: pal.infoBlue,
                  tooltip: 'Abrir recurso',
                ),
              IconButton(
                key: Key('ex_editor_remove_res_$resId'),
                onPressed: () => _removeLinkedResource(resId),
                icon: const Icon(Icons.close, size: 17),
                color: pal.textSecondary,
                tooltip: 'Quitar recurso del ejercicio',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const PlannerFieldLabel(
            'Instrucción particular para usar este recurso',
            optional: true,
          ),
          TextField(
            key: Key('ex_editor_res_note_$resId'),
            controller: noteCtrl,
            maxLines: 2,
            onChanged: (v) {
              final nextNotes = Map<String, String>.from(_draft.resourceUsageNotes);
              if (v.trim().isEmpty) {
                nextNotes.remove(resId);
              } else {
                nextNotes[resId] = v.trim();
              }
              _draft = _draft.copyWith(resourceUsageNotes: nextNotes);
            },
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: pal.textPrimary,
            ),
            decoration: plannerInputDecoration(
              pal,
              hintText: 'Ej. Mostrar solo los primeros 20s antes del drill...',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector modal de recursos de Pizarra (videos, imágenes, enlaces y notas)
/// que conserva los IDs estables y nunca marca recursos como utilizados.
class PlannerResourcePickerSheet extends StatefulWidget {
  final List<PlannerResourceItem> resources;
  final Set<String> initialSelectedIds;
  final Future<PlannerResourceItem?> Function()? onCreateLocalResource;

  const PlannerResourcePickerSheet({
    super.key,
    required this.resources,
    required this.initialSelectedIds,
    this.onCreateLocalResource,
  });

  @override
  State<PlannerResourcePickerSheet> createState() =>
      _PlannerResourcePickerSheetState();
}

class _PlannerResourcePickerSheetState
    extends State<PlannerResourcePickerSheet> {
  late List<PlannerResourceItem> _resources;
  late Set<String> _selectedIds;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _mediaFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _resources = List<PlannerResourceItem>.from(widget.resources);
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  IconData _iconForKind(ResourceMediaKind kind) {
    switch (kind) {
      case ResourceMediaKind.video:
        return Icons.play_circle_outline_rounded;
      case ResourceMediaKind.imagen:
        return Icons.image_outlined;
      case ResourceMediaKind.enlace:
        return Icons.link_rounded;
      case ResourceMediaKind.nota:
        return Icons.notes_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final q = _query.trim().toLowerCase();
    final filtered = _resources.where((r) {
      final matchKind =
          _mediaFilter == 'Todos' || r.mediaLabel == _mediaFilter;
      final matchQ = q.isEmpty ||
          r.title.toLowerCase().contains(q) ||
          r.notes.toLowerCase().contains(q) ||
          r.category.toLowerCase().contains(q);
      return matchKind && matchQ;
    }).toList();

    return SafeArea(
      child: Container(
        color: pal.background,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: pal.surface,
                border: Border(bottom: BorderSide(color: pal.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vincular recursos de la Pizarra',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          'No marca los recursos como utilizados al planificar.',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: pal.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('res_picker_search_field'),
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          style: GoogleFonts.montserrat(
                              fontSize: 12.5, color: pal.textPrimary),
                          decoration: plannerInputDecoration(
                            pal,
                            hintText: 'Buscar video, imagen, enlace o nota...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (widget.onCreateLocalResource != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          key: const Key('res_picker_new_button'),
                          onPressed: () async {
                            final created =
                                await widget.onCreateLocalResource!();
                            if (created != null && mounted) {
                              setState(() {
                                _resources = [
                                  created,
                                  ..._resources.where(
                                      (r) => r.resourceId != created.resourceId),
                                ];
                                _selectedIds.add(created.resourceId);
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            side: BorderSide(color: pal.accent),
                            foregroundColor: pal.accent,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Nuevo'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in const [
                        'Todos',
                        'Video',
                        'Imagen',
                        'Enlace',
                        'Nota',
                      ])
                        PlannerChoicePill(
                          label: f,
                          selected: _mediaFilter == f,
                          onTap: () => setState(() => _mediaFilter = f),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: PlannerNoticeBanner(
                        title: 'Sin recursos coincidentes',
                        message:
                            'Prueba otro filtro de tipo o crea un nuevo recurso.',
                        color: pal.infoBlue,
                        backgroundColor: pal.infoBlueBg,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, idx) {
                        final res = filtered[idx];
                        final selected = _selectedIds.contains(res.resourceId);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            key: Key('res_picker_item_${res.resourceId}'),
                            onTap: () => setState(() {
                              if (selected) {
                                _selectedIds.remove(res.resourceId);
                              } else {
                                _selectedIds.add(res.resourceId);
                              }
                            }),
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selected ? pal.surfaceTint : pal.surface,
                                borderRadius:
                                    BorderRadius.circular(GingaRadius.md),
                                border: Border.all(
                                  color: selected ? pal.accent : pal.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: selected
                                        ? pal.accent
                                        : pal.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            PlannerBadge(
                                              label: res.mediaLabel,
                                              color: pal.amber,
                                              backgroundColor: pal.amberBg,
                                              icon: _iconForKind(res.mediaKind),
                                            ),
                                            PlannerBadge(
                                              label: res.category,
                                              color: pal.infoBlue,
                                              backgroundColor: pal.infoBlueBg,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          res.title,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: pal.textPrimary,
                                          ),
                                        ),
                                        if (res.notes.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            res.notes,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11.5,
                                              color: pal.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.surface,
                border: Border(top: BorderSide(color: pal.border)),
              ),
              child: ElevatedButton.icon(
                key: const Key('res_picker_confirm_button'),
                onPressed: () =>
                    Navigator.of(context).pop(_selectedIds.toList()),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: pal.accent,
                  foregroundColor: pal.onAccent,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: Text(
                  'Vincular (${_selectedIds.length})',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/curriculum_repository.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../models/class_plan_models.dart';
import '../models/live_session_models.dart';
import '../services/class_plan_editor_operations.dart';
import '../services/live_session_persistence.dart';
import '../services/planner_data_source.dart';
import '../services/planner_v2_engine_client.dart';
import '../theme/planner_palette.dart';
import 'planner_advanced_create_view.dart';
import 'planner_class_editor_view.dart';
import 'planner_live_class_view.dart';
import 'planner_quick_create_view.dart';
import 'planner_shared_widgets.dart';

/// Hub unificado del Planificador Pedagógico GINGA (PED-04B1 / PED-04B2).
/// Integra Mis Planes, Pizarra de Recursos, Historial, Creación Rápida/Avanzada y Editor V2.
class PlannerHubBody extends StatefulWidget {
  final PlannerDataSource dataSource;
  final CurriculumRepository? curriculumRepository;
  final PlannerV2EngineClient? engineClient;
  final PlannerHubTab initialTab;
  final PlannerCreationMode? initialCreationMode;
  final String? initialGroupIdForCreation;
  final String? initialEditingPlanId;
  final String? initialLivePlanId;
  final bool initialCreateManual;
  final LiveSessionStorage? liveSessionStorage;
  final DateTime Function()? clock;
  final VoidCallback? onOpenBiblioteca;
  final VoidCallback? onLegacyCreateIdea;
  final ValueChanged<PlannerResourceItem>? onLegacyEditIdea;
  final ValueChanged<PlannerResourceItem>? onLegacyDeleteIdea;
  final ValueChanged<PlannerResourceItem>? onLegacyOpenResourceMedia;
  final void Function(PlannerResourceItem resource, bool value)?
      onLegacyToggleIdea;
  final ValueChanged<ClassPlanModel>? onOpenLegacyPlanDetail;
  final ValueChanged<ClassPlanModel>? onStartLegacyLiveClass;
  final ValueChanged<ClassPlanModel>? onDeletePlan;

  const PlannerHubBody({
    super.key,
    required this.dataSource,
    this.curriculumRepository,
    this.engineClient,
    this.initialTab = PlannerHubTab.plans,
    this.initialCreationMode,
    this.initialGroupIdForCreation,
    this.initialEditingPlanId,
    this.initialLivePlanId,
    this.initialCreateManual = false,
    this.liveSessionStorage,
    this.clock,
    this.onOpenBiblioteca,
    this.onLegacyCreateIdea,
    this.onLegacyEditIdea,
    this.onLegacyDeleteIdea,
    this.onLegacyOpenResourceMedia,
    this.onLegacyToggleIdea,
    this.onOpenLegacyPlanDetail,
    this.onStartLegacyLiveClass,
    this.onDeletePlan,
  });

  @override
  State<PlannerHubBody> createState() => _PlannerHubBodyState();
}

class _PlannerHubBodyState extends State<PlannerHubBody> {
  late PlannerHubTab _activeTab;
  PlannerCreationMode? _activeCreationMode;
  ClassPlanDraftRequest? _pendingDraftRequest;
  ClassPlanModel? _editingPlan;
  bool _editingIsDuplicate = false;
  late LiveSessionStorage _liveStorage;
  LiveSessionState? _activeLiveSession;
  LiveSessionState? _recoverableSession;
  bool _isGeneratingWithEngine = false;
  String? _generationError;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  bool _loading = true;
  String? _loadError;
  List<PlannerGroupProfile> _groups = const [];
  List<ClassPlanModel> _plans = const [];
  List<PlannerResourceItem> _resources = const [];
  List<TaughtSessionRecord> _history = const [];
  Map<String, String> _movementNamesById = {};

  final TextEditingController _plansSearchCtrl = TextEditingController();
  final TextEditingController _resourcesSearchCtrl = TextEditingController();
  String _plansSearchQuery = '';
  String _planAudienceFilter = 'Todos';

  String _resourcesSearchQuery = '';
  String _resourceAudienceFilter = 'Todos';
  String _resourcePhaseFilter = 'Todos';
  String _resourceStatusFilter = 'Todos';
  final Set<String> _selectedResourceIdsForPlan = {};

  String _historyGroupFilter = 'Todos';
  String _historyDateFilter = 'Todas';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _activeCreationMode = widget.initialCreationMode;
    _liveStorage =
        widget.liveSessionStorage ?? const SharedPreferencesLiveSessionStorage();
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant PlannerHubBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveSessionStorage != widget.liveSessionStorage) {
      _liveStorage =
          widget.liveSessionStorage ?? const SharedPreferencesLiveSessionStorage();
    }
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialCreationMode != widget.initialCreationMode ||
        oldWidget.initialGroupIdForCreation !=
            widget.initialGroupIdForCreation ||
        oldWidget.initialEditingPlanId != widget.initialEditingPlanId ||
        oldWidget.initialLivePlanId != widget.initialLivePlanId ||
        oldWidget.initialCreateManual != widget.initialCreateManual) {
      _activeTab = widget.initialTab;
      _activeCreationMode = widget.initialCreationMode;
      _editingPlan = null;
      _editingIsDuplicate = false;
      _activeLiveSession = null;
      _isGeneratingWithEngine = false;
      _generationError = null;
      if (_activeCreationMode != null) {
        _pendingDraftRequest = _buildDefaultRequest(_activeCreationMode!);
      }
      if (widget.initialCreateManual) {
        _editingPlan = ClassPlanModel.emptyManual(
          group: _groups.isNotEmpty ? _groups.first : null,
        );
      } else if (widget.initialLivePlanId != null) {
        for (final p in _plans) {
          if (p.id == widget.initialLivePlanId) {
            _activeLiveSession = _buildLiveSessionFromPlan(p);
            break;
          }
        }
      } else if (widget.initialEditingPlanId != null) {
        for (final p in _plans) {
          if (p.id == widget.initialEditingPlanId) {
            _editingPlan = p;
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _plansSearchCtrl.dispose();
    _resourcesSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        widget.dataSource.loadGroups(),
        widget.dataSource.loadPlans(),
        widget.dataSource.loadResources(),
        widget.dataSource.loadHistory(),
        _liveStorage.loadActiveSession(),
      ]);
      if (!mounted) return;
      final groups = results[0] as List<PlannerGroupProfile>;
      final plans = results[1] as List<ClassPlanModel>;
      final resources = results[2] as List<PlannerResourceItem>;
      final history = results[3] as List<TaughtSessionRecord>;
      final recovered = results[4] as LiveSessionState?;

      final namesMap = <String, String>{};
      final repo = widget.curriculumRepository;
      if (repo != null) {
        try {
          final movs = await repo.queryMovements();
          for (final m in movs) {
            namesMap[m.movementId] = m.canonicalName;
          }
        } catch (_) {}
      }
      if (!mounted) return;

      ClassPlanModel? initialEditorPlan;
      LiveSessionState? initialLiveSession;
      if (widget.initialCreateManual && _editingPlan == null) {
        initialEditorPlan = ClassPlanModel.emptyManual(
          group: groups.isNotEmpty ? groups.first : null,
        );
      } else if (widget.initialLivePlanId != null && _activeLiveSession == null) {
        for (final p in plans) {
          if (p.id == widget.initialLivePlanId) {
            initialLiveSession = LiveSessionState.startFromPlan(
              plan: p,
              resources: resources,
              now: _now(),
              groupId: _resolveGroupId(p, groups),
            );
            break;
          }
        }
      } else if (widget.initialEditingPlanId != null && _editingPlan == null) {
        for (final p in plans) {
          if (p.id == widget.initialEditingPlanId) {
            initialEditorPlan = p;
            break;
          }
        }
      }

      setState(() {
        _groups = groups;
        _plans = plans;
        _resources = resources;
        _history = history;
        _recoverableSession = recovered;
        _movementNamesById = namesMap;
        if (initialEditorPlan != null) {
          _editingPlan = initialEditorPlan;
        }
        if (initialLiveSession != null) {
          _activeLiveSession = initialLiveSession;
        }
        _loading = false;
        if (_activeCreationMode != null && _pendingDraftRequest == null) {
          _pendingDraftRequest = _buildDefaultRequest(_activeCreationMode!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  ClassPlanDraftRequest _buildDefaultRequest(PlannerCreationMode mode) {
    if (_groups.isNotEmpty) {
      PlannerGroupProfile firstGroup = _groups.first;
      if (widget.initialGroupIdForCreation != null) {
        for (final g in _groups) {
          if (g.id == widget.initialGroupIdForCreation) {
            firstGroup = g;
            break;
          }
        }
      }
      final base = ClassPlanDraftRequest.fromGroup(firstGroup, mode: mode);
      final matched = PedagogicalContinuityContext.findLatestSessionForGroup(
        _history,
        groupId: firstGroup.id,
        groupName: firstGroup.name,
        audienceType: firstGroup.audienceType,
      );
      if (matched == null) return base;
      final ctx = PedagogicalContinuityContext.fromSession(matched);
      return base.copyWith(
        continuityContext: ctx,
        continuitySummary: ctx.hasContent ? ctx.shortHeadline : null,
      );
    }
    return ClassPlanDraftRequest(
      creationMode: mode,
      groupSource: PlannerGroupSource.manual,
      groupName: 'Grupo Adultos manual',
      audienceType: PlannerAudienceType.adultos,
      curriculumScope: PlannerCurriculumScope.adultoFiu,
      ageMin: 16,
      ageMax: 40,
      participantsCount: 10,
      experienceDistribution: const ExperienceDistribution(),
    );
  }

  void _openCreation(
    PlannerCreationMode mode, {
    ClassPlanModel? reusePlan,
    List<PlannerResourceItem>? preselectedResources,
    TaughtSessionRecord? fromSession,
  }) {
    var req = _buildDefaultRequest(mode);
    if (reusePlan != null) {
      PlannerGroupProfile? matchedPlanGroup;
      for (final g in _groups) {
        if (g.name.toLowerCase() == reusePlan.groupName.toLowerCase() &&
            g.audienceType == reusePlan.audienceType) {
          matchedPlanGroup = g;
          break;
        }
      }
      final latestForPlanGroup =
          PedagogicalContinuityContext.findLatestSessionForGroup(
        _history,
        groupId: matchedPlanGroup?.id,
        groupName: reusePlan.groupName,
        audienceType: reusePlan.audienceType,
      );
      final planGroupCtx = latestForPlanGroup != null
          ? PedagogicalContinuityContext.fromSession(latestForPlanGroup)
          : null;
      req = req.copyWith(
        creationMode: mode,
        groupSource: matchedPlanGroup != null
            ? PlannerGroupSource.realClass
            : PlannerGroupSource.manual,
        realClaseId: matchedPlanGroup?.id,
        clearRealClaseId: matchedPlanGroup == null,
        groupName: reusePlan.groupName,
        audienceType: reusePlan.audienceType,
        curriculumScope: reusePlan.curriculumScope,
        ageMin: reusePlan.ageMin,
        ageMax: reusePlan.ageMax,
        participantsCount: reusePlan.participantsCount,
        experienceDistribution: reusePlan.experienceDistribution,
        durationMin: reusePlan.duracionTotal,
        focuses: reusePlan.enfoque
            .split('·')
            .map((e) => e.trim())
            .where((e) => kPlannerFocusOptions.contains(e))
            .toList(),
        objectives: reusePlan.objetivo.isNotEmpty
            ? [reusePlan.objetivo]
            : req.objectives,
        continuityContext: planGroupCtx,
        continuitySummary:
            planGroupCtx != null && planGroupCtx.hasContent ? planGroupCtx.shortHeadline : null,
        clearContinuity: planGroupCtx == null,
      );
    }
    if (fromSession != null) {
      PlannerGroupProfile? matchedGroup;
      for (final g in _groups) {
        if ((fromSession.groupId != null && g.id == fromSession.groupId) ||
            g.name == fromSession.groupName) {
          matchedGroup = g;
          break;
        }
      }
      if (matchedGroup != null) {
        req = ClassPlanDraftRequest.fromGroup(matchedGroup, mode: mode);
      } else {
        req = req.copyWith(
          groupSource: PlannerGroupSource.manual,
          clearRealClaseId: true,
          groupName: fromSession.groupName,
          audienceType: fromSession.audienceType,
          curriculumScope:
              PlannerCurriculumScope.suggestedForAudience(fromSession.audienceType),
        );
      }
      final ctx = PedagogicalContinuityContext.fromSession(fromSession);
      req = req.copyWith(
        continuityContext: ctx,
        continuitySummary: ctx.hasContent ? ctx.shortHeadline : null,
      );
    }
    if (preselectedResources != null && preselectedResources.isNotEmpty) {
      req = req.copyWith(
        selectedResources: preselectedResources
            .map((r) => SelectedTeacherResource(resource: r))
            .toList(),
      );
    }
    setState(() {
      _pendingDraftRequest = req;
      _activeCreationMode = mode;
    });
  }

  Future<void> _handleCreateLocalDraft(ClassPlanDraftRequest req) async {
    final draft = ClassPlanModel.fromLocalDraftRequest(req);
    await widget.dataSource.saveLocalDraft(draft);
    final updatedPlans = await widget.dataSource.loadPlans();
    if (!mounted) return;
    setState(() {
      _plans = updatedPlans;
      _activeCreationMode = null;
      _pendingDraftRequest = null;
      _generationError = null;
      _selectedResourceIdsForPlan.clear();
      _activeTab = PlannerHubTab.plans;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Borrador "${draft.titulo}" creado localmente sin marcar recursos como usados.',
        ),
        backgroundColor: PlannerPalette.of(context).accent,
        action: SnackBarAction(
          label: 'Abrir editor',
          textColor: PlannerPalette.of(context).onAccent,
          onPressed: () {
            if (mounted) _openEditor(draft);
          },
        ),
      ),
    );
  }

  Future<void> _handleGenerateWithEngine(ClassPlanDraftRequest req) async {
    final client = widget.engineClient;
    if (client == null) {
      await _handleCreateLocalDraft(req);
      return;
    }

    setState(() {
      _pendingDraftRequest = req;
      _isGeneratingWithEngine = true;
      _generationError = null;
    });

    try {
      final result = await client.generatePlan(request: req);
      await widget.dataSource.saveLocalDraft(result.plan);
      final updatedPlans = await widget.dataSource.loadPlans();
      if (!mounted) return;
      setState(() {
        _plans = updatedPlans;
        _isGeneratingWithEngine = false;
        _generationError = null;
        _activeCreationMode = null;
        _pendingDraftRequest = null;
        _selectedResourceIdsForPlan.clear();
        _editingPlan = result.plan;
        _editingIsDuplicate = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Propuesta "${result.plan.titulo}" generada en modo simulado offline y abierta para revisión.',
          ),
          backgroundColor: PlannerPalette.of(context).accent,
        ),
      );
    } on PlannerV2EngineException catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingWithEngine = false;
        _generationError = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingWithEngine = false;
        _generationError =
            'No se pudo completar la generación (${e.toString()}). Tus datos del borrador siguen intactos.';
      });
    }
  }

  String? _resolveGroupId(
    ClassPlanModel plan,
    List<PlannerGroupProfile> groups,
  ) {
    for (final g in groups) {
      if (g.name.toLowerCase() == plan.groupName.toLowerCase()) {
        return g.id;
      }
    }
    return null;
  }

  LiveSessionState _buildLiveSessionFromPlan(ClassPlanModel plan) {
    return LiveSessionState.startFromPlan(
      plan: plan,
      resources: _resources,
      now: _now(),
      groupId: _resolveGroupId(plan, _groups),
    );
  }

  Future<void> _startLiveClass(ClassPlanModel plan) async {
    final session = _buildLiveSessionFromPlan(plan);
    await _liveStorage.saveActiveSession(session);
    if (!mounted) return;
    setState(() {
      _activeCreationMode = null;
      _pendingDraftRequest = null;
      _editingPlan = null;
      _editingIsDuplicate = false;
      _activeLiveSession = session;
      _recoverableSession = session;
    });
  }

  void _resumeRecoveredSession() {
    final rec = _recoverableSession;
    if (rec == null) return;
    final resumed = rec.resume(_now());
    _liveStorage.saveActiveSession(resumed);
    setState(() {
      _activeCreationMode = null;
      _pendingDraftRequest = null;
      _editingPlan = null;
      _activeLiveSession = resumed;
      _recoverableSession = resumed;
    });
  }

  Future<void> _discardRecoveredSession() async {
    await _liveStorage.clearActiveSession();
    if (!mounted) return;
    setState(() {
      _activeLiveSession = null;
      _recoverableSession = null;
    });
  }

  Future<void> _handleFinalizeLiveSession(
    TaughtSessionRecord record,
    Set<String> taughtResourceIds,
  ) async {
    final recorded = await widget.dataSource.recordCompletedLiveSession(
      record,
      taughtResourceIds: taughtResourceIds,
    );
    await _liveStorage.clearActiveSession();
    final results = await Future.wait([
      widget.dataSource.loadHistory(),
      widget.dataSource.loadResources(),
      widget.dataSource.loadPlans(),
    ]);
    if (!mounted) return;
    setState(() {
      _history = results[0] as List<TaughtSessionRecord>;
      _resources = results[1] as List<PlannerResourceItem>;
      _plans = results[2] as List<ClassPlanModel>;
      _activeLiveSession = null;
      _recoverableSession = null;
      _activeTab = PlannerHubTab.history;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recorded
              ? 'Sesión "${record.planTitle}" guardada en Historial (${taughtResourceIds.length} recursos contabilizados).'
              : 'Esta sesión ya había sido registrada en Historial.',
        ),
        backgroundColor: PlannerPalette.of(context).accent,
      ),
    );
  }

  void _openManualFromScratch() {
    final blank = ClassPlanModel.emptyManual(
      group: _groups.isNotEmpty ? _groups.first : null,
    );
    setState(() {
      _activeCreationMode = null;
      _pendingDraftRequest = null;
      _editingPlan = blank;
      _editingIsDuplicate = false;
    });
  }

  void _openEditor(ClassPlanModel plan, {bool isDuplicate = false}) {
    setState(() {
      _activeCreationMode = null;
      _pendingDraftRequest = null;
      _editingPlan = plan;
      _editingIsDuplicate = isDuplicate;
    });
  }

  void _duplicateAndEditPlan(ClassPlanModel original) {
    final copy = ClassPlanEditorOperations.duplicatePlan(
      original,
      existingPlanIds: _plans.map((p) => p.id).toSet(),
    );
    _openEditor(copy, isDuplicate: true);
  }

  Future<void> _handleSaveEditedPlan(ClassPlanModel savedPlan) async {
    await widget.dataSource.saveLocalDraft(savedPlan);
    final updatedPlans = await widget.dataSource.loadPlans();
    if (!mounted) return;
    setState(() {
      _plans = updatedPlans;
      _editingPlan = null;
      _editingIsDuplicate = false;
      _activeTab = PlannerHubTab.plans;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Clase "${savedPlan.titulo}" guardada sin marcar recursos como usados.',
        ),
        backgroundColor: PlannerPalette.of(context).accent,
      ),
    );
  }

  Future<PlannerResourceItem?> _createLocalResourceFromEditor() async {
    final inMemory = widget.dataSource;
    if (inMemory is! InMemoryPlannerDataSource) return null;
    PlannerResourceItem? created;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: LocalResourceEditorSheet(
          onSave: (item) async {
            await inMemory.saveLocalResource(item);
            final updated = await inMemory.loadResources();
            created = item;
            if (!mounted) return;
            setState(() => _resources = updated);
          },
        ),
      ),
    );
    return created;
  }

  void _openPlanDetail(ClassPlanModel plan) {
    if (widget.onOpenLegacyPlanDetail != null &&
        plan.isLegacyV1 &&
        plan.rawLegacyMap.isNotEmpty) {
      widget.onOpenLegacyPlanDetail!(plan);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: ClassPlanSummarySheet(
          plan: plan,
          movementNamesById: _movementNamesById,
          resourcesById: {
            for (final r in _resources) r.resourceId: r,
          },
          onEditPlan: () => _openEditor(plan),
          onDuplicatePlan: () => _duplicateAndEditPlan(plan),
          onReuseInQuick: () =>
              _openCreation(PlannerCreationMode.quick, reusePlan: plan),
          onStartLive: () => _startLiveClass(plan),
        ),
      ),
    );
  }

  void _openAddOrEditLocalResource({PlannerResourceItem? initial}) {
    final inMemory = widget.dataSource;
    if (inMemory is! InMemoryPlannerDataSource) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: LocalResourceEditorSheet(
          initialResource: initial,
          onSave: (item) async {
            await inMemory.saveLocalResource(item);
            final updated = await inMemory.loadResources();
            if (!mounted) return;
            setState(() => _resources = updated);
          },
        ),
      ),
    );
  }

  void _openResourceViewer(PlannerResourceItem res) {
    if (widget.onLegacyOpenResourceMedia != null && res.url.isNotEmpty) {
      widget.onLegacyOpenResourceMedia!(res);
      return;
    }
    final pal = PlannerPalette.of(context);
    showDialog(
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
                PlannerBadge(
                  label: res.audienceLabel,
                  color: pal.textSecondary,
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
          if (widget.onLegacyEditIdea != null ||
              widget.dataSource is InMemoryPlannerDataSource)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: pal.accent,
                foregroundColor: pal.onAccent,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (widget.onLegacyEditIdea != null) {
                  widget.onLegacyEditIdea!(res);
                } else {
                  _openAddOrEditLocalResource(initial: res);
                }
              },
              child: Text(
                'Editar',
                style: GoogleFonts.montserrat(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  void _openSessionDetail(TaughtSessionRecord ses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: TaughtSessionDetailSheet(
          session: ses,
          onPrepareNextClass: () =>
              _openCreation(PlannerCreationMode.quick, fromSession: ses),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final baseTheme = Theme.of(context);
    final scopedTheme = baseTheme.copyWith(
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: GoogleFonts.montserrat(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return Theme(
      data: scopedTheme,
      child: _buildBodyContent(context, pal),
    );
  }

  Widget _buildBodyContent(BuildContext context, PlannerPalette pal) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: pal.accent),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PlannerNoticeBanner(
            title: 'No se pudo cargar el planificador',
            message: _loadError!,
            icon: Icons.error_outline,
            color: Colors.redAccent,
            backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
          ),
        ),
      );
    }

    if (_activeLiveSession != null) {
      return PlannerLiveClassView(
        key: ValueKey('live_class_${_activeLiveSession!.sessionId}'),
        initialSession: _activeLiveSession!,
        resources: _resources,
        curriculumRepository: widget.curriculumRepository,
        movementNamesById: _movementNamesById,
        storage: _liveStorage,
        clock: widget.clock,
        onOpenResource: _openResourceViewer,
        onFinalizeSession: _handleFinalizeLiveSession,
        onExitKeepPaused: () async {
          final loaded = await _liveStorage.loadActiveSession();
          if (!mounted) return;
          setState(() {
            _activeLiveSession = null;
            _recoverableSession = loaded;
          });
        },
        onDiscardSession: _discardRecoveredSession,
      );
    }

    if (_editingPlan != null) {
      return PlannerClassEditorView(
        key: ValueKey('class_editor_${_editingPlan!.id}_$_editingIsDuplicate'),
        initialPlan: _editingPlan!,
        isDuplicateCopy: _editingIsDuplicate,
        resources: _resources,
        curriculumRepository: widget.curriculumRepository,
        movementNamesById: _movementNamesById,
        onCreateLocalResource:
            widget.dataSource is InMemoryPlannerDataSource
                ? _createLocalResourceFromEditor
                : null,
        onOpenResource: _openResourceViewer,
        onSavePlan: _handleSaveEditedPlan,
        onCancel: () => setState(() {
          _editingPlan = null;
          _editingIsDuplicate = false;
        }),
      );
    }

    if (_activeCreationMode == PlannerCreationMode.quick) {
      return PlannerQuickCreateView(
        groups: _groups,
        resources: _resources,
        history: _history,
        curriculumRepository: widget.curriculumRepository,
        initialRequest: _pendingDraftRequest ??
            _buildDefaultRequest(PlannerCreationMode.quick),
        onCreateLocalDraft: _handleCreateLocalDraft,
        onGenerateWithEngine:
            widget.engineClient != null ? _handleGenerateWithEngine : null,
        isGenerating: _isGeneratingWithEngine,
        generationError: _generationError,
        onSwitchToAdvanced: (req) => setState(() {
          _pendingDraftRequest =
              req.copyWith(creationMode: PlannerCreationMode.advanced);
          _activeCreationMode = PlannerCreationMode.advanced;
          _generationError = null;
        }),
        onCancel: () => setState(() {
          _activeCreationMode = null;
          _generationError = null;
        }),
      );
    }

    if (_activeCreationMode == PlannerCreationMode.advanced) {
      return PlannerAdvancedCreateView(
        groups: _groups,
        resources: _resources,
        history: _history,
        curriculumRepository: widget.curriculumRepository,
        initialRequest: _pendingDraftRequest ??
            _buildDefaultRequest(PlannerCreationMode.advanced),
        onCreateLocalDraft: _handleCreateLocalDraft,
        onGenerateWithEngine:
            widget.engineClient != null ? _handleGenerateWithEngine : null,
        isGenerating: _isGeneratingWithEngine,
        generationError: _generationError,
        onSwitchToQuick: (req) => setState(() {
          _pendingDraftRequest =
              req.copyWith(creationMode: PlannerCreationMode.quick);
          _activeCreationMode = PlannerCreationMode.quick;
          _generationError = null;
        }),
        onCancel: () => setState(() {
          _activeCreationMode = null;
          _generationError = null;
        }),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final horizontalPad = width >= 900 ? 24.0 : 16.0;

    return RefreshIndicator(
      color: pal.accent,
      onRefresh: _loadAll,
      child: ListView(
        padding: EdgeInsets.fromLTRB(horizontalPad, 14, horizontalPad, 88),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recoverableSession != null) ...[
                    _buildRecoverableSessionBanner(pal, _recoverableSession!),
                    const SizedBox(height: 12),
                  ],
                  _buildHeaderBanner(pal),
                  const SizedBox(height: 14),
                  _buildTabBar(pal),
                  const SizedBox(height: 14),
                  if (_activeTab == PlannerHubTab.plans)
                    _buildPlansSection(pal, width)
                  else if (_activeTab == PlannerHubTab.resources)
                    _buildResourcesSection(pal, width)
                  else
                    _buildHistorySection(pal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoverableSessionBanner(
    PlannerPalette pal,
    LiveSessionState recovered,
  ) {
    return Container(
      key: const Key('hub_resume_live_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.amberBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.amber.withValues(alpha: 0.55)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.play_circle_outline_rounded,
                    color: pal.amber, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clase en vivo interrumpida lista para reanudar',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${recovered.planTitle} · ${recovered.completedCount}/${recovered.totalExercisesCount} ejercicios completados',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const Key('hub_discard_live_btn'),
                onPressed: _discardRecoveredSession,
                child: Text(
                  'Descartar',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pal.textSecondary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('hub_resume_live_btn'),
                onPressed: _resumeRecoveredSession,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: pal.accent,
                  foregroundColor: pal.onAccent,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  'Reanudar clase',
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(PlannerPalette pal) {
    final latestSession = _history.isNotEmpty ? _history.first : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surfaceTint,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PlannerBadge(
                          label: 'Planificador Pedagógico',
                          color: pal.accent,
                          icon: Icons.school_outlined,
                        ),
                        PlannerBadge(
                          label: '${_groups.length} grupos activos',
                          color: pal.infoBlue,
                          backgroundColor: pal.infoBlueBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prepara clases con continuidad real, recursos de Pizarra y Currículo FIU',
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                    if (latestSession != null &&
                        latestSession.pendingNextSession.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Continuidad reciente (${latestSession.groupName}): ${latestSession.pendingNextSession}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    key: const Key('hub_quick_create_button'),
                    onPressed: () => _openCreation(PlannerCreationMode.quick),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: pal.accent,
                      foregroundColor: pal.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 17),
                    label: Text(
                      'Creación rápida',
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('hub_advanced_create_button'),
                    onPressed: () =>
                        _openCreation(PlannerCreationMode.advanced),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: pal.accent),
                      foregroundColor: pal.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 17),
                    label: Text(
                      'Creación avanzada',
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('hub_manual_create_button'),
                    onPressed: _openManualFromScratch,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: pal.border),
                      foregroundColor: pal.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.note_add_outlined, size: 17),
                    label: Text(
                      'Crear desde cero',
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.onOpenBiblioteca != null)
                    OutlinedButton.icon(
                      onPressed: widget.onOpenBiblioteca,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: BorderSide(color: pal.border),
                        foregroundColor: pal.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 17),
                      label: Text(
                        'Biblioteca FIU',
                        style: GoogleFonts.montserrat(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(PlannerPalette pal) {
    final counts = {
      PlannerHubTab.plans: _plans.length,
      PlannerHubTab.resources: _resources.length,
      PlannerHubTab.history: _history.length,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in PlannerHubTab.values)
          InkWell(
            key: Key('hub_tab_${tab.name}'),
            onTap: () => setState(() => _activeTab = tab),
            borderRadius: BorderRadius.circular(GingaRadius.full),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _activeTab == tab ? pal.accent : pal.surface,
                borderRadius: BorderRadius.circular(GingaRadius.full),
                border: Border.all(
                  color: _activeTab == tab ? pal.accent : pal.border,
                ),
              ),
              child: Text(
                '${tab.label} (${counts[tab] ?? 0})',
                style: GoogleFonts.montserrat(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _activeTab == tab ? pal.onAccent : pal.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlansSection(PlannerPalette pal, double width) {
    final q = _plansSearchQuery.trim().toLowerCase();
    final filtered = _plans.where((p) {
      final matchAud = _planAudienceFilter == 'Todos' ||
          p.audienceType.label == _planAudienceFilter;
      final matchQ = q.isEmpty ||
          p.titulo.toLowerCase().contains(q) ||
          p.groupName.toLowerCase().contains(q) ||
          p.enfoque.toLowerCase().contains(q) ||
          p.objetivo.toLowerCase().contains(q);
      return matchAud && matchQ;
    }).toList();

    final crossAxisCount = width >= 1120 ? 3 : (width >= 720 ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width >= 720 ? 320 : double.infinity,
              child: TextField(
                key: const Key('plans_search_field'),
                controller: _plansSearchCtrl,
                onChanged: (v) => setState(() => _plansSearchQuery = v),
                style: GoogleFonts.montserrat(
                    fontSize: 12.5, color: pal.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: pal.textSecondary),
                  hintText: 'Buscar planes por título, grupo o enfoque...',
                  isDense: true,
                  suffixIcon: _plansSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _plansSearchCtrl.clear();
                            setState(() => _plansSearchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final f in const ['Todos', 'Adultos', 'Infantil', 'Mixto'])
                  PlannerChoicePill(
                    label: f,
                    selected: _planAudienceFilter == f,
                    onTap: () => setState(() => _planAudienceFilter = f),
                  ),
                Text(
                  '${filtered.length} planes',
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    color: pal.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          PlannerNoticeBanner(
            title: 'Sin planes en este filtro',
            message:
                'Ajusta la búsqueda o crea un borrador con Creación rápida o Creación avanzada.',
            color: pal.infoBlue,
            backgroundColor: pal.infoBlueBg,
          )
        else
          _ResponsivePlanGrid(
            columns: crossAxisCount,
            children: [
              for (final plan in filtered)
                _PlanSummaryCard(
                  plan: plan,
                  onView: () => _openPlanDetail(plan),
                  onEditPlan: () => _openEditor(plan),
                  onReuseQuick: () => _duplicateAndEditPlan(plan),
                  onStartLive: widget.onStartLegacyLiveClass != null
                      ? () => widget.onStartLegacyLiveClass!(plan)
                      : () => _startLiveClass(plan),
                  onDelete: widget.onDeletePlan != null
                      ? () => widget.onDeletePlan!(plan)
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildResourcesSection(PlannerPalette pal, double width) {
    final q = _resourcesSearchQuery.trim().toLowerCase();
    final filtered = _resources.where((r) {
      final matchPub = _resourceAudienceFilter == 'Todos' ||
          r.audienceLabel == _resourceAudienceFilter ||
          r.audienceLabel == 'Todos' ||
          r.audienceLabel == 'Mixto';
      final matchPhase = _resourcePhaseFilter == 'Todos' ||
          r.category.toLowerCase() == _resourcePhaseFilter.toLowerCase();
      final matchStatus = _resourceStatusFilter == 'Todos' ||
          (_resourceStatusFilter == 'Nuevos' && !r.hasBeenTaught) ||
          (_resourceStatusFilter == 'En Clases' && r.hasBeenTaught);
      final matchQ = q.isEmpty ||
          r.title.toLowerCase().contains(q) ||
          r.notes.toLowerCase().contains(q) ||
          r.category.toLowerCase().contains(q) ||
          r.mediaLabel.toLowerCase().contains(q);
      return matchPub && matchPhase && matchStatus && matchQ;
    }).toList();

    final columns = width >= 1120 ? 3 : (width >= 680 ? 2 : 1);
    final selectedResources = _resources
        .where((r) => _selectedResourceIdsForPlan.contains(r.resourceId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra superior: buscador + Añadir recurso siempre visible
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width >= 720 ? 340 : double.infinity,
              child: TextField(
                key: const Key('pizarra_search_field'),
                controller: _resourcesSearchCtrl,
                onChanged: (v) => setState(() => _resourcesSearchQuery = v),
                style: GoogleFonts.montserrat(
                    fontSize: 12.5, color: pal.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: pal.textSecondary),
                  hintText: 'Buscar por título, nota, tipo o categoría...',
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
            ),
            ElevatedButton.icon(
              key: const Key('pizarra_add_resource_button'),
              onPressed: () {
                if (widget.onLegacyCreateIdea != null) {
                  widget.onLegacyCreateIdea!();
                } else {
                  _openAddOrEditLocalResource();
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 42),
                backgroundColor: pal.accent,
                foregroundColor: pal.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Añadir recurso',
                style: GoogleFonts.montserrat(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filtros organizados visualmente por grupo
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterGroupRow(
                label: 'Público:',
                options: const ['Todos', 'Adultos', 'Niños'],
                selectedValue: _resourceAudienceFilter,
                onSelect: (v) => setState(() => _resourceAudienceFilter = v),
              ),
              const SizedBox(height: 8),
              _FilterGroupRow(
                label: 'Categoría:',
                options: const [
                  'Todos',
                  'Calentamiento',
                  'Técnica',
                  'Acrobacias',
                  'Juegos',
                  'Roda',
                ],
                selectedValue: _resourcePhaseFilter,
                onSelect: (v) => setState(() => _resourcePhaseFilter = v),
              ),
              const SizedBox(height: 8),
              _FilterGroupRow(
                label: 'Estado:',
                options: const ['Todos', 'Nuevos', 'En Clases'],
                selectedValue: _resourceStatusFilter,
                onSelect: (v) => setState(() => _resourceStatusFilter = v),
              ),
            ],
          ),
        ),
        if (selectedResources.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.surfaceTint,
              borderRadius: BorderRadius.circular(GingaRadius.md),
              border: Border.all(color: pal.accent.withValues(alpha: 0.45)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${selectedResources.length} recurso(s) seleccionado(s) para planificar (sin marcar como usados)',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedResourceIdsForPlan.clear()),
                      child: Text(
                        'Limpiar',
                        style: GoogleFonts.montserrat(
                            fontSize: 12, color: pal.textSecondary),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('pizarra_use_in_quick_button'),
                      onPressed: () => _openCreation(
                        PlannerCreationMode.quick,
                        preselectedResources: selectedResources,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        side: BorderSide(color: pal.accent),
                        foregroundColor: pal.accent,
                      ),
                      icon: const Icon(Icons.flash_on_outlined, size: 16),
                      label: Text(
                        'Usar en rápida',
                        style: GoogleFonts.montserrat(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    ElevatedButton.icon(
                      key: const Key('pizarra_use_in_advanced_button'),
                      onPressed: () => _openCreation(
                        PlannerCreationMode.advanced,
                        preselectedResources: selectedResources,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        backgroundColor: pal.accent,
                        foregroundColor: pal.onAccent,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(
                        'Usar en avanzada',
                        style: GoogleFonts.montserrat(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          PlannerNoticeBanner(
            title: 'Sin recursos para estos filtros',
            message: 'Ajusta la búsqueda o añade un nuevo recurso a tu Pizarra.',
            color: pal.infoBlue,
            backgroundColor: pal.infoBlueBg,
          )
        else
          _ResponsivePlanGrid(
            columns: columns,
            children: [
              for (final res in filtered)
                _ResourceGridCard(
                  resource: res,
                  selectedForPlan:
                      _selectedResourceIdsForPlan.contains(res.resourceId),
                  onToggleSelectForPlan: () => setState(() {
                    if (_selectedResourceIdsForPlan.contains(res.resourceId)) {
                      _selectedResourceIdsForPlan.remove(res.resourceId);
                    } else {
                      _selectedResourceIdsForPlan.add(res.resourceId);
                    }
                  }),
                  onView: () => _openResourceViewer(res),
                  onEdit: () {
                    if (widget.onLegacyEditIdea != null) {
                      widget.onLegacyEditIdea!(res);
                    } else {
                      _openAddOrEditLocalResource(initial: res);
                    }
                  },
                  onDelete: widget.onLegacyDeleteIdea != null
                      ? () => widget.onLegacyDeleteIdea!(res)
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildHistorySection(PlannerPalette pal) {
    final hasSimulatedFixtures = _history.any((s) => s.isSimulatedFixture);
    final groupOptions = <String>{
      'Todos',
      ..._history.map((s) => s.groupName),
    }.toList();

    final now = DateTime.now();
    final filtered = _history.where((ses) {
      final matchGroup = _historyGroupFilter == 'Todos' ||
          ses.groupName == _historyGroupFilter;
      final daysAgo = now.difference(ses.date).inDays;
      final matchDate = _historyDateFilter == 'Todas' ||
          (_historyDateFilter == 'Últimos 7 días' && daysAgo <= 7) ||
          (_historyDateFilter == 'Últimos 30 días' && daysAgo <= 30);
      return matchGroup && matchDate;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSimulatedFixtures) ...[
          PlannerNoticeBanner(
            title: 'Datos de ejemplo del entorno local',
            message:
                'Estas sesiones de muestra conviven con las sesiones reales que finalices y guardes localmente.',
            icon: Icons.science_outlined,
            color: pal.amber,
            backgroundColor: pal.amberBg,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterGroupRow(
                label: 'Grupo:',
                options: groupOptions,
                selectedValue: _historyGroupFilter,
                onSelect: (v) => setState(() => _historyGroupFilter = v),
              ),
              const SizedBox(height: 8),
              _FilterGroupRow(
                label: 'Fecha:',
                options: const ['Todas', 'Últimos 7 días', 'Últimos 30 días'],
                selectedValue: _historyDateFilter,
                onSelect: (v) => setState(() => _historyDateFilter = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          PlannerNoticeBanner(
            title: 'Sin sesiones para estos filtros',
            message:
                'Prueba ampliar el rango de fechas o seleccionar todos los grupos.',
            color: pal.infoBlue,
            backgroundColor: pal.infoBlueBg,
          )
        else
          for (final ses in filtered)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
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
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PlannerBadge(
                            label:
                                '${ses.date.day}/${ses.date.month}/${ses.date.year}',
                            color: pal.accent,
                            icon: Icons.event_available_outlined,
                          ),
                          PlannerBadge(
                            label: ses.groupName,
                            color: pal.infoBlue,
                            backgroundColor: pal.infoBlueBg,
                          ),
                          PlannerBadge(
                            label:
                                '${ses.durationMin} min · ${ses.attendeesCount} alumnos',
                            color: pal.textSecondary,
                          ),
                        ],
                      ),
                      PlannerBadge(
                        label:
                            '${ses.completedExercisesCount}/${ses.totalExercisesCount} ejercicios',
                        color: pal.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ses.planTitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  if (ses.practicedMovements.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Movimientos:',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: pal.textSecondary,
                          ),
                        ),
                        for (final mov in ses.practicedMovements)
                          PlannerBadge(
                            label: mov,
                            color: pal.accent,
                          ),
                      ],
                    ),
                  ],
                  if (ses.summaryNote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      ses.summaryNote,
                      style: GoogleFonts.montserrat(
                        fontSize: 12.5,
                        color: pal.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (ses.pendingNextSession.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    PlannerNoticeBanner(
                      title: 'Pendiente / Continuidad próxima sesión',
                      message: ses.pendingNextSession,
                      icon: Icons.forward_outlined,
                      color: pal.accent,
                      backgroundColor: pal.surfaceTint,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: Key('history_detail_${ses.sessionId}'),
                        onPressed: () => _openSessionDetail(ses),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          side: BorderSide(color: pal.border),
                          foregroundColor: pal.textPrimary,
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text(
                          'Ver detalle',
                          style: GoogleFonts.montserrat(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      ElevatedButton.icon(
                        key: Key('history_prepare_next_${ses.sessionId}'),
                        onPressed: () => _openCreation(
                          PlannerCreationMode.quick,
                          fromSession: ses,
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: pal.accent,
                          foregroundColor: pal.onAccent,
                        ),
                        icon: const Icon(Icons.play_lesson_outlined, size: 16),
                        label: Text(
                          'Preparar siguiente clase',
                          style: GoogleFonts.montserrat(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _FilterGroupRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelect;

  const _FilterGroupRow({
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: pal.textSecondary,
          ),
        ),
        for (final opt in options)
          PlannerChoicePill(
            label: opt,
            selected: selectedValue == opt,
            onTap: () => onSelect(opt),
          ),
      ],
    );
  }
}

class _ResponsivePlanGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const _ResponsivePlanGrid({
    required this.columns,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        children: [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
        ],
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
        i,
        (i + columns) > children.length ? children.length : (i + columns),
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 14),
                  Expanded(
                    child:
                        c < slice.length ? slice[c] : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _PlanSummaryCard extends StatelessWidget {
  final ClassPlanModel plan;
  final VoidCallback onView;
  final VoidCallback onEditPlan;
  final VoidCallback onReuseQuick;
  final VoidCallback? onStartLive;
  final VoidCallback? onDelete;

  const _PlanSummaryCard({
    required this.plan,
    required this.onView,
    required this.onEditPlan,
    required this.onReuseQuick,
    this.onStartLive,
    this.onDelete,
  });

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final origins = plan.detectedOrigins;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PlannerBadge(
                          label: '${plan.duracionTotal} min',
                          color: pal.accent,
                        ),
                        PlannerBadge(
                          label: plan.audienceType.label,
                          color: pal.infoBlue,
                          backgroundColor: pal.infoBlueBg,
                        ),
                        PlannerBadge(
                          label: plan.planStatus.label,
                          color: pal.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: pal.textSecondary),
                      onPressed: onDelete,
                      tooltip: 'Eliminar plan',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                plan.titulo,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${plan.groupName} · ${plan.bloques.length} bloques · ${plan.enfoque}',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: pal.textSecondary,
                ),
              ),
              if (plan.ultimaEjecucion != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Última ejecución: ${_formatDate(plan.ultimaEjecucion!)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: pal.accent,
                  ),
                ),
              ],
              if (plan.objetivo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  plan.objetivo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: pal.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final origin in origins)
                    PlannerOriginBadge(origin: origin),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onView,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: BorderSide(color: pal.border),
                    foregroundColor: pal.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(
                    'Ver plan',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onEditPlan,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: BorderSide(color: pal.accent),
                    foregroundColor: pal.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    'Editar plan',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onReuseQuick,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: BorderSide(color: pal.border),
                    foregroundColor: pal.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: Text(
                    'Reutilizar',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Tooltip(
                  message: onStartLive != null
                      ? 'Iniciar clase en vivo'
                      : 'Disponible próximamente en la fase de ejecución en vivo',
                  child: ElevatedButton.icon(
                    onPressed: onStartLive,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: pal.accent,
                      foregroundColor: pal.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      'Iniciar clase',
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
}

class _ResourceGridCard extends StatelessWidget {
  final PlannerResourceItem resource;
  final bool selectedForPlan;
  final VoidCallback onToggleSelectForPlan;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _ResourceGridCard({
    required this.resource,
    required this.selectedForPlan,
    required this.onToggleSelectForPlan,
    required this.onView,
    required this.onEdit,
    this.onDelete,
  });

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

  Widget _buildThumbnail(PlannerPalette pal) {
    final thumb = resource.resolvedThumbnailUrl;
    if (thumb != null && thumb.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        child: Image.asset(
          thumb,
          height: 92,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _mediaPlaceholder(pal),
        ),
      );
    }
    if (thumb != null && thumb.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        child: Image.network(
          thumb,
          height: 92,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _mediaPlaceholder(pal),
        ),
      );
    }
    return _mediaPlaceholder(pal);
  }

  Widget _mediaPlaceholder(PlannerPalette pal) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _iconForMedia(resource.mediaKind),
            size: 24,
            color: pal.accent,
          ),
          const SizedBox(width: 8),
          Text(
            resource.mediaLabel,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: pal.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selectedForPlan ? pal.surfaceTint : pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(
          color: selectedForPlan
              ? pal.accent
              : (resource.hasBeenTaught
                  ? pal.accent.withValues(alpha: 0.45)
                  : pal.border),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(pal),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PlannerBadge(
                    label: resource.mediaLabel,
                    color: pal.amber,
                    backgroundColor: pal.amberBg,
                    icon: _iconForMedia(resource.mediaKind),
                  ),
                  PlannerBadge(
                    label: resource.category,
                    color: pal.infoBlue,
                    backgroundColor: pal.infoBlueBg,
                  ),
                  PlannerBadge(
                    label: resource.audienceLabel,
                    color: pal.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                resource.title,
                style: GoogleFonts.montserrat(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: pal.textPrimary,
                ),
              ),
              if (resource.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  resource.notes,
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PlannerChoicePill(
                  key: Key('pizarra_select_${resource.resourceId}'),
                  label: selectedForPlan ? 'Seleccionado' : 'Planificar',
                  icon: selectedForPlan
                      ? Icons.check_box_outlined
                      : Icons.add_circle_outline,
                  selected: selectedForPlan,
                  onTap: onToggleSelectForPlan,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.visibility_outlined,
                          size: 18, color: pal.textPrimary),
                      onPressed: onView,
                      tooltip: 'Ver recurso',
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          size: 18, color: pal.textPrimary),
                      onPressed: onEdit,
                      tooltip: 'Editar recurso',
                    ),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: pal.textSecondary),
                        onPressed: onDelete,
                        tooltip: 'Eliminar recurso',
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
}

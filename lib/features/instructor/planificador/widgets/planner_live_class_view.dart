import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/curriculum_repository.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../../../biblioteca/movimiento_detalle_screen.dart';
import '../../../biblioteca/widgets/biblioteca_user_context.dart';
import '../models/class_plan_models.dart';
import '../models/live_session_models.dart';
import '../services/live_session_persistence.dart';
import '../theme/planner_palette.dart';
import 'planner_live_closure_sheet.dart';
import 'planner_shared_widgets.dart';

/// Ejecución de clases en vivo V2 integrada al Planificador Pedagógico.
class PlannerLiveClassView extends StatefulWidget {
  final LiveSessionState initialSession;
  final List<PlannerResourceItem> resources;
  final CurriculumRepository? curriculumRepository;
  final Map<String, String> movementNamesById;
  final LiveSessionStorage storage;
  final DateTime Function()? clock;
  final ValueChanged<PlannerResourceItem>? onOpenResource;
  final Future<void> Function(
    TaughtSessionRecord record,
    Set<String> taughtResourceIds,
  ) onFinalizeSession;
  final VoidCallback onExitKeepPaused;
  final VoidCallback onDiscardSession;

  const PlannerLiveClassView({
    super.key,
    required this.initialSession,
    required this.resources,
    this.curriculumRepository,
    required this.movementNamesById,
    required this.storage,
    this.clock,
    this.onOpenResource,
    required this.onFinalizeSession,
    required this.onExitKeepPaused,
    required this.onDiscardSession,
  });

  @override
  State<PlannerLiveClassView> createState() => _PlannerLiveClassViewState();
}

class _PlannerLiveClassViewState extends State<PlannerLiveClassView>
    with WidgetsBindingObserver {
  late LiveSessionState _state;
  Timer? _uiRefreshTimer;
  int _selectedVariantTab = 0;
  bool _showAllVariants = false;
  final Set<String> _notifiedTimeoutExerciseIds = {};
  bool _openingClosure = false;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = widget.initialSession;
    _persistState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant PlannerLiveClassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSession.sessionId != widget.initialSession.sessionId) {
      _state = widget.initialSession;
      _notifiedTimeoutExerciseIds.clear();
      _selectedVariantTab = 0;
      _persistState();
      _syncTicker();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _persistState();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {});
        _checkExerciseTimeout();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _uiRefreshTimer?.cancel();
    if (!_state.isRunning) return;
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkExerciseTimeout();
    });
  }

  void _checkExerciseTimeout() {
    final active = _state.activeExercise;
    final rem = _state.effectiveActiveExerciseRemainingSec(_now());
    if (_state.isRunning &&
        rem <= 0 &&
        !_notifiedTimeoutExerciseIds.contains(active.exerciseId)) {
      _notifiedTimeoutExerciseIds.add(active.exerciseId);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _persistState() async {
    await widget.storage.saveActiveSession(_state);
  }

  void _updateState(LiveSessionState next) {
    setState(() {
      _state = next;
    });
    _syncTicker();
    _persistState();
  }

  void _togglePlayPause() {
    final now = _now();
    _updateState(_state.isRunning ? _state.pause(now) : _state.resume(now));
  }

  void _adjustMinutes(int delta) {
    final now = _now();
    if (delta > 0) {
      _notifiedTimeoutExerciseIds.remove(_state.activeExercise.exerciseId);
    }
    _updateState(_state.adjustActiveExerciseMinutes(delta, now));
  }

  void _resetActiveTimer() {
    _notifiedTimeoutExerciseIds.remove(_state.activeExercise.exerciseId);
    _updateState(_state.resetActiveExerciseTimer(_now()));
  }

  void _goToExercise(int index) {
    _selectedVariantTab = 0;
    _updateState(_state.goToExercise(index, _now()));
  }

  void _goToBlock(int blockIndex) {
    _selectedVariantTab = 0;
    _updateState(_state.goToBlock(blockIndex, _now()));
  }

  void _markSkippedAndAdvance() {
    final now = _now();
    final isLast = _state.activeExerciseIndex >= _state.totalExercisesCount - 1;
    final updated = _state.markActiveStatus(
      LiveExerciseStatus.skipped,
      now,
      advanceToNext: !isLast,
    );
    _updateState(updated);
    if (isLast) {
      _openClosureSheet(endedEarly: updated.pendingCount > 0);
    }
  }

  Future<void> _markCompletedAndAdvance() async {
    final now = _now();
    final realSec = _state.effectiveActiveExerciseElapsedSec(now);
    if (realSec <= 0) {
      final pal = PlannerPalette.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('live_zero_duration_dialog'),
          backgroundColor: pal.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            side: BorderSide(color: pal.border),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: pal.amber, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ejercicio en 00:00',
                  style: GoogleFonts.montserrat(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'El tiempo real registrado en "${_state.activeExercise.exercise.nombre}" es 00:00. ¿Confirmas marcarlo como completado y contabilizar su progreso?',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: pal.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              key: const Key('live_cancel_zero_complete_btn'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.montserrat(color: pal.textSecondary),
              ),
            ),
            ElevatedButton(
              key: const Key('live_confirm_zero_complete_btn'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: pal.accent,
                foregroundColor: pal.onAccent,
              ),
              child: Text(
                'Confirmar completado',
                style: GoogleFonts.montserrat(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _commitCompletedAndAdvance(_now());
  }

  void _commitCompletedAndAdvance(DateTime now) {
    final isLast = _state.activeExerciseIndex >= _state.totalExercisesCount - 1;
    final updated = _state.markActiveStatus(
      LiveExerciseStatus.completed,
      now,
      advanceToNext: !isLast,
    );
    _updateState(updated);
    if (isLast) {
      _openClosureSheet(endedEarly: false);
    }
  }

  Future<void> _openMovementDetail(String movId) async {
    final repo = widget.curriculumRepository;
    final mov = repo != null ? await repo.getMovementById(movId) : null;
    if (!mounted) return;
    if (repo != null && mov != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MovimientoDetalleScreen(
            movement: mov,
            repository: repo,
            userContext: const BibliotecaUserContext(
              role: 'profesor',
              cordaName: 'Laranja e Amarelo',
              displayName: 'Profesor',
            ),
          ),
        ),
      );
      return;
    }
    final pal = PlannerPalette.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        title: Text(
          widget.movementNamesById[movId] ?? movId,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            color: pal.textPrimary,
          ),
        ),
        content: Text(
          'Movimiento FIU vinculado ($movId). Consulta técnica rápida sin perder el estado de la clase en curso.',
          style: GoogleFonts.montserrat(color: pal.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _openLinkedResource(
    PlannerResourceItem? res, {
    String? fallbackLabel,
    String? usageNote,
  }) {
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
          res?.title ?? fallbackLabel ?? 'Recurso de Pizarra',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            color: pal.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (res != null) ...[
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
              const SizedBox(height: 10),
            ],
            if (usageNote != null && usageNote.trim().isNotEmpty) ...[
              PlannerNoticeBanner(
                title: 'Consigna particular para este ejercicio',
                message: usageNote.trim(),
                icon: Icons.push_pin_outlined,
                color: pal.accent,
                backgroundColor: pal.surfaceTint,
              ),
              const SizedBox(height: 10),
            ],
            if (res != null && res.notes.isNotEmpty)
              Text(
                res.notes,
                style: GoogleFonts.montserrat(
                  fontSize: 12.5,
                  color: pal.textSecondary,
                  height: 1.4,
                ),
              ),
            if (res != null && res.url.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                res.url,
                style: GoogleFonts.montserrat(
                  fontSize: 11.5,
                  color: pal.infoBlue,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Volver a la clase',
              style: GoogleFonts.montserrat(color: pal.textSecondary),
            ),
          ),
          if (res != null && widget.onOpenResource != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onOpenResource!(res);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: pal.accent,
                foregroundColor: pal.onAccent,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Abrir recurso'),
            ),
        ],
      ),
    );
  }

  Future<void> _openClosureSheet({required bool endedEarly}) async {
    if (_openingClosure) return;
    _openingClosure = true;
    final now = _now();
    final pausedSnap = _state.pause(now);
    setState(() => _state = pausedSnap);
    _syncTicker();
    await _persistState();
    if (!mounted) {
      _openingClosure = false;
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PlannerLiveClosureSheet(
          key: ValueKey('closure_sheet_${pausedSnap.sessionId}'),
          sessionSnapshot: pausedSnap,
          resources: widget.resources,
          movementNamesById: widget.movementNamesById,
          finishedAt: now,
          endedEarly: endedEarly || pausedSnap.pendingCount > 0,
          onConfirmSave: (closureInput) async {
            final record = pausedSnap.toTaughtSessionRecord(
              finishedAt: now,
              closure: closureInput,
              movementNamesById: widget.movementNamesById,
            );
            final taughtIds = pausedSnap.taughtResourceIds;
            await widget.onFinalizeSession(record, taughtIds);
            if (sheetCtx.mounted) {
              Navigator.of(sheetCtx).pop();
            }
          },
        ),
      ),
    );
    _openingClosure = false;
  }

  Future<void> _confirmDiscardOrExit() async {
    final pal = PlannerPalette.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          side: BorderSide(color: pal.border),
        ),
        title: Text(
          'Salir de la clase en vivo',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            color: pal.textPrimary,
          ),
        ),
        content: Text(
          'Puedes volver al Planificador guardando tu progreso local para reanudar después, o descartar esta sesión.',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            color: pal.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDiscardSession();
            },
            child: Text(
              'Descartar sesión',
              style: GoogleFonts.montserrat(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Seguir enseñando',
              style: GoogleFonts.montserrat(color: pal.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final savedPaused = _state.pause(_now());
              _state = savedPaused;
              await widget.storage.saveActiveSession(savedPaused);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              widget.onExitKeepPaused();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pal.accent,
              foregroundColor: pal.onAccent,
            ),
            child: const Text('Guardar y salir'),
          ),
        ],
      ),
    );
  }

  Color _timerColor(PlannerPalette pal, int remainingSec, int allocatedSec) {
    if (remainingSec <= 0) return Colors.redAccent;
    final ratio = allocatedSec <= 0 ? 0.0 : remainingSec / allocatedSec;
    if (ratio > 0.40) return pal.accent;
    if (ratio > 0.15) return pal.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;
    final now = _now();
    final active = _state.activeExercise;
    final resourcesById = {
      for (final r in widget.resources) r.resourceId: r,
    };

    return ColoredBox(
      color: pal.background,
      child: Column(
        children: [
          _buildTopHeader(pal, now, width),
          _buildBlockStepper(pal),
          Expanded(
            child: isWide
                ? _buildDesktopSplitBody(pal, now, active, resourcesById)
                : _buildCompactScrollBody(pal, now, active, resourcesById),
          ),
          _buildBottomActionBar(pal, width),
        ],
      ),
    );
  }

  Widget _buildTopHeader(PlannerPalette pal, DateTime now, double width) {
    final elapsedSec = _state.effectiveTotalElapsedSec(now);
    final isCompact = width < 640;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isCompact ? 12 : 20, 10, isCompact ? 12 : 20, 10),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(bottom: BorderSide(color: pal.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('live_exit_btn'),
                tooltip: 'Salir y guardar progreso para reanudar',
                onPressed: _confirmDiscardOrExit,
                icon: Icon(Icons.arrow_back_rounded, color: pal.textPrimary),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _state.planTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _state.groupName,
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: pal.textSecondary,
                          ),
                        ),
                        Text(
                          '· ${formatDurationMmSs(elapsedSec)} / ${_state.plannedTotalDurationMin} min',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: pal.accent,
                          ),
                        ),
                        Text(
                          '· ${_state.completedCount}/${_state.totalExercisesCount} completados',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('live_finish_btn'),
                onPressed: () => _openClosureSheet(
                  endedEarly: _state.pendingCount > 0,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  side: BorderSide(color: pal.amber),
                  foregroundColor: pal.amber,
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14),
                ),
                icon: const Icon(Icons.flag_outlined, size: 17),
                label: Text(
                  'Finalizar',
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.full),
            child: LinearProgressIndicator(
              value: _state.progressRatio,
              minHeight: 6,
              backgroundColor: pal.border,
              valueColor: AlwaysStoppedAnimation<Color>(pal.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockStepper(PlannerPalette pal) {
    final blocks = <({int blockIndex, String title, int total, int done, int skipped})>[];
    for (final ex in _state.exercises) {
      if (blocks.isEmpty || blocks.last.blockIndex != ex.blockIndex) {
        final inBlock =
            _state.exercises.where((e) => e.blockIndex == ex.blockIndex).toList();
        blocks.add((
          blockIndex: ex.blockIndex,
          title: ex.blockTitle,
          total: inBlock.length,
          done: inBlock.where((e) => e.status == LiveExerciseStatus.completed).length,
          skipped: inBlock.where((e) => e.status == LiveExerciseStatus.skipped).length,
        ));
      }
    }

    final activeBlockIdx = _state.activeExercise.blockIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pal.surfaceAlt.withValues(alpha: 0.55),
        border: Border(bottom: BorderSide(color: pal.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final blk in blocks) ...[
              InkWell(
                key: Key('live_block_step_${blk.blockIndex}'),
                onTap: () => _goToBlock(blk.blockIndex),
                borderRadius: BorderRadius.circular(GingaRadius.lg),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: blk.blockIndex == activeBlockIdx
                        ? pal.accent
                        : (blk.done == blk.total
                            ? pal.surfaceTint
                            : pal.surface),
                    borderRadius: BorderRadius.circular(GingaRadius.lg),
                    border: Border.all(
                      color: blk.blockIndex == activeBlockIdx
                          ? pal.accent
                          : (blk.done == blk.total
                              ? pal.accent.withValues(alpha: 0.5)
                              : pal.border),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (blk.done == blk.total)
                        Icon(
                          Icons.check_circle,
                          size: 15,
                          color: blk.blockIndex == activeBlockIdx
                              ? pal.onAccent
                              : pal.accent,
                        )
                      else
                        Text(
                          '${blk.blockIndex + 1}.',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: blk.blockIndex == activeBlockIdx
                                ? pal.onAccent
                                : pal.accent,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        blk.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: blk.blockIndex == activeBlockIdx
                              ? pal.onAccent
                              : pal.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${blk.done}/${blk.total})',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: blk.blockIndex == activeBlockIdx
                              ? pal.onAccent.withValues(alpha: 0.9)
                              : pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSplitBody(
    PlannerPalette pal,
    DateTime now,
    LiveExerciseExecution active,
    Map<String, PlannerResourceItem> resourcesById,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 62,
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimerCard(pal, now, active, isCompact: false),
                const SizedBox(height: 16),
                _buildExerciseDetailCard(pal, active, resourcesById),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: pal.border),
        Expanded(
          flex: 38,
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(18),
            child: _buildExerciseSequencePanel(pal, now),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactScrollBody(
    PlannerPalette pal,
    DateTime now,
    LiveExerciseExecution active,
    Map<String, PlannerResourceItem> resourcesById,
  ) {
    final width = MediaQuery.of(context).size.width;
    final pad = width >= 640 ? 18.0 : 12.0;
    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimerCard(pal, now, active, isCompact: width < 640),
          const SizedBox(height: 14),
          _buildExerciseDetailCard(pal, active, resourcesById),
          const SizedBox(height: 14),
          _buildExerciseSequencePanel(pal, now),
        ],
      ),
    );
  }

  Widget _buildTimerCard(
    PlannerPalette pal,
    DateTime now,
    LiveExerciseExecution active, {
    required bool isCompact,
  }) {
    final remaining = _state.effectiveActiveExerciseRemainingSec(now);
    final realExSec = _state.effectiveActiveExerciseElapsedSec(now);
    final allocated = _state.activeExerciseAllocatedSec;
    final color = _timerColor(pal, remaining, allocated);
    final isOvertime = remaining <= 0;
    final displayText =
        remaining > 0 ? formatDurationMmSs(remaining) : '00:00';
    final progress = allocated <= 0
        ? 0.0
        : (remaining.clamp(0, allocated) / allocated).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.xl),
        border: Border.all(
          color: _state.isRunning
              ? color.withValues(alpha: 0.45)
              : pal.amber.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PlannerBadge(
                label:
                    'Bloque ${active.blockIndex + 1} · ${active.blockTitle}',
                color: pal.infoBlue,
                backgroundColor: pal.infoBlueBg,
              ),
              PlannerBadge(
                label:
                    'Ejercicio ${_state.activeExerciseIndex + 1} de ${_state.totalExercisesCount}',
                color: pal.accent,
              ),
              PlannerBadge(
                label: _state.isRunning ? 'En curso' : 'Pausado',
                color: _state.isRunning ? pal.accent : pal.amber,
                backgroundColor:
                    _state.isRunning ? null : pal.amberBg,
                icon: _state.isRunning
                    ? Icons.timer_outlined
                    : Icons.pause_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _togglePlayPause,
            child: Text(
              displayText,
              key: const Key('live_timer_display'),
              style: GoogleFonts.montserrat(
                fontSize: isCompact ? 46 : 56,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOvertime
                ? 'Tiempo planificado cumplido (+${formatDurationMmSs(-remaining)} extra) · Real: ${formatDurationMmSs(realExSec)}'
                : 'Tiempo real en ejercicio: ${formatDurationMmSs(realExSec)} · Asignado: ${allocated ~/ 60} min',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOvertime ? Colors.redAccent : pal.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: pal.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (isOvertime) ...[
            const SizedBox(height: 12),
            PlannerNoticeBanner(
              title: 'Bloque / ejercicio listo para cerrar',
              message:
                  'Puedes añadir minutos (+1 m) o marcar el ejercicio como completado y pasar al siguiente.',
              icon: Icons.notifications_active_outlined,
              color: pal.amber,
              backgroundColor: pal.amberBg,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                key: const Key('live_minus_1m_btn'),
                onPressed: () => _adjustMinutes(-1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(66, 48),
                  side: BorderSide(color: pal.border),
                  foregroundColor: pal.textPrimary,
                ),
                child: Text(
                  '-1 m',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('live_play_pause_btn'),
                onPressed: _togglePlayPause,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(146, 48),
                  backgroundColor: _state.isRunning ? pal.amber : pal.accent,
                  foregroundColor:
                      _state.isRunning ? Colors.white : pal.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                icon: Icon(
                  _state.isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                ),
                label: Text(
                  _state.isRunning ? 'Pausar' : 'Reanudar',
                  style: GoogleFonts.montserrat(
                      fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton(
                key: const Key('live_plus_1m_btn'),
                onPressed: () => _adjustMinutes(1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(66, 48),
                  side: BorderSide(color: pal.border),
                  foregroundColor: pal.textPrimary,
                ),
                child: Text(
                  '+1 m',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('live_reset_timer_btn'),
                onPressed: _resetActiveTimer,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(color: pal.border),
                  foregroundColor: pal.textSecondary,
                ),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: Text(
                  'Reiniciar',
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

  Widget _buildExerciseDetailCard(
    PlannerPalette pal,
    LiveExerciseExecution active,
    Map<String, PlannerResourceItem> resourcesById,
  ) {
    final ej = active.exercise;
    final variants = <({String label, String text})>[
      if (ej.differentiationBeginner != null &&
          ej.differentiationBeginner!.isNotEmpty)
        (label: 'Principiantes', text: ej.differentiationBeginner!),
      if (ej.differentiationIntermediate != null &&
          ej.differentiationIntermediate!.isNotEmpty)
        (label: 'Intermedios', text: ej.differentiationIntermediate!),
      if (ej.differentiationAdvanced != null &&
          ej.differentiationAdvanced!.isNotEmpty)
        (label: 'Avanzados', text: ej.differentiationAdvanced!),
    ];
    final selectedIdx =
        variants.isEmpty ? 0 : _selectedVariantTab.clamp(0, variants.length - 1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.xl),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PlannerOriginBadge(origin: ej.contentOrigin),
              if (ej.organizacion != null && ej.organizacion!.isNotEmpty)
                PlannerBadge(
                  label: ej.organizacion!,
                  color: pal.infoBlue,
                  backgroundColor: pal.infoBlueBg,
                  icon: Icons.groups_outlined,
                ),
              if (active.status != LiveExerciseStatus.pending)
                PlannerBadge(
                  label: active.status.label,
                  color: active.status == LiveExerciseStatus.completed
                      ? pal.accent
                      : pal.amber,
                  backgroundColor:
                      active.status == LiveExerciseStatus.completed
                          ? null
                          : pal.amberBg,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ej.nombre,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          if (ej.detalle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              ej.detalle,
              style: GoogleFonts.montserrat(
                fontSize: 13.5,
                color: pal.textPrimary,
                height: 1.45,
              ),
            ),
          ],
          if (variants.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Variantes por nivel',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (variants.length > 1)
                  PlannerChoicePill(
                    key: const Key('live_variant_all_btn'),
                    label: 'Ver todos los niveles',
                    icon: Icons.view_agenda_outlined,
                    selected: _showAllVariants,
                    onTap: () =>
                        setState(() => _showAllVariants = !_showAllVariants),
                  ),
                for (int i = 0; i < variants.length; i++)
                  PlannerChoicePill(
                    key: Key('live_variant_tab_${variants[i].label}'),
                    label: variants[i].label,
                    selected: !_showAllVariants && selectedIdx == i,
                    onTap: () => setState(() {
                      _showAllVariants = false;
                      _selectedVariantTab = i;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_showAllVariants)
              Column(
                key: const Key('live_all_variants_panel'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final v in variants)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.surfaceTint,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(
                            color: pal.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.label,
                            style: GoogleFonts.montserrat(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: pal.accent,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            v.text,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              color: pal.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.surfaceTint,
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  border:
                      Border.all(color: pal.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  variants[selectedIdx].text,
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    color: pal.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
          ],
          if (ej.materiales.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Materiales',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mat in ej.materiales)
                  PlannerBadge(
                    label: mat,
                    color: pal.textPrimary,
                    icon: Icons.inventory_2_outlined,
                  ),
              ],
            ),
          ],
          if (ej.safetyNote != null && ej.safetyNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            PlannerNoticeBanner(
              title: 'Seguridad durante el ejercicio',
              message: ej.safetyNote!,
              icon: Icons.health_and_safety_outlined,
              color: pal.amber,
              backgroundColor: pal.amberBg,
            ),
          ],
          if (ej.observacionesProfesor != null &&
              ej.observacionesProfesor!.isNotEmpty) ...[
            const SizedBox(height: 10),
            PlannerNoticeBanner(
              title: 'Observaciones del profesor',
              message: ej.observacionesProfesor!,
              icon: Icons.notes_rounded,
              color: pal.infoBlue,
              backgroundColor: pal.infoBlueBg,
            ),
          ],
          if (ej.curriculumMovementIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Movimientos FIU vinculados (toca para consultar)',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final movId in ej.curriculumMovementIds)
                  ActionChip(
                    key: Key('live_mov_chip_$movId'),
                    backgroundColor: pal.surfaceTint,
                    side: BorderSide(color: pal.accent.withValues(alpha: 0.45)),
                    avatar: Icon(Icons.menu_book_outlined,
                        size: 16, color: pal.accent),
                    label: Text(
                      widget.movementNamesById[movId] ?? movId,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    onPressed: () => _openMovementDetail(movId),
                  ),
              ],
            ),
          ],
          if (active.resolvedResourceIds.isNotEmpty ||
              (ej.legacyRecursoRelacionado != null &&
                  ej.legacyRecursoRelacionado!.trim().isNotEmpty &&
                  ej.legacyRecursoRelacionado!.toLowerCase() != 'null')) ...[
            const SizedBox(height: 14),
            Text(
              'Recursos de Pizarra vinculados',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final resId in active.resolvedResourceIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: Key('live_res_btn_$resId'),
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  onTap: () => _openLinkedResource(
                    resourcesById[resId],
                    usageNote: ej.resourceUsageNotes[resId],
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pal.infoBlueBg,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(
                          color: pal.infoBlue.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.video_library_outlined,
                            size: 20, color: pal.infoBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resourcesById[resId]?.title ?? resId,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                              if (ej.resourceUsageNotes[resId] != null)
                                Text(
                                  ej.resourceUsageNotes[resId]!,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11.5,
                                    color: pal.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded,
                            size: 16, color: pal.infoBlue),
                      ],
                    ),
                  ),
                ),
              ),
            if (active.resolvedResourceIds.isEmpty &&
                ej.legacyRecursoRelacionado != null)
              ActionChip(
                onPressed: () => _openLinkedResource(
                  null,
                  fallbackLabel: ej.legacyRecursoRelacionado,
                ),
                avatar: Icon(Icons.push_pin_outlined,
                    size: 16, color: pal.infoBlue),
                label: Text(ej.legacyRecursoRelacionado!),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseSequencePanel(PlannerPalette pal, DateTime now) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Secuencia de la sesión (${_state.resolvedCount}/${_state.totalExercisesCount})',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < _state.exercises.length; i++)
            _buildSequenceRow(pal, i, _state.exercises[i], now),
        ],
      ),
    );
  }

  Widget _buildSequenceRow(
    PlannerPalette pal,
    int index,
    LiveExerciseExecution ex,
    DateTime now,
  ) {
    final isCurrent = index == _state.activeExerciseIndex;
    final realSec = isCurrent
        ? _state.effectiveActiveExerciseElapsedSec(now)
        : ex.actualDurationSec;

    final IconData statusIcon;
    final Color statusColor;
    switch (ex.status) {
      case LiveExerciseStatus.completed:
        statusIcon = Icons.check_circle_rounded;
        statusColor = pal.accent;
        break;
      case LiveExerciseStatus.skipped:
        statusIcon = Icons.skip_next_rounded;
        statusColor = pal.amber;
        break;
      case LiveExerciseStatus.pending:
        statusIcon =
            isCurrent ? Icons.play_circle_filled_rounded : Icons.radio_button_unchecked;
        statusColor = isCurrent ? pal.accent : pal.textSecondary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('live_seq_item_$index'),
        onTap: () => _goToExercise(index),
        borderRadius: BorderRadius.circular(GingaRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCurrent ? pal.surfaceTint : pal.background,
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(
              color: isCurrent ? pal.accent : pal.border,
              width: isCurrent ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(statusIcon, size: 19, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.blockTitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textSecondary,
                      ),
                    ),
                    Text(
                      ex.exercise.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${ex.plannedDurationSec ~/ 60} m',
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  if (realSec > 0)
                    Text(
                      'Real ${formatDurationMmSs(realSec)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.5,
                        color: pal.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(PlannerPalette pal, double width) {
    final canPrev = _state.activeExerciseIndex > 0;
    final isLast = _state.activeExerciseIndex >= _state.totalExercisesCount - 1;
    final isCompact = width < 560;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 10 : 18,
        10,
        isCompact ? 10 : 18,
        12,
      ),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.border)),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('live_prev_btn'),
                  onPressed: canPrev
                      ? () => _goToExercise(_state.activeExerciseIndex - 1)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: pal.border),
                    foregroundColor: pal.textPrimary,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    'Anterior',
                    style: GoogleFonts.montserrat(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('live_skip_btn'),
                  onPressed: _markSkippedAndAdvance,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: pal.amber),
                    foregroundColor: pal.amber,
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(
                    'Omitir',
                    style: GoogleFonts.montserrat(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              key: const Key('live_complete_next_btn'),
              onPressed: _markCompletedAndAdvance,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(isCompact ? 200 : 240, 50),
                backgroundColor: pal.accent,
                foregroundColor: pal.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              icon: Icon(
                isLast ? Icons.check_circle_outline : Icons.check_rounded,
                size: 20,
              ),
              label: Text(
                isLast ? 'Completar y finalizar' : 'Completar y siguiente',
                style: GoogleFonts.montserrat(
                    fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

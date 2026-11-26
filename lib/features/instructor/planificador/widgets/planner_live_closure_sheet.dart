import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../models/class_plan_models.dart';
import '../models/live_session_models.dart';
import '../theme/planner_palette.dart';
import 'planner_shared_widgets.dart';

/// Formulario de cierre pedagógico al finalizar (completa o anticipadamente) una clase en vivo.
class PlannerLiveClosureSheet extends StatefulWidget {
  final LiveSessionState sessionSnapshot;
  final List<PlannerResourceItem> resources;
  final Map<String, String> movementNamesById;
  final DateTime finishedAt;
  final bool endedEarly;
  final Future<void> Function(LiveSessionClosureInput input) onConfirmSave;

  const PlannerLiveClosureSheet({
    super.key,
    required this.sessionSnapshot,
    required this.resources,
    required this.movementNamesById,
    required this.finishedAt,
    required this.endedEarly,
    required this.onConfirmSave,
  });

  @override
  State<PlannerLiveClosureSheet> createState() =>
      _PlannerLiveClosureSheetState();
}

class _PlannerLiveClosureSheetState extends State<PlannerLiveClosureSheet> {
  static const List<String> _responseOptions = [
    'Excelente',
    'Buena',
    'Regular',
    'Desafiante',
  ];

  late String _groupResponse;
  late int _attendeesCount;
  late TextEditingController _observationsCtrl;
  late TextEditingController _difficultiesCtrl;
  late TextEditingController _reinforceCtrl;
  late TextEditingController _continuityCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _groupResponse = 'Buena';
    _attendeesCount = widget.sessionSnapshot.participantsCount;
    _observationsCtrl = TextEditingController();
    _difficultiesCtrl = TextEditingController();
    _reinforceCtrl = TextEditingController();
    _continuityCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _observationsCtrl.dispose();
    _difficultiesCtrl.dispose();
    _reinforceCtrl.dispose();
    _continuityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onConfirmSave(
        LiveSessionClosureInput(
          groupResponse: _groupResponse,
          teacherObservations: _observationsCtrl.text.trim(),
          difficulties: _difficultiesCtrl.text.trim(),
          reinforceContent: _reinforceCtrl.text.trim(),
          continuityProposal: _continuityCtrl.text.trim(),
          endedEarly: widget.endedEarly,
          attendeesCount: _attendeesCount,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final snap = widget.sessionSnapshot;
    final totalElapsedSec = snap.effectiveTotalElapsedSec(widget.finishedAt);
    final completed = snap.exercises
        .where((e) => e.status == LiveExerciseStatus.completed)
        .toList();
    final notCompleted = snap.exercises
        .where((e) => e.status != LiveExerciseStatus.completed)
        .toList();
    final taughtIds = snap.taughtResourceIds;
    final resourcesById = {
      for (final r in widget.resources) r.resourceId: r,
    };

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
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            PlannerBadge(
                              label: widget.endedEarly
                                  ? 'Cierre anticipado'
                                  : 'Clase completada',
                              color: widget.endedEarly ? pal.amber : pal.accent,
                              backgroundColor: widget.endedEarly
                                  ? pal.amberBg
                                  : null,
                            ),
                            PlannerBadge(
                              label:
                                  'Tiempo real: ${formatDurationMmSs(totalElapsedSec)}',
                              color: pal.infoBlue,
                              backgroundColor: pal.infoBlueBg,
                            ),
                            PlannerBadge(
                              label: snap.groupName,
                              color: pal.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cierre pedagógico · ${snap.planTitle}',
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
                    tooltip: 'Volver a la clase',
                    icon: Icon(Icons.close, color: pal.textPrimary),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                primary: false,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildExecutionSummaryCard(
                    pal,
                    completed: completed,
                    notCompleted: notCompleted,
                    taughtIds: taughtIds,
                    resourcesById: resourcesById,
                  ),
                  const SizedBox(height: 16),
                  const PlannerFieldLabel('Respuesta general del grupo'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opt in _responseOptions)
                        PlannerChoicePill(
                          key: Key('closure_response_$opt'),
                          label: opt,
                          selected: _groupResponse == opt,
                          onTap: () => setState(() => _groupResponse = opt),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PlannerStepperField(
                    label: 'Alumnos presentes',
                    value: _attendeesCount,
                    suffix: 'alumnos',
                    min: 0,
                    max: 99,
                    onChanged: (v) => setState(() => _attendeesCount = v),
                  ),
                  const SizedBox(height: 14),
                  const PlannerFieldLabel(
                    'Observaciones del profesor',
                    optional: true,
                  ),
                  TextField(
                    key: const Key('closure_observations_field'),
                    controller: _observationsCtrl,
                    maxLines: 3,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: pal.textPrimary,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText:
                          'Fluidez general, energía, postura o coordinación observada...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const PlannerFieldLabel(
                    'Dificultades encontradas',
                    optional: true,
                  ),
                  TextField(
                    key: const Key('closure_difficulties_field'),
                    controller: _difficultiesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: pal.textPrimary,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText:
                          'Ej. pérdida de equilibrio al salir en rolê, tiempos de espera...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const PlannerFieldLabel(
                    'Contenido que debe reforzarse',
                    optional: true,
                  ),
                  TextField(
                    key: const Key('closure_reinforce_field'),
                    controller: _reinforceCtrl,
                    maxLines: 2,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: pal.textPrimary,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText:
                          'Ej. cobertura facial en cocorinha y ritmo en palmas...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const PlannerFieldLabel(
                    'Propuesta de continuidad para la próxima clase',
                    optional: true,
                  ),
                  TextField(
                    key: const Key('closure_continuity_field'),
                    controller: _continuityCtrl,
                    maxLines: 2,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: pal.textPrimary,
                    ),
                    decoration: plannerInputDecoration(
                      pal,
                      hintText:
                          'Qué retomar o progresar en la siguiente sesión con este grupo...',
                    ),
                  ),
                  if (notCompleted.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('closure_suggest_pending_btn'),
                        onPressed: () {
                          final pendingNames = notCompleted
                              .map((e) => e.exercise.nombre)
                              .take(2)
                              .join(' · ');
                          setState(() {
                            _continuityCtrl.text = 'Retomar: $pendingNames';
                          });
                        },
                        icon: Icon(Icons.auto_fix_high_outlined,
                            size: 16, color: pal.accent),
                        label: Text(
                          'Usar sugerencia de ejercicios pendientes',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: pal.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PlannerNoticeBanner(
                    title: 'Plan original protegido',
                    message:
                        'Se guardará una instantánea fiel de esta ejecución en Historial sin modificar tu plan guardado.',
                    icon: Icons.lock_outline,
                    color: pal.infoBlue,
                    backgroundColor: pal.infoBlueBg,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.surface,
                border: Border(top: BorderSide(color: pal.border)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      side: BorderSide(color: pal.border),
                      foregroundColor: pal.textPrimary,
                    ),
                    icon: const Icon(Icons.arrow_back, size: 17),
                    label: Text(
                      'Volver a la clase',
                      style: GoogleFonts.montserrat(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('closure_confirm_save_btn'),
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: pal.accent,
                      foregroundColor: pal.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    icon: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: pal.onAccent,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      _saving ? 'Guardando...' : 'Guardar sesión en Historial',
                      style: GoogleFonts.montserrat(
                          fontSize: 13, fontWeight: FontWeight.w800),
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

  Widget _buildExecutionSummaryCard(
    PlannerPalette pal, {
    required List<LiveExerciseExecution> completed,
    required List<LiveExerciseExecution> notCompleted,
    required Set<String> taughtIds,
    required Map<String, PlannerResourceItem> resourcesById,
  }) {
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
            'Ejercicios realizados y pendientes',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              PlannerBadge(
                label: '${completed.length} realizados',
                color: pal.accent,
                icon: Icons.check_circle_outline,
              ),
              PlannerBadge(
                label: '${notCompleted.length} omitidos / pendientes',
                color: notCompleted.isEmpty ? pal.textSecondary : pal.amber,
                backgroundColor: notCompleted.isEmpty ? null : pal.amberBg,
                icon: Icons.pending_actions_outlined,
              ),
            ],
          ),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final ex in completed)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: pal.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${ex.exercise.nombre} (${formatDurationMmSs(ex.actualDurationSec)})',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: pal.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (notCompleted.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final ex in notCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${ex.exercise.nombre} (${ex.status.label})',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: pal.textSecondary,
                  ),
                ),
              ),
          ],
          const Divider(height: 18),
          Text(
            taughtIds.isEmpty
                ? 'Recursos de Pizarra contabilizados: ninguno (solo se contabilizan recursos de ejercicios completados).'
                : 'Recursos que se marcarán como impartidos (${taughtIds.length}):',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: taughtIds.isEmpty ? pal.textSecondary : pal.accent,
            ),
          ),
          if (taughtIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in taughtIds)
                  PlannerBadge(
                    label: resourcesById[id]?.title ?? id,
                    color: pal.accent,
                    icon: Icons.video_library_outlined,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

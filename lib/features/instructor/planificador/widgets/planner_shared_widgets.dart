import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../models/class_plan_models.dart';
import '../theme/planner_palette.dart';

/// Decoración consistente y de alto contraste para campos editables del planificador.
InputDecoration plannerInputDecoration(
  PlannerPalette pal, {
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool isDense = false,
}) {
  return InputDecoration(
    filled: true,
    fillColor: pal.inputFill,
    isDense: isDense,
    hintText: hintText,
    hintStyle: GoogleFonts.montserrat(
      fontSize: 12.5,
      color: pal.textSecondary.withValues(alpha: 0.78),
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 14,
      vertical: isDense ? 10 : 12,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(GingaRadius.md),
      borderSide: BorderSide(color: pal.inputBorder, width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(GingaRadius.md),
      borderSide: BorderSide(color: pal.inputBorder, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(GingaRadius.md),
      borderSide: BorderSide(color: pal.accent, width: 1.8),
    ),
  );
}

/// Etiqueta superior nítida para campos de formulario, evitando etiquetas flotantes recortadas.
class PlannerFieldLabel extends StatelessWidget {
  final String text;
  final bool optional;

  const PlannerFieldLabel(
    this.text, {
    super.key,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: pal.textPrimary,
            ),
          ),
          if (optional)
            Text(
              '(opcional)',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: pal.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Etiqueta compacta adaptable al tema activo para metadatos del planificador.
class PlannerBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;
  final IconData? icon;

  const PlannerBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GingaRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill seleccionable consistente con GingaTheme Claro/Oscuro y sin desbordamiento en móvil.
class PlannerChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const PlannerChoicePill({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

/// Distintivo visual para separar los 3 orígenes de contenido dentro de un plan.
class PlannerOriginBadge extends StatelessWidget {
  final ContentOrigin origin;

  const PlannerOriginBadge({super.key, required this.origin});

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    switch (origin) {
      case ContentOrigin.officialFiuCurriculum:
        return PlannerBadge(
          label: 'Currículo FIU',
          color: pal.accent,
          icon: Icons.verified_outlined,
        );
      case ContentOrigin.teacherResource:
        return PlannerBadge(
          label: 'Recurso Profesor',
          color: pal.infoBlue,
          backgroundColor: pal.infoBlueBg,
          icon: Icons.video_library_outlined,
        );
      case ContentOrigin.aiComplementaryProposal:
        return PlannerBadge(
          label: 'Propuesta IA',
          color: pal.purple,
          backgroundColor: pal.purpleBg,
          icon: Icons.auto_awesome_outlined,
        );
    }
  }
}

/// Aviso pedagógico consistente con alto contraste en claro y oscuro.
class PlannerNoticeBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;

  const PlannerNoticeBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final fg = color ?? pal.amber;
    final bg = backgroundColor ?? pal.amberBg;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    color: pal.textSecondary,
                    height: 1.35,
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

/// Control +/- accesible para conteo de alumnos o rangos de edad.
class PlannerStepperField extends StatelessWidget {
  final String label;
  final int value;
  final String? suffix;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const PlannerStepperField({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.min = 0,
    this.max = 99,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepIconBtn(
                icon: Icons.remove,
                enabled: value > min,
                onTap: () => onChanged((value - 1).clamp(min, max)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  suffix == null ? '$value' : '$value $suffix',
                  style: GoogleFonts.montserrat(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              _StepIconBtn(
                icon: Icons.add,
                enabled: value < max,
                onTap: () => onChanged((value + 1).clamp(min, max)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepIconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepIconBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(GingaRadius.sm),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? pal.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(GingaRadius.sm),
          border: Border.all(
            color: enabled ? pal.border : pal.border.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? pal.textPrimary : pal.textSecondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// Visor de detalle para planes guardados o borradores locales.
class ClassPlanSummarySheet extends StatelessWidget {
  final ClassPlanModel plan;
  final Map<String, String>? movementNamesById;
  final Map<String, PlannerResourceItem>? resourcesById;
  final VoidCallback? onEditPlan;
  final VoidCallback? onDuplicatePlan;
  final VoidCallback? onReuseInQuick;
  final VoidCallback? onReuseInAdvanced;

  const ClassPlanSummarySheet({
    super.key,
    required this.plan,
    this.movementNamesById,
    this.resourcesById,
    this.onEditPlan,
    this.onDuplicatePlan,
    this.onReuseInQuick,
    this.onReuseInAdvanced,
  });

  String _movementLabel(String id) {
    final found = movementNamesById?[id];
    if (found != null && found.isNotEmpty) return found;
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final planned = plan.plannedDurationMin;
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
                              label: '${plan.duracionTotal} min objetivo',
                              color: pal.accent,
                            ),
                            if (planned != plan.duracionTotal)
                              PlannerBadge(
                                label: '$planned min planificados',
                                color: pal.amber,
                                backgroundColor: pal.amberBg,
                              ),
                            PlannerBadge(
                              label: plan.planStatus.label,
                              color: pal.infoBlue,
                              backgroundColor: pal.infoBlueBg,
                            ),
                            PlannerBadge(
                              label: plan.curriculumScope.teacherLabel,
                              color: pal.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.titulo,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (plan.planStatus == ClassPlanStatus.draft &&
                      !plan.detectedOrigins
                          .contains(ContentOrigin.aiComplementaryProposal)) ...[
                    PlannerNoticeBanner(
                      title: 'Borrador local sin generación IA',
                      message:
                          'Esta estructura base se creó localmente con tus parámetros sin invocar modelos de IA.',
                      icon: Icons.edit_note_rounded,
                      color: pal.amber,
                      backgroundColor: pal.amberBg,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (plan.objetivos.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final obj in plan.objetivos)
                          PlannerBadge(
                            label: obj,
                            color: pal.accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ] else if (plan.objetivo.isNotEmpty) ...[
                    Text(
                      plan.objetivo,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: pal.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final block in plan.bloques) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: pal.surface,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: pal.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  block.fase,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: pal.textPrimary,
                                  ),
                                ),
                              ),
                              PlannerBadge(
                                label: '${block.duracionMin} min',
                                color: pal.accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final ej in block.ejercicios) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: pal.background,
                                borderRadius:
                                    BorderRadius.circular(GingaRadius.md),
                                border: Border.all(color: pal.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      PlannerOriginBadge(
                                          origin: ej.contentOrigin),
                                      if (ej.duracionMin != null)
                                        PlannerBadge(
                                          label: '${ej.duracionMin} min',
                                          color: pal.accent,
                                        ),
                                      if (ej.organizacion != null &&
                                          ej.organizacion!.isNotEmpty)
                                        PlannerBadge(
                                          label: ej.organizacion!,
                                          color: pal.infoBlue,
                                          backgroundColor: pal.infoBlueBg,
                                        ),
                                      for (final movId
                                          in ej.curriculumMovementIds)
                                        PlannerBadge(
                                          label: _movementLabel(movId),
                                          color: pal.accent,
                                        ),
                                      for (final resId in ej.linkedResourceIds)
                                        PlannerBadge(
                                          label: resourcesById?[resId]?.title ??
                                              'Recurso vinculado',
                                          color: pal.infoBlue,
                                          backgroundColor: pal.infoBlueBg,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ej.nombre,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                  if (ej.detalle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      ej.detalle,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: pal.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  if (ej.differentiationBeginner != null &&
                                      ej.differentiationBeginner!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Principiantes: ${ej.differentiationBeginner}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.5,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (ej.differentiationIntermediate != null &&
                                      ej.differentiationIntermediate!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Intermedios: ${ej.differentiationIntermediate}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.5,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (ej.differentiationAdvanced != null &&
                                      ej.differentiationAdvanced!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Avanzados: ${ej.differentiationAdvanced}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.5,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (ej.resourceUsageNotes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    for (final entry
                                        in ej.resourceUsageNotes.entries)
                                      Text(
                                        'Uso de ${resourcesById?[entry.key]?.title ?? entry.key}: ${entry.value}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11.5,
                                          color: pal.infoBlue,
                                        ),
                                      ),
                                  ],
                                  if (ej.materiales.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Materiales: ${ej.materiales.join(", ")}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.5,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (ej.safetyNote != null &&
                                      ej.safetyNote!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Seguridad: ${ej.safetyNote}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.5,
                                        color: pal.amber,
                                      ),
                                    ),
                                  ],
                                  if (ej.observacionesProfesor != null &&
                                      ej.observacionesProfesor!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Notas del profesor: ${ej.observacionesProfesor}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.5,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (ej.videoReferenceNote != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      ej.videoReferenceNote!,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: pal.amber,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onEditPlan != null ||
                onDuplicatePlan != null ||
                onReuseInQuick != null ||
                onReuseInAdvanced != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.surface,
                  border: Border(top: BorderSide(color: pal.border)),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (onDuplicatePlan != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDuplicatePlan!();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: BorderSide(color: pal.border),
                          foregroundColor: pal.textPrimary,
                        ),
                        icon: const Icon(Icons.copy_all_outlined, size: 17),
                        label: Text(
                          'Duplicar clase',
                          style: GoogleFonts.montserrat(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (onReuseInQuick != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onReuseInQuick!();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: BorderSide(color: pal.accent),
                          foregroundColor: pal.accent,
                        ),
                        icon: const Icon(Icons.flash_on_outlined, size: 17),
                        label: Text(
                          'Reutilizar en rápida',
                          style: GoogleFonts.montserrat(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (onEditPlan != null || onReuseInAdvanced != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (onEditPlan != null) {
                            onEditPlan!();
                          } else {
                            onReuseInAdvanced!();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: pal.accent,
                          foregroundColor: pal.onAccent,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: Text(
                          'Editar plan',
                          style: GoogleFonts.montserrat(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
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
}

/// Detalle de una sesión del Historial con movimientos practicados y salto a continuidad.
class TaughtSessionDetailSheet extends StatelessWidget {
  final TaughtSessionRecord session;
  final VoidCallback onPrepareNextClass;

  const TaughtSessionDetailSheet({
    super.key,
    required this.session,
    required this.onPrepareNextClass,
  });

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
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
                              label:
                                  '${session.date.day}/${session.date.month}/${session.date.year}',
                              color: pal.accent,
                              icon: Icons.event_available_outlined,
                            ),
                            PlannerBadge(
                              label: session.groupName,
                              color: pal.infoBlue,
                              backgroundColor: pal.infoBlueBg,
                            ),
                            if (session.isSimulatedFixture)
                              PlannerBadge(
                                label: 'Ejemplo de preview',
                                color: pal.amber,
                                backgroundColor: pal.amberBg,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          session.planTitle,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (session.isSimulatedFixture) ...[
                    PlannerNoticeBanner(
                      title: 'Sesión de ejemplo del entorno local',
                      message:
                          'Este registro pertenece a fixtures locales de prueba. El registro real de sesiones impartidas se implementará en la siguiente fase.',
                      color: pal.amber,
                      backgroundColor: pal.amberBg,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PlannerBadge(
                        label: '${session.durationMin} min impartidos',
                        color: pal.textSecondary,
                      ),
                      PlannerBadge(
                        label: '${session.attendeesCount} alumnos presentes',
                        color: pal.infoBlue,
                        backgroundColor: pal.infoBlueBg,
                      ),
                      PlannerBadge(
                        label:
                            '${session.completedExercisesCount}/${session.totalExercisesCount} ejercicios completados',
                        color: pal.accent,
                      ),
                    ],
                  ),
                  if (session.practicedMovements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Movimientos practicados',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in session.practicedMovements)
                          PlannerBadge(
                            label: m,
                            color: pal.accent,
                            icon: Icons.verified_outlined,
                          ),
                      ],
                    ),
                  ],
                  if (session.summaryNote.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notas de la sesión',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.surface,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: pal.border),
                      ),
                      child: Text(
                        session.summaryNote,
                        style: GoogleFonts.montserrat(
                          fontSize: 12.5,
                          color: pal.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  if (session.pendingNextSession.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    PlannerNoticeBanner(
                      title: 'Continuidad sugerida para la próxima clase',
                      message: session.pendingNextSession,
                      icon: Icons.forward_outlined,
                      color: pal.accent,
                      backgroundColor: pal.surfaceTint,
                    ),
                  ],
                ],
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
                onPressed: () {
                  Navigator.of(context).pop();
                  onPrepareNextClass();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: pal.accent,
                  foregroundColor: pal.onAccent,
                ),
                icon: const Icon(Icons.play_lesson_outlined, size: 18),
                label: Text(
                  'Preparar siguiente clase',
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

/// Visor y editor en memoria de recursos para el preview aislado (sin Firestore).
class LocalResourceEditorSheet extends StatefulWidget {
  final PlannerResourceItem? initialResource;
  final ValueChanged<PlannerResourceItem> onSave;

  const LocalResourceEditorSheet({
    super.key,
    this.initialResource,
    required this.onSave,
  });

  @override
  State<LocalResourceEditorSheet> createState() =>
      _LocalResourceEditorSheetState();
}

class _LocalResourceEditorSheetState extends State<LocalResourceEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _urlCtrl;
  late ResourceMediaKind _mediaKind;
  late String _category;
  late String _audience;

  static const _categories = [
    'Calentamiento',
    'Técnica',
    'Acrobacias',
    'Juegos',
    'Roda',
  ];
  static const _audiences = ['Todos', 'Adultos', 'Niños'];

  @override
  void initState() {
    super.initState();
    final r = widget.initialResource;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _urlCtrl = TextEditingController(text: r?.url ?? '');
    _mediaKind = r?.mediaKind ?? ResourceMediaKind.nota;
    _category = r != null && _categories.contains(r.category)
        ? r.category
        : 'Técnica';
    _audience = r != null && _audiences.contains(r.audienceLabel)
        ? r.audienceLabel
        : 'Todos';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final isEditing = widget.initialResource != null;
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
                    child: Text(
                      isEditing ? 'Editar recurso' : 'Añadir recurso',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: pal.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    key: const Key('local_res_title_field'),
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título del recurso',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tipo de recurso',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kind in ResourceMediaKind.values)
                        PlannerChoicePill(
                          label: kind.label,
                          selected: _mediaKind == kind,
                          onTap: () => setState(() => _mediaKind = kind),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Categoría',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final cat in _categories)
                        PlannerChoicePill(
                          label: cat,
                          selected: _category == cat,
                          onTap: () => setState(() => _category = cat),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Público',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final aud in _audiences)
                        PlannerChoicePill(
                          label: aud,
                          selected: _audience == aud,
                          onTap: () => setState(() => _audience = aud),
                        ),
                    ],
                  ),
                  if (_mediaKind != ResourceMediaKind.nota) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enlace o URL (opcional)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas pedagógicas / descripción',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.surface,
                border: Border(top: BorderSide(color: pal.border)),
              ),
              child: ElevatedButton(
                key: const Key('local_res_save_button'),
                onPressed: () {
                  final title = _titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final item = PlannerResourceItem(
                    resourceId: widget.initialResource?.resourceId ??
                        'local_res_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    type: _mediaKind.storageType,
                    category: _category,
                    audienceLabel: _audience,
                    notes: _notesCtrl.text.trim(),
                    url: _urlCtrl.text.trim(),
                    thumbnailUrl: widget.initialResource?.thumbnailUrl,
                    hasBeenTaught: widget.initialResource?.hasBeenTaught ?? false,
                    timesUsed: widget.initialResource?.timesUsed ?? 0,
                  );
                  widget.onSave(item);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: pal.accent,
                  foregroundColor: pal.onAccent,
                ),
                child: Text(
                  isEditing ? 'Guardar cambios' : 'Guardar recurso',
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

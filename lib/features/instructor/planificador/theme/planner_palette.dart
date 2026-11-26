import 'package:flutter/material.dart';
import '../../../../core/theme/ginga_theme.dart';

/// Tokens cromáticos derivados de [Theme.of(context).brightness] para garantizar
/// compatibilidad total entre el modo claro y el modo oscuro originales de GINGA.
class PlannerPalette {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceTint;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color amber;
  final Color amberBg;
  final Color infoBlue;
  final Color infoBlueBg;
  final Color purple;
  final Color purpleBg;

  const PlannerPalette._({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceTint,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.amber,
    required this.amberBg,
    required this.infoBlue,
    required this.infoBlueBg,
    required this.purple,
    required this.purpleBg,
  });

  factory PlannerPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return PlannerPalette._(
        isDark: true,
        background: GingaColors.backgroundDark,
        surface: GingaColors.surfaceDark,
        surfaceAlt: const Color(0xFF222822),
        surfaceTint: const Color(0xFF1F3321),
        border: const Color(0xFF3A443A),
        textPrimary: GingaColors.textWhite,
        textSecondary: const Color(0xFFB7C0B7),
        accent: const Color(0xFF66BB6A),
        onAccent: const Color(0xFF0A140A),
        amber: GingaColors.accentAmber,
        amberBg: GingaColors.accentAmber.withValues(alpha: 0.14),
        infoBlue: const Color(0xFF64B5F6),
        infoBlueBg: const Color(0xFF64B5F6).withValues(alpha: 0.15),
        purple: const Color(0xFFCE93D8),
        purpleBg: const Color(0xFFCE93D8).withValues(alpha: 0.16),
      );
    }

    return const PlannerPalette._(
      isDark: false,
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFF6F9F6),
      surfaceAlt: Color(0xFFE8F5E9),
      surfaceTint: Color(0xFFEBF7EB),
      border: Color(0xFFDDE5DD),
      textPrimary: Color(0xFF111812),
      textSecondary: Color(0xFF525E53),
      accent: GingaColors.brandGreen,
      onAccent: Colors.white,
      amber: Color(0xFFB27600),
      amberBg: Color(0xFFFFF8E1),
      infoBlue: Color(0xFF1565C0),
      infoBlueBg: Color(0xFFE3F2FD),
      purple: Color(0xFF6A1B9A),
      purpleBg: Color(0xFFF3E5F5),
    );
  }
}

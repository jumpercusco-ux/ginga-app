// ============================================================
//  GINGA APP — Theme Configuration v1.0
//  Jumper Studio | Flutter Design System
// ============================================================

import 'package:flutter/material.dart';
import 'dart:ui';
import 'theme_manager.dart';

// ─────────────────────────────────────────
//  COLOR TOKENS
// ─────────────────────────────────────────

class GingaColors {
  GingaColors._();

  // Primario (Marca)
  static const Color brandGreen       = Color(0xFF1E9B12); // Verde Principal (manual de marca)
  static const Color accentAmber      = Color(0xFFFBC02D); // Amarillo Dorado / Alerta

  // Neutros — Modo Claro
  static Color get backgroundLight {
    final mode = ThemeManager.instance.themeMode;
    if (mode == ThemeMode.dark) return backgroundDark;
    if (mode == ThemeMode.light) return const Color(0xFFFFFFFF);
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark ? backgroundDark : const Color(0xFFFFFFFF);
  }

  static Color get cardLight {
    final mode = ThemeManager.instance.themeMode;
    if (mode == ThemeMode.dark) return surfaceDark;
    if (mode == ThemeMode.light) return const Color(0xFFE8F5E9);
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark ? surfaceDark : const Color(0xFFE8F5E9);
  }

  static Color get textPrimary {
    final mode = ThemeManager.instance.themeMode;
    if (mode == ThemeMode.dark) return textWhite;
    if (mode == ThemeMode.light) return const Color(0xFF000000);
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark ? textWhite : const Color(0xFF000000);
  }

  static Color get textSecondary {
    final mode = ThemeManager.instance.themeMode;
    if (mode == ThemeMode.dark) return textMuted;
    if (mode == ThemeMode.light) return const Color(0xFF5F6368);
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark ? textMuted : const Color(0xFF5F6368);
  }

  static Color get borderLight {
    final mode = ThemeManager.instance.themeMode;
    if (mode == ThemeMode.dark) return surfaceDark;
    if (mode == ThemeMode.light) return const Color(0xFFE0E0E0);
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark ? surfaceDark : const Color(0xFFE0E0E0);
  }

  // Neutros — Modo Oscuro
  static const Color backgroundDark   = Color(0xFF1B1F1C); // Fondo Base Dark
  static const Color surfaceDark      = Color(0xFF2A312A); // Tarjetas / superficie dark
  static const Color textWhite        = Color(0xFFFFFFFF); // Títulos sobre fondo oscuro
  static const Color textMuted        = Color(0xFF9E9E9E); // Subtextos sobre fondo oscuro
  static const Color accentGreenDark  = Color(0xFF4CAF50); // Verde brillante / iconos activos
}

// ─────────────────────────────────────────
//  TYPOGRAPHY
// ─────────────────────────────────────────

class GingaTextStyles {
  GingaTextStyles._();

  // Montserrat en toda la app (headers y body), según manual de marca.

  static TextStyle displayLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: GingaColors.textPrimary,
  );

  static TextStyle headlineMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: GingaColors.textPrimary,
  );

  static TextStyle titleMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: GingaColors.textPrimary,
  );

  static TextStyle bodyLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: GingaColors.textSecondary,
  );

  static TextStyle bodySmall = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: GingaColors.textSecondary,
  );

  static const TextStyle labelButton = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: GingaColors.textWhite,
  );

  // Variantes Dark
  static const TextStyle displayLargeDark = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: GingaColors.textWhite,
  );

  static const TextStyle bodyLargeDark = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: GingaColors.textMuted,
  );
}

// ─────────────────────────────────────────
//  SPACING SYSTEM
// ─────────────────────────────────────────

class GingaSpacing {
  GingaSpacing._();

  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;
}

// ─────────────────────────────────────────
//  RADIUS SYSTEM
// ─────────────────────────────────────────

class GingaRadius {
  GingaRadius._();

  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 24.0;
  static const double full = 100.0;
}

// ─────────────────────────────────────────
//  LIGHT THEME
// ─────────────────────────────────────────

ThemeData get gingaLightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'Montserrat',

  colorScheme: ColorScheme.light(
    primary:        GingaColors.brandGreen,
    secondary:      GingaColors.accentAmber,
    surface:        GingaColors.backgroundLight,
    onPrimary:      GingaColors.textWhite,
    onSecondary:    GingaColors.textPrimary,
    onSurface:      GingaColors.textPrimary,
    outline:        GingaColors.borderLight,
  ),

  scaffoldBackgroundColor: GingaColors.backgroundLight,

  appBarTheme: AppBarTheme(
    backgroundColor:  GingaColors.backgroundLight,
    foregroundColor:  GingaColors.textPrimary,
    elevation:        0,
    centerTitle:      false,
    titleTextStyle:   GingaTextStyles.headlineMedium,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor:    GingaColors.brandGreen,
      foregroundColor:    GingaColors.textWhite,
      minimumSize:        const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GingaRadius.full),
      ),
      textStyle:          GingaTextStyles.labelButton,
      elevation:          0,
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor:    GingaColors.brandGreen,
      minimumSize:        const Size(double.infinity, 52),
      side: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GingaRadius.full),
      ),
      textStyle:          GingaTextStyles.labelButton.copyWith(color: GingaColors.brandGreen),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled:           true,
    fillColor:        GingaColors.backgroundLight,
    contentPadding:   const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.md),
      borderSide:     BorderSide(color: GingaColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.md),
      borderSide:     BorderSide(color: GingaColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.md),
      borderSide:     const BorderSide(color: GingaColors.brandGreen, width: 2),
    ),
    hintStyle:        GingaTextStyles.bodyLarge,
    labelStyle:       GingaTextStyles.bodyLarge,
  ),

  cardTheme: CardThemeData(
    color:            GingaColors.cardLight,
    elevation:        0,
    shape: RoundedRectangleBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.lg),
    ),
  ),

  canvasColor: GingaColors.backgroundLight,
  dialogBackgroundColor: GingaColors.backgroundLight,

  dialogTheme: const DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),

  datePickerTheme: DatePickerThemeData(
    backgroundColor: Colors.white,
    headerBackgroundColor: GingaColors.brandGreen,
    headerForegroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.white;
      }
      return GingaColors.textPrimary;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return GingaColors.brandGreen;
      }
      return null;
    }),
    todayForegroundColor: WidgetStateProperty.all(GingaColors.brandGreen),
    todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
    yearForegroundColor: WidgetStateProperty.all(GingaColors.textPrimary),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor:      GingaColors.backgroundLight,
    selectedItemColor:    GingaColors.brandGreen,
    unselectedItemColor:  GingaColors.textSecondary,
    type:                 BottomNavigationBarType.fixed,
    elevation:            8,
    selectedLabelStyle:   TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 11),
  ),
);

// ─────────────────────────────────────────
//  DARK THEME
// ─────────────────────────────────────────

ThemeData get gingaDarkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Montserrat',

  colorScheme: ColorScheme.dark(
    primary:        GingaColors.accentGreenDark,
    secondary:      GingaColors.accentAmber,
    surface:        GingaColors.backgroundDark,
    onPrimary:      GingaColors.textWhite,
    onSecondary:    GingaColors.textPrimary,
    onSurface:      GingaColors.textWhite,
    outline:        GingaColors.surfaceDark,
  ),

  scaffoldBackgroundColor: GingaColors.backgroundDark,

  appBarTheme: const AppBarTheme(
    backgroundColor:  GingaColors.backgroundDark,
    foregroundColor:  GingaColors.textWhite,
    elevation:        0,
    centerTitle:      false,
    titleTextStyle: TextStyle(
      fontFamily:     'Montserrat',
      fontSize:       22,
      fontWeight:     FontWeight.w700,
      color:          GingaColors.textWhite,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor:    GingaColors.accentGreenDark,
      foregroundColor:    GingaColors.textWhite,
      minimumSize:        const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GingaRadius.full),
      ),
      textStyle:          GingaTextStyles.labelButton,
      elevation:          0,
    ),
  ),

  cardTheme: CardThemeData(
    color:            GingaColors.surfaceDark,
    elevation:        0,
    shape: RoundedRectangleBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.lg),
    ),
  ),

  canvasColor: GingaColors.backgroundDark,
  dialogBackgroundColor: GingaColors.backgroundDark,

  dialogTheme: const DialogThemeData(
    backgroundColor: GingaColors.backgroundDark,
    surfaceTintColor: Colors.transparent,
  ),

  datePickerTheme: DatePickerThemeData(
    backgroundColor: GingaColors.backgroundDark,
    headerBackgroundColor: GingaColors.surfaceDark,
    headerForegroundColor: GingaColors.textWhite,
    surfaceTintColor: Colors.transparent,
    dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return GingaColors.textWhite;
      }
      return GingaColors.textWhite;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return GingaColors.accentGreenDark;
      }
      return null;
    }),
    todayForegroundColor: WidgetStateProperty.all(GingaColors.accentGreenDark),
    todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
    yearForegroundColor: WidgetStateProperty.all(GingaColors.textWhite),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled:           true,
    fillColor:        GingaColors.surfaceDark,
    contentPadding:   const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.md),
      borderSide:     const BorderSide(color: Colors.transparent),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.md),
      borderSide:     const BorderSide(color: Colors.transparent),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.md),
      borderSide:     const BorderSide(color: GingaColors.accentGreenDark, width: 2),
    ),
    hintStyle:        const TextStyle(color: GingaColors.textMuted),
    labelStyle:       const TextStyle(color: GingaColors.textMuted),
    floatingLabelStyle: const TextStyle(color: GingaColors.accentGreenDark),
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor:      GingaColors.backgroundDark,
    selectedItemColor:    GingaColors.accentGreenDark,
    unselectedItemColor:  GingaColors.textMuted,
    type:                 BottomNavigationBarType.fixed,
    elevation:            8,
    selectedLabelStyle:   TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 11),
  ),
);

// ─────────────────────────────────────────
//  COMMON PICKER THEME BUILDERS
// ─────────────────────────────────────────

Widget buildGingaDatePickerTheme(BuildContext context, Widget? child) {
  final isDark = ThemeManager.instance.themeMode == ThemeMode.dark ||
      (ThemeManager.instance.themeMode == ThemeMode.system &&
          MediaQuery.of(context).platformBrightness == Brightness.dark);

  final baseTheme = isDark ? gingaDarkTheme : gingaLightTheme;

  return Theme(
    data: baseTheme.copyWith(
      dialogBackgroundColor: isDark ? GingaColors.backgroundDark : Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: isDark ? GingaColors.backgroundDark : Colors.white,
        onSurface: isDark ? Colors.white : GingaColors.textPrimary,
        surfaceContainerHigh: isDark ? GingaColors.surfaceDark : Colors.white,
        surfaceContainerHighest: isDark ? GingaColors.surfaceDark : Colors.white,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: isDark ? GingaColors.backgroundDark : Colors.white,
        headerBackgroundColor: isDark ? GingaColors.surfaceDark : GingaColors.brandGreen,
        headerForegroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? Colors.white : GingaColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? GingaColors.accentGreenDark : GingaColors.brandGreen;
          }
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.all(isDark ? GingaColors.accentGreenDark : GingaColors.brandGreen),
        todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
        yearForegroundColor: WidgetStateProperty.all(isDark ? Colors.white : GingaColors.textPrimary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? GingaColors.accentGreenDark : GingaColors.brandGreen,
        ),
      ),
    ),
    child: child!,
  );
}

Widget buildGingaTimePickerTheme(BuildContext context, Widget? child) {
  final isDark = ThemeManager.instance.themeMode == ThemeMode.dark ||
      (ThemeManager.instance.themeMode == ThemeMode.system &&
          MediaQuery.of(context).platformBrightness == Brightness.dark);

  final baseTheme = isDark ? gingaDarkTheme : gingaLightTheme;

  return Theme(
    data: baseTheme.copyWith(
      dialogBackgroundColor: isDark ? GingaColors.backgroundDark : Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: isDark ? GingaColors.backgroundDark : Colors.white,
        onSurface: isDark ? Colors.white : GingaColors.textPrimary,
        surfaceContainerHigh: isDark ? GingaColors.surfaceDark : Colors.white,
        surfaceContainerHighest: isDark ? GingaColors.surfaceDark : Colors.white,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: isDark ? GingaColors.backgroundDark : Colors.white,
        hourMinuteTextColor: isDark ? Colors.white : GingaColors.textPrimary,
        dayPeriodTextColor: isDark ? Colors.white : GingaColors.textPrimary,
        dialHandColor: isDark ? GingaColors.accentGreenDark : GingaColors.brandGreen,
        dialTextColor: isDark ? Colors.white : GingaColors.textPrimary,
        dialBackgroundColor: isDark ? GingaColors.surfaceDark : const Color(0xFFF0F0F0),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? GingaColors.accentGreenDark : GingaColors.brandGreen,
        ),
      ),
    ),
    child: child!,
  );
}
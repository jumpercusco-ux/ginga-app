// ============================================================
//  GINGA APP — Theme Configuration v1.0
//  Jumper Studio | Flutter Design System
// ============================================================

import 'package:flutter/material.dart';

// ─────────────────────────────────────────
//  COLOR TOKENS
// ─────────────────────────────────────────

class GingaColors {
  GingaColors._();

  // Primario (Marca)
  static const Color brandGreen       = Color(0xFF388E3C); // Verde Principal
  static const Color accentAmber      = Color(0xFFFBC02D); // Amarillo Dorado / Alerta

  // Neutros — Modo Claro
  static const Color backgroundLight  = Color(0xFFFFFFFF); // Fondo Base
  static const Color cardLight        = Color(0xFFE8F5E9); // Fondo Tarjeta seleccionada
  static const Color textPrimary      = Color(0xFF000000); // Títulos principales
  static const Color textSecondary    = Color(0xFF5F6368); // Subtextos / leyendas
  static const Color borderLight      = Color(0xFFE0E0E0); // Bordes e inputs

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

  // Usa 'Montserrat' para headers (añadir al pubspec.yaml)
  // Usa 'Nunito' para body (añadir al pubspec.yaml)

  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: GingaColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: GingaColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: GingaColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: GingaColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Nunito',
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
    fontFamily: 'Nunito',
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

final ThemeData gingaLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'Nunito',

  colorScheme: const ColorScheme.light(
    primary:        GingaColors.brandGreen,
    secondary:      GingaColors.accentAmber,
    surface:        GingaColors.backgroundLight,
    onPrimary:      GingaColors.textWhite,
    onSecondary:    GingaColors.textPrimary,
    onSurface:      GingaColors.textPrimary,
    outline:        GingaColors.borderLight,
  ),

  scaffoldBackgroundColor: GingaColors.backgroundLight,

  appBarTheme: const AppBarTheme(
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
      borderSide:     const BorderSide(color: GingaColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius:   BorderRadius.circular(GingaRadius.md),
      borderSide:     const BorderSide(color: GingaColors.borderLight),
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

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
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

final ThemeData gingaDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Nunito',

  colorScheme: const ColorScheme.dark(
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
import 'package:flutter/material.dart';

/// Brand palette from design board
/// Light: Seashell bg, Denim primary, Obsidian text
/// Dark:  Obsidian bg, Denim primary, Seashell text
class AppColors {
  // Core brand
  static const obsidian     = Color(0xFF2A2A2A);   // near-black
  static const seashell     = Color(0xFFF0F0ED);   // off-white / cream
  static const denim        = Color(0xFF3E83AE);   // Celtic Blue / Denim
  static const denimDark    = Color(0xFF2B6390);   // deeper denim for dark mode

  // Supporting palette
  static const teaGreen     = Color(0xFFA8C5A0);   // soft green
  static const vanilla      = Color(0xFFEDE8A0);   // pale yellow
  static const ivory        = Color(0xFFF8F5EC);   // warm white
  static const oliveDark    = Color(0xFF3A3F2C);   // Dark Olive Brown

  // Functional
  static const error        = Color(0xFFD94F4F);
  static const success      = Color(0xFF4CAF73);
}

class AppTheme {
  // ─────────────────────────────────────────────
  //  LIGHT  (Seashell background, Denim accents)
  // ─────────────────────────────────────────────
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.denim,
    scaffoldBackgroundColor: AppColors.seashell,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.seashell,
      foregroundColor: AppColors.obsidian,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.obsidian),
      titleTextStyle: TextStyle(
        color: AppColors.obsidian,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),

    colorScheme: const ColorScheme.light(
      primary: AppColors.denim,
      secondary: AppColors.teaGreen,
      tertiary: AppColors.vanilla,
      surface: AppColors.ivory,
      onPrimary: Colors.white,
      onSecondary: AppColors.obsidian,
      onSurface: AppColors.obsidian,
      error: AppColors.error,
    ),

    cardTheme: CardThemeData(
      color: AppColors.ivory,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.denim.withOpacity(0.08)),
      ),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.obsidian, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: AppColors.obsidian, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: AppColors.obsidian, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: AppColors.obsidian, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.obsidian, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.obsidian),
      bodyMedium: TextStyle(color: Color(0xFF555555)),
      labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.denim,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.denim,
        side: const BorderSide(color: AppColors.denim, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.denim),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return AppColors.denim;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return AppColors.denim.withOpacity(0.45);
        return const Color(0xFFCCCCCC);
      }),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.denim,
      linearTrackColor: Color(0xFFD8D8D8),
    ),

    dividerColor: AppColors.denim.withOpacity(0.12),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.denim.withOpacity(0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.denim.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.denim, width: 1.8),
      ),
      labelStyle: const TextStyle(color: Color(0xFF777777)),
      hintStyle: TextStyle(color: AppColors.obsidian.withOpacity(0.35)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.teaGreen.withOpacity(0.25),
      selectedColor: AppColors.denim,
      labelStyle: const TextStyle(color: AppColors.obsidian),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    iconTheme: const IconThemeData(color: AppColors.denim),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.denim),
  );

  // ─────────────────────────────────────────────
  //  DARK  (Obsidian background, Denim accents)
  // ─────────────────────────────────────────────
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.denimDark,
    scaffoldBackgroundColor: AppColors.obsidian,

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: AppColors.seashell,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.seashell),
      titleTextStyle: TextStyle(
        color: AppColors.seashell,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),

    colorScheme: const ColorScheme.dark(
      primary: AppColors.denimDark,
      secondary: AppColors.teaGreen,
      tertiary: AppColors.vanilla,
      surface: Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      onSecondary: AppColors.obsidian,
      onSurface: AppColors.seashell,
      error: AppColors.error,
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.denimDark.withOpacity(0.25)),
      ),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.seashell, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: AppColors.seashell, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: AppColors.seashell, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: AppColors.seashell, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.seashell, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.seashell),
      bodyMedium: TextStyle(color: Color(0xFFBBB9B0)),
      labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.denimDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.seashell,
        side: BorderSide(color: AppColors.seashell.withOpacity(0.4), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.seashell.withOpacity(0.85),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return AppColors.seashell;
        return const Color(0xFF888888);
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return AppColors.denimDark.withOpacity(0.7);
        return const Color(0xFF444444);
      }),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.denimDark,
      linearTrackColor: AppColors.seashell.withOpacity(0.15),
    ),

    dividerColor: AppColors.seashell.withOpacity(0.1),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.seashell.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.seashell.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.denimDark, width: 1.8),
      ),
      labelStyle: TextStyle(color: AppColors.seashell.withOpacity(0.5)),
      hintStyle: TextStyle(color: AppColors.seashell.withOpacity(0.3)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.teaGreen.withOpacity(0.15),
      selectedColor: AppColors.denimDark,
      labelStyle: const TextStyle(color: AppColors.seashell),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    iconTheme: const IconThemeData(color: AppColors.seashell),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.denimDark),
  );
}

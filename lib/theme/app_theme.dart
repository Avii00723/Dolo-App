import 'package:flutter/material.dart';

/// DOLO palette sampled from the home mockup.
class AppColors {
  static const ink = Color(0xFF1D2430);
  static const mutedInk = Color(0xFF66717F);
  static const mist = Color(0xFFEAF2FA);
  static const surface = Color(0xFFFFFFFF);
  static const primaryBlue = Color(0xFF5C87D6);
  static const primaryBlueDark = Color(0xFF3F69B4);
  static const heroBlue = Color(0xFFABC9EA);
  static const sage = Color(0xFFD5DDA7);
  static const sageDark = Color(0xFF7C8E3D);
  static const paleYellow = Color(0xFFEAE8B7);
  static const border = Color(0xFFDCE6F0);
  static const shadow = Color(0x1A1D2430);
  static const error = Color(0xFFD95555);
  static const success = Color(0xFF5E9F71);
}

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primaryBlue,
    scaffoldBackgroundColor: AppColors.mist,
    cardColor: AppColors.surface,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryBlue,
      secondary: AppColors.sage,
      tertiary: AppColors.heroBlue,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: AppColors.ink,
      onTertiary: AppColors.ink,
      onSurface: AppColors.ink,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.mist,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.primaryBlue),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: AppColors.ink, fontWeight: FontWeight.w800, letterSpacing: 0),
      displayMedium: TextStyle(
          color: AppColors.ink, fontWeight: FontWeight.w800, letterSpacing: 0),
      headlineMedium: TextStyle(
          color: AppColors.ink, fontWeight: FontWeight.w800, letterSpacing: 0),
      titleLarge: TextStyle(
          color: AppColors.ink, fontWeight: FontWeight.w800, letterSpacing: 0),
      titleMedium: TextStyle(
          color: AppColors.ink, fontWeight: FontWeight.w700, letterSpacing: 0),
      bodyLarge: TextStyle(color: AppColors.ink, letterSpacing: 0),
      bodyMedium: TextStyle(color: AppColors.mutedInk, letterSpacing: 0),
      labelLarge: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: AppColors.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
    ),
    iconTheme: const IconThemeData(color: AppColors.primaryBlue),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.primaryBlue,
      textColor: AppColors.ink,
    ),
    dividerColor: AppColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
      ),
      labelStyle: const TextStyle(color: AppColors.mutedInk),
      hintStyle: const TextStyle(color: AppColors.mutedInk),
      prefixIconColor: AppColors.primaryBlue,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.sage.withValues(alpha: 0.7),
      selectedColor: AppColors.primaryBlue,
      labelStyle:
          const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryBlue,
      linearTrackColor: AppColors.border,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.primaryBlue
            : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.primaryBlue.withValues(alpha: 0.35)
            : AppColors.border;
      }),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.heroBlue,
    scaffoldBackgroundColor: const Color(0xFF111923),
    cardColor: const Color(0xFF1A2430),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.heroBlue,
      secondary: AppColors.sage,
      tertiary: AppColors.primaryBlue,
      surface: Color(0xFF1A2430),
      error: AppColors.error,
      onPrimary: AppColors.ink,
      onSecondary: AppColors.ink,
      onTertiary: Colors.white,
      onSurface: Color(0xFFEAF2FA),
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111923),
      foregroundColor: Color(0xFFEAF2FA),
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.heroBlue),
      titleTextStyle: TextStyle(
        color: Color(0xFFEAF2FA),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A2430),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.heroBlue.withValues(alpha: 0.12)),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Color(0xFFEAF2FA),
          fontWeight: FontWeight.w800,
          letterSpacing: 0),
      displayMedium: TextStyle(
          color: Color(0xFFEAF2FA),
          fontWeight: FontWeight.w800,
          letterSpacing: 0),
      headlineMedium: TextStyle(
          color: Color(0xFFEAF2FA),
          fontWeight: FontWeight.w800,
          letterSpacing: 0),
      titleLarge: TextStyle(
          color: Color(0xFFEAF2FA),
          fontWeight: FontWeight.w800,
          letterSpacing: 0),
      titleMedium: TextStyle(
          color: Color(0xFFEAF2FA),
          fontWeight: FontWeight.w700,
          letterSpacing: 0),
      bodyLarge: TextStyle(color: Color(0xFFEAF2FA), letterSpacing: 0),
      bodyMedium: TextStyle(color: Color(0xFFB9C4D0), letterSpacing: 0),
      labelLarge: TextStyle(
          color: AppColors.ink, fontWeight: FontWeight.w700, letterSpacing: 0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.heroBlue,
        foregroundColor: AppColors.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEAF2FA),
        side: BorderSide(
            color: AppColors.heroBlue.withValues(alpha: 0.22), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.heroBlue),
    ),
    iconTheme: const IconThemeData(color: AppColors.heroBlue),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.heroBlue),
    dividerColor: AppColors.heroBlue.withValues(alpha: 0.12),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A2430),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: AppColors.heroBlue.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: AppColors.heroBlue.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.heroBlue, width: 1.8),
      ),
      labelStyle: const TextStyle(color: Color(0xFFB9C4D0)),
      hintStyle: const TextStyle(color: Color(0xFF8D9AAA)),
      prefixIconColor: AppColors.heroBlue,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.sage.withValues(alpha: 0.2),
      selectedColor: AppColors.heroBlue,
      labelStyle: const TextStyle(
          color: Color(0xFFEAF2FA), fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.heroBlue,
      foregroundColor: AppColors.ink,
      shape: CircleBorder(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.heroBlue,
      linearTrackColor: AppColors.heroBlue.withValues(alpha: 0.12),
    ),
  );
}

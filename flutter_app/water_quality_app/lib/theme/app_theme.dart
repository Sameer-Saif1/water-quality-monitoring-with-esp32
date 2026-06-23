import 'package:flutter/material.dart';

/// Design tokens for the Water Quality app.
/// Aesthetic direction: a marine instrument panel — deep teal depths,
/// monospace numeric readouts (like a real sensor display), sage-teal
/// for "healthy" readings, amber/red for caution/alert zones.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0B2027);
  static const Color surface = Color(0xFF14333B);
  static const Color surfaceRaised = Color(0xFF1B3F48);
  static const Color border = Color(0xFF2A4F57);

  static const Color textPrimary = Color(0xFFE9EEE8);
  static const Color textMuted = Color(0xFF8FAAA8);
  static const Color textFaint = Color(0xFF5E7C7A);

  static const Color accent = Color(0xFF70A9A1); // healthy / good / primary action
  static const Color accentDim = Color(0xFF40798C);
  static const Color warning = Color(0xFFE8871E);
  static const Color alert = Color(0xFFC2452D);

  static const Color phLow = Color(0xFFE8871E); // acidic
  static const Color phMid = Color(0xFF70A9A1); // neutral, healthy
  static const Color phHigh = Color(0xFF5B8DEF); // alkaline

  static const Color adminBadge = Color(0xFFD9A441);
}

class AppText {
  AppText._();

  static const String displayFontFamily = 'RobotoMono';
  static const String bodyFontFamily = 'Inter';

  static const TextStyle reading = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.0,
  );

  static const TextStyle readingSmall = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle label = TextStyle(
    fontFamily: bodyFontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors.textMuted,
    letterSpacing: 1.1,
  );

  static const TextStyle unit = TextStyle(
    fontFamily: bodyFontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    color: AppColors.textMuted,
  );

  static const TextStyle title = TextStyle(
    fontFamily: bodyFontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: bodyFontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: bodyFontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.textMuted,
  );
}

/// Breakpoints for responsive layout decisions across the app.
class AppBreakpoints {
  AppBreakpoints._();
  static const double compact = 600;   // phones
  static const double medium = 1024;   // tablets / foldables
  // >= medium is treated as desktop/large-tablet
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    brightness: Brightness.dark,
    fontFamily: AppText.bodyFontFamily,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.accent,
      secondary: AppColors.accentDim,
      error: AppColors.alert,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.title,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.alert),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textFaint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: AppText.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}

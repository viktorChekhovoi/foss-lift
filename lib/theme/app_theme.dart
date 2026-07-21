import 'package:flutter/material.dart';

/// Palette lifted directly from the design mockup (design/mockup.html).
/// A deliberately cool, navy-biased dark ground with an "ignition" orange
/// accent, mint for completed work, and gold for personal records.
class AppColors {
  static const ground = Color(0xFF0F1218);
  static const surface = Color(0xFF171B24);
  static const surface2 = Color(0xFF1F2530);
  static const surface3 = Color(0xFF272E3B);
  static const line = Color(0xFF2A313D);
  static const text = Color(0xFFEAEEF5);
  static const muted = Color(0xFF8B95A7);
  static const faint = Color(0xFF5A6474);
  static const accent = Color(0xFFFF6A3D);
  static const accentPress = Color(0xFFE0521F);
  static const good = Color(0xFF3ED598);
  static const gold = Color(0xFFFFC24B);
}

/// A monospace text style for numeric data (weights, reps, timers, volume) —
/// tabular figures so columns of digits line up like a barbell readout.
const TextStyle kMono = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
);

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Color(0xFF1A0E07),
      secondary: AppColors.good,
      onSecondary: Color(0xFF062015),
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: Color(0xFFFF5D5D),
      outline: AppColors.line,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ground,
      colorScheme: scheme,
      splashColor: AppColors.accent.withValues(alpha: 0.08),
      highlightColor: AppColors.accent.withValues(alpha: 0.06),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      dividerColor: AppColors.line,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF1A0E07),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

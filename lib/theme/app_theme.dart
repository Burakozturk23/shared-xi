import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppTheme {
  // Brand
  static const Color primaryColor = Color(0xFF2F7BFF);
  static const Color primaryPressed = Color(0xFF1E63DB);
  static const Color secondaryColor = Color(0xFF20D47B);

  // Surfaces
  static const Color backgroundColor = Color(0xFF07100D);
  static const Color surfaceColor = Color(0xFF0B1415);
  static const Color cardColor = Color(0xFF0E171B);
  static const Color elevatedCardColor = Color(0xFF121D22);
  static const Color mutedSurfaceColor = Color(0xFF162128);

  // Content
  static const Color textColor = Color(0xFFF7FAFC);
  static const Color secondaryTextColor = Color(0xFFB5C0C8);
  static const Color hintColor = Color(0xFF7F8B94);
  static const Color borderColor = Color(0xFF27343D);
  static const Color strongBorderColor = Color(0xFF3A4A54);

  // Semantic
  static const Color successColor = Color(0xFF20D47B);
  static const Color warningColor = Color(0xFFFFB64A);
  static const Color dangerColor = Color(0xFFFF5D68);
  static const Color infoColor = Color(0xFF59A8FF);

  static ThemeData get darkTheme {
    final scheme = const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: cardColor,
      error: dangerColor,
      onPrimary: Colors.white,
      onSecondary: Color(0xFF04120B),
      onSurface: textColor,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      dividerColor: borderColor,
      splashColor: primaryColor.withValues(alpha: 0.10),
      highlightColor: primaryColor.withValues(alpha: 0.06),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: secondaryTextColor),
        bodySmall: TextStyle(color: hintColor),
        labelLarge: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: const TextStyle(color: hintColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          foregroundColor: textColor,
          side: const BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Approved Ortak Saha V3.1 palette. Accent is for selection; lime is for action.
@immutable
class PitchColors extends ThemeExtension<PitchColors> {
  const PitchColors({
    required this.background,
    required this.surface,
    required this.raised,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.tint,
    required this.limeInk,
    required this.limeTint,
    required this.success,
    required this.error,
  });

  final Color background, surface, raised, text, muted, border, accent, tint;
  final Color limeInk, limeTint, success, error;
  static const lime = Color(0xFFC8FF3D);
  static const onAction = Color(0xFF0B1210);
  static const dark = PitchColors(
    background: Color(0xFF0B1210),
    surface: Color(0xFF101C18),
    raised: Color(0xFF16241F),
    text: Color(0xFFF2F6F1),
    muted: Color(0xFFA1B2A9),
    border: Color(0xFF26372F),
    accent: Color(0xFF33E6FF),
    tint: Color(0xFF123039),
    limeInk: lime,
    limeTint: Color(0xFF213016),
    success: Color(0xFF20D47B),
    error: Color(0xFFFF5C68),
  );
  static const light = PitchColors(
    background: Color(0xFFF5F7F2),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEAF0E7),
    text: Color(0xFF14241C),
    muted: Color(0xFF53655B),
    border: Color(0xFFD5DFD4),
    accent: Color(0xFF00737D),
    tint: Color(0xFFE1F4F4),
    limeInk: Color(0xFF456000),
    limeTint: Color(0xFFEFF7DF),
    success: Color(0xFF087C44),
    error: Color(0xFFBC283A),
  );
  static PitchColors of(BuildContext context) =>
      Theme.of(context).extension<PitchColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  PitchColors copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? text,
    Color? muted,
    Color? border,
    Color? accent,
    Color? tint,
    Color? limeInk,
    Color? limeTint,
    Color? success,
    Color? error,
  }) => PitchColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    tint: tint ?? this.tint,
    limeInk: limeInk ?? this.limeInk,
    limeTint: limeTint ?? this.limeTint,
    success: success ?? this.success,
    error: error ?? this.error,
  );
  @override
  PitchColors lerp(covariant PitchColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return PitchColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      raised: mix(raised, other.raised),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      border: mix(border, other.border),
      accent: mix(accent, other.accent),
      tint: mix(tint, other.tint),
      limeInk: mix(limeInk, other.limeInk),
      limeTint: mix(limeTint, other.limeTint),
      success: mix(success, other.success),
      error: mix(error, other.error),
    );
  }
}

class OrtakSahaTheme {
  static ThemeData get dark => _build(Brightness.dark, PitchColors.dark);
  static ThemeData get light => _build(Brightness.light, PitchColors.light);

  static ThemeData _build(Brightness brightness, PitchColors p) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    TextStyle display(double size, double height) => TextStyle(
      fontFamily: 'Satoshi',
      fontSize: size,
      height: height / size,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
      color: p.text,
    );
    TextStyle body(
      double size, {
      FontWeight weight = FontWeight.w400,
      Color? color,
    }) => TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      height: 1.5,
      fontWeight: weight,
      color: color ?? p.text,
    );
    // Button styles bypass TextTheme merging. Resolve their typography before
    // animating between the shell and legacy authentication/game themes.
    final buttonText = Typography.englishLike2021.labelLarge!.merge(
      body(16, weight: FontWeight.w600),
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.accent,
          brightness: brightness,
        ).copyWith(
          primary: PitchColors.lime,
          onPrimary: PitchColors.onAction,
          primaryContainer: p.limeTint,
          onPrimaryContainer: p.limeInk,
          secondary: p.accent,
          onSecondary: brightness == Brightness.dark
              ? PitchColors.onAction
              : Colors.white,
          secondaryContainer: p.tint,
          onSecondaryContainer: p.accent,
          surface: p.surface,
          onSurface: p.text,
          onSurfaceVariant: p.muted,
          surfaceContainerHighest: p.raised,
          outline: p.border,
          error: p.error,
          onError: brightness == Brightness.dark
              ? PitchColors.onAction
              : Colors.white,
        );
    final action = FilledButton.styleFrom(
      backgroundColor: PitchColors.lime,
      foregroundColor: PitchColors.onAction,
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: shape,
      textStyle: buttonText,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: scheme,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      cardColor: p.surface,
      dividerColor: p.border,
      hintColor: p.muted,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: TextTheme(
        displaySmall: display(32, 40),
        headlineLarge: display(32, 40),
        headlineMedium: display(30, 36),
        headlineSmall: display(24, 32),
        titleLarge: display(20, 24),
        titleMedium: body(18, weight: FontWeight.w600),
        titleSmall: body(16, weight: FontWeight.w600),
        bodyLarge: body(16),
        bodyMedium: body(15),
        bodySmall: body(13, color: p.muted),
        labelLarge: body(16, weight: FontWeight.w600),
        labelMedium: body(12, weight: FontWeight.w600, color: p.muted),
        labelSmall: body(12, color: p.muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(20, 24),
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: p.border)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(style: action),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: action.copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: BorderSide(color: p.accent),
          shape: shape,
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.muted,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: body(15, color: p.muted),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.background,
        indicatorColor: p.tint,
        elevation: 0,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.accent : p.muted,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => body(
            12,
            color: s.contains(WidgetState.selected) ? p.text : p.muted,
            weight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.tint : p.raised,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.border),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.tint,
        labelStyle: body(13),
        secondaryLabelStyle: body(13, color: p.accent),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.accent,
        unselectedLabelColor: p.muted,
        indicatorColor: p.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.surface, shape: shape),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.raised,
        contentTextStyle: body(14),
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
    );
  }
}

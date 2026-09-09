import 'package:flutter/material.dart';

abstract final class KopitiamColors {
  static const ink = Color(0xFF071F33);
  static const navy = Color(0xFF063B5C);
  static const ocean = Color(0xFF087797);
  static const cyan = Color(0xFF32A9C2);
  static const cyanSoft = Color(0xFFE4F4F7);
  static const gold = Color(0xFFD6A93A);
  static const yellow = Color(0xFFF6D03F);
  static const canvas = Color(0xFFF1F6F8);
  static const surface = Color(0xFFFBFDFE);
  static const surfaceStrong = Color(0xFFEAF1F4);
  static const line = Color(0xFFD4E1E6);
  static const muted = Color(0xFF607681);
  static const success = Color(0xFF16855A);
  static const successSoft = Color(0xFFE6F5EE);
  static const danger = Color(0xFFBA3A43);
  static const dangerSoft = Color(0xFFFBEAEC);
  static const warning = Color(0xFFA66D14);
  static const warningSoft = Color(0xFFFFF1D6);
  static const scrim = Color(0xB3071F33);
  static const cameraOverlay = Color(0xCC071F33);
}

abstract final class KopitiamTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: KopitiamColors.ocean,
      onPrimary: KopitiamColors.surface,
      secondary: KopitiamColors.gold,
      onSecondary: KopitiamColors.ink,
      error: KopitiamColors.danger,
      onError: KopitiamColors.surface,
      surface: KopitiamColors.surface,
      onSurface: KopitiamColors.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: KopitiamColors.canvas,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: KopitiamColors.navy,
        foregroundColor: KopitiamColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: KopitiamColors.surface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: KopitiamColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: KopitiamColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KopitiamColors.ocean,
          foregroundColor: KopitiamColors.surface,
          minimumSize: const Size(44, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KopitiamColors.yellow,
          foregroundColor: KopitiamColors.ink,
          elevation: 0,
          minimumSize: const Size(44, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KopitiamColors.ocean,
          minimumSize: const Size(44, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          side: const BorderSide(color: KopitiamColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KopitiamColors.surface,
        labelStyle: const TextStyle(color: KopitiamColors.muted),
        hintStyle: const TextStyle(color: KopitiamColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: KopitiamColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: KopitiamColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: KopitiamColors.cyan, width: 1.8)),
      ),
      dividerTheme: const DividerThemeData(color: KopitiamColors.line, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: KopitiamColors.cyan, linearTrackColor: KopitiamColors.surfaceStrong, circularTrackColor: KopitiamColors.surfaceStrong),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: KopitiamColors.ink, contentTextStyle: TextStyle(color: KopitiamColors.surface)),
      dialogTheme: DialogThemeData(backgroundColor: KopitiamColors.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: KopitiamColors.surface, indicatorColor: KopitiamColors.cyanSoft),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: KopitiamColors.yellow, foregroundColor: KopitiamColors.ink),
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(color: KopitiamColors.ink, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.4),
        titleLarge: const TextStyle(color: KopitiamColors.ink, fontSize: 20, fontWeight: FontWeight.w800),
        titleMedium: const TextStyle(color: KopitiamColors.ink, fontSize: 16, fontWeight: FontWeight.w800),
        bodyMedium: const TextStyle(color: KopitiamColors.ink, fontSize: 14, height: 1.45),
        bodySmall: const TextStyle(color: KopitiamColors.muted, fontSize: 12, height: 1.4),
      ),
    );
  }
}

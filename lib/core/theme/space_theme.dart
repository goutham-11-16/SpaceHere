import 'package:flutter/material.dart';

class SpaceColors {
  static const canvas = Color(0xFF08111F);
  static const surface = Color(0xFF101B2D);
  static const surfaceLight = Color(0xFF16253D);
  static const glass = Color(0x99152236);
  static const border = Color(0x332FE8FF);
  static const cyan = Color(0xFF2FE8FF);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF48F08A);
  static const amber = Color(0xFFFFC857);
  static const danger = Color(0xFFFF5C7A);
  static const text = Color(0xFFEAF6FF);
  static const muted = Color(0xFF8EA3B7);
}

class SpaceTheme {
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: SpaceColors.cyan,
      brightness: Brightness.dark,
      surface: SpaceColors.surface,
      primary: SpaceColors.cyan,
      secondary: SpaceColors.violet,
      tertiary: SpaceColors.green,
      error: SpaceColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SpaceColors.canvas,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: SpaceColors.text,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          color: SpaceColors.text,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: SpaceColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: SpaceColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          color: SpaceColors.text,
          fontSize: 16,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          color: SpaceColors.muted,
          fontSize: 14,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          color: SpaceColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SpaceColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: SpaceColors.glass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: SpaceColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpaceColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpaceColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpaceColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpaceColors.cyan, width: 1.4),
        ),
        labelStyle: const TextStyle(color: SpaceColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SpaceColors.cyan,
          foregroundColor: const Color(0xFF03131D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpaceColors.text,
          side: const BorderSide(color: SpaceColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: SpaceColors.text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0A1424),
        selectedIconTheme: IconThemeData(color: SpaceColors.cyan),
        selectedLabelTextStyle: TextStyle(
          color: SpaceColors.cyan,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: SpaceColors.muted),
        unselectedLabelTextStyle: TextStyle(color: SpaceColors.muted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0A1424),
        selectedItemColor: SpaceColors.cyan,
        unselectedItemColor: SpaceColors.muted,
        type: BottomNavigationBarType.fixed,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SpaceColors.cyan,
        linearTrackColor: Color(0x3348F08A),
      ),
    );
  }
}

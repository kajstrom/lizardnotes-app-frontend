import 'package:flutter/material.dart';
import 'colour_tokens.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: LnColors.lnBg,
      colorScheme: const ColorScheme.dark(
        surface: LnColors.lnSurface,
        primary: LnColors.lnAccent,
        onPrimary: LnColors.lnText,
        secondary: LnColors.lnAccent2,
        error: LnColors.lnDanger,
        onSurface: LnColors.lnText,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: LnColors.lnText),
        displayMedium: TextStyle(color: LnColors.lnText),
        displaySmall: TextStyle(color: LnColors.lnText),
        headlineLarge: TextStyle(color: LnColors.lnText),
        headlineMedium: TextStyle(color: LnColors.lnText),
        headlineSmall: TextStyle(color: LnColors.lnText),
        titleLarge: TextStyle(color: LnColors.lnText),
        titleMedium: TextStyle(color: LnColors.lnText),
        titleSmall: TextStyle(color: LnColors.lnText),
        bodyLarge: TextStyle(color: LnColors.lnText),
        bodyMedium: TextStyle(color: LnColors.lnText),
        bodySmall: TextStyle(color: LnColors.lnText2),
        labelLarge: TextStyle(color: LnColors.lnText),
        labelMedium: TextStyle(color: LnColors.lnText),
        labelSmall: TextStyle(color: LnColors.lnText2),
      ),
      dividerColor: LnColors.lnBorder2,
      cardColor: LnColors.lnSurface2,
      hoverColor: LnColors.lnSurface3,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: LnColors.lnSurface2,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: LnColors.lnBorder2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: LnColors.lnBorder2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: LnColors.lnAccent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LnColors.lnAccent,
          foregroundColor: LnColors.lnText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LnColors.lnAccent2,
        ),
      ),
      iconTheme: const IconThemeData(color: LnColors.lnText2),
      appBarTheme: const AppBarTheme(
        backgroundColor: LnColors.lnSurface,
        foregroundColor: LnColors.lnText,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );
  }
}

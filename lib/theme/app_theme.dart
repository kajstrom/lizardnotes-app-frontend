import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colour_tokens.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    // Base TextTheme with Inter applied to all Material slots.
    final base = GoogleFonts.interTextTheme(
      const TextTheme(
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
    );

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
      textTheme: base,
      dividerColor: LnColors.lnBorder2,
      cardColor: LnColors.lnSurface2,
      hoverColor: LnColors.lnSurface3,

      // Inputs: lnSurface2 fill, 1 px borders, 6 px radius, 10×12 px padding.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LnColors.lnSurface2,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: LnColors.lnBorder2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: LnColors.lnBorder2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: LnColors.lnAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: LnColors.lnDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: LnColors.lnDanger),
        ),
      ),

      // Primary button: lnAccent fill, 11×16 px padding, 6 px radius, 12/500.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LnColors.lnAccent,
          foregroundColor: LnColors.lnText,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),

      // Secondary link: 12.5 px, lnText2 default.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LnColors.lnText2,
          textStyle: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
          ),
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

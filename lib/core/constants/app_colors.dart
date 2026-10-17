import 'package:flutter/material.dart';

/// SkyTune Official Design System Tokens
class AppColors {
  AppColors._();

  // Core Brand & Palette
  static const Color primarySkyBlue = Color(0xFF1E90FF);   // Primary Sky Blue
  static const Color deepNightBlue  = Color(0xFF0B1026);   // Deep Night Blue (backgrounds)
  static const Color surface        = Color(0xFF151B3B);   // Surface / Cards
  static const Color elevated       = Color(0xFF1F2750);   // Elevated Surface / Borders
  static const Color cyanAccent     = Color(0xFF38D6FF);   // Cyan Accent (progress bars, active icons)
  static const Color sunsetCoral    = Color(0xFFFF6B6B);   // Sunset Coral Accent (like button, highlights)
  static const Color softGold       = Color(0xFFFFC857);   // Soft Gold (crescent sun, small badges)

  // Standard aliases for components
  static const Color background     = deepNightBlue;
  static const Color card           = surface;
  static const Color accent         = cyanAccent;
  static const Color accentLight    = Color(0xFF6DE2FF);

  // Text Hierarchy
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA9B4D6);
  static const Color textMuted     = Color(0xFF6B78A0);

  // Functional Colors
  static const Color error         = sunsetCoral;
  static const Color warning       = softGold;
  static const Color success       = Color(0xFF00E676);
  static const Color offline       = Color(0xFF2E385D);
  static const Color shimmerBase   = Color(0xFF151B3B);
  static const Color shimmerHighlight = Color(0xFF1F2750);

  // Logo & App Gradient
  // Gradient: #38D6FF (top) -> #1E90FF (middle) -> #5B4BFF (bottom)
  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF38D6FF),
      Color(0xFF1E90FF),
      Color(0xFF5B4BFF),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF38D6FF),
      Color(0xFF1E90FF),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1F2750),
      Color(0xFF151B3B),
    ],
  );
}

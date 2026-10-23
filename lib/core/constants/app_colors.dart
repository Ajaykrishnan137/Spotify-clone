import 'package:flutter/material.dart';

/// SkyTune Official Design System Tokens (Flat & Calm Palette)
class AppColors {
  AppColors._();

  // Core Brand & Palette (Calm & Elegant)
  static const Color background     = Color(0xFF0F1320);   // Dark Slate Background
  static const Color deepNightBlue  = background;          // Compatibility alias
  static const Color surface        = Color(0xFF181D2E);   // Surface Cards / Containers
  static const Color elevated       = Color(0xFF222840);   // Elevated Surface / Borders
  static const Color primarySkyBlue = Color(0xFF4A90D9);   // Primary Accent (Muted Sky Blue)
  static const Color sunsetCoral    = Color(0xFFE36A6A);   // Secondary Accent (Soft Coral, likes only)
  static const Color softGold       = Color(0xFFE5B558);   // Soft Gold
  static const Color dividers       = Color(0xFF2A3047);   // 1px Dividers

  // Standard aliases for components
  static const Color card           = surface;
  static const Color accent         = primarySkyBlue;
  static const Color cyanAccent     = primarySkyBlue;      // Clean alias pointing to calm primary
  static const Color accentLight    = Color(0xFF6BA8E8);

  // Text Hierarchy
  static const Color textPrimary   = Color(0xFFF2F4F8);
  static const Color textSecondary = Color(0xFF9AA3B8);
  static const Color textMuted     = Color(0xFF6B7898);

  // Functional Colors
  static const Color error         = sunsetCoral;
  static const Color warning       = softGold;
  static const Color success       = Color(0xFF48BB78);
  static const Color offline       = Color(0xFF2A3047);
  static const Color shimmerBase   = surface;
  static const Color shimmerHighlight = elevated;

  // Subtle default album/playlist placeholder gradient (two close shades, never neon)
  static const LinearGradient subtlePlaceholderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1F263B),
      Color(0xFF161B2C),
    ],
  );

  // Logo gradient alias (subtle sky blue tone)
  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4A90D9),
      Color(0xFF3570B2),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4A90D9),
      Color(0xFF3570B2),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF181D2E),
      Color(0xFF131726),
    ],
  );
}

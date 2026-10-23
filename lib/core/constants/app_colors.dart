import 'package:flutter/material.dart';

/// SkyTune Official Design System Tokens (Vibrant, Clean, Flat & High-Contrast)
class AppColors {
  AppColors._();

  // Core Brand & Palette (Vivid, High-Contrast & Solid Flat Fills)
  static const Color background     = Color(0xFF0A0E1A);   // Deep, slightly darker so content pops
  static const Color deepNightBlue  = background;          // Compatibility alias
  static const Color surface        = Color(0xFF151B2E);   // Surface cards / containers
  static const Color elevated       = Color(0xFF1E2640);   // Elevated surface / borders
  static const Color primarySkyBlue = Color(0xFF1E90FF);   // Primary Accent (Clear sky blue, saturated)
  static const Color secondaryAccent = Color(0xFFFF5A5F);  // Secondary Accent (Likes, delete, alerts)
  static const Color sunsetCoral    = secondaryAccent;     // Compatibility alias
  static const Color softGold       = Color(0xFFFFB020);   // Warning / Gold Accent
  static const Color dividers       = Color(0xFF2C3552);   // Clean 1px Dividers

  // Standard aliases for components
  static const Color card           = surface;
  static const Color accent         = primarySkyBlue;
  static const Color cyanAccent     = primarySkyBlue;      // Clean alias pointing to vivid primary
  static const Color accentLight    = Color(0xFF4DA6FF);

  // Text Hierarchy (High-Contrast & WCAG 4.5:1 Compliant)
  static const Color textPrimary   = Color(0xFFFFFFFF);   // Pure white for crisp contrast
  static const Color textSecondary = Color(0xFFB4BDD6);   // Bright, legible secondary (not dull/dim)
  static const Color textMuted     = Color(0xFF8896B8);   // Muted notes

  // Functional Colors
  static const Color error         = secondaryAccent;     // #FF5A5F
  static const Color warning       = softGold;            // #FFB020
  static const Color success       = Color(0xFF2ECC71);   // Clear vibrant success green
  static const Color offline       = Color(0xFF2C3552);
  static const Color shimmerBase   = surface;
  static const Color shimmerHighlight = elevated;

  // Subtle default album/playlist placeholder gradient (two close shades of same hue, never neon)
  static const LinearGradient subtlePlaceholderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E90FF),
      Color(0xFF1877D2),
    ],
  );

  // Logo gradient alias (clear vivid sky blue tones)
  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E90FF),
      Color(0xFF1877D2),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E90FF),
      Color(0xFF1877D2),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF151B2E),
      Color(0xFF101524),
    ],
  );
}

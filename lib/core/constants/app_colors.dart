import 'package:flutter/material.dart';

/// AppColors defines the complete color palette for Túi Khôn Mobile App.
/// Based on Material Design 3 and tailored for emerald prosperity theme.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary Emerald Palette (Main brand accent)
  static const Color primary = Color(0xFF007F5B);
  static const Color primaryContainer = Color(0xFF00A878);
  static const Color primaryFixed = Color(0xFF85F8C4);
  static const Color primaryFixedDim = Color(0xFF68DBA9);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary Indigo / Modern Accent
  static const Color secondary = Color(0xFF4648D4);
  static const Color secondaryContainer = Color(0xFF6063EE);
  static const Color secondaryFixed = Color(0xFFE1E0FF);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Tertiary Gold / Amber (VIP, Promo, Rewards)
  static const Color tertiary = Color(0xFF825100);
  static const Color tertiaryContainer = Color(0xFFA36700);
  static const Color tertiaryFixed = Color(0xFFFFDDB8);

  // Semantic Feedback Colors
  static const Color error = Color(0xFFE5484D);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);

  // Surface & Neutral Colors
  static const Color background = Color(0xFFF3F8F1);
  static const Color surface = Color(0xFFF8FBF7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEDF4ED);
  static const Color surfaceContainer = Color(0xFFE5F0E8);
  static const Color surfaceContainerHigh = Color(0xFFDCECE2);
  static const Color surfaceContainerHighest = Color(0xFFD0E5DA);

  // Text & Typography Neutrals
  static const Color surfaceVariant = surfaceContainerHigh;
  static const Color onSurface = Color(0xFF122C35);
  static const Color onSurfaceVariant = Color(0xFF64766E);
  static const Color outline = Color(0xFF6D7A72);
  static const Color outlineVariant = Color(0xFFBCCAC0);
}

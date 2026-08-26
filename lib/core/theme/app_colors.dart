import 'package:flutter/material.dart';

/// Couleurs de marque de Yame — coque sombre quasi noire, accent or/jaune.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0B0B10);
  static const surface = Color(0xFF16161D);
  static const surfaceElevated = Color(0xFF1E1E27);
  static const fieldFill = Color(0xFF1A1A22);

  static const accent = Color(0xFFF5A623);
  static const accentBright = Color(0xFFFFC24D);
  static const accentDeep = Color(0xFFD1860F);

  static const textPrimary = Color(0xFFF7F7FA);
  static const textSecondary = Color(0xFFA6A6B3);
  static const textDisabled = Color(0xFF5C5C68);

  static const border = Color(0xFF2A2A34);

  static const success = Color(0xFF3DDC97);
  static const error = Color(0xFFFF6B6B);

  // Registre clair, utilisé par les écrans utilitaires (paiement, notation,
  // annulation, partage de position) — volontairement distinct du reste.
  static const lightBackground = Color(0xFFFAFAFC);
  static const lightSurface = Color(0xFFF2F2F5);
  static const lightBorder = Color(0xFFE2E2E8);
  static const lightTextPrimary = Color(0xFF17171C);
  static const lightTextSecondary = Color(0xFF6B6B76);
}

import 'package:flutter/material.dart';

/// Bitewise brand palette.
///
/// Premium, rustig en betrouwbaar. Navy als basis, goud als accent.
abstract final class AppColors {
  // Brand
  static const Color navy = Color(0xFF062B52);
  static const Color gold = Color(0xFFC99A3D);
  static const Color cream = Color(0xFFFAF7F0);

  // Navy shades
  static const Color navy800 = Color(0xFF0C355C);
  static const Color navy600 = Color(0xFF34546F);
  static const Color navy400 = Color(0xFF6E8293);

  // Neutrals
  static const Color ink = Color(0xFF18324B);
  static const Color slate = Color(0xFF667789);
  static const Color mist = Color(0xFFE8E0D4);
  static const Color surface = cream;
  static const Color white = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF6D8E5D);
  static const Color warning = Color(0xFFD9A441);
  static const Color danger = Color(0xFFC65B54);

  // Macro accents (used in progress rings)
  static const Color kcal = gold;
  static const Color protein = Color(0xFF4B8FB3);
  static const Color sugar = Color(0xFFC65B54);
  static const Color carbs = Color(0xFF6BA292);
}

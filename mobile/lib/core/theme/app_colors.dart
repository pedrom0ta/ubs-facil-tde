import 'package:flutter/material.dart';

/// Paleta do UBS Fácil. Todas as combinações de texto têm contraste mínimo de 4,5:1 (WCAG AA).
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF1B63D6); // branco sobre ele: 5,5:1
  static const primaryDark = Color(0xFF124AA3);
  static const primarySoft = Color(0xFFEAF2FE);
  static const navy = Color(0xFF0B1726);
  static const background = Color(0xFFF4F7FB);
  static const surface = Colors.white;
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF5A6577); // 5,9:1 sobre branco
  static const border = Color(0xFFE2E8F0);
  static const inputBorder = Color(0xFFCBD5E1);
  static const success = Color(0xFF0F7A4F);
  static const successSoft = Color(0xFFE3F5EC);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFEECEB);
  static const warning = Color(0xFF8A4B00);
  static const warningSoft = Color(0xFFFFF4E5);
  static const ring = Color(0xFF2BB78A);
}

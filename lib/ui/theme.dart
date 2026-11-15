import 'package:flutter/material.dart';

/// ألوان وخطوط واجهات اللعبة.
class AppColors {
  static const sea = Color(0xFF0B4F86);
  static const seaDeep = Color(0xFF062B4F);
  static const sand = Color(0xFFFFF4DC);
  static const coral = Color(0xFFFF8A3D);
  static const coralDark = Color(0xFFE0641A);
  static const gold = Color(0xFFFFD54F);
  static const panel = Color(0xF2FFFBF2);
  static const ink = Color(0xFF1D2B3A);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Tajawal',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.sea, primary: AppColors.sea, secondary: AppColors.coral),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
  );
}

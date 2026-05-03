import 'package:flutter/material.dart';
import 'colors.dart';

class AppText {
  AppText._();

  static const _base = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
  );

  static final displayLarge = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700);
  static final displayMedium = _base.copyWith(fontSize: 40, fontWeight: FontWeight.w700);
  static final headlineLarge = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700);
  static final headlineMedium = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
  static final titleLarge = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static final titleMedium = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
  static final bodyMedium = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final bodySmall = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted);
  static final labelMedium = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted);
  static final labelSmall = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textFaint);
  static final monoBody = _base.copyWith(fontSize: 13, fontFamily: 'JetBrains Mono');
  static final link = _base.copyWith(fontSize: 14, color: AppColors.accentBlue, fontWeight: FontWeight.w500);
}

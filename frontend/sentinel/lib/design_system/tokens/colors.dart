import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const bgPrimary = Color(0xFF1B2733);
  static const bgCard = Color(0xFF0D1521);
  static const bgInput = Color(0xFF162032);
  static const bgHover = Color(0xFF1E2E40);
  static const bgOverlay = Color(0xFF0D1521);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF8BA0B4);
  static const textFaint = Color(0xFF5A7A94);

  // Accent
  static const accentBlue = Color(0xFF3B8BEB);

  // Severity
  static const severityCritical = Color(0xFFEF4444);
  static const severityMajor = Color(0xFFF59E0B);
  static const severityMinor = Color(0xFF22C55E);

  // Status
  static const statusOpen = Color(0xFF3B8BEB);
  static const statusInProgress = Color(0xFFF59E0B);
  static const statusResolved = Color(0xFF22C55E);
  static const statusClosed = Color(0xFF8BA0B4);

  // Border
  static const border = Color(0xFF2A3F52);

  static Color forSeverity(String severity) => switch (severity.toLowerCase()) {
        'critical' => severityCritical,
        'major' => severityMajor,
        'minor' => severityMinor,
        _ => textMuted,
      };

  static Color forStatus(String status) => switch (status.toLowerCase()) {
        'open' => statusOpen,
        'in_progress' => statusInProgress,
        'resolved' => statusResolved,
        'closed' => statusClosed,
        _ => textMuted,
      };

  static Color forConfidence(double value) {
    if (value >= 0.9) return severityMinor;
    if (value >= 0.7) return severityMajor;
    return severityCritical;
  }
}

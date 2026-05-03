import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/typography.dart';
import '../../tokens/spacing.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  String get _label => switch (status.toLowerCase()) {
        'in_progress' => 'In Progress',
        'open' => 'Open',
        'resolved' => 'Resolved',
        'closed' => 'closed',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
      ),
      child: Text(
        _label,
        style: AppText.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

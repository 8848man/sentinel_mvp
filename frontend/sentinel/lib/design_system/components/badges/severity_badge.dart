import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/typography.dart';
import '../../tokens/spacing.dart';

enum SeverityBadgeSize { small, large }

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({
    super.key,
    required this.severity,
    this.size = SeverityBadgeSize.small,
  });

  final String severity;
  final SeverityBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSeverity(severity);
    final label = severity.toUpperCase();
    final textStyle = size == SeverityBadgeSize.large
        ? AppText.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)
        : AppText.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
      ),
      child: Text(label, style: textStyle),
    );
  }
}

import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/typography.dart';
import '../../tokens/spacing.dart';
import '../badges/severity_badge.dart';
import '../badges/status_badge.dart';
import '../../tokens/view_mode.dart';

export '../../tokens/view_mode.dart';

class IncidentCard extends StatelessWidget {
  const IncidentCard({
    super.key,
    required this.incidentCode,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.viewMode,
    required this.onTap,
  });

  final String incidentCode;
  final String title;
  final String? description;
  final String severity;
  final String status;
  final DashboardViewMode viewMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border(
            left: BorderSide(color: AppColors.forSeverity(severity), width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(incidentCode, style: AppText.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: AppText.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(description!, style: AppText.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: AppSpacing.sm),
              viewMode == DashboardViewMode.status
                  ? SeverityBadge(severity: severity)
                  : StatusBadge(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

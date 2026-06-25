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
    this.createdAt,
  });

  final String incidentCode;
  final String title;
  final String? description;
  final String severity;
  final String status;
  final DashboardViewMode viewMode;
  final VoidCallback onTap;

  /// When provided, renders a compact elapsed-time chip (e.g. "23m", "2h",
  /// "3d") next to the severity/status badge — see
  /// sdd/frontend/10_3_responsive_dashboard.md for the format decision.
  final DateTime? createdAt;

  static String formatElapsed(DateTime createdAt, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

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
              Row(
                children: [
                  viewMode == DashboardViewMode.status
                      ? SeverityBadge(severity: severity)
                      : StatusBadge(status: status),
                  if (createdAt != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _ElapsedTimeChip(createdAt: createdAt!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElapsedTimeChip extends StatelessWidget {
  const _ElapsedTimeChip({required this.createdAt});
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
      ),
      child: Text(
        IncidentCard.formatElapsed(createdAt),
        style: AppText.labelSmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

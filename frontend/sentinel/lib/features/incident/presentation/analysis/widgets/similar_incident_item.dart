import 'package:flutter/material.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/similar_incident.dart';

class SimilarIncidentItem extends StatelessWidget {
  const SimilarIncidentItem({
    super.key,
    required this.similarIncident,
    required this.onViewDetails,
  });

  final SimilarIncident similarIncident;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final matchPct = (similarIncident.matchScore * 100).round();

    return GestureDetector(
      onTap: onViewDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${similarIncident.incidentCode} · $matchPct% match',
                style: AppText.bodySmall
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
            Text(
              'View Details',
              style: AppText.bodySmall.copyWith(color: AppColors.accentBlue),
            ),
          ],
        ),
      ),
    );
  }
}

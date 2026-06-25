import 'package:flutter/material.dart';
import '../../../../../design_system/design_system.dart';

/// Incident title + incident ID, rendered in the page content area.
///
/// Mobile-only (D13, sdd/frontend/10_2_responsive_strategy.md): the AppBar
/// is reserved for navigation/page-context, so this content lives here
/// instead of competing with it for width.
class IncidentContextHeader extends StatelessWidget {
  const IncidentContextHeader({
    super.key,
    required this.title,
    required this.incidentCode,
  });

  final String title;
  final String incidentCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(incidentCode,
              style: AppText.labelMedium.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/design_system.dart';
import '../../../core/models/incident.dart';

class StatusColumn extends StatelessWidget {
  const StatusColumn({
    super.key,
    required this.label,
    required this.color,
    required this.incidents,
  });

  final String label;
  final Color color;
  final List<IncidentModel> incidents;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              label,
              style: AppText.titleMedium.copyWith(color: color),
            ),
          ),
          Expanded(
            child: incidents.isEmpty
                ? Center(
                    child: Text('No incidents', style: AppText.bodySmall),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 0),
                    itemCount: incidents.length,
                    itemBuilder: (context, index) {
                      final incident = incidents[index];
                      return IncidentCard(
                        incidentCode: incident.incidentCode,
                        title: incident.title,
                        description: incident.description,
                        severity: incident.severity,
                        status: incident.status,
                        viewMode: DashboardViewMode.status,
                        onTap: () => context.go(
                            '/incidents/${incident.id}/workspace'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

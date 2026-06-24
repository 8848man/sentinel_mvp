import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../design_system/design_system.dart';
import '../../data/models/dashboard_incident_summary_model.dart';

class StatusColumn extends StatelessWidget {
  const StatusColumn({
    super.key,
    required this.label,
    required this.color,
    required this.incidents,
    this.sectioned = false,
  });

  final String label;
  final Color color;
  final List<DashboardIncidentSummaryModel> incidents;

  /// True below the dashboard sub-breakpoint (<900px): renders as a
  /// full-width labeled section (count in heading, no internal scroll)
  /// instead of a bounded-height board column.
  final bool sectioned;

  void _onTap(BuildContext context, DashboardIncidentSummaryModel incident) {
    context.go(incident.status == 'open'
        ? '/incidents/${incident.id}/analysis'
        : '/incidents/${incident.id}/workspace');
  }

  @override
  Widget build(BuildContext context) {
    if (sectioned) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label (${incidents.length})',
              style: AppText.titleMedium.copyWith(color: color)),
          const SizedBox(height: AppSpacing.sm),
          if (incidents.isEmpty)
            Text('No incidents', style: AppText.bodySmall)
          else
            ...incidents.map(
              (incident) => IncidentCard(
                incidentCode: incident.incidentCode,
                title: incident.title,
                description: incident.description,
                severity: incident.severity,
                status: incident.status,
                viewMode: DashboardViewMode.status,
                createdAt: incident.createdAt,
                onTap: () => _onTap(context, incident),
              ),
            ),
        ],
      );
    }

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
                        createdAt: incident.createdAt,
                        onTap: () => context.go(
                            incident.status == 'open'
                                ? '/incidents/${incident.id}/analysis'
                                : '/incidents/${incident.id}/workspace'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

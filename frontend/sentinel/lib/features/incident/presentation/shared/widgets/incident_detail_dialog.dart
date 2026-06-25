import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/incident.dart';
import '../providers/incident_detail_provider.dart';
import 'timeline_list.dart';

/// Opens the incident detail view as a bottom sheet on mobile (<768px) or a
/// centered dialog on tablet/desktop (sdd/frontend/10_6_responsive_auth_dialogs.md, D6).
void showIncidentDetailDialog(BuildContext context, String incidentId) {
  if (context.isMobileWidth) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _BottomSheetFrame(
          child: IncidentDetailDialog(
            incidentId: incidentId,
            stacked: true,
            scrollController: scrollController,
          ),
        ),
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (_) => IncidentDetailDialog(incidentId: incidentId, stacked: false),
  );
}

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class IncidentDetailDialog extends ConsumerWidget {
  const IncidentDetailDialog({
    super.key,
    required this.incidentId,
    this.stacked = false,
    this.scrollController,
  });

  final String incidentId;
  final bool stacked;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIncident = ref.watch(incidentDetailProvider(incidentId));

    final content = asyncIncident.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      ),
      error: (_, __) => Center(
        child: Text('Failed to load incident.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
      ),
      data: (incident) => _DialogContent(
        incident: incident,
        stacked: stacked,
        scrollController: scrollController,
      ),
    );

    if (stacked) return content;

    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.70,
        height: MediaQuery.of(context).size.height * 0.60,
        child: content,
      ),
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────────

class _DialogContent extends StatelessWidget {
  const _DialogContent({
    required this.incident,
    required this.stacked,
    this.scrollController,
  });

  final Incident incident;
  final bool stacked;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final body = stacked
        ? SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimelinePanel(incident: incident, stacked: true),
                const SizedBox(height: AppSpacing.lg),
                _SummaryPanel(incident: incident),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TwoPanelLayout(
              leftFlex: 40,
              rightFlex: 60,
              left: _TimelinePanel(incident: incident, stacked: false),
              right: _SummaryPanel(incident: incident),
            ),
          );

    return Column(
      children: [
        _DialogHeader(incident: incident),
        const Divider(color: AppColors.border, height: 1),
        Expanded(child: body),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.cardPadding, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${incident.incidentCode} — ${incident.title}',
              style: AppText.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(status: incident.status),
          const SizedBox(width: AppSpacing.xs),
          SeverityBadge(severity: incident.severity),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close,
                color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}

// ── Timeline panel ────────────────────────────────────────────────────────────

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.incident, required this.stacked});
  final Incident incident;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timeline', style: AppText.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TimelineList(events: incident.timeline, shrinkWrap: stacked),
      ],
    );
  }
}

// ── Summary panel ─────────────────────────────────────────────────────────────

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final selectedFlow = incident.selectedFixFlowId != null
        ? incident.fixFlows
            .where((f) => f.id == incident.selectedFixFlowId)
            .firstOrNull
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incident Summary', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            label: 'Root Cause',
            value: incident.rootCause ?? 'Not yet analyzed.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Impact',
            value: incident.description ?? '—',
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Fix Flow',
            value: selectedFlow?.title ?? 'None selected.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Memo',
              style: AppText.labelMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            incident.note?.content.isNotEmpty == true
                ? incident.note!.content
                : 'No notes recorded.',
            style: AppText.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                AppText.bodySmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: AppText.bodyMedium),
      ],
    );
  }
}

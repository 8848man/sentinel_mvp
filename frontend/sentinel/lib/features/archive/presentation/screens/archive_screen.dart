import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/design_system.dart';
import '../../../incident/domain/entities/incident.dart';
import '../../../incident/presentation/shared/widgets/incident_detail_dialog.dart';
import '../providers/archive_provider.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(archiveProvider);

    return SentinelScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onRefresh: () => ref.read(archiveProvider.notifier).reload()),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
              error: (_, __) => _ErrorView(
                onRetry: () => ref.read(archiveProvider.notifier).reload(),
              ),
              data: (incidents) {
                final table = incidents.isEmpty
                    ? _EmptyView()
                    : _ArchiveTable(incidents: incidents);
                // Pull-to-refresh mirrors Dashboard's mobile-gated affordance
                // (10_5_responsive_archive.md) — desktop/tablet stay untouched.
                if (!context.isMobileWidth) return table;
                return RefreshIndicator(
                  color: AppColors.accentBlue,
                  onRefresh: () => ref.read(archiveProvider.notifier).reload(),
                  child: table,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GhostButton(
          label: '← Dashboard',
          onPressed: () => context.go('/dashboard'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('Archive', style: AppText.headlineLarge),
        const Spacer(),
        GhostButton(label: 'Refresh', onPressed: onRefresh),
      ],
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _ArchiveTable extends StatelessWidget {
  const _ArchiveTable({required this.incidents});
  final List<Incident> incidents;

  @override
  Widget build(BuildContext context) {
    // <768px: card list (sdd/frontend/10_5_responsive_archive.md, D1).
    if (context.isMobileWidth) {
      return _ArchiveCardList(incidents: incidents);
    }

    final table = Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          _TableHeader(),
          const Divider(color: AppColors.border, height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: incidents.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, i) =>
                  _TableRow(incident: incidents[i]),
            ),
          ),
        ],
      ),
    );

    // 768-1199px: keep the table, horizontal-scroll fallback instead of a
    // redesign (D2). The table needs a definite width for its flex columns
    // once it's inside a horizontally-unbounded scroll view, and a definite
    // height carried over from the available space (the Expanded ListView
    // inside `table` needs a bounded height to lay out).
    if (context.isTabletWidth) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 900,
            height: constraints.maxHeight,
            child: table,
          ),
        ),
      );
    }

    return table;
  }
}

// ── Card list (<768px) ────────────────────────────────────────────────────────

class _ArchiveCardList extends StatelessWidget {
  const _ArchiveCardList({required this.incidents});
  final List<Incident> incidents;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: incidents.length,
      itemBuilder: (context, i) => _ArchiveCard(incident: incidents[i]),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = incident.resolvedAt != null
        ? DateFormat('MMM d, HH:mm').format(incident.resolvedAt!.toLocal())
        : '—';

    return InkWell(
      onTap: () => showIncidentDetailDialog(context, incident.id),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(incident.incidentCode,
                          style: AppText.monoBody
                              .copyWith(color: AppColors.accentBlue)),
                      const SizedBox(width: AppSpacing.xs),
                      StatusBadge(status: incident.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(incident.title,
                      style: AppText.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(resolvedLabel,
                          style: AppText.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SeverityBadge(severity: incident.severity),
                const SizedBox(height: AppSpacing.sm),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding, vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          _HeaderCell('Code', flex: 10),
          _HeaderCell('Title', flex: 30),
          _HeaderCell('Severity', flex: 10),
          _HeaderCell('Status', flex: 10),
          _HeaderCell('Resolved', flex: 14),
          _HeaderCell('Fix Flow', flex: 20),
          const Spacer(flex: 6),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex});
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: AppText.labelMedium.copyWith(color: AppColors.textMuted)),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = incident.resolvedAt != null
        ? DateFormat('MMM d, HH:mm').format(incident.resolvedAt!.toLocal())
        : '—';

    final selectedFlow = incident.selectedFixFlowId != null
        ? incident.fixFlows
            .where((f) => f.id == incident.selectedFixFlowId)
            .firstOrNull
        : null;

    return InkWell(
      onTap: () => showIncidentDetailDialog(context, incident.id),
      hoverColor: AppColors.bgHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding, vertical: AppSpacing.sm + 4),
        child: Row(
          children: [
            // Code
            Expanded(
              flex: 10,
              child: Text(incident.incidentCode,
                  style: AppText.monoBody
                      .copyWith(color: AppColors.accentBlue)),
            ),
            // Title
            Expanded(
              flex: 30,
              child: Text(
                incident.title,
                style: AppText.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Severity
            Expanded(
              flex: 10,
              child: SeverityBadge(severity: incident.severity),
            ),
            // Status
            Expanded(
              flex: 10,
              child: StatusBadge(status: incident.status),
            ),
            // Resolved at
            Expanded(
              flex: 14,
              child: Text(resolvedLabel,
                  style:
                      AppText.bodySmall.copyWith(color: AppColors.textPrimary)),
            ),
            // Fix flow title
            Expanded(
              flex: 20,
              child: Text(
                selectedFlow?.title ?? '—',
                style: AppText.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // View details link
            Expanded(
              flex: 6,
              child: Text(
                'View',
                style: AppText.link,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty + Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Center(
        child: Text(
          'No archived incidents.',
          style: AppText.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Failed to load archive.',
              style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}

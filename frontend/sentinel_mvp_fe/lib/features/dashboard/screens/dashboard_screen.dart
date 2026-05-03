import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../design_system/design_system.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/status_column.dart';
import '../widgets/severity_column.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final isStatusView = state.viewMode == DashboardViewMode.status;

    return SentinelScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(state: state, isStatusView: isStatusView),
          const SizedBox(height: AppSpacing.md),
          _ViewToggle(isStatusView: isStatusView),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accentBlue))
                : state.error != null
                    ? _ErrorView(
                        message: state.error!,
                        onRetry: () =>
                            ref.read(dashboardProvider.notifier).loadIncidents(),
                      )
                    : isStatusView
                        ? _StatusBoard(state: state)
                        : _SeverityBoard(state: state),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.isStatusView});

  final DashboardState state;
  final bool isStatusView;

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('HH:mm').format(state.utcTime) + ' UTC';
    final subtitle = isStatusView
        ? 'Incident Command Center'
        : 'Incident Prioritization by Severity';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: title + subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sentinel', style: AppText.headlineLarge),
            Text(subtitle, style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
          ],
        ),
        const Spacer(),

        // Right: Archive + Register + Clock
        Row(
          children: [
            SecondaryButton(
              label: 'Archive',
              onPressed: () => context.go('/archive'),
            ),
            const SizedBox(width: AppSpacing.sm),
            PrimaryButton(
              label: '+ Register Incident',
              onPressed: () => context.go('/incidents/new'),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(timeLabel,
                style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

// ── View Toggle ───────────────────────────────────────────────────────────────

class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.isStatusView});

  final bool isStatusView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _ToggleChip(
          label: 'Status View',
          isActive: isStatusView,
          onTap: () {
            if (!isStatusView) {
              ref.read(dashboardProvider.notifier).toggleViewMode();
            }
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        _ToggleChip(
          label: 'Severity View',
          isActive: !isStatusView,
          onTap: () {
            if (isStatusView) {
              ref.read(dashboardProvider.notifier).toggleViewMode();
            }
          },
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? AppColors.accentBlue : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
          color: isActive
              ? AppColors.accentBlue.withOpacity(0.08)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: AppText.labelMedium.copyWith(
            color: isActive ? AppColors.accentBlue : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Status Board ──────────────────────────────────────────────────────────────

class _StatusBoard extends StatelessWidget {
  const _StatusBoard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: StatusColumn(
            label: 'Open',
            color: AppColors.statusOpen,
            incidents: state.byStatus('open'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatusColumn(
            label: 'In Progress',
            color: AppColors.statusInProgress,
            incidents: state.byStatus('in_progress'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatusColumn(
            label: 'Resolved',
            color: AppColors.statusResolved,
            incidents: state.byStatus('resolved'),
          ),
        ),
      ],
    );
  }
}

// ── Severity Board ────────────────────────────────────────────────────────────

class _SeverityBoard extends StatelessWidget {
  const _SeverityBoard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SeverityColumn(
            label: 'Critical',
            color: AppColors.severityCritical,
            incidents: state.bySeverity('critical'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SeverityColumn(
            label: 'Major',
            color: AppColors.severityMajor,
            incidents: state.bySeverity('major'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SeverityColumn(
            label: 'Minor',
            color: AppColors.severityMinor,
            incidents: state.bySeverity('minor'),
          ),
        ),
      ],
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/incident.dart';
import '../providers/analysis_provider.dart';
import '../../workspace/providers/workspace_provider.dart';
import '../widgets/fix_flow_row.dart';
import '../widgets/similar_incident_item.dart';
import '../../shared/widgets/incident_detail_dialog.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisProvider(incidentId));
    final stacked = context.isMobileWidth;

    ref.listen<AnalysisState>(analysisProvider(incidentId), (prev, next) {
      if (prev?.navigateToWorkspace == false && next.navigateToWorkspace) {
        ref.invalidate(workspaceProvider(incidentId));
        context.go('/incidents/$incidentId/workspace');
      }
    });

    Widget body;
    if (state.isLoading) {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.accentBlue));
    } else if (state.error != null && state.incident == null) {
      body = _ErrorView(
        message: state.error!,
        onRetry: () => ref.invalidate(analysisProvider(incidentId)),
      );
    } else {
      final content = _Body(
        incident: state.incident!,
        isSelectingFlow: state.isSelectingFlow,
        stacked: stacked,
        onSelectFlow: (flowId) => ref
            .read(analysisProvider(incidentId).notifier)
            .selectFixFlow(flowId),
      );
      body = stacked ? SingleChildScrollView(child: content) : content;
    }

    return SentinelScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            incidentCode: state.incident?.incidentCode,
            title: state.incident?.title,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({this.incidentCode, this.title});

  final String? incidentCode;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GhostButton(
          label: '← Dashboard',
          onPressed: () => context.go('/dashboard'),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (incidentCode != null) ...[
          Text(incidentCode!, style: AppText.headlineLarge),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title ?? '',
              style: AppText.bodyMedium
                  .copyWith(color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          Text('AI Analysis', style: AppText.headlineLarge),
      ],
    );
  }
}

// ── Two-panel body ────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.incident,
    required this.isSelectingFlow,
    required this.onSelectFlow,
    required this.stacked,
  });

  final Incident incident;
  final bool isSelectingFlow;
  final void Function(String flowId) onSelectFlow;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final left = _LeftPanel(incident: incident, stacked: stacked);
    final right = _RightPanel(
      incident: incident,
      isSelectingFlow: isSelectingFlow,
      onSelectFlow: onSelectFlow,
      stacked: stacked,
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, const SizedBox(height: AppSpacing.md), right],
      );
    }

    return TwoPanelLayout(
      leftFlex: 28,
      rightFlex: 72,
      left: left,
      right: right,
    );
  }
}

// ── Left panel: root cause + confidence + similar incidents ───────────────────

class _LeftPanel extends StatefulWidget {
  const _LeftPanel({required this.incident, required this.stacked});
  final Incident incident;
  final bool stacked;

  @override
  State<_LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<_LeftPanel> {
  // Decision (Analysis Summary Expansion): conditionally collapsed.
  // Default state is *expanded* unless there's content to hide — avoids an
  // unnecessary collapse/expand affordance when the analysis is already
  // short. "More to reveal" = root cause text long enough to likely overflow
  // one line (~60 chars, a deterministic proxy for "would wrap"), or at
  // least one similar incident. See sdd/frontend/10_4_responsive_incident_flow.md.
  static const _rootCauseOverflowThreshold = 60;
  bool _expanded = false;

  bool get _hasMore {
    final rootCause = widget.incident.rootCause ?? '';
    return rootCause.length > _rootCauseOverflowThreshold ||
        widget.incident.similarIncidents.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    // Desktop/tablet: always fully expanded, unchanged from before — the
    // collapse behavior is mobile-only (D10: no behavior change off mobile).
    final showCollapsed = widget.stacked && !_expanded && _hasMore;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Likely Root Cause', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            incident.rootCause ?? 'Root cause analysis pending.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textMuted),
            maxLines: showCollapsed ? 1 : null,
            overflow: showCollapsed ? TextOverflow.ellipsis : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Confidence', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (incident.confidence != null) ...[
            Text(
              '${(incident.confidence! * 100).round()}%',
              style: AppText.displayMedium.copyWith(
                color: AppColors.forConfidence(incident.confidence!),
              ),
            ),
          ] else
            Text('—', style: AppText.displayMedium),
          const SizedBox(height: AppSpacing.lg),
          Text(
            showCollapsed
                ? 'Similar Incidents (${incident.similarIncidents.length})'
                : 'Similar Incidents',
            style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          if (!showCollapsed) ...[
            const SizedBox(height: AppSpacing.sm),
            if (incident.similarIncidents.isEmpty)
              Text('No similar incidents found.', style: AppText.bodySmall)
            else
              ...incident.similarIncidents.map(
                (si) => SimilarIncidentItem(
                  similarIncident: si,
                  onViewDetails: () =>
                      showIncidentDetailDialog(context, si.incidentId),
                ),
              ),
          ],
          if (widget.stacked && _hasMore) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Show less' : 'Show details',
                style: AppText.labelMedium.copyWith(color: AppColors.accentBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Right panel: fix flow list ────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.incident,
    required this.isSelectingFlow,
    required this.onSelectFlow,
    required this.stacked,
  });

  final Incident incident;
  final bool isSelectingFlow;
  final void Function(String flowId) onSelectFlow;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recommended Fix Flow',
                        style: AppText.headlineMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Selecting a fix flow will attach it to this incident and move it to In Progress.',
                      style: AppText.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isSelectingFlow) ...[
                const SizedBox(width: AppSpacing.md),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Fix flow rows ──────────────────────────────────
          if (incident.fixFlows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text('No fix flows available.',
                    style: AppText.bodyMedium
                        .copyWith(color: AppColors.textMuted)),
              ),
            )
          else
            _fixFlowList(),
        ],
      ),
    );
  }

  Widget _fixFlowList() {
    // Recommended = highest-confidence unattempted flow (Information
    // Hierarchy Change, sdd/frontend/10_4_responsive_incident_flow.md).
    final unattempted = incident.fixFlows.where((f) => !f.isAttempted);
    final recommendedId = unattempted.isEmpty
        ? null
        : unattempted.reduce((a, b) => b.confidence > a.confidence ? b : a).id;

    final list = ListView.builder(
      shrinkWrap: stacked,
      physics: stacked ? const NeverScrollableScrollPhysics() : null,
      itemCount: incident.fixFlows.length,
      itemBuilder: (_, i) {
        final flow = incident.fixFlows[i];
        return FixFlowRow(
          fixFlow: flow,
          index: i,
          isSelected: flow.id == incident.selectedFixFlowId,
          isLoading: isSelectingFlow,
          isRecommended: flow.id == recommendedId,
          onTap: () => onSelectFlow(flow.id),
        );
      },
    );
    return stacked ? list : Expanded(child: list);
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

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
          Text(message,
              style:
                  AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}

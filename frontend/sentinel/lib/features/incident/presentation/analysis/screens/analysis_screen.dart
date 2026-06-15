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

    ref.listen<AnalysisState>(analysisProvider(incidentId), (prev, next) {
      if (prev?.navigateToWorkspace == false && next.navigateToWorkspace) {
        ref.invalidate(workspaceProvider(incidentId));
        context.go('/incidents/$incidentId/workspace');
      }
    });

    return SentinelScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            incidentCode: state.incident?.incidentCode,
            title: state.incident?.title,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accentBlue))
                : state.error != null && state.incident == null
                    ? _ErrorView(
                        message: state.error!,
                        onRetry: () => ref
                            .invalidate(analysisProvider(incidentId)),
                      )
                    : _Body(
                        incident: state.incident!,
                        isSelectingFlow: state.isSelectingFlow,
                        onSelectFlow: (flowId) => ref
                            .read(analysisProvider(incidentId).notifier)
                            .selectFixFlow(flowId),
                      ),
          ),
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
  });

  final Incident incident;
  final bool isSelectingFlow;
  final void Function(String flowId) onSelectFlow;

  @override
  Widget build(BuildContext context) {
    return TwoPanelLayout(
      leftFlex: 28,
      rightFlex: 72,
      left: _LeftPanel(incident: incident),
      right: _RightPanel(
        incident: incident,
        isSelectingFlow: isSelectingFlow,
        onSelectFlow: onSelectFlow,
      ),
    );
  }
}

// ── Left panel: root cause + confidence + similar incidents ───────────────────

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.incident});
  final Incident incident;

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
          Text('Likely Root Cause', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            incident.rootCause ?? 'Root cause analysis pending.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textMuted),
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
          Text('Similar Incidents',
              style: AppText.bodySmall
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          if (incident.similarIncidents.isEmpty)
            Text('No similar incidents found.',
                style: AppText.bodySmall)
          else
            ...incident.similarIncidents.map(
              (si) => SimilarIncidentItem(
                similarIncident: si,
                onViewDetails: () => showIncidentDetailDialog(
                    context, si.incidentId),
              ),
            ),
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
  });

  final Incident incident;
  final bool isSelectingFlow;
  final void Function(String flowId) onSelectFlow;

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
          Expanded(
            child: incident.fixFlows.isEmpty
                ? Center(
                    child: Text('No fix flows available.',
                        style: AppText.bodyMedium
                            .copyWith(color: AppColors.textMuted)))
                : ListView.builder(
                    itemCount: incident.fixFlows.length,
                    itemBuilder: (_, i) {
                      final flow = incident.fixFlows[i];
                      return FixFlowRow(
                        fixFlow: flow,
                        index: i,
                        isSelected:
                            flow.id == incident.selectedFixFlowId,
                        isLoading: isSelectingFlow,
                        onTap: () => onSelectFlow(flow.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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

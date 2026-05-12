import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/fix_flow.dart';
import '../providers/workspace_provider.dart';
import '../widgets/checklist_item_widget.dart';
import '../../analysis/providers/analysis_provider.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider(widget.incidentId));

    // Sync controller text when incident first loads
    ref.listen<WorkspaceState>(workspaceProvider(widget.incidentId),
        (prev, next) {
      if (prev?.incident == null && next.incident != null) {
        _noteController.text = next.noteContent;
      }
      if (prev?.navigateToDashboard == false && next.navigateToDashboard) {
        context.go('/dashboard');
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
          if (state.error != null && state.incident != null)
            _InlineError(message: state.error!),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accentBlue))
                : state.error != null && state.incident == null
                    ? _ErrorView(
                        message: state.error!,
                        onRetry: () =>
                            ref.invalidate(workspaceProvider(widget.incidentId)),
                      )
                    : _Body(
                        incident: state.incident!,
                        noteController: _noteController,
                        togglingItemId: state.togglingItemId,
                        isResolving: state.isResolving,
                        isClosing: state.isClosing,
                        onToggleItem: (itemId, completed) => ref
                            .read(workspaceProvider(widget.incidentId).notifier)
                            .toggleChecklistItem(itemId, completed),
                        onNoteChanged: (content) => ref
                            .read(workspaceProvider(widget.incidentId).notifier)
                            .updateNote(content),
                        onResolve: () => ref
                            .read(workspaceProvider(widget.incidentId).notifier)
                            .resolve(),
                        onClose: () => ref
                            .read(workspaceProvider(widget.incidentId).notifier)
                            .close(),
                        onGoToAnalysis: () {
                          ref.invalidate(analysisProvider(widget.incidentId));
                          context.go('/incidents/${widget.incidentId}/analysis');
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
              style: AppText.bodyMedium.copyWith(color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          Text('Workspace', style: AppText.headlineLarge),
      ],
    );
  }
}

// ── Inline error banner ───────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.severityCritical.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(
            color: AppColors.severityCritical.withValues(alpha: 0.4)),
      ),
      child: Text(message,
          style: AppText.bodySmall
              .copyWith(color: AppColors.severityCritical)),
    );
  }
}

// ── Two-panel body ────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.incident,
    required this.noteController,
    required this.togglingItemId,
    required this.isResolving,
    required this.isClosing,
    required this.onToggleItem,
    required this.onNoteChanged,
    required this.onResolve,
    required this.onClose,
    required this.onGoToAnalysis,
  });

  final Incident incident;
  final TextEditingController noteController;
  final String? togglingItemId;
  final bool isResolving;
  final bool isClosing;
  final void Function(String itemId, bool completed) onToggleItem;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onResolve;
  final VoidCallback onClose;
  final VoidCallback onGoToAnalysis;

  @override
  Widget build(BuildContext context) {
    return TwoPanelLayout(
      leftFlex: 28,
      rightFlex: 72,
      left: _LeftPanel(incident: incident),
      right: _RightPanel(
        incident: incident,
        noteController: noteController,
        togglingItemId: togglingItemId,
        isResolving: isResolving,
        isClosing: isClosing,
        onToggleItem: onToggleItem,
        onNoteChanged: onNoteChanged,
        onResolve: onResolve,
        onClose: onClose,
        onGoToAnalysis: onGoToAnalysis,
      ),
    );
  }
}

// ── Left panel: incident meta + timeline ─────────────────────────────────────

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
          // Badges
          Row(
            children: [
              StatusBadge(status: incident.status),
              const SizedBox(width: AppSpacing.xs),
              SeverityBadge(severity: incident.severity),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Components
          if (incident.components.isNotEmpty) ...[
            Text('Components',
                style:
                    AppText.labelMedium.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: incident.components
                  .map((c) => _ComponentTag(label: c))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Root cause
          Text('Root Cause',
              style: AppText.labelMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            incident.rootCause ?? 'Not analyzed.',
            style: AppText.bodySmall.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Timeline
          Text('Timeline', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: incident.timeline.isEmpty
                ? Text('No events recorded.', style: AppText.bodySmall)
                : ListView.separated(
                    itemCount: incident.timeline.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (_, i) {
                      final event = incident.timeline[i];
                      final time = DateFormat('HH:mm')
                          .format(event.occurredAt.toLocal());
                      return Text(
                        '$time — ${event.event}',
                        style: AppText.bodySmall
                            .copyWith(color: AppColors.textPrimary),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Right panel: fix flow checklist + notes + actions ────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.incident,
    required this.noteController,
    required this.togglingItemId,
    required this.isResolving,
    required this.isClosing,
    required this.onToggleItem,
    required this.onNoteChanged,
    required this.onResolve,
    required this.onClose,
    required this.onGoToAnalysis,
  });

  final Incident incident;
  final TextEditingController noteController;
  final String? togglingItemId;
  final bool isResolving;
  final bool isClosing;
  final void Function(String itemId, bool completed) onToggleItem;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onResolve;
  final VoidCallback onClose;
  final VoidCallback onGoToAnalysis;

  @override
  Widget build(BuildContext context) {
    final selectedFlow = incident.selectedFixFlowId != null
        ? incident.fixFlows
            .where((f) => f.id == incident.selectedFixFlowId)
            .firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checklist card
        Expanded(
          flex: 6,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChecklistHeader(flow: selectedFlow),
                const SizedBox(height: AppSpacing.md),
                if (selectedFlow == null)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No fix flow selected.\nGo back to Analysis to select one.',
                        style: AppText.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: selectedFlow.checklistItems.length,
                      itemBuilder: (_, i) {
                        final item = selectedFlow.checklistItems[i];
                        return ChecklistItemWidget(
                          item: item,
                          totalSteps: selectedFlow.checklistItems.length,
                          isToggling: togglingItemId == item.id,
                          onTap: () => onToggleItem(item.id, item.isCompleted),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Notes + actions card
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Incident Notes', style: AppText.titleMedium),
                    ),
                    SecondaryButton(
                      label: '← Analysis',
                      onPressed: onGoToAnalysis,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (isResolving || isClosing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentBlue,
                        ),
                      )
                    else if (incident.status == 'resolved')
                      PrimaryButton(
                        label: 'Close Incident',
                        onPressed: onClose,
                      )
                    else
                      PrimaryButton(
                        label: 'Mark Resolved',
                        onPressed: onResolve,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: SentinelTextArea(
                    placeholder: 'Add notes, observations, or next steps…',
                    controller: noteController,
                    expands: true,
                    onChanged: onNoteChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Read-only component tag ───────────────────────────────────────────────────

class _ComponentTag extends StatelessWidget {
  const _ComponentTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(
            color: AppColors.accentBlue.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        color: AppColors.accentBlue.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        style:
            AppText.labelMedium.copyWith(color: AppColors.accentBlue),
      ),
    );
  }
}

// ── Checklist header ──────────────────────────────────────────────────────────

class _ChecklistHeader extends StatelessWidget {
  const _ChecklistHeader({required this.flow});
  final FixFlow? flow;

  @override
  Widget build(BuildContext context) {
    if (flow == null) {
      return Text('Fix Flow Checklist', style: AppText.headlineMedium);
    }

    final completed = flow!.checklistItems.where((c) => c.isCompleted).length;
    final total = flow!.checklistItems.length;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fix Flow Checklist', style: AppText.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                flow!.title,
                style:
                    AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Text(
          '$completed / $total completed',
          style: AppText.labelMedium,
        ),
      ],
    );
  }
}

// ── Full-page error ───────────────────────────────────────────────────────────

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/fix_flow.dart';
import '../../../domain/entities/timeline_event.dart';
import '../providers/workspace_provider.dart';
import '../widgets/checklist_item_widget.dart';
import '../../analysis/providers/analysis_provider.dart';
import '../../shared/widgets/timeline_list.dart';
import '../../shared/widgets/full_timeline_sheet.dart';
import '../../shared/widgets/incident_context_header.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  late final TextEditingController _noteController;
  late final FocusNode _noteFocusNode;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    // Drives the mobile-only collapsed-preview/expand-on-focus behavior for
    // Notes (10_4_responsive_incident_flow.md) — same controller throughout,
    // only the rendered height changes, so in-progress text and the existing
    // debounced auto-save in workspace_provider.dart are unaffected.
    _noteFocusNode = FocusNode();
    _noteFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider(widget.incidentId));
    final stacked = context.isMobileWidth;

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

    Widget body;
    if (state.isLoading) {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.accentBlue));
    } else if (state.error != null && state.incident == null) {
      body = _ErrorView(
        message: state.error!,
        onRetry: () => ref.invalidate(workspaceProvider(widget.incidentId)),
      );
    } else {
      final content = _Body(
        incident: state.incident!,
        noteController: _noteController,
        noteFocusNode: _noteFocusNode,
        togglingItemId: state.togglingItemId,
        isResolving: state.isResolving,
        isClosing: state.isClosing,
        isReopening: state.isReopening,
        stacked: stacked,
        onToggleItem: (itemId, completed) => ref
            .read(workspaceProvider(widget.incidentId).notifier)
            .toggleChecklistItem(itemId, completed),
        onNoteChanged: (content) => ref
            .read(workspaceProvider(widget.incidentId).notifier)
            .updateNote(content),
        onResolve: () =>
            ref.read(workspaceProvider(widget.incidentId).notifier).resolve(),
        onClose: () =>
            ref.read(workspaceProvider(widget.incidentId).notifier).close(),
        onReopen: () =>
            ref.read(workspaceProvider(widget.incidentId).notifier).reopen(),
        onGoToAnalysis: () {
          ref.invalidate(analysisProvider(widget.incidentId));
          context.go('/incidents/${widget.incidentId}/analysis');
        },
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
          if (state.error != null && state.incident != null)
            _InlineError(message: state.error!),
          Expanded(child: body),
          // Mobile-only sticky action bar — Layout Change (D11): same
          // actions/order as the inline row it replaces, just always
          // reachable without scrolling (10_4_responsive_incident_flow.md).
          if (stacked && state.incident != null)
            StickyActionBar(
              children: [
                _ActionButtons(
                  isResolving: state.isResolving,
                  isClosing: state.isClosing,
                  isReopening: state.isReopening,
                  status: state.incident!.status,
                  onResolve: () => ref
                      .read(workspaceProvider(widget.incidentId).notifier)
                      .resolve(),
                  onClose: () => ref
                      .read(workspaceProvider(widget.incidentId).notifier)
                      .close(),
                  onReopen: () => ref
                      .read(workspaceProvider(widget.incidentId).notifier)
                      .reopen(),
                  onGoToAnalysis: () {
                    ref.invalidate(analysisProvider(widget.incidentId));
                    context.go('/incidents/${widget.incidentId}/analysis');
                  },
                  stacked: true,
                ),
              ],
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
    // Mobile AppBar Hierarchy (D13, sdd/frontend/10_2_responsive_strategy.md):
    // the header is navigation/page-context only on mobile — incident code
    // and title render in the page content instead (see _LeftPanel).
    if (context.isMobileWidth) {
      return Row(
        children: [
          GhostButton(
            label: '← Dashboard',
            onPressed: () => context.go('/dashboard'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Workspace', style: AppText.headlineLarge),
        ],
      );
    }

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
    required this.noteFocusNode,
    required this.togglingItemId,
    required this.isResolving,
    required this.isClosing,
    required this.isReopening,
    required this.onToggleItem,
    required this.onNoteChanged,
    required this.onResolve,
    required this.onClose,
    required this.onReopen,
    required this.onGoToAnalysis,
    required this.stacked,
  });

  final Incident incident;
  final TextEditingController noteController;
  final FocusNode noteFocusNode;
  final String? togglingItemId;
  final bool isResolving;
  final bool isClosing;
  final bool isReopening;
  final void Function(String itemId, bool completed) onToggleItem;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onResolve;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onGoToAnalysis;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final left = _LeftPanel(incident: incident, stacked: stacked);
    final right = _RightPanel(
      incident: incident,
      noteController: noteController,
      noteFocusNode: noteFocusNode,
      togglingItemId: togglingItemId,
      isResolving: isResolving,
      isClosing: isClosing,
      isReopening: isReopening,
      onToggleItem: onToggleItem,
      onNoteChanged: onNoteChanged,
      onResolve: onResolve,
      onClose: onClose,
      onReopen: onReopen,
      onGoToAnalysis: onGoToAnalysis,
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

// ── Left panel: incident meta + timeline ─────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.incident, required this.stacked});
  final Incident incident;
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
          // Incident title + ID, moved here from the header on mobile (D13).
          if (stacked)
            IncidentContextHeader(
              title: incident.title,
              incidentCode: incident.incidentCode,
            ),
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
          // Timeline — exactly the 3 most recent events on mobile (Decision:
          // Timeline Summary Count, 10_4_responsive_incident_flow.md); full
          // history one tap away via the existing bottom-sheet pattern.
          // Desktop/tablet show the full list inline, unchanged.
          Text('Timeline', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TimelineList(events: _displayedEvents, shrinkWrap: stacked),
          if (stacked && incident.timeline.length > _mobileTimelineCount) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => showFullTimelineSheet(context, incident.id),
              child: Text(
                'View full timeline (${incident.timeline.length})',
                style: AppText.labelMedium.copyWith(color: AppColors.accentBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _mobileTimelineCount = 3;

  List<TimelineEvent> get _displayedEvents {
    if (!stacked || incident.timeline.length <= _mobileTimelineCount) {
      return incident.timeline;
    }
    return incident.timeline.sublist(incident.timeline.length - _mobileTimelineCount);
  }
}

// ── Right panel: fix flow checklist + notes + actions ────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.incident,
    required this.noteController,
    required this.noteFocusNode,
    required this.togglingItemId,
    required this.isResolving,
    required this.isClosing,
    required this.isReopening,
    required this.onToggleItem,
    required this.onNoteChanged,
    required this.onResolve,
    required this.onClose,
    required this.onReopen,
    required this.onGoToAnalysis,
    required this.stacked,
  });

  final Incident incident;
  final TextEditingController noteController;
  final FocusNode noteFocusNode;
  final String? togglingItemId;
  final bool isResolving;
  final bool isClosing;
  final bool isReopening;
  final void Function(String itemId, bool completed) onToggleItem;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onResolve;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onGoToAnalysis;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final selectedFlow = incident.selectedFixFlowId != null
        ? incident.fixFlows
            .where((f) => f.id == incident.selectedFixFlowId)
            .firstOrNull
        : null;

    final checklistBody = selectedFlow == null
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                'No fix flow selected.\nGo back to Analysis to select one.',
                style: AppText.bodyMedium.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView.builder(
            shrinkWrap: stacked,
            physics: stacked ? const NeverScrollableScrollPhysics() : null,
            itemCount: selectedFlow.checklistItems.length,
            itemBuilder: (_, i) {
              final item = selectedFlow.checklistItems[i];
              return ChecklistItemWidget(
                item: item,
                totalSteps: selectedFlow.checklistItems.length,
                isToggling: togglingItemId == item.id,
                readOnly: incident.status == 'resolved',
                onTap: () => onToggleItem(item.id, item.isCompleted),
              );
            },
          );

    final checklistCard = Container(
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
          stacked ? checklistBody : Expanded(child: checklistBody),
        ],
      ),
    );

    // Notes: collapsed fixed-height preview when unfocused, expands on focus
    // (Layout Change — 10_4_responsive_incident_flow.md). Same controller
    // throughout; only minLines/maxLines change, so no text loss and the
    // existing debounced auto-save is unaffected. Desktop/tablet unchanged
    // (always `expands: true` inside its own Expanded, as before).
    final notesCollapsed = stacked && !noteFocusNode.hasFocus;
    final notesField = SentinelTextArea(
      placeholder: 'Add notes, observations, or next steps…',
      controller: noteController,
      focusNode: noteFocusNode,
      expands: !stacked,
      minLines: stacked ? (notesCollapsed ? 3 : 8) : 6,
      maxLines: stacked ? (notesCollapsed ? 3 : 14) : 20,
      onChanged: onNoteChanged,
    );

    final notesCard = Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stacked)
            Text('Incident Notes', style: AppText.titleMedium)
          else
            Row(
              children: [
                Expanded(
                    child:
                        Text('Incident Notes', style: AppText.titleMedium)),
                _ActionButtons(
                  isResolving: isResolving,
                  isClosing: isClosing,
                  isReopening: isReopening,
                  status: incident.status,
                  onResolve: onResolve,
                  onClose: onClose,
                  onReopen: onReopen,
                  onGoToAnalysis: onGoToAnalysis,
                  stacked: false,
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          stacked ? notesField : Expanded(child: notesField),
        ],
      ),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          checklistCard,
          const SizedBox(height: AppSpacing.md),
          notesCard,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: checklistCard),
        const SizedBox(height: AppSpacing.md),
        Expanded(flex: 4, child: notesCard),
      ],
    );
  }
}

// ── Action buttons (full-width stacked on mobile, inline row otherwise) ───────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isResolving,
    required this.isClosing,
    required this.isReopening,
    required this.status,
    required this.onResolve,
    required this.onClose,
    required this.onReopen,
    required this.onGoToAnalysis,
    required this.stacked,
  });

  final bool isResolving;
  final bool isClosing;
  final bool isReopening;
  final String status;
  final VoidCallback onResolve;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onGoToAnalysis;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (isResolving || isClosing || isReopening) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue),
        ),
      );
    }

    final buttons = status == 'resolved'
        ? [
            SecondaryButton(label: 'Mark In Progress', onPressed: onReopen),
            PrimaryButton(label: 'Close Incident', onPressed: onClose),
          ]
        : [PrimaryButton(label: 'Mark Resolved', onPressed: onResolve)];

    final backButton = SecondaryButton(label: '← Analysis', onPressed: onGoToAnalysis);

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in buttons) ...[b, const SizedBox(height: AppSpacing.sm)],
          backButton,
        ],
      );
    }

    return Row(
      children: [
        backButton,
        const SizedBox(width: AppSpacing.sm),
        for (final b in buttons) ...[b, const SizedBox(width: AppSpacing.sm)],
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

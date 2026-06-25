import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../design_system/design_system.dart';
import '../../workspace/providers/workspace_provider.dart';
import 'timeline_list.dart';

/// Full timeline as a bottom sheet — reuses the exact `DraggableScrollableSheet`
/// composition already shipped in `incident_detail_dialog.dart`, not a new
/// pattern. Overlay on the current screen, not a route
/// (sdd/frontend/10_7_responsive_mobile_ia.md).
void showFullTimelineSheet(BuildContext context, String incidentId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _SheetFrame(
        child: _FullTimelineContent(
          incidentId: incidentId,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
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

class _FullTimelineContent extends ConsumerStatefulWidget {
  const _FullTimelineContent({
    required this.incidentId,
    required this.scrollController,
  });

  final String incidentId;
  final ScrollController scrollController;

  @override
  ConsumerState<_FullTimelineContent> createState() => _FullTimelineContentState();
}

class _FullTimelineContentState extends ConsumerState<_FullTimelineContent> {
  bool _didInitialScroll = false;

  // Decision (Timeline Summary Count / scale validation, 10_4): open already
  // scrolled to the most recent event rather than the oldest — chronological
  // order is unchanged, only the initial viewport position.
  void _scrollToMostRecentOnce() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.hasClients) return;
      widget.scrollController.jumpTo(widget.scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Live state — the same provider Workspace already watches, not a
    // frozen snapshot — so events arriving while the sheet is open appear
    // without reopening it (10_4_responsive_incident_flow.md).
    final state = ref.watch(workspaceProvider(widget.incidentId));
    final events = state.incident?.timeline ?? const [];

    if (events.isNotEmpty) _scrollToMostRecentOnce();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          child: Row(
            children: [
              Expanded(child: Text('Timeline', style: AppText.titleMedium)),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TimelineList(events: events, shrinkWrap: true, groupByHour: true),
          ),
        ),
      ],
    );
  }
}

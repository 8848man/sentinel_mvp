import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/timeline_event.dart';

/// Dot + connecting-line timeline, applied at all breakpoints
/// (sdd/frontend/10_2_responsive_strategy.md, D7).
///
/// [shrinkWrap] must be true when this widget sits inside an already
/// scrollable column (e.g. a stacked mobile layout) to avoid requiring
/// unbounded height from an `Expanded` ancestor.
class TimelineList extends StatelessWidget {
  const TimelineList({
    super.key,
    required this.events,
    this.shrinkWrap = false,
    this.controller,
    this.groupByHour = false,
  });

  final List<TimelineEvent> events;
  final bool shrinkWrap;

  /// External scroll controller (e.g. a `DraggableScrollableSheet`'s) — only
  /// meaningful when [shrinkWrap] is false. Do not set both this and
  /// [shrinkWrap]; see full_timeline_sheet.dart for the composition that
  /// needs this (outer scrollable owns the controller, this list stays
  /// `shrinkWrap: true` instead) vs. a standalone, directly-scrollable use.
  final ScrollController? controller;

  /// Above ~20 events, insert non-interactive hour-group separator rows for
  /// scanability (sdd/frontend/10_4_responsive_incident_flow.md, Full
  /// Timeline requirements). No-op below that threshold.
  final bool groupByHour;

  static const _groupingThreshold = 20;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text('No events recorded.', style: AppText.bodySmall);
    }

    final useGrouping = groupByHour && events.length > _groupingThreshold;
    final rows = useGrouping ? _buildGroupedRows() : null;

    final list = ListView.builder(
      shrinkWrap: shrinkWrap,
      controller: shrinkWrap ? null : controller,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: useGrouping ? rows!.length : events.length,
      itemBuilder: (_, i) {
        if (useGrouping) return rows![i];

        final event = events[i];
        final isLast = i == events.length - 1;
        final time = DateFormat('HH:mm').format(event.occurredAt.toLocal());
        return _TimelineRow(time: time, label: event.event, isLast: isLast);
      },
    );

    return shrinkWrap ? list : Expanded(child: list);
  }

  List<Widget> _buildGroupedRows() {
    final rows = <Widget>[];
    String? lastHourLabel;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final occurred = event.occurredAt.toLocal();
      final hourLabel = DateFormat('MMM d, HH:00').format(occurred);
      if (hourLabel != lastHourLabel) {
        rows.add(_HourSeparator(label: hourLabel));
        lastHourLabel = hourLabel;
      }
      final isLast = i == events.length - 1;
      final time = DateFormat('HH:mm').format(occurred);
      rows.add(_TimelineRow(time: time, label: event.event, isLast: isLast));
    }
    return rows;
  }
}

class _HourSeparator extends StatelessWidget {
  const _HourSeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppText.labelSmall.copyWith(
          color: AppColors.textFaint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.time,
    required this.label,
    required this.isLast,
  });

  final String time;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppColors.severityMinor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: 22,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '$time — $label',
              style: AppText.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../tokens/breakpoints.dart';
import '../../tokens/spacing.dart';

/// Side-by-side panel layout used by Registration/Analysis/Workspace and the
/// Incident Detail Dialog.
///
/// Callers gate the mobile breakpoint themselves and swap to a stacked
/// `Column` below 768px (panel content needs to switch internal scrollables
/// to shrinkWrap lists in that mode — see sdd/frontend/10_4 and 10_6). This
/// widget only owns the row-mode flex ratio: [leftFlex]/[rightFlex] apply
/// >=1200px (desktop), [tabletLeftFlex]/[tabletRightFlex] apply for any
/// narrower width it's given (768-1199px in practice, since callers never
/// render it below 768px) — see 10_2_responsive_strategy.md, D3.
class TwoPanelLayout extends StatelessWidget {
  const TwoPanelLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 28,
    this.rightFlex = 72,
    this.tabletLeftFlex = 38,
    this.tabletRightFlex = 62,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final int tabletLeftFlex;
  final int tabletRightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = AppBreakpoints.isDesktop(constraints.maxWidth);
        final effectiveLeftFlex = isDesktop ? leftFlex : tabletLeftFlex;
        final effectiveRightFlex = isDesktop ? rightFlex : tabletRightFlex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: effectiveLeftFlex, child: left),
            const SizedBox(width: AppSpacing.panelGap),
            Expanded(flex: effectiveRightFlex, child: right),
          ],
        );
      },
    );
  }
}

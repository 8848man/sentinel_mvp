import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';

/// Bottom-anchored action container, always visible regardless of scroll
/// position. Layout Change only (10_2_responsive_strategy.md, D11) — same
/// actions, same order as the inline row it replaces; reused by Registration's
/// submit button and Workspace's resolve/close/back row.
///
/// Place as a non-`Expanded` sibling *below* the screen's scrollable content
/// in the outer `Column` (like `Scaffold.bottomNavigationBar`) — it reserves
/// its own space rather than overlaying content, so there's no risk of
/// hiding the last scrollable item underneath it.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final child in children) ...[
              child,
              if (child != children.last) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

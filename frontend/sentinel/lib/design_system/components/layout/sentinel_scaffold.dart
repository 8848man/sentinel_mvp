import 'package:flutter/material.dart';
import '../../tokens/breakpoints.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';

/// Standard page wrapper that enforces consistent background and padding.
///
/// Padding is breakpoint-aware by default (32px tablet/desktop, 16px mobile —
/// see sdd/frontend/10_2_responsive_strategy.md, D2). Pass [padding]
/// explicitly to opt out (e.g. auth screens that center their own card).
class SentinelScaffold extends StatelessWidget {
  const SentinelScaffold({
    super.key,
    required this.body,
    this.padding,
    this.floatingActionButton,
  });

  final Widget body;
  final EdgeInsetsGeometry? padding;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ??
        EdgeInsets.all(
          context.isMobileWidth ? AppSpacing.md : AppSpacing.pagePadding,
        );

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      floatingActionButton: floatingActionButton,
      body: Padding(
        padding: resolvedPadding,
        child: body,
      ),
    );
  }
}

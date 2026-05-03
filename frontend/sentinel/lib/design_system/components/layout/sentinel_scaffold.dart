import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';

/// Standard page wrapper that enforces consistent background and padding.
class SentinelScaffold extends StatelessWidget {
  const SentinelScaffold({
    super.key,
    required this.body,
    this.padding = const EdgeInsets.all(AppSpacing.pagePadding),
  });

  final Widget body;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Padding(
        padding: padding,
        child: body,
      ),
    );
  }
}

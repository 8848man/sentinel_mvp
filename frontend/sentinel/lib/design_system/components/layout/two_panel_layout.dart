import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';

class TwoPanelLayout extends StatelessWidget {
  const TwoPanelLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 28,
    this.rightFlex = 72,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: AppSpacing.panelGap),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}

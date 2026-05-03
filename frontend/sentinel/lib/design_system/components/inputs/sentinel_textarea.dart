import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/typography.dart';
import '../../tokens/spacing.dart';

class SentinelTextArea extends StatelessWidget {
  const SentinelTextArea({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.minLines = 6,
    this.maxLines = 20,
    this.onChanged,
    this.monospace = false,
    this.expands = false,
  });

  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool monospace;
  // When true, fills parent vertically. Must be inside a bounded parent (e.g. Expanded).
  final bool expands;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      minLines: expands ? null : minLines,
      maxLines: expands ? null : maxLines,
      expands: expands,
      onChanged: onChanged,
      style: monospace ? AppText.monoBody : AppText.bodyMedium,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: AppText.bodySmall.copyWith(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.5),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppText.labelMedium),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (expands) Expanded(child: field) else field,
      ],
    );
  }
}

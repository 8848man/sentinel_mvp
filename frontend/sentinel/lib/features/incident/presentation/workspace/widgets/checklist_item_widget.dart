import 'package:flutter/material.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/checklist_item.dart';

class ChecklistItemWidget extends StatelessWidget {
  const ChecklistItemWidget({
    super.key,
    required this.item,
    required this.totalSteps,
    required this.isToggling,
    required this.onTap,
    this.readOnly = false,
  });

  final ChecklistItem item;
  final int totalSteps;
  final bool isToggling;
  final VoidCallback onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final completed = item.isCompleted;

    return Opacity(
      opacity: readOnly ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: (isToggling || readOnly) ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: completed
                ? AppColors.bgInput.withValues(alpha: 0.5)
                : AppColors.bgInput,
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            border: Border.all(
              color: completed ? AppColors.border : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${item.stepNumber}/$totalSteps',
                  style: AppText.labelSmall,
                ),
              ),
              if (isToggling)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentBlue,
                  ),
                )
              else
                Icon(
                  completed ? Icons.check_circle : Icons.check_circle_outline,
                  size: 18,
                  color: completed ? AppColors.severityMinor : AppColors.textFaint,
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.description,
                  style: AppText.bodyMedium.copyWith(
                    color: completed ? AppColors.textMuted : AppColors.textPrimary,
                    decoration:
                        completed ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

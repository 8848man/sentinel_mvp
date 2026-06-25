import 'package:flutter/material.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/fix_flow.dart';

class FixFlowRow extends StatelessWidget {
  const FixFlowRow({
    super.key,
    required this.fixFlow,
    required this.index,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
    this.isRecommended = false,
  });

  final FixFlow fixFlow;
  final int index;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  /// Highest-confidence unattempted flow (Information Hierarchy Change —
  /// sdd/frontend/10_4_responsive_incident_flow.md). Visually distinct from
  /// [isSelected] (blue border) and the per-row "Attempted" indicator: this
  /// badge is the only green-colored row treatment.
  final bool isRecommended;

  Widget _recommendedBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.severityMinor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
      ),
      child: Text(
        'RECOMMENDED',
        style: AppText.labelSmall.copyWith(
          color: AppColors.severityMinor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _confidenceText(Color confidenceColor, int confidencePct) {
    return Text(
      '$confidencePct% confidence',
      style: AppText.labelMedium.copyWith(color: confidenceColor),
    );
  }

  Widget _attemptedIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          fixFlow.isAttempted ? Icons.check_circle : Icons.check_circle_outline,
          size: 14,
          color: fixFlow.isAttempted ? AppColors.accentBlue : AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          fixFlow.isAttempted ? 'Attempted' : 'Not attempted',
          style: AppText.labelSmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        fixFlow.checklistItems.where((c) => c.isCompleted).length;
    final total = fixFlow.checklistItems.length;
    final confidenceColor = AppColors.forConfidence(fixFlow.confidence);
    final confidencePct = (fixFlow.confidence * 100).round();
    final progressText = total > 0
        ? 'Progress: $completed / $total completed'
        : 'No steps defined';
    final isMobile = context.isMobileWidth;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: isSelected
              ? Border.all(color: AppColors.accentBlue, width: 1.5)
              : Border.all(color: AppColors.border),
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fix Flow Name gets the full row to itself so it never
                  // competes with Recommended/Confidence for width.
                  Text(
                    '${index + 1}. ${fixFlow.title}',
                    style: AppText.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(progressText, style: AppText.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isRecommended) _recommendedBadge(),
                      _confidenceText(confidenceColor, confidencePct),
                      _attemptedIndicator(),
                    ],
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: title + progress ───────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${index + 1}. ${fixFlow.title}',
                                style: AppText.bodyMedium,
                              ),
                            ),
                            if (isRecommended) ...[
                              const SizedBox(width: AppSpacing.xs),
                              _recommendedBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(progressText, style: AppText.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // ── Right: confidence + attempted ────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _confidenceText(confidenceColor, confidencePct),
                      const SizedBox(height: AppSpacing.xs),
                      _attemptedIndicator(),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

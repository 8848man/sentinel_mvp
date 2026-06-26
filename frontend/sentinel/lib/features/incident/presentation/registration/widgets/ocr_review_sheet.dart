import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/ocr_extraction_result.dart';
import '../providers/ocr_flow_provider.dart';

/// Review Screen for OCR-assisted Raw Log extraction
/// (sdd/context/04_1_ocr_log_extraction.md, OCR4).
///
/// Bottom sheet on mobile (<768px), centered dialog otherwise — reuses the
/// same D6 presentation split as `incident_detail_dialog.dart`
/// (sdd/frontend/10_6_responsive_auth_dialogs.md).
void showOcrReviewSheet(
  BuildContext context,
  OcrExtractionResult result, {
  required ValueChanged<String> onInsert,
}) {
  if (context.isMobileWidth) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _BottomSheetFrame(
          child: _OcrReviewContent(
            result: result,
            stacked: true,
            scrollController: scrollController,
            onInsert: onInsert,
          ),
        ),
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.70,
        height: MediaQuery.of(context).size.height * 0.70,
        child: _OcrReviewContent(
          result: result,
          stacked: false,
          onInsert: onInsert,
        ),
      ),
    ),
  );
}

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
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

class _OcrReviewContent extends ConsumerWidget {
  const _OcrReviewContent({
    required this.result,
    required this.stacked,
    required this.onInsert,
    this.scrollController,
  });

  final OcrExtractionResult result;
  final bool stacked;
  final ValueChanged<String> onInsert;
  final ScrollController? scrollController;

  void _cancel(BuildContext context, WidgetRef ref) {
    ref.read(ocrFlowProvider.notifier).cancel();
    Navigator.of(context).pop();
  }

  void _use(BuildContext context, WidgetRef ref, String text) {
    onInsert(text);
    ref.read(ocrFlowProvider.notifier).completeInsertion();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanupOk =
        result.cleanupStatus == OcrCleanupStatus.ok && result.cleanedText != null;

    final blocks = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TextBlock(label: 'OCR Original', text: result.ocrText),
              const SizedBox(height: AppSpacing.lg),
              _CleanedBlock(result: result),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _TextBlock(label: 'OCR Original', text: result.ocrText)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _CleanedBlock(result: result)),
            ],
          );

    final body = SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: blocks,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text('Review Extracted Log', style: AppText.titleMedium),
              ),
              GestureDetector(
                onTap: () => _cancel(context, ref),
                child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),
        Expanded(child: body),
        const Divider(color: AppColors.border, height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cleanupOk)
                      PrimaryButton(
                        label: 'Use Cleaned Log',
                        onPressed: () => _use(context, ref, result.cleanedText!),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      label: 'Use OCR Original',
                      onPressed: () => _use(context, ref, result.ocrText),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GhostButton(
                        label: 'Cancel', onPressed: () => _cancel(context, ref)),
                  ],
                )
              : Row(
                  children: [
                    GhostButton(
                        label: 'Cancel', onPressed: () => _cancel(context, ref)),
                    const Spacer(),
                    SecondaryButton(
                      label: 'Use OCR Original',
                      onPressed: () => _use(context, ref, result.ocrText),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (cleanupOk)
                      PrimaryButton(
                        label: 'Use Cleaned Log',
                        onPressed: () => _use(context, ref, result.cleanedText!),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.labelMedium.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            border: Border.all(color: AppColors.border),
          ),
          // Soft-wrapping monospace text — no horizontal scroll, no overflow
          // on narrow viewports (compatibility review, P3).
          child: Text(text, style: AppText.monoBody, softWrap: true),
        ),
      ],
    );
  }
}

class _CleanedBlock extends StatelessWidget {
  const _CleanedBlock({required this.result});
  final OcrExtractionResult result;

  @override
  Widget build(BuildContext context) {
    if (result.cleanupStatus == OcrCleanupStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cleaned Log',
              style: AppText.labelMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'AI cleanup unavailable, showing OCR output only.',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      );
    }

    return _TextBlock(label: 'Cleaned Log', text: result.cleanedText ?? '');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../design_system/design_system.dart';
import '../providers/ocr_flow_provider.dart';
import '../providers/registration_form_provider.dart';
import '../providers/registration_metadata_provider.dart';
import 'architecture_component_list.dart';
import 'ocr_picker_action.dart';
import 'ocr_review_sheet.dart';

class MetadataPanel extends ConsumerStatefulWidget {
  const MetadataPanel({super.key, required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  ConsumerState<MetadataPanel> createState() => _MetadataPanelState();
}

class _MetadataPanelState extends ConsumerState<MetadataPanel> {
  late final TextEditingController _titleController;
  late final TextEditingController _logController;

  @override
  void initState() {
    super.initState();
    final form = ref.read(registrationFormProvider);
    _titleController = TextEditingController(text: form.title);
    _logController = TextEditingController(text: form.rawLog);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _logController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _logController.text = text;
    ref.read(registrationFormProvider.notifier).updateRawLog(text);
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(registrationFormProvider);
    final isAnalyzing = ref.watch(
      registrationMetadataProvider.select((s) => s.isAnalyzing),
    );
    final isMobile = context.isMobileWidth;

    // Sync title controller when metadata auto-populates
    ref.listen<RegistrationFormState>(registrationFormProvider, (prev, next) {
      if (prev?.title != next.title && _titleController.text != next.title) {
        _titleController.text = next.title;
        _titleController.selection =
            TextSelection.collapsed(offset: next.title.length);
      }
    });

    // Opens the Review Screen the moment OCR + cleanup finish successfully
    // (OCR4) — a one-shot side effect, not a rebuild-driven widget, so it
    // doesn't reopen if the sheet is dismissed and the state hasn't changed.
    ref.listen<OcrFlowState>(ocrFlowProvider, (prev, next) {
      if (prev?.stage != OcrFlowStage.reviewing &&
          next.stage == OcrFlowStage.reviewing &&
          next.result != null) {
        showOcrReviewSheet(
          context,
          next.result!,
          onInsert: (text) {
            _logController.text = text;
            ref.read(registrationFormProvider.notifier).updateRawLog(text);
          },
        );
      }
    });

    final ocrFlow = ref.watch(ocrFlowProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Text('Incident Metadata', style: AppText.titleMedium),
                const Spacer(),
                if (isAnalyzing) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Analyzing...',
                    style: AppText.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          // ── Scrollable fields ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SentinelInput(
                    label: 'Title',
                    placeholder: 'Incident title',
                    controller: _titleController,
                    onChanged: (v) => ref
                        .read(registrationFormProvider.notifier)
                        .updateTitle(v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  isMobile
                      ? _SeverityChips(
                          value: formState.severity,
                          onChanged: (v) => ref
                              .read(registrationFormProvider.notifier)
                              .updateSeverity(v),
                        )
                      : SentinelDropdown(
                          label: 'Severity',
                          value: formState.severity,
                          items: const ['critical', 'major', 'minor'],
                          onChanged: (v) {
                            if (v != null) {
                              ref
                                  .read(registrationFormProvider.notifier)
                                  .updateSeverity(v);
                            }
                          },
                        ),
                  const SizedBox(height: AppSpacing.md),
                  const ArchitectureComponentList(),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text('Raw Log / Description',
                            style: AppText.labelMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                      // Wrap (not Row) so these actions reflow onto a second
                      // line instead of overflowing horizontally on narrow
                      // viewports (compatibility review, P3).
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _pasteFromClipboard,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.content_paste,
                                      size: 14, color: AppColors.accentBlue),
                                  const SizedBox(width: 4),
                                  Text('Paste',
                                      style: AppText.labelSmall
                                          .copyWith(color: AppColors.accentBlue)),
                                ],
                              ),
                            ),
                          ),
                          const OcrPickerAction(),
                        ],
                      ),
                    ],
                  ),
                  if (ocrFlow.stage == OcrFlowStage.uploading) ...[
                    const SizedBox(height: AppSpacing.xs),
                    // Row + Expanded (not a fixed-width Text) so the
                    // time-based message wraps within the available width
                    // instead of overflowing on narrow/mobile viewports
                    // (R4 mobile compatibility).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accentBlue),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ocrFlow.processingMessage.headline,
                                style: AppText.bodySmall
                                    .copyWith(color: AppColors.textMuted),
                                softWrap: true,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ocrFlow.processingMessage.subtext,
                                style: AppText.labelSmall
                                    .copyWith(color: AppColors.textMuted),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (ocrFlow.stage == OcrFlowStage.error &&
                      ocrFlow.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    GestureDetector(
                      onTap: () => ref.read(ocrFlowProvider.notifier).cancel(),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 14, color: AppColors.severityCritical),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(ocrFlow.errorMessage!,
                                style: AppText.bodySmall
                                    .copyWith(color: AppColors.severityCritical)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  SentinelTextArea(
                    placeholder:
                        'ERROR 2024-01-15 14:23:01 [auth-service] Connection timeout...',
                    controller: _logController,
                    monospace: true,
                    minLines: 6,
                    maxLines: 14,
                    onChanged: (v) => ref
                        .read(registrationFormProvider.notifier)
                        .updateRawLog(v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Footer (desktop/tablet only — mobile uses a screen-level
                  // sticky bar so Submit is reachable without scrolling).
                  if (!isMobile) _SubmitFooter(formState: formState, onSubmit: widget.onSubmit),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitFooter extends StatelessWidget {
  const _SubmitFooter({required this.formState, required this.onSubmit});
  final RegistrationFormState formState;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (formState.submitError != null) ...[
          Text(
            formState.submitError!,
            style: AppText.bodySmall.copyWith(color: AppColors.severityCritical),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        PrimaryButton(
          label: formState.isSubmitting ? 'Creating...' : 'Create Incident',
          onPressed: formState.isSubmitting ? () {} : onSubmit,
        ),
      ],
    );
  }
}

class _SeverityChips extends StatelessWidget {
  const _SeverityChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Severity', style: AppText.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: ['critical', 'major', 'minor'].map((s) {
            final isSelected = s == value;
            final color = AppColors.forSeverity(s);
            return GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                  color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
                ),
                child: Text(
                  s.toUpperCase(),
                  style: AppText.labelMedium.copyWith(
                    color: isSelected ? color : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

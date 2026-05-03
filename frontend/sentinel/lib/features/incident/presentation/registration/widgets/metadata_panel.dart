import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../design_system/design_system.dart';
import '../providers/registration_form_provider.dart';
import '../providers/registration_metadata_provider.dart';
import 'architecture_component_list.dart';

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

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(registrationFormProvider);
    final isAnalyzing = ref.watch(
      registrationMetadataProvider.select((s) => s.isAnalyzing),
    );

    // Sync title controller when metadata auto-populates
    ref.listen<RegistrationFormState>(registrationFormProvider, (prev, next) {
      if (prev?.title != next.title && _titleController.text != next.title) {
        _titleController.text = next.title;
        _titleController.selection =
            TextSelection.collapsed(offset: next.title.length);
      }
    });

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
                  SentinelDropdown(
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
                  SentinelTextArea(
                    label: 'Raw Log / Description',
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
                ],
              ),
            ),
          ),
          // ── Footer: error + submit ───────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (formState.submitError != null) ...[
                  Text(
                    formState.submitError!,
                    style: AppText.bodySmall
                        .copyWith(color: AppColors.severityCritical),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                PrimaryButton(
                  label: formState.isSubmitting
                      ? 'Creating...'
                      : 'Create Incident',
                  onPressed:
                      formState.isSubmitting ? () {} : widget.onSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

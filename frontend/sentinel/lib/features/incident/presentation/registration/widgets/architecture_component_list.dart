import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../design_system/design_system.dart';
import '../providers/registration_form_provider.dart';

class ArchitectureComponentList extends ConsumerStatefulWidget {
  const ArchitectureComponentList({super.key});

  @override
  ConsumerState<ArchitectureComponentList> createState() =>
      _ArchitectureComponentListState();
}

class _ArchitectureComponentListState
    extends ConsumerState<ArchitectureComponentList> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(registrationFormProvider.notifier).addComponent(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final components =
        ref.watch(registrationFormProvider.select((s) => s.components));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Affected Components', style: AppText.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        if (components.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: components
                .map((c) => ComponentChip(
                      label: c,
                      onRemove: () => ref
                          .read(registrationFormProvider.notifier)
                          .removeComponent(c),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: AppText.bodyMedium,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: 'Add component...',
                  hintStyle:
                      AppText.bodySmall.copyWith(color: AppColors.textFaint),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(
                        color: AppColors.accentBlue, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GhostButton(label: 'Add', onPressed: _add),
          ],
        ),
      ],
    );
  }
}

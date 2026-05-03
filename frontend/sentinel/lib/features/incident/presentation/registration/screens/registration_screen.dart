import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../design_system/design_system.dart';
import '../providers/registration_form_provider.dart';
import '../providers/registration_metadata_provider.dart';
import '../widgets/metadata_panel.dart';

class RegistrationScreen extends ConsumerWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate the metadata provider so it starts listening for rawLog changes.
    ref.watch(registrationMetadataProvider);

    ref.listen<RegistrationFormState>(registrationFormProvider, (prev, next) {
      if (prev?.createdIncidentId == null && next.createdIncidentId != null) {
        context.go('/incidents/${next.createdIncidentId}/analysis');
      }
    });

    return SentinelScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TwoPanelLayout(
              leftFlex: 30,
              rightFlex: 70,
              left: const _GuidePanel(),
              right: MetadataPanel(
                onSubmit: () =>
                    ref.read(registrationFormProvider.notifier).submit(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GhostButton(
          label: '← Dashboard',
          onPressed: () => context.go('/dashboard'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('Register Incident', style: AppText.headlineLarge),
      ],
    );
  }
}

// ── Guide Panel (left) ──────────────────────────────────────────────────────

class _GuidePanel extends StatelessWidget {
  const _GuidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: AppText.titleMedium),
          const SizedBox(height: AppSpacing.md),
          const _Step(
            number: '1',
            title: 'Paste your log',
            body:
                'Copy raw error logs, stack traces, or a plain description of the incident into the log field.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _Step(
            number: '2',
            title: 'AI pre-fills metadata',
            body:
                'Sentinel analyzes the log and automatically suggests a title, severity, and affected components.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _Step(
            number: '3',
            title: 'Review and adjust',
            body:
                'Edit any field before submitting. You can add or remove components and change the severity.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _Step(
            number: '4',
            title: 'Create the incident',
            body:
                'Hit "Create Incident" to register it. You\'ll land on the AI Analysis page where fix flows are recommended.',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(
                  color: AppColors.accentBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.accentBlue),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'The more detail you provide in the log, the more accurate the AI analysis will be.',
                    style: AppText.bodySmall
                        .copyWith(color: AppColors.accentBlue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppText.labelSmall.copyWith(color: AppColors.accentBlue),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.labelMedium.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(body,
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

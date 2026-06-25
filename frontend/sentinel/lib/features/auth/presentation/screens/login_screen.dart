import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../design_system/design_system.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _validationError = 'Email and password are required.');
      return;
    }
    setState(() => _validationError = null);

    await ref.read(authProvider.notifier).signIn(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return SentinelScaffold(
      padding: EdgeInsets.zero,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sentinel', style: AppText.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('AI Error Resolution Copilot',
                    style: AppText.bodyMedium
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.xl),

                SentinelInput(
                  label: 'Email',
                  placeholder: 'you@company.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),

                SentinelInput(
                  label: 'Password',
                  placeholder: '••••••••',
                  controller: _passwordCtrl,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.lg),

                PrimaryButton(
                  label: 'Continue',
                  onPressed: _onContinue,
                  isLoading: auth.isLoading,
                  fullWidth: true,
                ),

                if (_validationError != null || auth.error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _validationError ?? auth.error!,
                    style: AppText.bodySmall
                        .copyWith(color: AppColors.severityCritical),
                  ),
                ],

                // const SizedBox(height: AppSpacing.md),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     Text("don't you have any account? ",
                //         style: AppText.bodySmall),
                //     GestureDetector(
                //       onTap: () => context.go('/signup'),
                //       child: Text('sign up', style: AppText.link),
                //     ),
                //   ],
                // ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../design_system/design_system.dart';
import '../providers/auth_provider.dart';

/// Sign-up is a two-stage flow on one screen.
/// Stage 1: Enter email → "Send Code" triggers Supabase OTP.
/// Stage 2: Enter password + received code → "Continue" verifies OTP.
/// Field display order matches design: Password → Validation Code → Email.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    await ref.read(authProvider.notifier).sendSignUpCode(email, password);

    if (mounted && ref.read(authProvider).error == null) {
      setState(() => _codeSent = true);
      _showSnack('Verification code sent to $email');
    }
  }

  Future<void> _onContinue() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (email.isEmpty || code.isEmpty) return;

    await ref.read(authProvider.notifier).verifySignUp(email, code);

    if (mounted && ref.read(authProvider).isAuthenticated) {
      context.go('/dashboard');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.bodySmall.copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return SentinelScaffold(
      padding: EdgeInsets.zero,
      body: Center(
        child: SizedBox(
          width: 400,
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
                Text('Sentinel - SignUp', style: AppText.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('AI Error Resolution Copilot',
                    style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.xl),

                // Password — first field as per design
                SentinelInput(
                  label: 'Password',
                  placeholder: '••••••••',
                  controller: _passwordCtrl,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),

                // Validation code — second field as per design
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    SentinelInput(
                      label: 'validation code',
                      placeholder: 'enter received code',
                      controller: _codeCtrl,
                    ),
                    if (!_codeSent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: GestureDetector(
                          onTap: auth.isLoading ? null : _onSendCode,
                          child: Text(
                            'Send code',
                            style: AppText.labelSmall.copyWith(color: AppColors.accentBlue),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Email — third field as per design
                SentinelInput(
                  label: 'Email',
                  placeholder: 'you@company.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.lg),

                PrimaryButton(
                  label: 'Continue',
                  onPressed: _codeSent ? _onContinue : _onSendCode,
                  isLoading: auth.isLoading,
                  fullWidth: true,
                ),

                if (auth.error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    auth.error!,
                    style: AppText.bodySmall.copyWith(color: AppColors.severityCritical),
                  ),
                ],

                if (_codeSent) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Code sent — check your email.',
                    style: AppText.bodySmall.copyWith(color: AppColors.severityMinor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

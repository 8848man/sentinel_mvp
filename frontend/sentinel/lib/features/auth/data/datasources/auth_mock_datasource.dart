import '../mocks/mock_auth_accounts.dart';

class MockAuthResult {
  const MockAuthResult({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });
  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
}

class AuthMockDatasource {
  // Tracks pending sign-ups: email → password (waiting for OTP verification)
  final Map<String, String> _pendingSignUps = {};

  // Tracks users registered via the dev direct-registration flow
  final Map<String, String> _directRegistrations = {};

  Future<MockAuthResult> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final account = kMockAuthAccounts
        .where((a) => a.email == email.trim())
        .firstOrNull;

    if (account == null) {
      throw Exception('Invalid login credentials');
    }
    if (account.password != password) {
      throw Exception('Invalid login credentials');
    }

    return MockAuthResult(
      userId: account.userId,
      email: account.email,
      accessToken: account.accessToken,
      refreshToken: account.refreshToken,
    );
  }

  /// Dev-only direct registration without OTP verification.
  Future<MockAuthResult> registerDirect(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final normalized = email.trim().toLowerCase();

    final isDuplicate = kMockAuthAccounts.any((a) => a.email == normalized) ||
        _directRegistrations.containsKey(normalized);
    if (isDuplicate) {
      throw Exception('An account with this email already exists.');
    }

    _directRegistrations[normalized] = password;

    return MockAuthResult(
      userId: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
      email: normalized,
      accessToken: 'mock.access.$normalized',
      refreshToken: 'mock.refresh.$normalized',
    );
  }

  /// Step 1 of sign-up: stores credentials, simulates OTP email send.
  Future<void> sendSignUpCode(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Allow re-sending OTP for registered mock accounts freely.
    // Real Supabase would error on duplicate email; mock does not.
    _pendingSignUps[email.trim()] = password;
  }

  /// Step 2 of sign-up: verifies OTP code against registered mock accounts.
  Future<MockAuthResult> verifySignUp(String email, String otp) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (!_pendingSignUps.containsKey(email.trim())) {
      throw Exception('No pending sign-up for this email. Call sendSignUpCode first.');
    }

    final account = kMockAuthAccounts
        .where((a) => a.email == email.trim())
        .firstOrNull;

    if (account == null || account.otpCode != otp.trim()) {
      throw Exception('Invalid or expired verification code');
    }

    _pendingSignUps.remove(email.trim());
    return MockAuthResult(
      userId: account.userId,
      email: account.email,
      accessToken: account.accessToken,
      refreshToken: account.refreshToken,
    );
  }
}

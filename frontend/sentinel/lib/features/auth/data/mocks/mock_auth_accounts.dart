// Mock auth accounts for frontend testing without a live Supabase project.
// See /sdd/frontend/mock_auth_accounts.md for the full spec.

class MockAuthAccount {
  const MockAuthAccount({
    required this.email,
    required this.password,
    required this.otpCode,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String email;
  final String password;
  final String otpCode;
  final String userId;
  final String accessToken;
  final String refreshToken;
}

const kMockAuthAccounts = [
  MockAuthAccount(
    email: 'admin@sentinel.ai',
    password: 'Sentinel2026!',
    otpCode: '000000',
    userId: 'mock-user-001',
    accessToken: 'mock.access.token.admin.sentinel.ai',
    refreshToken: 'mock.refresh.token.admin.sentinel.ai',
  ),
  MockAuthAccount(
    email: 'dev@sentinel.ai',
    password: 'Dev1234!',
    otpCode: '111111',
    userId: 'mock-user-002',
    accessToken: 'mock.access.token.dev.sentinel.ai',
    refreshToken: 'mock.refresh.token.dev.sentinel.ai',
  ),
];

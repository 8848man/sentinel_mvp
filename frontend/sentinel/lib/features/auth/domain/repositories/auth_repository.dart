import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  /// Returns the currently authenticated user, or null if no session exists.
  Future<AuthUser?> getSignedInUser();

  /// Authenticates with email and password.
  Future<AuthUser> signIn(String email, String password);

  /// Signs out the current user.
  Future<void> signOut();

  /// Dev-only: registers and immediately authenticates without OTP.
  Future<AuthUser> registerDirect(String email, String password);

  /// Production step 1: creates account and sends a verification code by email.
  Future<void> sendSignUpCode(String email, String password);

  /// Production step 2: verifies the OTP code and completes sign-up.
  Future<AuthUser> verifySignUp(String email, String code);

  /// Emits the current user on every auth state change (sign-in, sign-out).
  Stream<AuthUser?> get authStateChanges;
}

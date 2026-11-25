import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return client;
  }

  Stream<AuthState> get authStateChanges {
    final client = _client;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  User? get currentUser => _client?.auth.currentUser;

  Session? get currentSession => _client?.auth.currentSession;

  /// Direct Email + Password registration (no OTP step).
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    return _requireClient.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  /// Step 1 & 2 of Registration: Sends a 6-digit OTP to email.
  Future<void> sendRegistrationOtp(String email) async {
    await _requireClient.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Step 3 of Registration: Verifies the 6-digit email OTP.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    return _requireClient.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  /// Step 4 of Registration (and Password Reset): Sets password for signed-in user.
  Future<UserResponse> setPassword(String password) async {
    return _requireClient.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  /// Standard Email + Password Login.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _requireClient.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends a password recovery OTP to the user's email.
  Future<void> sendPasswordResetOtp(String email) async {
    await _requireClient.auth.resetPasswordForEmail(email.trim());
  }

  /// Verifies a recovery OTP code.
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    return _requireClient.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

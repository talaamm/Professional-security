import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// User-facing auth error with a safe, already-translated message.
class AuthServiceException implements Exception {
  final String message;
  AuthServiceException(this.message);

  @override
  String toString() => message;
}

/// Employees sign in with an Employee ID, but Supabase Auth requires an
/// email. We map employee_id -> a deterministic internal email address.
/// Real address delivery is never used for this domain.
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  static String _emailForEmployeeId(String employeeId) {
    return '${employeeId.trim().toLowerCase()}@internal.app';
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> login({
    required String employeeId,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: _emailForEmployeeId(employeeId),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthServiceException(_mapSignInError(e));
    }
  }

  Future<Profile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<void> logout() => _client.auth.signOut();

  /// Submits a "please reset my password" request from the (unauthenticated)
  /// Forgot Password screen. Goes through request_password_reset() - see
  /// db_files/phase7-password-reset.sql - the only function in this app
  /// callable while signed out, since a locked-out employee has no session
  /// for report_issue() to resolve an employee_id from.
  Future<void> requestPasswordReset({
    required String employeeId,
    String? message,
  }) async {
    try {
      await _client.rpc('request_password_reset', params: {
        'p_employee_id': employeeId,
        'p_message': message,
      });
    } on PostgrestException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  /// Changes the currently signed-in user's password. Supabase trusts the
  /// active session for this - no need to re-enter the current password.
  Future<void> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  String _mapSignInError(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect Employee ID or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Your account is not verified yet. Please contact an administrator.';
    }
    return 'Login failed. Please try again.';
  }
}

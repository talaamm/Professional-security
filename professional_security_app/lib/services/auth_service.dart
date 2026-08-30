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

  /// Registers a new employee account. The database trigger always creates
  /// the profile with role = 'employee' regardless of what is sent here, so
  /// there is no client-side path to self-register as admin/super_admin.
  Future<void> register({
    required String employeeId,
    required String fullName,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(
        email: _emailForEmployeeId(employeeId),
        password: password,
        data: {
          'employee_id': employeeId.trim(),
          'full_name': fullName.trim(),
        },
      );
    } on AuthException catch (e) {
      throw AuthServiceException(_mapSignUpError(e));
    }
  }

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

  /// Changes the currently signed-in user's password. Supabase trusts the
  /// active session for this - no need to re-enter the current password.
  Future<void> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  String _mapSignUpError(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already exists') ||
        message.contains('duplicate')) {
      return 'This Employee ID is already registered.';
    }
    if (message.contains('password')) {
      return e.message;
    }
    return 'Registration failed. Please check your details and try again.';
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

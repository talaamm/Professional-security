import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../screens/admin_root_screen.dart';
import '../screens/login_screen.dart';
import '../screens/root_screen.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';

enum _GateStatus { loading, loggedOut, loggedIn }

/// Root widget that decides between the Login screen and the main app based
/// on the current Supabase session, and re-validates the profile
/// (active/inactive) on every app start and auth state change. Admins and
/// super admins land on AdminRootScreen instead of the employee RootScreen -
/// they're treated identically for now, the super-admin-over-admins
/// hierarchy is a later phase.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  late final StreamSubscription<AuthState> _subscription;

  _GateStatus _status = _GateStatus.loading;
  Profile? _profile;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _subscription = _authService.authStateChanges.listen((_) => _resolve());
    _resolve();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    if (_authService.currentSession == null) {
      _setLoggedOut(null);
      return;
    }

    try {
      final profile = await _authService.fetchCurrentProfile();

      if (profile == null) {
        await _authService.logout();
        _setLoggedOut(AppStrings.t('auth_gate_profile_not_found'));
        return;
      }

      if (profile.status == UserStatus.inactive) {
        await _authService.logout();
        _setLoggedOut(AppStrings.t('auth_gate_deactivated'));
        return;
      }

      if (!mounted) return;
      setState(() {
        _status = _GateStatus.loggedIn;
        _profile = profile;
        _loginError = null;
      });
    } catch (_) {
      await _authService.logout();
      _setLoggedOut(AppStrings.t('auth_gate_generic_error'));
    }
  }

  void _setLoggedOut(String? error) {
    if (!mounted) return;
    setState(() {
      _status = _GateStatus.loggedOut;
      _profile = null;
      _loginError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _GateStatus.loading:
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      case _GateStatus.loggedOut:
        return LoginScreen(errorMessage: _loginError);
      case _GateStatus.loggedIn:
        final profile = _profile!;
        if (profile.role == UserRole.admin || profile.role == UserRole.superAdmin) {
          return AdminRootScreen(profile: profile);
        }
        return RootScreen(profile: profile);
    }
  }
}

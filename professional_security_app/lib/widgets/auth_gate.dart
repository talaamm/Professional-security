import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';

enum _GateStatus { loading, loggedOut, loggedIn }

/// Root widget that decides between the Login and Home screens based on the
/// current Supabase session, and re-validates the profile (active/inactive)
/// on every app start and auth state change.
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
        _setLoggedOut(
          'We could not find your profile. Please contact an administrator.',
        );
        return;
      }

      if (profile.status == UserStatus.inactive) {
        await _authService.logout();
        _setLoggedOut(
          'This account is inactive. Please contact an administrator.',
        );
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
      _setLoggedOut('Something went wrong. Please log in again.');
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
        return HomeScreen(profile: _profile!);
    }
  }
}

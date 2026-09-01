import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/work_session_service.dart';

/// Shared "Log out" action for every employee-facing screen (Home,
/// Profile). If the employee has an active work session, warns that
/// logging out will end it (see requirements: prevents leaving a
/// session running while switching to another account) and force-ends
/// it via end_work_session_for_logout() before signing out. With no
/// active session, logs out immediately.
Future<void> handleLogout(BuildContext context, String employeeId) async {
  final sessionService = WorkSessionService();
  final authService = AuthService();

  final activeSession = await sessionService.fetchActiveSession(employeeId);
  if (!context.mounted) return;

  if (activeSession == null) {
    await authService.logout();
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        AppStrings.t('logout_confirm_title'),
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: Text(
        AppStrings.t('logout_confirm_desc'),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppStrings.t('common_cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(AppStrings.t('logout_confirm_button')),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  if (!context.mounted) return;

  try {
    await sessionService.endSessionForLogout();
    await authService.logout();
  } on WorkSessionException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('logout_error', {'reason': e.message}))),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('logout_error_generic'))),
    );
  }
}

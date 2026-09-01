import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/active_employee_session.dart';
import '../models/profile.dart';
import '../models/unverified_session.dart';
import '../services/admin_service.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/error_banner.dart';
import 'session_review_screen.dart';

/// Admin/super-admin landing page: who's currently working, and which
/// completed sessions still need review. Admins and super admins are
/// treated identically for now - the super-admin-over-admins hierarchy
/// is a later phase.
class AdminHomeScreen extends StatefulWidget {
  final Profile profile;

  const AdminHomeScreen({super.key, required this.profile});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _adminService = AdminService();
  final _authService = AuthService();

  List<ActiveEmployeeSession> _active = [];
  List<UnverifiedSession> _unverified = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _adminService.fetchActiveSessions(),
        _adminService.fetchUnverifiedSessions(),
      ]);
      if (!mounted) return;
      setState(() {
        _active = results[0] as List<ActiveEmployeeSession>;
        _unverified = results[1] as List<UnverifiedSession>;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('admin_home_error'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewSession(UnverifiedSession session) async {
    final outcome = await Navigator.of(context).push<SessionReviewOutcome>(
      MaterialPageRoute(builder: (_) => SessionReviewScreen(session: session)),
    );
    if (outcome != null) {
      await _load();
      if (!mounted) return;
      final message = outcome == SessionReviewOutcome.verified
          ? AppStrings.t('admin_home_session_verified_snackbar')
          : AppStrings.t('admin_home_session_deleted_snackbar');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _endSession(ActiveEmployeeSession session) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppStrings.t('admin_home_end_dialog_title', {'name': session.employeeName}),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t('admin_home_end_dialog_desc'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(hintText: AppStrings.t('common_reason_optional_hint')),
            ),
          ],
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
            child: Text(AppStrings.t('admin_home_end_dialog_confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _adminService.endActiveSession(
        sessionId: session.sessionId,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppStrings.t('admin_home_session_ended'))));
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('common_something_wrong'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.t('admin_home_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.t('common_log_out'),
            onPressed: _authService.logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    AppStrings.t('common_welcome', {'name': widget.profile.fullName}),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  DashboardSection(
                    title: AppStrings.t('admin_home_currently_working'),
                    count: _active.length,
                    emptyText: AppStrings.t('admin_home_no_active'),
                    children: _active
                        .map((session) => _ActiveSessionTile(
                              session: session,
                              onEnd: () => _endSession(session),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  DashboardSection(
                    title: AppStrings.t('admin_home_unverified_sessions'),
                    count: _unverified.length,
                    emptyText: AppStrings.t('admin_home_no_unverified'),
                    children: _unverified
                        .map((session) => _UnverifiedSessionTile(
                              session: session,
                              onTap: () => _reviewSession(session),
                            ))
                        .toList(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ActiveSessionTile extends StatelessWidget {
  final ActiveEmployeeSession session;
  final VoidCallback onEnd;

  const _ActiveSessionTile({required this.session, required this.onEnd});

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        session.employeeName,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t('admin_home_since', {
              'workplace': session.workplaceName != null || session.manualLocationName != null
                  ? session.workplaceLabel
                  : AppStrings.t('workplace_unknown'),
              'time': _formatTime(session.startedAt),
            }),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (session.isPendingReview)
            Text(
              AppStrings.t('admin_home_manual_flag'),
              style: const TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
        ],
      ),
      leading: const Icon(Icons.circle, color: AppColors.success, size: 12),
      trailing: IconButton(
        icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
        tooltip: AppStrings.t('admin_home_end_session_tooltip'),
        onPressed: onEnd,
      ),
    );
  }
}

class _UnverifiedSessionTile extends StatelessWidget {
  final UnverifiedSession session;
  final VoidCallback onTap;

  const _UnverifiedSessionTile({required this.session, required this.onTap});

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        session.employeeName,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t('admin_home_unverified_row_date', {
              'workplace': session.workplaceName != null || session.manualLocationName != null
                  ? session.workplaceLabel
                  : AppStrings.t('workplace_unknown'),
              'date': _formatDate(session.startedAt),
            }),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            AppStrings.unverifiedReason(session.startNeedsReview, session.endNeedsReview),
            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
    );
  }
}

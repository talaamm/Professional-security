import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/active_employee_session.dart';
import '../models/profile.dart';
import '../models/unverified_session.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
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
      setState(() => _error = 'Could not load the dashboard. Pull down to retry.');
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
          ? 'Session verified.'
          : 'Session deleted.';
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
          'End ${session.employeeName}\'s session?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will immediately end their active session. It will be marked as '
              'admin-ended and queued for review.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Session'),
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
          .showSnackBar(const SnackBar(content: Text('Session ended.')));
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
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
                    'Welcome, ${widget.profile.fullName}',
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
                  _DashboardSection(
                    title: 'Currently Working',
                    count: _active.length,
                    emptyText: 'No employees are currently working.',
                    children: _active
                        .map((session) => _ActiveSessionTile(
                              session: session,
                              onEnd: () => _endSession(session),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _DashboardSection(
                    title: 'Unverified Sessions',
                    count: _unverified.length,
                    emptyText: 'No sessions are waiting for review.',
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

class _DashboardSection extends StatelessWidget {
  final String title;
  final int count;
  final String emptyText;
  final List<Widget> children;

  const _DashboardSection({
    required this.title,
    required this.count,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            '$title  ($count)',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          children: [
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(emptyText, style: const TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...children,
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
            '${session.workplaceLabel} · Since ${_formatTime(session.startedAt)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (session.isPendingReview)
            const Text(
              '⚠ Manual location entered',
              style: TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
        ],
      ),
      leading: const Icon(Icons.circle, color: AppColors.success, size: 12),
      trailing: IconButton(
        icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
        tooltip: 'End session',
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
            '${session.workplaceLabel} · ${_formatDate(session.startedAt)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            session.reason,
            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
    );
  }
}

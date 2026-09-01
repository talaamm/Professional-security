import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/work_session.dart';
import '../services/app_strings.dart';
import '../services/issue_service.dart';
import '../services/work_session_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/logout_helper.dart';
import 'end_work_screen.dart';
import 'start_work_screen.dart';

/// Employee home dashboard: current work status and the start/finish work
/// action. Starting work hands off to StartWorkScreen (GPS + workplace
/// detection); finishing asks for confirmation here, then hands off to
/// EndWorkScreen (GPS + re-check against the session's start workplace).
class HomeScreen extends StatefulWidget {
  final Profile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionService = WorkSessionService();
  final _issueService = IssueService();

  WorkSession? _activeSession;
  bool _isLoading = true;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadActiveSession();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _sessionService.fetchActiveSession(widget.profile.employeeId);
      if (!mounted) return;
      setState(() => _activeSession = session);
      _configureTicker();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('home_error_status'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _configureTicker() {
    _ticker?.cancel();
    if (_activeSession != null && _activeSession!.isActive) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _goToStartWork() async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const StartWorkScreen()),
    );
    if (started == true) {
      await _loadActiveSession();
    }
  }

  Future<void> _confirmFinishWork() async {
    final session = _activeSession;
    if (session == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppStrings.t('home_finish_dialog_title'),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          AppStrings.t('home_finish_dialog_content', {
            'time': _formatTime(session.startedAt),
            'elapsed': _formatElapsed(session.startedAt),
          }),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.t('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.t('home_finish_dialog_confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _goToEndWork(session);
    }
  }

  Future<void> _goToEndWork(WorkSession session) async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EndWorkScreen(session: session)),
    );
    if (verified == null) return;

    _ticker?.cancel();
    await _loadActiveSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verified
              ? AppStrings.t('home_session_ended_verified')
              : AppStrings.t('home_session_ended_unverified'),
        ),
      ),
    );
  }

  Future<void> _reportIssue() async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            AppStrings.t('home_report_issue_title'),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t('home_report_issue_desc'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLength: 50,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(hintText: AppStrings.t('home_report_issue_hint')),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.t('common_cancel')),
            ),
            ElevatedButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(AppStrings.t('common_send')),
            ),
          ],
        ),
      ),
    );

    if (message == null || message.isEmpty) return;
    if (!mounted) return;

    try {
      await _issueService.reportIssue(message);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppStrings.t('home_report_issue_sent'))));
    } on IssueServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('common_something_wrong'))),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatElapsed(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt);
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final session = _activeSession;
    final isWorking = session != null && session.isActive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.t('home_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.t('common_log_out'),
            onPressed: () => handleLogout(context, widget.profile.employeeId),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _loadActiveSession,
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
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.t('common_employee_id', {'id': widget.profile.employeeId}),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  _StatusCard(
                    isWorking: isWorking,
                    session: session,
                    formatTime: _formatTime,
                    formatElapsed: _formatElapsed,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isWorking ? _confirmFinishWork : _goToStartWork,
                    style: isWorking
                        ? ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          )
                        : null,
                    child: Text(isWorking
                        ? AppStrings.t('home_finish_button')
                        : AppStrings.t('home_start_button')),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _reportIssue,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: Text(AppStrings.t('home_report_issue')),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isWorking;
  final WorkSession? session;
  final String Function(DateTime) formatTime;
  final String Function(DateTime) formatElapsed;

  const _StatusCard({
    required this.isWorking,
    required this.session,
    required this.formatTime,
    required this.formatElapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t('home_status_label'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWorking ? AppColors.success : AppColors.textSecondary,
                  boxShadow: isWorking
                      ? [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isWorking ? AppStrings.t('home_working') : AppStrings.t('home_not_working'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isWorking
                ? AppStrings.t('home_working_desc')
                : AppStrings.t('home_not_working_desc'),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (isWorking && session != null) ...[
            const Divider(height: 32, color: AppColors.background),
            _InfoRow(label: AppStrings.t('home_working_since'), value: formatTime(session!.startedAt)),
            const SizedBox(height: 16),
            _InfoRow(label: AppStrings.t('home_elapsed'), value: formatElapsed(session!.startedAt)),
            const SizedBox(height: 16),
            _InfoRow(
              label: AppStrings.t('home_workplace'),
              value: session!.workplaceName != null || session!.manualLocationName != null
                  ? session!.workplaceLabel
                  : AppStrings.t('workplace_unknown'),
            ),
            if (session!.isPendingReview) ...[
              const SizedBox(height: 6),
              Text(
                AppStrings.t('home_manual_pending'),
                style: const TextStyle(color: AppColors.secondary, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

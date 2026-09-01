import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../services/app_strings.dart';
import '../services/issue_service.dart';
import '../widgets/logout_helper.dart';
import '../widgets/work_session_panel.dart';

/// Employee home dashboard: current work status and the start/finish work
/// action (WorkSessionPanel), plus a way to report an issue to admins.
class HomeScreen extends StatefulWidget {
  final Profile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _issueService = IssueService();
  final _panelKey = GlobalKey<WorkSessionPanelState>();

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

  @override
  Widget build(BuildContext context) {
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
        onRefresh: () async => _panelKey.currentState?.refresh(),
        child: ListView(
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
            WorkSessionPanel(key: _panelKey, profile: widget.profile),
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

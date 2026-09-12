import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../services/app_strings.dart';
import '../services/work_session_service.dart';
import '../widgets/developer_contact_helper.dart';
import '../widgets/language_picker.dart';
import '../widgets/logout_helper.dart';
import 'change_password_screen.dart';

/// Employee profile: their details, when their account was created, how
/// many sessions they've completed, a language preference, and a
/// change-password action.
class EmployeeProfileScreen extends StatefulWidget {
  final Profile profile;

  const EmployeeProfileScreen({super.key, required this.profile});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final _sessionService = WorkSessionService();

  int? _completedSessions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final count = await _sessionService.countCompletedSessions(widget.profile.employeeId);
      if (!mounted) return;
      setState(() => _completedSessions = count);
    } catch (_) {
      // Non-critical info; leave counters blank rather than blocking the page.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLanguage() => pickLanguage(context: context);

  String _formatDate(DateTime dt) {
    final months = AppStrings.list('months_short');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.t('profile_title')),
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
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
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
                    widget.profile.fullName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.t('common_employee_id', {'id': widget.profile.employeeId}),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const Divider(height: 28, color: AppColors.background),
                  _InfoRow(
                    label: AppStrings.t('profile_member_since'),
                    value: _formatDate(widget.profile.createdAt),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: AppStrings.t('profile_completed_sessions'),
                    value: _isLoading ? '—' : '${_completedSessions ?? 0}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ProfileActionTile(
              icon: Icons.language,
              title: AppStrings.t('profile_language'),
              subtitle: AppStrings.current.value.label,
              onTap: _pickLanguage,
            ),
            const SizedBox(height: 12),
            _ProfileActionTile(
              icon: Icons.lock_outline,
              title: AppStrings.t('profile_change_password'),
              subtitle: AppStrings.t('profile_change_password_subtitle'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileActionTile(
              icon: Icons.feedback_outlined,
              title: AppStrings.t('profile_contact_developer'),
              subtitle: AppStrings.t('profile_contact_developer_subtitle'),
              onTap: () => openDeveloperContactForm(context),
            ),
          ],
        ),
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../widgets/language_picker.dart';
import 'change_password_screen.dart';

/// Admin/super-admin profile: their name and role, how many employee
/// accounts are currently active (able to sign in - not necessarily
/// working right now), a language preference, change-password, and
/// logout. No active-session warning on logout here - admins don't have
/// work sessions of their own.
class AdminProfileScreen extends StatefulWidget {
  final Profile profile;

  const AdminProfileScreen({super.key, required this.profile});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _adminService = AdminService();
  final _authService = AuthService();
  final _languageService = LanguageService();

  int? _activeEmployeeCount;
  AppLanguage _language = AppLanguage.english;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _adminService.fetchActiveEmployeeCount(),
        _languageService.getLanguage(),
      ]);
      if (!mounted) return;
      setState(() {
        _activeEmployeeCount = results[0] as int;
        _language = results[1] as AppLanguage;
      });
    } catch (_) {
      // Non-critical info; leave the counter blank rather than blocking the page.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLanguage() => pickLanguage(
        context: context,
        current: _language,
        onChanged: (language) => setState(() => _language = language),
      );

  String get _roleLabel {
    switch (widget.profile.role) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.employee:
        return 'Employee';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
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
                  Text(_roleLabel, style: const TextStyle(color: AppColors.textSecondary)),
                  const Divider(height: 28, color: AppColors.background),
                  _InfoRow(
                    label: 'ACTIVE EMPLOYEES',
                    value: _isLoading ? '—' : '${_activeEmployeeCount ?? 0}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ProfileActionTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: _language.label,
              onTap: _pickLanguage,
            ),
            const SizedBox(height: 12),
            _ProfileActionTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
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

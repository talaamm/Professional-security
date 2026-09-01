import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/workplace.dart';
import '../services/admin_service.dart';
import '../services/app_strings.dart';
import '../widgets/error_banner.dart';
import 'workplace_form_screen.dart';

/// Workplaces tab: every workplace (active and inactive), tap to edit, a
/// button to add one from the admin's current GPS location.
class AdminWorkplacesScreen extends StatefulWidget {
  final Profile profile;

  const AdminWorkplacesScreen({super.key, required this.profile});

  @override
  State<AdminWorkplacesScreen> createState() => _AdminWorkplacesScreenState();
}

class _AdminWorkplacesScreenState extends State<AdminWorkplacesScreen> {
  final _adminService = AdminService();

  List<Workplace> _workplaces = [];
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
      final workplaces = await _adminService.fetchAllWorkplaces();
      if (!mounted) return;
      setState(() => _workplaces = workplaces);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('workplaces_error'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({Workplace? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkplaceFormScreen(adminProfile: widget.profile, existing: existing),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppStrings.t('workplaces_title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(AppStrings.t('workplaces_add_button')),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                children: [
                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  if (_workplaces.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          AppStrings.t('workplaces_empty'),
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    for (final workplace in _workplaces) ...[
                      _WorkplaceCard(
                        workplace: workplace,
                        onTap: () => _openForm(existing: workplace),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
      ),
    );
  }
}

class _WorkplaceCard extends StatelessWidget {
  final Workplace workplace;
  final VoidCallback onTap;

  const _WorkplaceCard({required this.workplace, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = workplace.isActive;

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workplace.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${workplace.isPermanent ? AppStrings.t('workplaces_permanent') : AppStrings.t('workplaces_temporary')}'
                    '  ·  ${AppStrings.t('workplaces_radius', {'radius': '${workplace.radiusMeters ?? '—'}'})}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? AppStrings.t('common_active') : AppStrings.t('common_inactive'),
                style: TextStyle(
                  color: isActive ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

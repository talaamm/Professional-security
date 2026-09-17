import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/workplace.dart';
import '../services/admin_service.dart';
import '../services/app_strings.dart';
import '../services/report_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/month_selector.dart';
import 'location_picker_screen.dart';

const int _maxRadiusMeters = 10000; // matches workplaces_radius_reasonable

// The app's data starts in August 2026 - no earlier month has any
// sessions to report on (same constant as admin_employee_detail_screen.dart).
final DateTime _minReportMonth = DateTime(2026, 8);

/// Add a new workplace or edit an existing one. The workplace's
/// coordinates always come from the admin searching/tapping a spot on the
/// map in LocationPickerScreen ("Choose Location") - never from the
/// admin's own device GPS, since they may be creating or editing a
/// workplace while not physically there.
class WorkplaceFormScreen extends StatefulWidget {
  final Profile adminProfile;
  final Workplace? existing;

  const WorkplaceFormScreen({super.key, required this.adminProfile, this.existing});

  @override
  State<WorkplaceFormScreen> createState() => _WorkplaceFormScreenState();
}

class _WorkplaceFormScreenState extends State<WorkplaceFormScreen> {
  final _adminService = AdminService();
  final _reportService = ReportService();
  final _nameController = TextEditingController();

  late final bool _isEditing = widget.existing != null;
  late String _type = widget.existing?.type ?? 'permanent';

  double? _latitude;
  double? _longitude;
  int? _radiusMeters;
  String? _locationName;

  bool _isSubmitting = false;
  String? _error;
  bool _isUpdatingStatus = false;
  late bool _isActive = widget.existing?.isActive ?? true;

  late DateTime _sessionsMonth = clampToMonthRange(
    DateTime(DateTime.now().year, DateTime.now().month),
    _minReportMonth,
  );
  bool _isGeneratingSessionsReport = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.name ?? '';
    _latitude = widget.existing?.latitude;
    _longitude = widget.existing?.longitude;
    _radiusMeters = widget.existing?.radiusMeters;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialRadiusMeters: _radiusMeters,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _radiusMeters = result.radiusMeters;
      _locationName = result.name;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final latitude = _latitude;
    final longitude = _longitude;
    final radius = _radiusMeters;

    if (name.isEmpty) {
      setState(() => _error = AppStrings.t('workplace_form_name_required'));
      return;
    }
    if (latitude == null || longitude == null || radius == null) {
      setState(() => _error = AppStrings.t('workplace_form_location_required'));
      return;
    }
    if (radius <= 0 || radius > _maxRadiusMeters) {
      setState(() => _error = AppStrings.t(
          'workplace_form_radius_too_large', {'max': '$_maxRadiusMeters'}));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _adminService.updateWorkplace(
          id: widget.existing!.id,
          name: name,
          radiusMeters: radius,
          type: _type,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        await _adminService.createWorkplace(
          name: name,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radius,
          type: _type,
          createdBy: widget.adminProfile.employeeId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.t('common_something_wrong'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmToggleStatus() async {
    final activating = !_isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          activating
              ? AppStrings.t('workplace_form_activate_dialog_title')
              : AppStrings.t('workplace_form_deactivate_dialog_title'),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          activating
              ? AppStrings.t('workplace_form_activate_dialog_desc')
              : AppStrings.t('workplace_form_deactivate_dialog_desc'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.t('common_cancel')),
          ),
          ElevatedButton(
            style: activating
                ? null
                : ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activating
                ? AppStrings.t('admin_detail_activate_confirm')
                : AppStrings.t('admin_detail_deactivate_confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdatingStatus = true;
      _error = null;
    });

    try {
      await _adminService.setWorkplaceStatus(id: widget.existing!.id, active: activating);
      if (!mounted) return;
      setState(() => _isActive = activating);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activating
            ? AppStrings.t('workplace_form_activated_snackbar')
            : AppStrings.t('workplace_form_deactivated_snackbar'))),
      );
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.t('common_something_wrong'));
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _changeSessionsMonth(int delta) {
    final next = clampToMonthRange(
      DateTime(_sessionsMonth.year, _sessionsMonth.month + delta),
      _minReportMonth,
    );
    if (next == _sessionsMonth) return;
    setState(() => _sessionsMonth = next);
  }

  Future<void> _downloadSessions() async {
    setState(() {
      _isGeneratingSessionsReport = true;
      _error = null;
    });

    try {
      final sessions = await _adminService.fetchWorkplaceSessionsForMonth(
        workplaceId: widget.existing!.id,
        monthStart: _sessionsMonth,
        monthEndExclusive: DateTime(_sessionsMonth.year, _sessionsMonth.month + 1),
      );
      await _reportService.generateWorkplaceMonthlySessionsReport(
        workplaceName: widget.existing!.name,
        month: _sessionsMonth,
        sessions: sessions,
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on ReportServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('common_something_wrong'));
    } finally {
      if (mounted) setState(() => _isGeneratingSessionsReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing
            ? AppStrings.t('workplace_form_edit_title')
            : AppStrings.t('workplace_form_add_title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          Text(AppStrings.t('workplace_form_name_section'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: AppStrings.t('workplace_form_name_hint')),
          ),
          const SizedBox(height: 16),
          Text(AppStrings.t('workplace_form_type_section'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'permanent', label: Text(AppStrings.t('workplaces_permanent'))),
              ButtonSegment(value: 'temporary', label: Text(AppStrings.t('workplaces_temporary'))),
            ],
            selected: {_type},
            onSelectionChanged: (selected) => setState(() => _type = selected.first),
          ),
          const SizedBox(height: 16),
          Text(AppStrings.t('workplace_form_location_section'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          _buildLocationCard(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(_isEditing
                    ? AppStrings.t('workplace_form_save_button')
                    : AppStrings.t('workplace_form_create_button')),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isUpdatingStatus ? null : _confirmToggleStatus,
              style: _isActive
                  ? OutlinedButton.styleFrom(foregroundColor: AppColors.error)
                  : null,
              child: _isUpdatingStatus
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(_isActive
                      ? AppStrings.t('workplace_form_deactivate_button')
                      : AppStrings.t('workplace_form_activate_button')),
            ),
            const SizedBox(height: 24),
            _buildSessionsReportCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsReportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t('workplace_form_sessions_report_section'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          MonthSelector(
            month: _sessionsMonth,
            minMonth: _minReportMonth,
            onChange: _isGeneratingSessionsReport ? null : _changeSessionsMonth,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isGeneratingSessionsReport ? null : _downloadSessions,
            icon: _isGeneratingSessionsReport
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(_isGeneratingSessionsReport
                ? AppStrings.t('admin_detail_generating')
                : AppStrings.t('workplace_form_download_sessions_button')),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final latitude = _latitude;
    final longitude = _longitude;
    final hasLocation = latitude != null && longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(hasLocation ? Icons.place : Icons.location_off_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasLocation
                      ? (_locationName ?? AppStrings.t('workplace_form_selected_location'))
                      : AppStrings.t('workplace_form_no_location_selected'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (hasLocation) ...[
            const SizedBox(height: 6),
            Text(
              '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.t('location_picker_radius_label', {'radius': '${_radiusMeters ?? '—'}'}),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _chooseLocation,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(hasLocation
                ? AppStrings.t('workplace_form_change_location_button')
                : AppStrings.t('workplace_form_choose_location_button')),
          ),
        ],
      ),
    );
  }
}

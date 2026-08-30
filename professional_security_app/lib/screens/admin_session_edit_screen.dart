import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/work_session.dart';
import '../models/workplace.dart';
import '../services/admin_service.dart';
import '../widgets/error_banner.dart';

/// Admin correction of one completed session: start/end time, workplace or
/// manual location, and an optional reason - or delete it outright. Every
/// save or delete is tracked server-side (which admin, old/new data) via
/// audit_logs, regardless of whether the session was already verified.
///
/// Pops `true` if the session was changed (edited or deleted), so the
/// employee detail screen knows to refresh.
class AdminSessionEditScreen extends StatefulWidget {
  final WorkSession session;

  const AdminSessionEditScreen({super.key, required this.session});

  @override
  State<AdminSessionEditScreen> createState() => _AdminSessionEditScreenState();
}

class _AdminSessionEditScreenState extends State<AdminSessionEditScreen> {
  final _adminService = AdminService();
  final _manualLocationController = TextEditingController();
  final _reasonController = TextEditingController();

  late DateTime _startedAt = widget.session.startedAt;
  late DateTime _endedAt = widget.session.endedAt!;
  String? _selectedWorkplaceId;
  List<Workplace> _workplaces = [];
  bool _isLoadingWorkplaces = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedWorkplaceId = widget.session.workplaceId;
    _manualLocationController.text = widget.session.manualLocationName ?? '';
    _loadWorkplaces();
  }

  @override
  void dispose() {
    _manualLocationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkplaces() async {
    setState(() => _isLoadingWorkplaces = true);
    try {
      final workplaces = await _adminService.fetchWorkplaces();
      if (!mounted) return;
      setState(() => _workplaces = workplaces);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load the workplace list.');
    } finally {
      if (mounted) setState(() => _isLoadingWorkplaces = false);
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startedAt : _endedAt;

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startedAt = combined;
      } else {
        _endedAt = combined;
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day}/${dt.year}  $hour:$minute';
  }

  bool get _canSave {
    if (_endedAt.isBefore(_startedAt) || _endedAt.isAtSameMomentAs(_startedAt)) return false;
    if (_selectedWorkplaceId == null && _manualLocationController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _adminService.editSession(
        sessionId: widget.session.id,
        startedAt: _startedAt,
        endedAt: _endedAt,
        workplaceId: _selectedWorkplaceId,
        manualLocationName:
            _selectedWorkplaceId == null ? _manualLocationController.text.trim() : null,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmDelete() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this session?', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes the session. This cannot be undone.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Reason (required)'),
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
            onPressed: reasonController.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _adminService.deleteSession(sessionId: widget.session.id, reason: reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Session')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            const Text('STARTED',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pickDateTime(isStart: true),
              child: Text(_formatDateTime(_startedAt)),
            ),
            const SizedBox(height: 16),
            const Text('ENDED', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pickDateTime(isStart: false),
              child: Text(_formatDateTime(_endedAt)),
            ),
            const SizedBox(height: 16),
            const Text('WORKPLACE',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            _isLoadingWorkplaces
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : DropdownButtonFormField<String?>(
                    initialValue: _selectedWorkplaceId,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Manual location —'),
                      ),
                      ..._workplaces.map(
                        (w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedWorkplaceId = value),
                  ),
            if (_selectedWorkplaceId == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _manualLocationController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'e.g. Wedding Hall - Beit Hanina'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            const Text('REASON FOR THIS CHANGE (OPTIONAL)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_isSubmitting || !_canSave) ? null : _save,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('SAVE CHANGES'),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.surface),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _confirmDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text('DELETE SESSION'),
            ),
          ],
        ),
      ),
    );
  }
}

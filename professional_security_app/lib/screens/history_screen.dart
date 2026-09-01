import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/work_session.dart';
import '../services/app_strings.dart';
import '../services/report_service.dart';
import '../services/work_session_service.dart';
import '../widgets/error_banner.dart';

/// Read-only work history for the signed-in employee: pick a month, see
/// every session that started in it. Sessions are fetched scoped to this
/// employee's own employee_id, and the work_sessions_select_own RLS policy
/// guarantees no other employee's sessions can ever be returned. There is
/// no way to edit or delete a session from this screen.
class HistoryScreen extends StatefulWidget {
  final Profile profile;

  const HistoryScreen({super.key, required this.profile});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _sessionService = WorkSessionService();
  final _reportService = ReportService();

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<WorkSession> _sessions = [];
  bool _isLoading = true;
  bool _isGeneratingReport = false;
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
      final sessions = await _sessionService.fetchSessionsForMonth(
        monthStart: _month,
        monthEndExclusive: DateTime(_month.year, _month.month + 1),
      );
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } on WorkSessionException catch (e) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('history_error', {'reason': e.message}));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('history_error_generic'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGeneratingReport = true;
      _error = null;
    });

    try {
      await _reportService.generateMonthlyReport(
        employee: widget.profile,
        month: _month,
        sessions: _sessions,
      );
    } on ReportServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.t('history_report_error_generic'));
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppStrings.t('history_title'))),
      body: Column(
        children: [
          _MonthSelector(month: _month, onChange: _changeMonth),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: ElevatedButton.icon(
              onPressed: (_isLoading || _isGeneratingReport) ? null : _generateReport,
              icon: _isGeneratingReport
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(_isGeneratingReport
                  ? AppStrings.t('history_generating')
                  : AppStrings.t('history_generate_report')),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: ErrorBanner(message: _error!),
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _sessions.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                AppStrings.t('history_empty'),
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: _sessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _SessionCard(session: _sessions[index]),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final ValueChanged<int> onChange;

  const _MonthSelector({required this.month, required this.onChange});

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = AppStrings.list('months_full');
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => onChange(-1),
          ),
          Text(
            '${monthNames[month.month - 1]} ${month.year}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: _isCurrentMonth ? null : () => onChange(1),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkSession session;

  const _SessionCard({required this.session});

  String _formatDate(DateTime dt) {
    final weekdays = AppStrings.list('weekdays_short');
    final months = AppStrings.list('months_short');
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final elapsed = end.difference(start);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Verified':
        return AppColors.success;
      case 'In progress':
        return AppColors.primary;
      default:
        return AppColors.secondary;
    }
  }

  /// WorkSession.verificationStatus/verifiedByLabel return fixed English
  /// internal values (also used for the color switch above) - these map
  /// them to display text without touching the model.
  String _statusLabel(String status) {
    switch (status) {
      case 'Verified':
        return AppStrings.t('status_verified');
      case 'In progress':
        return AppStrings.t('status_in_progress');
      default:
        return AppStrings.t('status_unverified');
    }
  }

  String _verifiedByLabel(WorkSession session) {
    final label = session.verifiedByLabel;
    if (label == 'Pending review') return AppStrings.t('verified_by_pending');
    if (label == 'You') return AppStrings.t('verified_by_you');
    return label ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final status = session.verificationStatus;
    final endedAt = session.endedAt;
    final statusColor = _statusColor(status);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(session.startedAt),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            session.workplaceName != null || session.manualLocationName != null
                ? session.workplaceLabel
                : AppStrings.t('workplace_unknown'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            endedAt == null
                ? '${_formatTime(session.startedAt)} → ${AppStrings.t('status_in_progress')}'
                : '${_formatTime(session.startedAt)} → ${_formatTime(endedAt)}  ·  '
                    '${_formatDuration(session.startedAt, endedAt)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (session.verifiedByLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.t('session_verified_by', {'name': _verifiedByLabel(session)}),
              style: TextStyle(
                color: session.verifiedBy == null
                    ? AppColors.secondary
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

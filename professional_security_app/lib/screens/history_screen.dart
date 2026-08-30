import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/work_session.dart';
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

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<WorkSession> _sessions = [];
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
      final sessions = await _sessionService.fetchSessionsForMonth(
        monthStart: _month,
        monthEndExclusive: DateTime(_month.year, _month.month + 1),
      );
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } on WorkSessionException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your history: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your history. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Work History')),
      body: Column(
        children: [
          _MonthSelector(month: _month, onChange: _changeMonth),
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
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No work sessions this month.',
                                style: TextStyle(color: AppColors.textSecondary),
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

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            tooltip: 'Previous month',
            onPressed: () => onChange(-1),
          ),
          Text(
            '${_monthNames[month.month - 1]} ${month.year}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            tooltip: 'Next month',
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

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime dt) =>
      '${_weekdays[dt.weekday - 1]}, ${_months[dt.month - 1]} ${dt.day}';

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
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            session.workplaceLabel,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            endedAt == null
                ? '${_formatTime(session.startedAt)} → in progress'
                : '${_formatTime(session.startedAt)} → ${_formatTime(endedAt)}  ·  '
                    '${_formatDuration(session.startedAt, endedAt)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (session.verifiedByLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Verified by: ${session.verifiedByLabel}',
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

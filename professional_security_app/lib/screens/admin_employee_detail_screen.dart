import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/work_session.dart';
import '../services/admin_service.dart';
import '../services/report_service.dart';
import '../widgets/error_banner.dart';
import 'admin_session_edit_screen.dart';

/// Admin's view of one employee: their details, an activate/deactivate
/// control, a month picker + Generate Report button that builds a PDF
/// (dates, workplace, start/end, duration, status) for the chosen month,
/// and a separate month picker + List Work Sessions button that only
/// loads/shows that month's sessions once pressed - editable/clickable
/// the same way as before, just no longer loaded (and re-fetched on
/// every visit) for the employee's entire history up front.
///
/// Pops `true` if the employee's status was changed, so the search screen
/// knows to refresh.
class AdminEmployeeDetailScreen extends StatefulWidget {
  final Profile employee;

  const AdminEmployeeDetailScreen({super.key, required this.employee});

  @override
  State<AdminEmployeeDetailScreen> createState() => _AdminEmployeeDetailScreenState();
}

class _AdminEmployeeDetailScreenState extends State<AdminEmployeeDetailScreen> {
  final _adminService = AdminService();
  final _reportService = ReportService();

  // The app's data starts in August 2026 - no earlier month has any
  // sessions to report/list.
  static final DateTime _minMonth = DateTime(2026, 8);

  late UserStatus _status = widget.employee.status;
  bool _isUpdatingStatus = false;
  bool _changed = false;
  String? _error;

  late DateTime _reportMonth = _clampToMonthRange(
    DateTime(DateTime.now().year, DateTime.now().month),
  );
  bool _isGeneratingReport = false;

  late DateTime _sessionsMonth = _clampToMonthRange(
    DateTime(DateTime.now().year, DateTime.now().month),
  );
  List<WorkSession> _sessions = [];
  bool _isLoadingSessions = false;
  bool _hasListedSessions = false;

  static DateTime _clampToMonthRange(DateTime month) {
    final maxMonth = DateTime(DateTime.now().year, DateTime.now().month);
    if (month.isBefore(_minMonth)) return _minMonth;
    if (month.isAfter(maxMonth)) return maxMonth;
    return month;
  }

  void _changeSessionsMonth(int delta) {
    final next = _clampToMonthRange(
      DateTime(_sessionsMonth.year, _sessionsMonth.month + delta),
    );
    if (next == _sessionsMonth) return;
    // The list on screen would otherwise still show the previous month's
    // sessions under a now-different month selector - hide it until the
    // admin explicitly lists this month too.
    setState(() {
      _sessionsMonth = next;
      _hasListedSessions = false;
      _sessions = [];
    });
  }

  Future<void> _listSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _error = null;
    });

    try {
      final sessions = await _adminService.fetchEmployeeSessionsForMonth(
        employeeId: widget.employee.employeeId,
        monthStart: _sessionsMonth,
        monthEndExclusive: DateTime(_sessionsMonth.year, _sessionsMonth.month + 1),
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _hasListedSessions = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load sessions. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  /// Pull-to-refresh: only re-fetches if a month is already listed - there
  /// is nothing to refresh before the admin has pressed List Work Sessions.
  Future<void> _refresh() async {
    if (_hasListedSessions) await _listSessions();
  }

  Future<void> _confirmToggleStatus() async {
    final activating = _status == UserStatus.inactive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          activating ? 'Activate this account?' : 'Deactivate this account?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          activating
              ? '${widget.employee.fullName} will be able to sign in and start work sessions again.'
              : '${widget.employee.fullName} will no longer be able to sign in or start work sessions.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: activating
                ? null
                : ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activating ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _toggleStatus(activating);
    }
  }

  Future<void> _confirmResetPassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Reset this password?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          "${widget.employee.fullName}'s password will be reset to the temporary "
          'password "123456". Let them know so they can sign in and change it from '
          'their Profile.',
          style: const TextStyle(color: AppColors.textSecondary),
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
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetPassword();
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _error = null);

    try {
      await _adminService.resetEmployeePassword(widget.employee.employeeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset to the temporary password "123456".')),
      );
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    }
  }

  Future<void> _toggleStatus(bool activate) async {
    setState(() {
      _isUpdatingStatus = true;
      _error = null;
    });

    try {
      await _adminService.setEmployeeStatus(
        employeeId: widget.employee.employeeId,
        active: activate,
      );
      if (!mounted) return;
      setState(() {
        _status = activate ? UserStatus.active : UserStatus.inactive;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activate ? 'Account activated.' : 'Account deactivated.')),
      );
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _changeReportMonth(int delta) {
    final next = _clampToMonthRange(
      DateTime(_reportMonth.year, _reportMonth.month + delta),
    );
    if (next == _reportMonth) return;
    setState(() => _reportMonth = next);
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGeneratingReport = true;
      _error = null;
    });

    try {
      final sessions = await _adminService.fetchEmployeeSessionsForMonth(
        employeeId: widget.employee.employeeId,
        monthStart: _reportMonth,
        monthEndExclusive: DateTime(_reportMonth.year, _reportMonth.month + 1),
      );
      await _reportService.generateMonthlyReport(
        employee: widget.employee,
        month: _reportMonth,
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
      setState(() => _error = 'Could not generate the report. Please try again.');
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  Future<void> _editSession(WorkSession session) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminSessionEditScreen(session: session)),
    );
    if (changed == true) {
      await _listSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Session updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _status == UserStatus.active;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.employee.fullName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
      ),
      body: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
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
                          widget.employee.fullName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isActive ? AppColors.success : AppColors.error)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: isActive ? AppColors.success : AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Employee ID: ${widget.employee.employeeId}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isUpdatingStatus ? null : _confirmToggleStatus,
                style: isActive
                    ? ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: _isUpdatingStatus
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isActive ? Colors.white : Colors.black,
                        ),
                      )
                    : Text(isActive ? 'DEACTIVATE ACCOUNT' : 'ACTIVATE ACCOUNT'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _confirmResetPassword,
                child: const Text('RESET PASSWORD'),
              ),
              const SizedBox(height: 28),
              const Text(
                'WORK SESSIONS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MONTHLY REPORT',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MonthSelector(
                      month: _reportMonth,
                      minMonth: _minMonth,
                      onChange: _isGeneratingReport ? null : _changeReportMonth,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingReport ? null : _generateReport,
                      icon: _isGeneratingReport
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(_isGeneratingReport ? 'Generating…' : 'Generate Report (PDF)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'VIEW SESSIONS',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MonthSelector(
                      month: _sessionsMonth,
                      minMonth: _minMonth,
                      onChange: _isLoadingSessions ? null : _changeSessionsMonth,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isLoadingSessions ? null : _listSessions,
                      icon: _isLoadingSessions
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.list_alt_outlined, size: 18),
                      label: Text(_isLoadingSessions ? 'Loading…' : 'List Work Sessions'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!_hasListedSessions)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: Text(
                      'Choose a month and tap "List Work Sessions" to view them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else if (_sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: Text(
                      'No completed sessions for this month.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ..._sessions.map((session) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SessionRow(
                        session: session,
                        onTap: () => _editSession(session),
                      ),
                    )),
            ],
          ),
        ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final WorkSession session;
  final VoidCallback onTap;

  const _SessionRow({required this.session, required this.onTap});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

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
    return status == 'Verified' ? AppColors.success : AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final status = session.verificationStatus;
    final endedAt = session.endedAt!;
    final statusColor = _statusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
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
            '${_formatTime(session.startedAt)} → ${_formatTime(endedAt)}  ·  '
            '${_formatDuration(session.startedAt, endedAt)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final DateTime minMonth;
  final ValueChanged<int>? onChange;

  const _MonthSelector({required this.month, required this.minMonth, this.onChange});

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  bool get _isMinMonth => month.year == minMonth.year && month.month == minMonth.month;

  bool get _isMaxMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          tooltip: 'Previous month',
          onPressed: (onChange == null || _isMinMonth) ? null : () => onChange!(-1),
        ),
        Text(
          '${_monthNames[month.month - 1]} ${month.year}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          tooltip: 'Next month',
          onPressed: (onChange == null || _isMaxMonth) ? null : () => onChange!(1),
        ),
      ],
    );
  }
}

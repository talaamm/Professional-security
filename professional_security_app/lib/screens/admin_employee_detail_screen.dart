import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../models/work_session.dart';
import '../services/admin_service.dart';
import '../widgets/error_banner.dart';
import 'admin_session_edit_screen.dart';

/// Admin's view of one employee: their details, an activate/deactivate
/// control, and their completed work sessions since they started. The
/// month/year filter and report download are UI-only placeholders for now,
/// per your instructions - wiring them up is a later task.
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

  late UserStatus _status = widget.employee.status;
  List<WorkSession> _sessions = [];
  bool _isLoadingSessions = true;
  bool _isUpdatingStatus = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _error = null;
    });

    try {
      final sessions = await _adminService.fetchEmployeeSessions(widget.employee.employeeId);
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load sessions. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
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

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  Future<void> _editSession(WorkSession session) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminSessionEditScreen(session: session)),
    );
    if (changed == true) {
      await _loadSessions();
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
          onRefresh: _loadSessions,
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _comingSoon('Filtering by month'),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Month & Year'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _comingSoon('Downloading a report'),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingSessions)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text(
                      'No completed sessions yet.',
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

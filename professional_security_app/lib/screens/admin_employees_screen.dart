import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/issue_report.dart';
import '../models/password_reset_request.dart';
import '../models/profile.dart';
import '../services/admin_service.dart';
import '../services/app_strings.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/error_banner.dart';
import 'admin_employee_detail_screen.dart';

/// Employees tab: open issue reports at the top (raised via the employee
/// Home screen's "Having Issue? Tell the admin" button), then search for
/// an employee by name or employee ID (case-insensitive, substring match -
/// works for Arabic/Hebrew names the same as Latin ones). An ID search
/// naturally returns just the one matching employee since employee_id is
/// unique; a name search returns everyone whose name contains that text.
class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final _adminService = AdminService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Profile> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;

  List<IssueReport> _issues = [];
  bool _isLoadingIssues = true;
  String? _issuesError;

  List<PasswordResetRequest> _resetRequests = [];
  bool _isLoadingResetRequests = true;
  String? _resetRequestsError;

  @override
  void initState() {
    super.initState();
    _loadIssues();
    _loadResetRequests();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoadingIssues = true;
      _issuesError = null;
    });

    try {
      final issues = await _adminService.fetchOpenIssues();
      if (!mounted) return;
      setState(() => _issues = issues);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _issuesError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _issuesError = AppStrings.t('admin_employees_could_not_load_issues'));
    } finally {
      if (mounted) setState(() => _isLoadingIssues = false);
    }
  }

  Future<void> _resolveIssue(IssueReport issue) async {
    try {
      await _adminService.resolveIssue(issue.issueId);
      if (!mounted) return;
      setState(() => _issues.removeWhere((i) => i.issueId == issue.issueId));
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('common_something_wrong'))),
      );
    }
  }

  Future<void> _loadResetRequests() async {
    setState(() {
      _isLoadingResetRequests = true;
      _resetRequestsError = null;
    });

    try {
      final requests = await _adminService.fetchOpenPasswordResetRequests();
      if (!mounted) return;
      setState(() => _resetRequests = requests);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _resetRequestsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resetRequestsError = AppStrings.t('admin_employees_could_not_load_resets'));
    } finally {
      if (mounted) setState(() => _isLoadingResetRequests = false);
    }
  }

  Future<void> _resolveResetRequest(PasswordResetRequest request) async {
    try {
      await _adminService.resolvePasswordResetRequest(request.requestId);
      if (!mounted) return;
      setState(() => _resetRequests.removeWhere((r) => r.requestId == request.requestId));
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('common_something_wrong'))),
      );
    }
  }

  Future<void> _openEmployeeById(String employeeId) async {
    try {
      final employee = await _adminService.fetchEmployeeByEmployeeId(employeeId);
      if (!mounted) return;
      if (employee == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('admin_employees_employee_not_found'))),
        );
        return;
      }
      await _openEmployee(employee);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
    });

    try {
      final results = await _adminService.searchEmployees(trimmed);
      if (!mounted) return;
      setState(() => _results = results);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchError = AppStrings.t('common_something_wrong'));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _openEmployee(Profile employee) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminEmployeeDetailScreen(employee: employee)),
    );
    // The detail screen's Reset Password action auto-resolves that
    // employee's open request server-side without telling this screen -
    // reload both queues so a stale, already-resolved row doesn't linger
    // (and fail with "already resolved") after coming back from it.
    await Future.wait([_loadIssues(), _loadResetRequests()]);
    if (changed == true) {
      await _search(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppStrings.t('admin_employees_title'))),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => Future.wait([_loadIssues(), _loadResetRequests()]),
        child: (_isLoadingIssues || _isLoadingResetRequests)
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_issuesError != null) ...[
                    ErrorBanner(message: _issuesError!),
                    const SizedBox(height: 16),
                  ],
                  if (_resetRequestsError != null) ...[
                    ErrorBanner(message: _resetRequestsError!),
                    const SizedBox(height: 16),
                  ],
                  DashboardSection(
                    title: AppStrings.t('admin_employees_password_reset_section'),
                    count: _resetRequests.length,
                    emptyText: AppStrings.t('admin_employees_no_reset_requests'),
                    children: _resetRequests
                        .map((request) => _PasswordResetTile(
                              request: request,
                              onTap: () => _openEmployeeById(request.employeeId),
                              onDone: () => _resolveResetRequest(request),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  DashboardSection(
                    title: AppStrings.t('admin_employees_reported_issues_section'),
                    count: _issues.length,
                    emptyText: AppStrings.t('admin_employees_no_issues'),
                    children: _issues
                        .map((issue) => _IssueTile(
                              issue: issue,
                              onTap: () => _openEmployeeById(issue.employeeId),
                              onDone: () => _resolveIssue(issue),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: AppStrings.t('admin_employees_search_hint'),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    ),
                    onChanged: _onQueryChanged,
                  ),
                  const SizedBox(height: 16),
                  if (_searchError != null) ...[
                    ErrorBanner(message: _searchError!),
                    const SizedBox(height: 16),
                  ],
                  _buildResults(),
                ],
              ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (!_hasSearched) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            AppStrings.t('admin_employees_search_prompt'),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(AppStrings.t('admin_employees_no_matches'),
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final employee in _results) ...[
          _EmployeeCard(employee: employee, onTap: () => _openEmployee(employee)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PasswordResetTile extends StatelessWidget {
  final PasswordResetRequest request;
  final VoidCallback onTap;
  final VoidCallback onDone;

  const _PasswordResetTile({required this.request, required this.onTap, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        '${request.employeeName}  ·  ${request.employeeId}',
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        request.message ?? AppStrings.t('admin_employees_no_message'),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: OutlinedButton(
        // Overrides the app theme's default minimumSize: Size.fromHeight(52) -
        // see the identical note on _IssueTile below.
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 36)),
        onPressed: onDone,
        child: Text(AppStrings.t('common_done')),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final IssueReport issue;
  final VoidCallback onTap;
  final VoidCallback onDone;

  const _IssueTile({required this.issue, required this.onTap, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        '${issue.employeeName}  ·  ${issue.employeeId}',
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(issue.message, style: const TextStyle(color: AppColors.textSecondary)),
      trailing: OutlinedButton(
        // Overrides the app theme's default minimumSize: Size.fromHeight(52),
        // which sets width to double.infinity for full-width buttons - fatal
        // here, since ListTile.trailing needs to measure a finite intrinsic
        // width for this widget.
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 36)),
        onPressed: onDone,
        child: Text(AppStrings.t('common_done')),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Profile employee;
  final VoidCallback onTap;

  const _EmployeeCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = employee.status == UserStatus.active;

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
                    employee.fullName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.t('admin_employees_id_prefix', {'id': employee.employeeId}),
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

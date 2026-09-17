import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/issue_report.dart';
import '../models/monthly_active_employee.dart';
import '../models/password_reset_request.dart';
import '../models/profile.dart';
import '../services/admin_service.dart';
import '../services/app_strings.dart';
import '../services/report_service.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/error_banner.dart';
import 'admin_employee_detail_screen.dart';
import 'admin_register_employee_screen.dart';

const int _monthlyPageSize = 5;

/// Employees tab: for a super admin, administrator accounts at the very
/// top (see _loadAdmins) - super admins have the same control over admin
/// accounts that admins have over employees, one tier down only (see
/// db_files/phase7-admin-self-sessions-and-super-admin.sql). Then open
/// issue reports (raised via the employee Home screen's "Having Issue?
/// Tell the admin" button), then search for an employee by name or
/// employee ID (case-insensitive, substring match - works for Arabic/
/// Hebrew names the same as Latin ones). An ID search naturally returns
/// just the one matching employee since employee_id is unique; a name
/// search returns everyone whose name contains that text.
class AdminEmployeesScreen extends StatefulWidget {
  final Profile profile;

  const AdminEmployeesScreen({super.key, required this.profile});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final _adminService = AdminService();
  final _reportService = ReportService();
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

  List<Profile> _admins = [];
  bool _isLoadingAdmins = true;
  String? _adminsError;

  List<MonthlyActiveEmployee> _monthlyEmployees = [];
  bool _monthlyLoaded = false;
  bool _isLoadingMonthly = false;
  bool _isLoadingMoreMonthly = false;
  bool _isDownloadingMonthly = false;
  String? _monthlyError;
  bool _monthlyHasMore = true;

  bool get _isSuperAdmin => widget.profile.role == UserRole.superAdmin;

  @override
  void initState() {
    super.initState();
    _loadIssues();
    _loadResetRequests();
    if (_isSuperAdmin) _loadAdmins();
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

  Future<void> _loadAdmins() async {
    setState(() {
      _isLoadingAdmins = true;
      _adminsError = null;
    });

    try {
      final admins = await _adminService.fetchAllAdmins();
      if (!mounted) return;
      setState(() => _admins = admins);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _adminsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _adminsError = AppStrings.t('admin_employees_could_not_load_admins'));
    } finally {
      if (mounted) setState(() => _isLoadingAdmins = false);
    }
  }

  /// Lazily triggered the first time the "Employees of This Month" section
  /// is expanded - never queried just because the tab loaded.
  void _onMonthlyExpansionChanged(bool expanded) {
    if (expanded && !_monthlyLoaded && !_isLoadingMonthly) {
      _fetchMonthlyEmployees(_monthlyPageSize);
    }
  }

  Future<void> _fetchMonthlyEmployees(int limit) async {
    setState(() {
      _isLoadingMonthly = true;
      _monthlyError = null;
    });

    try {
      final employees = await _adminService.fetchMonthlyActiveEmployees(limit: limit);
      if (!mounted) return;
      setState(() {
        _monthlyEmployees = employees;
        _monthlyHasMore = employees.length == limit;
        _monthlyLoaded = true;
      });
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _monthlyError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _monthlyError = AppStrings.t('admin_employees_monthly_could_not_load'));
    } finally {
      if (mounted) setState(() => _isLoadingMonthly = false);
    }
  }

  /// Re-fetches the same number of rows already on screen - a no-op if the
  /// section was never expanded, so pull-to-refresh doesn't query it either.
  Future<void> _refreshMonthlyEmployeesIfLoaded() {
    if (!_monthlyLoaded) return Future.value();
    final limit =
        _monthlyEmployees.length < _monthlyPageSize ? _monthlyPageSize : _monthlyEmployees.length;
    return _fetchMonthlyEmployees(limit);
  }

  Future<void> _loadMoreMonthlyEmployees() async {
    setState(() {
      _isLoadingMoreMonthly = true;
      _monthlyError = null;
    });

    try {
      final more = await _adminService.fetchMonthlyActiveEmployees(
        limit: _monthlyPageSize,
        offset: _monthlyEmployees.length,
      );
      if (!mounted) return;
      setState(() {
        _monthlyEmployees = [..._monthlyEmployees, ...more];
        _monthlyHasMore = more.length == _monthlyPageSize;
      });
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _monthlyError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _monthlyError = AppStrings.t('admin_employees_monthly_could_not_load'));
    } finally {
      if (mounted) setState(() => _isLoadingMoreMonthly = false);
    }
  }

  Future<void> _downloadMonthlyList() async {
    setState(() => _isDownloadingMonthly = true);
    try {
      final allEmployees = await _adminService.fetchMonthlyActiveEmployees();
      await _reportService.generateMonthlyActiveEmployeesReport(
        month: DateTime.now(),
        employees: allEmployees,
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ReportServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('common_something_wrong'))),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingMonthly = false);
    }
  }

  Future<void> _openAdmin(Profile admin) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminEmployeeDetailScreen(employee: admin, viewerRole: widget.profile.role),
      ),
    );
    await _loadAdmins();
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

  Future<void> _openRegisterEmployee() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminRegisterEmployeeScreen()),
    );
    if (created == true) {
      await _search(_searchController.text);
    }
  }

  Future<void> _openEmployee(Profile employee) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminEmployeeDetailScreen(employee: employee, viewerRole: widget.profile.role),
      ),
    );
    // The detail screen's Reset Password action auto-resolves that
    // employee's open request server-side without telling this screen -
    // reload both queues so a stale, already-resolved row doesn't linger
    // (and fail with "already resolved") after coming back from it.
    await Future.wait([
      _loadIssues(),
      _loadResetRequests(),
      // A promotion to admin only shows up here, not in an employee
      // search - reload it too so it appears without needing to leave
      // and reopen this tab.
      if (_isSuperAdmin) _loadAdmins(),
      _refreshMonthlyEmployeesIfLoaded(),
    ]);
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
        onRefresh: () => Future.wait([
          _loadIssues(),
          _loadResetRequests(),
          if (_isSuperAdmin) _loadAdmins(),
          _refreshMonthlyEmployeesIfLoaded(),
        ]),
        child: (_isLoadingIssues || _isLoadingResetRequests || (_isSuperAdmin && _isLoadingAdmins))
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ElevatedButton.icon(
                    onPressed: _openRegisterEmployee,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(AppStrings.t('admin_employees_register_button')),
                  ),
                  const SizedBox(height: 16),
                  if (_isSuperAdmin) ...[
                    if (_adminsError != null) ...[
                      ErrorBanner(message: _adminsError!),
                      const SizedBox(height: 16),
                    ],
                    DashboardSection(
                      title: AppStrings.t('admin_employees_administrators_section'),
                      count: _admins.length,
                      emptyText: AppStrings.t('admin_employees_no_admins'),
                      children: _admins
                          .map((admin) => _AdminTile(
                                admin: admin,
                                onTap: () => _openAdmin(admin),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                  const SizedBox(height: 16),
                  _buildMonthlySection(),
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

  Widget _buildMonthlySection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          onExpansionChanged: _onMonthlyExpansionChanged,
          title: Text(
            AppStrings.t('admin_employees_monthly_section'),
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          children: [_buildMonthlyContent()],
        ),
      ),
    );
  }

  Widget _buildMonthlyContent() {
    if (_isLoadingMonthly) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (!_monthlyLoaded) {
      // Only reached if the initial fetch failed outright (see
      // _fetchMonthlyEmployees's catch branches) - _onMonthlyExpansionChanged
      // already triggered it, so this isn't a real "not loaded yet" state.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ErrorBanner(message: _monthlyError ?? AppStrings.t('common_something_wrong')),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _isDownloadingMonthly ? null : _downloadMonthlyList,
            icon: _isDownloadingMonthly
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(AppStrings.t('admin_employees_monthly_download_button')),
          ),
          const SizedBox(height: 12),
          if (_monthlyError != null) ...[
            ErrorBanner(message: _monthlyError!),
            const SizedBox(height: 12),
          ],
          if (_monthlyEmployees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppStrings.t('admin_employees_monthly_empty'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final employee in _monthlyEmployees) ...[
              _MonthlyEmployeeTile(
                employee: employee,
                onTap: () => _openEmployeeById(employee.employeeId),
              ),
            ],
          if (_monthlyHasMore) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isLoadingMoreMonthly ? null : _loadMoreMonthlyEmployees,
              child: _isLoadingMoreMonthly
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(AppStrings.t('admin_employees_monthly_load_more')),
            ),
          ],
        ],
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

class _MonthlyEmployeeTile extends StatelessWidget {
  final MonthlyActiveEmployee employee;
  final VoidCallback onTap;

  const _MonthlyEmployeeTile({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        employee.fullName,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        AppStrings.t('admin_employees_id_prefix', {'id': employee.employeeId}),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: Text(
        AppStrings.t('admin_employees_monthly_sessions_count', {'count': '${employee.sessionCount}'}),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final Profile admin;
  final VoidCallback onTap;

  const _AdminTile({required this.admin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = admin.status == UserStatus.active;

    return ListTile(
      onTap: onTap,
      title: Text(
        admin.fullName,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        AppStrings.t('admin_employees_id_prefix', {'id': admin.employeeId}),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
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

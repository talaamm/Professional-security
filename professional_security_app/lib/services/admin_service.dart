import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/active_employee_session.dart';
import '../models/issue_report.dart';
import '../models/password_reset_request.dart';
import '../models/profile.dart';
import '../models/unverified_session.dart';
import '../models/work_session.dart';
import '../models/workplace.dart';

/// User-facing error with a safe, already-translated message.
class AdminServiceException implements Exception {
  final String message;
  AdminServiceException(this.message);

  @override
  String toString() => message;
}

/// Admin dashboard reads/actions. Every call goes through a SECURITY
/// DEFINER database function (see db_files/phase6-admin-dashboard.sql)
/// that explicitly checks is_admin() itself - the client role is never
/// trusted for who can see other employees' sessions or mark one verified.
class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ActiveEmployeeSession>> fetchActiveSessions() async {
    try {
      final data = await _client.rpc('admin_active_sessions');
      return (data as List)
          .map((row) => ActiveEmployeeSession.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  Future<List<UnverifiedSession>> fetchUnverifiedSessions() async {
    try {
      final data = await _client.rpc('admin_unverified_sessions');
      return (data as List)
          .map((row) => UnverifiedSession.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Marks [sessionId] verified. [startLocationName]/[endLocationName] only
  /// need to be passed for the side(s) that needed review - the backend
  /// keeps the employee's original claimed text for anything left null.
  Future<void> verifySession({
    required String sessionId,
    String? startLocationName,
    String? endLocationName,
    String? note,
  }) async {
    try {
      await _client.rpc('admin_verify_session', params: {
        'p_session_id': sessionId,
        'p_start_location_name': startLocationName,
        'p_end_location_name': endLocationName,
        'p_note': note,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Employee accounts (role = 'employee') whose employee_id or full_name
  /// contains [query] (case-insensitive, Unicode-safe - works the same for
  /// Arabic/Hebrew names as it does for Latin ones). Relies on the existing
  /// profiles_select_admin RLS policy.
  Future<List<Profile>> searchEmployees(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final byId = await _client
          .from('profiles')
          .select()
          .eq('role', 'employee')
          .ilike('employee_id', '%$q%');
      final byName = await _client
          .from('profiles')
          .select()
          .eq('role', 'employee')
          .ilike('full_name', '%$q%');

      final seen = <String>{};
      final results = <Profile>[];
      for (final row in [...byId, ...byName]) {
        final profile = Profile.fromMap(row);
        if (seen.add(profile.employeeId)) results.add(profile);
      }
      results.sort((a, b) => a.fullName.compareTo(b.fullName));
      return results;
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// One employee's completed sessions, newest first. Relies on the
  /// existing work_sessions_select_admin RLS policy (admins can view all
  /// sessions) - a non-admin caller would just get an empty list, but this
  /// is only ever reached from the admin-only Employees tab.
  Future<List<WorkSession>> fetchEmployeeSessions(String employeeId) async {
    try {
      final data = await _client
          .from('work_sessions')
          .select('*, workplaces(name)')
          .eq('employee_id', employeeId)
          .not('ended_at', 'is', null)
          .order('started_at', ascending: false);
      return (data as List)
          .map((row) => WorkSession.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Activates/deactivates an employee account. Blocked server-side for
  /// non-employee accounts and for an admin targeting their own account.
  Future<void> setEmployeeStatus({
    required String employeeId,
    required bool active,
    String? reason,
  }) async {
    try {
      await _client.rpc('admin_set_employee_status', params: {
        'p_employee_id': employeeId,
        'p_status': active ? 'active' : 'inactive',
        'p_reason': reason,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Terminates an employee's still-active session from the dashboard.
  /// Recorded as source = 'admin' with end_verification = 'manual' (there's
  /// no GPS reading from an admin acting remotely), so it lands in the
  /// unverified-sessions queue for proper follow-up.
  Future<void> endActiveSession({required String sessionId, String? reason}) async {
    try {
      await _client.rpc('admin_end_work_session', params: {
        'p_session_id': sessionId,
        'p_reason': reason,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// All workplaces (active or not) - an admin correcting historical data
  /// may need to assign a since-deactivated/temporary workplace. Relies on
  /// the existing workplaces_select_admin RLS policy.
  Future<List<Workplace>> fetchWorkplaces() async {
    try {
      final data = await _client.from('workplaces').select('id, name').order('name');
      return (data as List)
          .map((row) => Workplace.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// All workplaces (active and inactive), name-sorted, for the admin
  /// Workplaces tab. Relies on the existing workplaces_select_admin RLS
  /// policy.
  Future<List<Workplace>> fetchAllWorkplaces() async {
    try {
      final data = await _client.from('workplaces').select().order('name');
      return (data as List)
          .map((row) => Workplace.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Creates a workplace. Unlike every other admin write in this app,
  /// there's no SECURITY DEFINER function here - workplaces_insert_admin
  /// (db-schema-V2.sql section 19) already lets an admin insert directly,
  /// as long as created_by is their own employee_id.
  Future<void> createWorkplace({
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String type,
    required String createdBy,
  }) async {
    try {
      await _client.from('workplaces').insert({
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'type': type,
        'created_by': createdBy,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Updates a workplace's name/radius/type. [latitude]/[longitude] are
  /// only included when the admin recalibrated at the current location -
  /// omitting them leaves the stored coordinates untouched.
  Future<void> updateWorkplace({
    required String id,
    required String name,
    required int radiusMeters,
    required String type,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _client.from('workplaces').update({
        'name': name,
        'radius_meters': radiusMeters,
        'type': type,
        'latitude': ?latitude,
        'longitude': ?longitude,
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Activates/deactivates a workplace. There is no DELETE policy for this
  /// table by design (db-schema-V2.sql section 19) - historical sessions
  /// must keep referencing it, so "remove" always means deactivate.
  Future<void> setWorkplaceStatus({required String id, required bool active}) async {
    try {
      await _client.from('workplaces').update({
        'status': active ? 'active' : 'inactive',
        'deactivated_at': active ? null : DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Corrects a completed session's start/end time and workplace/location.
  /// Either [workplaceId] or [manualLocationName] must be given. Marks both
  /// sides verified, by this admin - they're now vouching for the data.
  Future<void> editSession({
    required String sessionId,
    required DateTime startedAt,
    required DateTime endedAt,
    String? workplaceId,
    String? manualLocationName,
    String? reason,
  }) async {
    try {
      await _client.rpc('admin_edit_work_session', params: {
        'p_session_id': sessionId,
        'p_started_at': startedAt.toUtc().toIso8601String(),
        'p_ended_at': endedAt.toUtc().toIso8601String(),
        'p_workplace_id': workplaceId,
        'p_manual_location_name': manualLocationName,
        'p_reason': reason,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Permanently deletes a completed session. [reason] is required - this
  /// is irreversible; the full row is preserved in audit_logs regardless.
  Future<void> deleteSession({required String sessionId, required String reason}) async {
    try {
      await _client.rpc('admin_delete_work_session', params: {
        'p_session_id': sessionId,
        'p_reason': reason,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Open issue reports for the Employees tab, oldest first.
  Future<List<IssueReport>> fetchOpenIssues() async {
    try {
      final data = await _client.rpc('admin_list_open_issues');
      return (data as List)
          .map((row) => IssueReport.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  Future<void> resolveIssue(String issueId) async {
    try {
      await _client.rpc('admin_resolve_issue', params: {'p_issue_id': issueId});
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// How many employee accounts (role = 'employee') are currently active -
  /// for the admin Profile screen. Not "in a work session right now", just
  /// "able to sign in and work" (status = 'active').
  Future<int> fetchActiveEmployeeCount() async {
    try {
      final response = await _client
          .from('profiles')
          .select('employee_id')
          .eq('role', 'employee')
          .eq('status', 'active')
          .count(CountOption.exact);
      return response.count;
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Resets [employeeId]'s password to the fixed default "123456" (see
  /// db_files/phase7-password-reset.sql) and auto-resolves any open
  /// password reset request for them.
  Future<void> resetEmployeePassword(String employeeId) async {
    try {
      await _client.rpc('admin_reset_employee_password', params: {
        'p_employee_id': employeeId,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Open password reset requests for the Employees tab, oldest first.
  Future<List<PasswordResetRequest>> fetchOpenPasswordResetRequests() async {
    try {
      final data = await _client.rpc('admin_list_open_password_reset_requests');
      return (data as List)
          .map((row) => PasswordResetRequest.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// Dismisses a password reset request without resetting the password
  /// (e.g. a duplicate, or it was already handled another way).
  Future<void> resolvePasswordResetRequest(String requestId) async {
    try {
      await _client.rpc('admin_resolve_password_reset_request', params: {
        'p_request_id': requestId,
      });
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }

  /// One employee's profile by employee_id - used to open the same detail
  /// screen from an issue report card that searching-then-tapping would.
  /// Relies on the existing profiles_select_admin RLS policy.
  Future<Profile?> fetchEmployeeByEmployeeId(String employeeId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('employee_id', employeeId)
          .maybeSingle();
      if (data == null) return null;
      return Profile.fromMap(data);
    } on PostgrestException catch (e) {
      throw AdminServiceException(e.message);
    }
  }
}

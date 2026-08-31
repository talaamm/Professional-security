import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/work_session.dart';
import '../models/workplace_match.dart';

/// User-facing error with a safe, already-translated message.
class WorkSessionException implements Exception {
  final String message;
  WorkSessionException(this.message);

  @override
  String toString() => message;
}

/// Starting/ending a session always goes through the start_work_session()
/// and end_work_session() database functions (see
/// db_files/phase3-session-functions.sql and
/// db_files/phase4-workplace-detection.sql) - the client has no
/// insert/update access to work_sessions, so it can never set its own
/// timestamps or claim a workplace it isn't actually near.
class WorkSessionService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<WorkSession?> fetchActiveSession(String employeeId) async {
    final data = await _client
        .from('work_sessions')
        .select('*, workplaces(name)')
        .eq('employee_id', employeeId)
        .isFilter('ended_at', null)
        .maybeSingle();

    if (data == null) return null;
    return WorkSession.fromMap(data);
  }

  /// How many of this employee's sessions have ended - relies on the
  /// existing work_sessions_select_own RLS policy, same as every other
  /// employee-scoped read here.
  Future<int> countCompletedSessions(String employeeId) async {
    final response = await _client
        .from('work_sessions')
        .select('id')
        .eq('employee_id', employeeId)
        .not('ended_at', 'is', null)
        .count(CountOption.exact);
    return response.count;
  }

  /// This employee's sessions started within [monthStart, monthEndExclusive),
  /// newest first. Goes through list_my_sessions_for_month() (see
  /// db_files/phase6-fix-history-verified-by.sql) rather than a plain
  /// client-side select: that function resolves the caller's employee_id
  /// itself from auth.uid() (never trusting a client-passed id) and can
  /// safely join the verifying admin's name, which a plain select can't -
  /// profiles has no RLS policy letting an employee read another
  /// employee/admin's profile row.
  Future<List<WorkSession>> fetchSessionsForMonth({
    required DateTime monthStart,
    required DateTime monthEndExclusive,
  }) async {
    try {
      final data = await _client.rpc('list_my_sessions_for_month', params: {
        'p_month_start': monthStart.toUtc().toIso8601String(),
        'p_month_end_exclusive': monthEndExclusive.toUtc().toIso8601String(),
      });
      return (data as List)
          .map((row) => WorkSession.fromMonthRow(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }

  /// Active workplaces within their own configured radius of the given
  /// coordinates, closest first. Purely informational for the picker UI -
  /// start_work_session() re-validates the distance itself.
  Future<List<WorkplaceMatch>> findNearbyWorkplaces({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final data = await _client.rpc('find_nearby_workplaces', params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
      });
      return (data as List)
          .map((row) => WorkplaceMatch.fromMap(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }

  /// Either [workplaceId] (a detected/confirmed workplace) or
  /// [manualLocationName] (no workplace detected) must be provided.
  Future<WorkSession> startWorkSession({
    required double latitude,
    required double longitude,
    required double accuracy,
    String? workplaceId,
    String? manualLocationName,
  }) async {
    try {
      final data = await _client.rpc('start_work_session', params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy': accuracy,
        'p_workplace_id': workplaceId,
        'p_manual_location_name': manualLocationName,
      });
      return WorkSession.fromMap(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }

  /// Force-ends the caller's active session with no GPS check, for the
  /// "logging out while working" warning flow (see
  /// lib/widgets/logout_helper.dart). Always lands as
  /// end_verification = 'manual', pending admin review - see
  /// db_files/phase7-logout-ends-session.sql.
  Future<WorkSession> endSessionForLogout() async {
    try {
      final data = await _client.rpc('end_work_session_for_logout');
      return WorkSession.fromMap(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }

  /// Ends the caller's active session. The backend checks [latitude]/
  /// [longitude] against the workplace recorded when that session started;
  /// if it doesn't match (or that workplace was never recognized), it
  /// throws with message 'LOCATION_MISMATCH' and the caller must resubmit
  /// with [manualLocationName], which ends the session as manual/unverified.
  Future<WorkSession> endWorkSession({
    required double latitude,
    required double longitude,
    required double accuracy,
    String? manualLocationName,
  }) async {
    try {
      final data = await _client.rpc('end_work_session', params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy': accuracy,
        'p_manual_location_name': manualLocationName,
      });
      return WorkSession.fromMap(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }
}

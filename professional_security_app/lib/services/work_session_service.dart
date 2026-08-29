import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/work_session.dart';

/// User-facing error with a safe, already-translated message.
class WorkSessionException implements Exception {
  final String message;
  WorkSessionException(this.message);

  @override
  String toString() => message;
}

/// Starting/ending a session always goes through the start_work_session()
/// and end_work_session() database functions (see
/// db_files/phase3-session-functions.sql) - the client has no insert/update
/// access to work_sessions, so it can never set its own timestamps.
class WorkSessionService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<WorkSession?> fetchActiveSession(String employeeId) async {
    final data = await _client
        .from('work_sessions')
        .select()
        .eq('employee_id', employeeId)
        .isFilter('ended_at', null)
        .maybeSingle();

    if (data == null) return null;
    return WorkSession.fromMap(data);
  }

  Future<WorkSession> startWorkSession() async {
    try {
      final data = await _client.rpc('start_work_session');
      return WorkSession.fromMap(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }

  Future<WorkSession> endWorkSession() async {
    try {
      final data = await _client.rpc('end_work_session');
      return WorkSession.fromMap(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }
}

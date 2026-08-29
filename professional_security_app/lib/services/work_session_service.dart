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

  Future<WorkSession> endWorkSession() async {
    try {
      final data = await _client.rpc('end_work_session');
      return WorkSession.fromMap(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw WorkSessionException(e.message);
    }
  }
}

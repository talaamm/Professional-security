import 'package:supabase_flutter/supabase_flutter.dart';

/// User-facing error with a safe, already-translated message.
class IssueServiceException implements Exception {
  final String message;
  IssueServiceException(this.message);

  @override
  String toString() => message;
}

/// Lets an employee send a short note to admins ("Having an issue? Tell
/// the admin"). Goes through report_issue() - the client has no direct
/// insert access to issue_reports, and employee_id is resolved server-side
/// from the caller's session, never taken from the client.
class IssueService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> reportIssue(String message) async {
    try {
      await _client.rpc('report_issue', params: {'p_message': message});
    } on PostgrestException catch (e) {
      throw IssueServiceException(e.message);
    }
  }
}

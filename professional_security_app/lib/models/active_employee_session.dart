/// One row from admin_active_sessions(): an employee currently working,
/// for the admin dashboard's "Currently Working" card.
class ActiveEmployeeSession {
  final String sessionId;
  final String employeeId;
  final String employeeName;
  final String? workplaceName;
  final String? manualLocationName;
  final DateTime startedAt;
  final String startVerification;

  const ActiveEmployeeSession({
    required this.sessionId,
    required this.employeeId,
    required this.employeeName,
    this.workplaceName,
    this.manualLocationName,
    required this.startedAt,
    required this.startVerification,
  });

  String get workplaceLabel => workplaceName ?? manualLocationName ?? 'Unknown';

  bool get isPendingReview => startVerification == 'manual';

  factory ActiveEmployeeSession.fromMap(Map<String, dynamic> map) {
    return ActiveEmployeeSession(
      sessionId: map['session_id'] as String,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      workplaceName: map['workplace_name'] as String?,
      manualLocationName: map['manual_location_name'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      startVerification: map['start_verification'] as String,
    );
  }
}

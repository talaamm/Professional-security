/// One row of admin_workplace_sessions_for_month() - a completed work
/// session at a specific workplace, for any role (employee, admin, or
/// super admin).
class WorkplaceMonthlySession {
  final String sessionId;
  final String employeeId;
  final String employeeName;
  final DateTime startedAt;
  final DateTime endedAt;

  const WorkplaceMonthlySession({
    required this.sessionId,
    required this.employeeId,
    required this.employeeName,
    required this.startedAt,
    required this.endedAt,
  });

  Duration get duration => endedAt.difference(startedAt);

  factory WorkplaceMonthlySession.fromMap(Map<String, dynamic> map) {
    return WorkplaceMonthlySession(
      sessionId: map['session_id'] as String,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: DateTime.parse(map['ended_at'] as String).toLocal(),
    );
  }
}

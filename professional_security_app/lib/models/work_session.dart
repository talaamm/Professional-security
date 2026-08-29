class WorkSession {
  final String id;
  final String employeeId;
  final String? workplaceId;
  final DateTime startedAt;
  final DateTime? endedAt;

  const WorkSession({
    required this.id,
    required this.employeeId,
    this.workplaceId,
    required this.startedAt,
    this.endedAt,
  });

  bool get isActive => endedAt == null;

  factory WorkSession.fromMap(Map<String, dynamic> map) {
    return WorkSession(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      workplaceId: map['workplace_id'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String).toLocal(),
    );
  }
}

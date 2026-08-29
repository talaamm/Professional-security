class WorkSession {
  final String id;
  final String employeeId;
  final String? workplaceId;
  final String? workplaceName;
  final String? manualLocationName;
  final String? startVerification;
  final DateTime startedAt;
  final DateTime? endedAt;

  const WorkSession({
    required this.id,
    required this.employeeId,
    this.workplaceId,
    this.workplaceName,
    this.manualLocationName,
    this.startVerification,
    required this.startedAt,
    this.endedAt,
  });

  bool get isActive => endedAt == null;

  /// The workplace to show the employee, whichever kind was recorded.
  String get workplaceLabel {
    if (workplaceName != null) return workplaceName!;
    if (manualLocationName != null) return manualLocationName!;
    return 'Unknown';
  }

  bool get isPendingReview => startVerification == 'manual';

  factory WorkSession.fromMap(Map<String, dynamic> map) {
    final workplace = map['workplaces'] as Map<String, dynamic>?;
    return WorkSession(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      workplaceId: map['workplace_id'] as String?,
      workplaceName: workplace?['name'] as String?,
      manualLocationName: map['manual_location_name'] as String?,
      startVerification: map['start_verification'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String).toLocal(),
    );
  }
}

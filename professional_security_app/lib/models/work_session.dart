class WorkSession {
  final String id;
  final String employeeId;
  final String? workplaceId;
  final String? workplaceName;
  final String? manualLocationName;
  final String? startVerification;
  final String? endVerification;
  final String? verifiedBy;
  final String? verifiedByName;
  final DateTime startedAt;
  final DateTime? endedAt;

  const WorkSession({
    required this.id,
    required this.employeeId,
    this.workplaceId,
    this.workplaceName,
    this.manualLocationName,
    this.startVerification,
    this.endVerification,
    this.verifiedBy,
    this.verifiedByName,
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

  /// Overall status for display in history: fully verified only when both
  /// the start and end were auto-matched to the recorded workplace -
  /// anything else (manual on either side) is unverified/pending review.
  String get verificationStatus {
    if (isActive) return 'In progress';
    if (startVerification == 'verified' && endVerification == 'verified') {
      return 'Verified';
    }
    return 'Unverified';
  }

  /// Who is vouching for this session, from the viewing employee's own
  /// perspective (session.employeeId is always their own - see
  /// WorkSessionService.fetchSessionsForMonth).
  String? get verifiedByLabel {
    if (isActive) return null;
    if (verifiedBy == null) return 'Pending review';
    if (verifiedBy == employeeId) return 'You';
    return verifiedByName ?? verifiedBy;
  }

  /// From a plain work_sessions select with an embedded `workplaces(name)`
  /// (fetchActiveSession, start/endWorkSession's returned row). Never
  /// carries a verifier name - only list_my_sessions_for_month() does,
  /// via fromMonthRow.
  factory WorkSession.fromMap(Map<String, dynamic> map) {
    final workplace = map['workplaces'] as Map<String, dynamic>?;
    return WorkSession(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      workplaceId: map['workplace_id'] as String?,
      workplaceName: workplace?['name'] as String?,
      manualLocationName: map['manual_location_name'] as String?,
      startVerification: map['start_verification'] as String?,
      endVerification: map['end_verification'] as String?,
      verifiedBy: map['verified_by'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String).toLocal(),
    );
  }

  /// From the flat row shape returned by list_my_sessions_for_month().
  factory WorkSession.fromMonthRow(Map<String, dynamic> map) {
    return WorkSession(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      workplaceId: map['workplace_id'] as String?,
      workplaceName: map['workplace_name'] as String?,
      manualLocationName: map['manual_location_name'] as String?,
      startVerification: map['start_verification'] as String?,
      endVerification: map['end_verification'] as String?,
      verifiedBy: map['verified_by'] as String?,
      verifiedByName: map['verified_by_name'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String).toLocal(),
    );
  }
}

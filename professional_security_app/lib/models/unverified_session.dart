/// One row from admin_unverified_sessions(): a completed session still
/// needing admin review, for the "Unverified Sessions" card.
class UnverifiedSession {
  final String sessionId;
  final String employeeId;
  final String employeeName;
  final String? workplaceName;
  final String? manualLocationName;
  final String? endManualLocationName;
  final DateTime startedAt;
  final DateTime endedAt;
  final String startVerification;
  final String endVerification;

  const UnverifiedSession({
    required this.sessionId,
    required this.employeeId,
    required this.employeeName,
    this.workplaceName,
    this.manualLocationName,
    this.endManualLocationName,
    required this.startedAt,
    required this.endedAt,
    required this.startVerification,
    required this.endVerification,
  });

  bool get startNeedsReview => startVerification != 'verified';
  bool get endNeedsReview => endVerification != 'verified';

  /// The location text the employee claimed at start, if the start needs
  /// review - the value to prefill an admin's correction field with.
  String get claimedStartLocation => manualLocationName ?? '';

  /// The location text the employee claimed at end, if the end needs review.
  String get claimedEndLocation => endManualLocationName ?? '';

  /// Short human explanation of why this session needs review.
  String get reason {
    if (startNeedsReview && endNeedsReview) {
      return 'Start and end location could not be verified';
    }
    if (startNeedsReview) return 'Start location could not be verified';
    return 'End location did not match the start workplace';
  }

  /// Workplace to show for context, whichever kind was recorded at start.
  String get workplaceLabel => workplaceName ?? manualLocationName ?? 'Unknown';

  factory UnverifiedSession.fromMap(Map<String, dynamic> map) {
    return UnverifiedSession(
      sessionId: map['session_id'] as String,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      workplaceName: map['workplace_name'] as String?,
      manualLocationName: map['manual_location_name'] as String?,
      endManualLocationName: map['end_manual_location_name'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: DateTime.parse(map['ended_at'] as String).toLocal(),
      startVerification: map['start_verification'] as String,
      endVerification: map['end_verification'] as String,
    );
  }
}

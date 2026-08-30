/// One open issue report, from admin_list_open_issues().
class IssueReport {
  final String issueId;
  final String employeeId;
  final String employeeName;
  final String message;
  final DateTime createdAt;

  const IssueReport({
    required this.issueId,
    required this.employeeId,
    required this.employeeName,
    required this.message,
    required this.createdAt,
  });

  factory IssueReport.fromMap(Map<String, dynamic> map) {
    return IssueReport(
      issueId: map['issue_id'] as String,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

/// One open password reset request, from
/// admin_list_open_password_reset_requests().
class PasswordResetRequest {
  final String requestId;
  final String employeeId;
  final String employeeName;
  final String? message;
  final DateTime createdAt;

  const PasswordResetRequest({
    required this.requestId,
    required this.employeeId,
    required this.employeeName,
    this.message,
    required this.createdAt,
  });

  factory PasswordResetRequest.fromMap(Map<String, dynamic> map) {
    return PasswordResetRequest(
      requestId: map['request_id'] as String,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      message: map['message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

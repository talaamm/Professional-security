/// One row of admin_monthly_active_employees() - an employee who
/// completed at least one work session in the current calendar month.
class MonthlyActiveEmployee {
  final String employeeId;
  final String fullName;
  final int sessionCount;

  const MonthlyActiveEmployee({
    required this.employeeId,
    required this.fullName,
    required this.sessionCount,
  });

  factory MonthlyActiveEmployee.fromMap(Map<String, dynamic> map) {
    return MonthlyActiveEmployee(
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      sessionCount: (map['session_count'] as num).toInt(),
    );
  }
}

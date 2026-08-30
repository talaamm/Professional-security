enum UserRole { employee, admin, superAdmin }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'super_admin':
      return UserRole.superAdmin;
    default:
      return UserRole.employee;
  }
}

enum UserStatus { active, inactive }

UserStatus userStatusFromString(String value) {
  return value == 'inactive' ? UserStatus.inactive : UserStatus.active;
}

class Profile {
  final String employeeId;
  final String authUserId;
  final String fullName;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;

  const Profile({
    required this.employeeId,
    required this.authUserId,
    required this.fullName,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      employeeId: map['employee_id'] as String,
      authUserId: map['auth_user_id'] as String,
      fullName: map['full_name'] as String,
      role: userRoleFromString(map['role'] as String),
      status: userStatusFromString(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

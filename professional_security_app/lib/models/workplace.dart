/// A workplace an admin can assign a session to. Deliberately minimal -
/// just enough for the admin session-edit picker.
class Workplace {
  final String id;
  final String name;

  const Workplace({required this.id, required this.name});

  factory Workplace.fromMap(Map<String, dynamic> map) {
    return Workplace(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}

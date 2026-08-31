/// A workplace. The admin session-edit picker only ever needs [id]/[name]
/// (fetchWorkplaces() selects just those columns), so the rest are
/// nullable - the admin Workplaces tab (fetchAllWorkplaces()) is what
/// populates the full row.
class Workplace {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final int? radiusMeters;
  final String? type;
  final String? status;

  const Workplace({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.type,
    this.status,
  });

  bool get isActive => status == 'active';
  bool get isPermanent => type == 'permanent';

  factory Workplace.fromMap(Map<String, dynamic> map) {
    return Workplace(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      radiusMeters: map['radius_meters'] as int?,
      type: map['type'] as String?,
      status: map['status'] as String?,
    );
  }
}

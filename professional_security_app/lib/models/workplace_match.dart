class WorkplaceMatch {
  final String workplaceId;
  final String name;
  final double distanceMeters;

  const WorkplaceMatch({
    required this.workplaceId,
    required this.name,
    required this.distanceMeters,
  });

  factory WorkplaceMatch.fromMap(Map<String, dynamic> map) {
    return WorkplaceMatch(
      workplaceId: map['workplace_id'] as String,
      name: map['name'] as String,
      distanceMeters: (map['distance_meters'] as num).toDouble(),
    );
  }
}

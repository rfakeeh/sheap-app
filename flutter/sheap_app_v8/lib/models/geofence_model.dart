enum GeofenceType { dynamicLeader, staticLocation }

class GeofenceConfig {
  final GeofenceType type;
  final double radiusInMeters;
  final List<String> targetMemberIds; // Phone numbers of tracked people
  final double? staticLatitude; // Used only if type == staticLocation
  final double? staticLongitude; // Used only if type == staticLocation

  GeofenceConfig({
    required this.type,
    required this.radiusInMeters,
    required this.targetMemberIds,
    this.staticLatitude,
    this.staticLongitude,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'radiusInMeters': radiusInMeters,
      'targetMemberIds': targetMemberIds,
      'staticLatitude': staticLatitude,
      'staticLongitude': staticLongitude,
    };
  }

  factory GeofenceConfig.fromMap(Map<String, dynamic> map) {
    return GeofenceConfig(
      type: GeofenceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => GeofenceType.dynamicLeader,
      ),
      radiusInMeters: (map['radiusInMeters'] as num).toDouble(),
      targetMemberIds: List<String>.from(map['targetMemberIds'] ?? []),
      staticLatitude: map['staticLatitude'],
      staticLongitude: map['staticLongitude'],
    );
  }
}

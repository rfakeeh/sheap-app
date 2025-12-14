class MemberGeofence {
  final String groupId;
  final String memberId;
  final bool isOutsideGeofence;
  final DateTime updatedAt;

  final double? distanceMeters;

  MemberGeofence({
    required this.groupId,
    required this.memberId,
    required this.isOutsideGeofence,
    required this.updatedAt,
    this.distanceMeters,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'memberId': memberId,
      'isOutsideGeofence': isOutsideGeofence,
      'updatedAt': updatedAt.toIso8601String(),
      'distanceMeters': distanceMeters,
    };
  }

  factory MemberGeofence.fromMap(Map<String, dynamic> map) {
    return MemberGeofence(
      groupId: map['groupId'] ?? '',
      memberId: map['memberId'] ?? '',
      isOutsideGeofence: map['isOutsideGeofence'] ?? false,
      updatedAt: map['updatedAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(map['updatedAt']) ?? DateTime.now(),
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
    );
  }
}

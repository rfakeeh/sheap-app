class AppLocation {
  final String id;
  final String nameEn;
  final String nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final double latitude;
  final double longitude;

  AppLocation({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    required this.latitude,
    required this.longitude,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameAr': nameAr,
      'descriptionEn': descriptionEn,
      'descriptionAr': descriptionAr,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory AppLocation.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppLocation(
      id: id ?? map['id'] ?? '',
      nameEn: map['nameEn'] ?? '',
      nameAr: map['nameAr'] ?? '',
      descriptionEn: map['descriptionEn'],
      descriptionAr: map['descriptionAr'],
      // Handle cases where Firestore returns int (e.g., 0 instead of 0.0)
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

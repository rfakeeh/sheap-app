// lib/models/user_model.dart

import 'location_model.dart'; // Import the class we made earlier

class AppUser {
  final String phoneNumber;
  final String fullName;
  final String nationalId;
  final DateTime createdAt;
  // Nullable, because we don't have location on Sign Up yet
  final AppLocation? lastKnownLocation;

  AppUser({
    required this.phoneNumber,
    required this.fullName,
    required this.nationalId,
    required this.createdAt,
    this.lastKnownLocation,
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'nationalId': nationalId,
      'createdAt': createdAt.toIso8601String(),
      // Check if null before writing
      'lastKnownLocation': lastKnownLocation?.toMap(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      phoneNumber: map['phoneNumber'] ?? '',
      fullName: map['fullName'] ?? '',
      nationalId: map['nationalId'] ?? '',
      // Parse string back to DateTime
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      // Parse if exists
      lastKnownLocation: map['lastKnownLocation'] != null
          ? AppLocation.fromMap(map['lastKnownLocation'])
          : null,
    );
  }
}

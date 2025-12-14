import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String username;
  final String id;
  final String phone;

  AppUser({required this.username, required this.id, required this.phone});

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'id': id,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppUser(
      username: data['username'] ?? '',
      id: data['id'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks if a user exists.
  /// If [transaction] is provided, performs the read within that transaction.
  Future<bool> checkUserExists(String phone, {Transaction? transaction}) async {
    DocumentReference ref = _firestore.collection('users').doc(phone);
    DocumentSnapshot snap;

    if (transaction != null) {
      snap = await transaction.get(ref);
    } else {
      snap = await ref.get();
    }
    return snap.exists;
  }

  /// Creates a user.
  /// If [transaction] is provided, writes within that transaction.
  Future<void> createUser(AppUser user, {Transaction? transaction}) async {
    DocumentReference ref = _firestore
        .collection('users')
        .doc(user.phoneNumber);

    if (transaction != null) {
      transaction.set(ref, user.toMap());
    } else {
      await ref.set(user.toMap());
    }
  }

  /// Fetches a user (Standard read)
  Future<AppUser?> getUser(String phoneNumber) async {
    try {
      final doc = await _firestore.collection('users').doc(phoneNumber).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}

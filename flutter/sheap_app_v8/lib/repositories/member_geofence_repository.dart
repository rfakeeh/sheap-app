import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_geofence_model.dart';

class MemberGeofenceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream full geofence documents for a given group.
  /// Used when you want ALL fields (not only outside members).
  Stream<List<MemberGeofence>> watchGeofencesForGroup(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('geofences')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MemberGeofence.fromMap(doc.data()))
              .toList();
        });
  }

  /// Fetch all geofence documents once (non-streaming).
  Future<List<MemberGeofence>> getGeofencesForGroup(String groupId) async {
    final snap = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('geofences')
        .get();

    return snap.docs.map((doc) => MemberGeofence.fromMap(doc.data())).toList();
  }

  /// Get the set of memberIds who are currently outside the geofence.
  Future<Set<String>> getOutsideMembers(String groupId) async {
    try {
      final query = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('geofences')
          .where('isOutsideGeofence', isEqualTo: true)
          .get();

      // doc.id is the memberId
      final outsideMembers = query.docs.map((doc) => doc.id).toSet();
      return outsideMembers;
    } catch (e) {
      print("Error reading outside members for group $groupId: $e");
      return <String>{};
    }
  }

  /// STREAM VERSION:
  /// A real-time stream that emits a Set<String> of memberIds currently outside the geofence.
  /// This is the recommended method for UI that needs live updates (Home, Map, Group Details).
  Stream<Set<String>> watchOutsideMembers(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('geofences')
        .snapshots()
        .map((snapshot) {
          final outsideSet = <String>{};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final isOutside = data['isOutsideGeofence'] == true;

            // doc.id is the memberId
            if (isOutside) {
              outsideSet.add(doc.id);
            }
          }

          return outsideSet;
        });
  }

  /// Create or update geofence state for a single member.
  /// Firestore merge ensures only provided fields are updated.
  Future<void> upsertMemberGeofence(MemberGeofence geofence) async {
    await _firestore
        .collection('groups')
        .doc(geofence.groupId)
        .collection('geofences')
        .doc(geofence.memberId)
        .set(geofence.toMap(), SetOptions(merge: true));
  }
}

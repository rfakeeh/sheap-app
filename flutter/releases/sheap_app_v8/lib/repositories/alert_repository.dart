import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';

class AlertRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _alertsCollection => _firestore.collection('alerts');
  CollectionReference get _groupsCollection => _firestore.collection('groups');

  /// You must provide EITHER [receiverId] (for a direct message)
  /// OR [targetGroupId] (to broadcast to all group members).
  Future<void> sendAlert({
    required String type, // e.g., 'SOS'
    required String message,
    required String senderId,
    String? receiverId,
    String? targetGroupId,
  }) async {
    if ((receiverId == null && targetGroupId == null) ||
        (receiverId != null && targetGroupId != null)) {
      throw ArgumentError(
        'You must provide either receiverId OR targetGroupId, but not both.',
      );
    }

    final DateTime now = DateTime.now();
    // Use a batch for atomicity, especially important for group broadcasts.
    WriteBatch batch = _firestore.batch();

    try {
      if (receiverId != null) {
        // --- CASE 1: Direct Send to Single User ---
        DocumentReference newDocRef = _alertsCollection.doc();
        final alert = AlertModel(
          id: newDocRef.id,
          type: type,
          message: message,
          sentAt: now,
          senderId: senderId,
          isOpened: false,
          receiverId: receiverId, // The specific target
        );
        batch.set(newDocRef, alert.toMap());
      } else if (targetGroupId != null) {
        // --- CASE 2: Broadcast to Group Members ---

        // 1. Fetch the group document to get the list of member IDs
        DocumentSnapshot groupDoc = await _groupsCollection
            .doc(targetGroupId)
            .get();

        if (!groupDoc.exists) {
          throw Exception("Group $targetGroupId not found.");
        }

        // 2. Extract memberIds (assuming your group document has this field)
        List<String> memberIds = List<String>.from(
          groupDoc.get('memberIds') ?? [],
        );

        if (memberIds.isEmpty) {
          throw Exception("Group has no members to alert.");
        }

        // 3. Iterate through members and create an alert for each one
        for (String receiverId in memberIds) {
          // Optional logic: Don't send SOS to yourself if you are the sender
          // if (memberId == senderId) continue;

          DocumentReference newDocRef = _alertsCollection.doc();
          final alert = AlertModel(
            id: newDocRef.id,
            type: type,
            message: message,
            sentAt: now,
            senderId: senderId,
            isOpened: false,
            receiverId: receiverId, // Target THIS specific member
          );
          // Add to batch
          batch.set(newDocRef, alert.toMap());
        }
      }

      // Commit all changes to Firestore atomically
      await batch.commit();
    } catch (e) {
      print("Error sending alert: $e");
      rethrow;
    }
  }

  /// Retrieves a stream of alerts specifically targeting this user.
  /// This is now the primary way to get alerts.
  Stream<List<AlertModel>> getAlertsForUser(String receiverId) {
    return _alertsCollection
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AlertModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  /// Marks an alert as opened/read.
  Future<void> markAlertAsOpened(String alertId) async {
    await _alertsCollection.doc(alertId).update({'isOpened': true});
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/alert_model.dart';

class AlertRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Reference to the "alerts" collection in Firestore
  CollectionReference get _alertsCollection => _firestore.collection('alerts');

  /// Sends a new alert to Firestore.
  ///
  /// This method is fully generic and supports:
  /// - Requests that require user action (requiresAction = true)
  /// - Simple notifications (requiresAction = false)
  /// - Linking multiple alerts under the same event (caseId)
  /// - Optional data attachment via [payload]
  ///
  /// Returns the created AlertModel instance.
  Future<AlertModel> sendAlert({
    required String type,
    String? message,
    required String senderId,
    required String receiverId,
    bool requiresAction = false,
    String? status,
    String? caseId,
    String? groupId,
    Map<String, dynamic>? payload,
  }) async {
    final now = DateTime.now();
    final docRef = _alertsCollection.doc();
    final String effectiveCaseId = caseId ?? _uuid.v4();

    final alert = AlertModel(
      id: docRef.id,
      type: type,
      message: message,
      sentAt: now,
      senderId: senderId,
      receiverId: receiverId,
      isOpened: false,
      // If no caseId is provided, use the alert id itself to create a new event chain
      caseId: effectiveCaseId,
      status: status,
      requiresAction: requiresAction,
      groupId: groupId,
      payload: payload,
    );

    await docRef.set(alert.toMap());
    return alert;
  }

  /// Stream of all alerts targeted to a specific user.
  ///
  /// Alerts are ordered by time (newest first).
  /// This keeps the UI always synchronized with Firestore.
  Stream<List<AlertModel>> getAlertsForUser(String receiverId) {
    return _alertsCollection
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) =>
                    AlertModel.fromMap(d.data() as Map<String, dynamic>, d.id),
              )
              .toList(),
        );
  }

  /// Marks a single alert as opened (dismissed from the banner).
  ///
  /// This does NOT change the status of the event/case,
  /// it only affects the UI so the banner does not reappear.
  Future<void> markAlertAsOpened(String alertId) async {
    await _alertsCollection.doc(alertId).update({'isOpened': true});
  }

  /// Resolves a single alert by its document ID.
  ///
  /// This will:
  /// - Mark the alert as opened (`isOpened = true`)
  /// - Set its status to `RESOLVED`
  ///
  /// The in-memory list in AlertProvider will be updated automatically
  /// on the next Firestore snapshot.
  Future<void> markAlertAsOpenedAndResolved(String alertId) async {
    await _alertsCollection.doc(alertId).update({
      'isOpened': true,
      'status': AlertStatus.resolved,
    });
  }

  /// Updates the status of all alerts that belong to the same event (caseId).
  ///
  /// This is crucial for:
  /// - Invitation flows (accept/reject)
  /// - SOS events (resolved, handled)
  /// - Any future multi-step alert flow
  ///
  /// Uses a Firestore batch to ensure atomic updates.
  Future<void> updateStatusForCase(String caseId, String newStatus) async {
    final query = await _alertsCollection
        .where('caseId', isEqualTo: caseId)
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'status': newStatus});
    }

    await batch.commit();
  }

  Future<bool> hasAlertTypeWithStatus({
    required String receiverId,
    required String type,
    required String status,
  }) async {
    final q = await _firestore
        .collection('alerts')
        .where('receiverId', isEqualTo: receiverId)
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: status)
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }

  Future<bool> hasAlertTypeWithStatusAndGroup({
    required String receiverId,
    required String type,
    required String status,
    required String groupId,
  }) async {
    final q = await _firestore
        .collection('alerts')
        .where('receiverId', isEqualTo: receiverId)
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: status)
        .where('groupId', isEqualTo: groupId)
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }

  Future<bool> hasAlertTypeWithStatusAndSender({
    required String receiverId,
    required String type,
    required String status,
    required String senderId,
  }) async {
    final q = await _firestore
        .collection('alerts')
        .where('receiverId', isEqualTo: receiverId)
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: status)
        .where('senderId', isEqualTo: senderId)
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }

  Future<bool> hasAlertTypeWithStatusAndPayloadProperty({
    required String receiverId,
    required String type,
    required String status,
    required String propertyName,
    required dynamic propertyValue,
  }) async {
    final q = await _firestore
        .collection('alerts')
        .where('receiverId', isEqualTo: receiverId)
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: status)
        .where('payload.$propertyName', isEqualTo: propertyValue)
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }

  Future<void> resolveAlertsForCase({required String caseId}) async {
    // 1) Query all alerts related to the same case id
    final query = await _firestore
        .collection('alerts')
        .where('caseId', isEqualTo: caseId)
        .get();

    if (query.docs.isEmpty) return;

    // 2) Use a write batch to update them all at once
    final batch = _firestore.batch();

    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isOpened': true,
        'status': AlertStatus.resolved,
      });
    }

    // 3) Commit the batch
    await batch.commit();
  }

  Future<void> resolveAlertsForCaseAndTypeAndSender({
    required String caseId,
    required String type,
    required String senderId,
  }) async {
    // 1) Query all alerts related to the same case id
    final query = await _firestore
        .collection('alerts')
        .where('caseId', isEqualTo: caseId)
        .where('type', isEqualTo: type)
        .where('senderId', isEqualTo: senderId)
        .get();

    if (query.docs.isEmpty) return;

    // 2) Use a write batch to update them all at once
    final batch = _firestore.batch();

    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isOpened': true,
        'status': AlertStatus.resolved,
      });
    }

    // 3) Commit the batch
    await batch.commit();
  }

  Future<void> resolveAlertsForMemberInGroup({
    required String memberId,
    required String groupId,
  }) async {
    // 1) Query all alerts related to the same group and the same member
    //    as either sender or receiver.
    final query = await _firestore
        .collection('alerts')
        .where('groupId', isEqualTo: groupId)
        .where(
          Filter.or(
            Filter('senderId', isEqualTo: memberId),
            Filter('receiverId', isEqualTo: memberId),
          ),
        )
        .get();

    if (query.docs.isEmpty) return;

    // 2) Use a write batch to update them all at once
    final batch = _firestore.batch();

    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isOpened': true,
        'status': AlertStatus.resolved,
      });
    }

    // 3) Commit the batch
    await batch.commit();
  }

  Future<void> resolveAlertsForMemberInGroupAndType({
    required String groupId,
    required String type,
    required String memberId,
  }) async {
    // 1) Query all alerts related to the same group and the same member
    //    as either sender or receiver.
    final query = await _firestore
        .collection('alerts')
        .where('groupId', isEqualTo: groupId)
        .where('type', isEqualTo: type)
        .where(
          Filter.or(
            Filter('senderId', isEqualTo: memberId),
            Filter('receiverId', isEqualTo: memberId),
          ),
        )
        .get();

    if (query.docs.isEmpty) return;

    // 2) Use a write batch to update them all at once
    final batch = _firestore.batch();

    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isOpened': true,
        'status': AlertStatus.resolved,
      });
    }

    // 3) Commit the batch
    await batch.commit();
  }

  /// Resolves all SOS-related alerts exchanged between two users,
  /// regardless of groupId.
  ///
  /// It marks only SOS alerts (REQUEST, REQUEST_SENT, MEMBER_COMING,
  /// REQUEST_CANCELLED, MEMBER_SAFE) as:
  ///   - isOpened = true
  ///   - status   = RESOLVED
  Future<void> resolveSosAlertsBetweenTwoMembers({
    required String userA,
    required String userB,
  }) async {
    final query = await _alertsCollection
        .where(
          Filter.or(
            Filter.and(
              Filter('senderId', isEqualTo: userA),
              Filter('receiverId', isEqualTo: userB),
            ),
            Filter.and(
              Filter('senderId', isEqualTo: userB),
              Filter('receiverId', isEqualTo: userA),
            ),
          ),
        )
        .get();

    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in query.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      batch.update(doc.reference, {
        'isOpened': true,
        'status': AlertStatus.resolved,
      });
    }

    await batch.commit();
  }

  Future<Set<String>> getMembersWithPendingSelfSos(
    List<String> memberIds,
  ) async {
    // Returns the set of memberIds that currently have a pending SOS_REQUEST_SENT alert for themselves.
    final result = <String>{};
    if (memberIds.isEmpty) return result;

    const chunkSize = 10; // Firestore whereIn limit (commonly 10)
    for (int i = 0; i < memberIds.length; i += chunkSize) {
      final chunk = memberIds.sublist(
        i,
        (i + chunkSize > memberIds.length) ? memberIds.length : i + chunkSize,
      );

      final q = await _firestore
          .collection('alerts')
          .where('type', isEqualTo: AlertType.sosRequestSent)
          .where('status', isEqualTo: AlertStatus.pending)
          .where('receiverId', whereIn: chunk)
          .get();

      for (final doc in q.docs) {
        final data = doc.data();
        final receiverId = data['receiverId'] as String? ?? '';
        final senderId = data['senderId'] as String? ?? '';

        // Self SOS: senderId == receiverId
        if (receiverId.isNotEmpty && receiverId == senderId) {
          result.add(receiverId);
        }
      }
    }

    return result;
  }

  Future<void> resolveAlertsForTypesAndSender({
    required List<String> types,
    required String senderId,
  }) async {
    final query = await _firestore
        .collection('alerts')
        .where('senderId', isEqualTo: senderId)
        .where('type', whereIn: types)
        .get();

    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isOpened': true,
        'status': AlertStatus.resolved,
      });
    }

    await batch.commit();
  }

  Future<bool> hasAlertTypesWithStatusAndSender({
    required String receiverId,
    required List<String> types,
    required String status,
    required String senderId,
  }) async {
    final q = await _firestore
        .collection('alerts')
        .where('receiverId', isEqualTo: receiverId)
        .where('type', whereIn: types)
        .where('status', isEqualTo: status)
        .where('senderId', isEqualTo: senderId)
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }

  /// Stream: returns only "self SOS pending" alerts for a given member.
  /// Self SOS means: receiverId == memberId AND senderId == memberId.
  /// We also filter by type and status to minimize bandwidth.
  Stream<List<AlertModel>> streamPendingSelfSosForMember(String memberId) {
    return _alertsCollection
        .where('receiverId', isEqualTo: memberId)
        .where('senderId', isEqualTo: memberId)
        .where('type', isEqualTo: AlertType.sosRequestSent)
        .where('status', isEqualTo: AlertStatus.pending)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) =>
                    AlertModel.fromMap(d.data() as Map<String, dynamic>, d.id),
              )
              .toList(),
        );
  }
}

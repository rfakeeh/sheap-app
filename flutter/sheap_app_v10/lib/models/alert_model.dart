class AlertStatus {
  /// The alert is waiting for a response (if requiresAction = true)
  static const pending = 'PENDING';
  static const resolved = 'RESOLVED';
}

class AlertType {
  static const broadcast = 'BROADCAST';

  /// A leader sends an invitation to a user to join a group
  static const invitationRequest = 'INVITATION_REQUEST';

  /// Confirmation notification sent to the creator indicating the invitation was delivered
  static const invitationSent = 'INVITATION_SENT';

  /// Notification sent to the creator when a user accepts the invitation
  static const invitationAccepted = 'INVITATION_ACCEPTED';

  /// Notification sent to the creator when a user rejects the invitation
  static const invitationRejected = 'INVITATION_REJECTED';

  /// Notification sent to the creator when a member joined the group (e.g., via QR)
  static const memberJoinedGroup = 'MEMBER_JOINED_GROUP';

  /// Notification sent to the creator when a member left a group
  static const memberLeftGroup = 'MEMBER_LEFT_GROUP';

  /// A member sends an SOS emergency request
  static const sosRequest = 'SOS_REQUEST';

  /// A confirmation alert sent to the SOS sender themselves
  static const sosRequestSent = 'SOS_REQUEST_SENT';

  /// A confirmation alert sent to the SOS request receivers
  static const sosRequestCancelled = 'SOS_REQUEST_CANCELLED';

  /// A notification that one member is on the way to help the SOS sender
  static const sosMemberComing = 'SOS_MEMBER_COMING';

  static const sosMemberComingSent = 'SOS_MEMBER_COMING_SENT';

  static const sosMemberComingCancelled = 'SOS_MEMBER_COMING_CANCELLED';

  static const sosMemberComingArrived = 'SOS_MEMBER_COMING_ARRIVED';

  static const sosMemberComingArrivedSent = 'SOS_MEMBER_COMING_ARRIVED_SENT';

  /// A notification that the SOS sender is now safe
  static const sosMemberSafe = 'SOS_MEMBER_SAFE';

  /// A member exited the geofence boundary
  static const geofenceExit = 'GEOFENCE_EXIT';

  /// A member re-entered the geofence boundary
  static const geofenceReenter = 'GEOFENCE_REENTER';

  /// Group reached final destination (if destination is enabled)
  static const destinationReached = 'DESTINATION_REACHED';
}

class AlertModel {
  /// Firestore document ID
  final String id;

  /// Type of alert (AlertType.*)
  final String type;

  /// The message displayed to the user
  final String? message;

  /// When the alert was created
  final DateTime sentAt;

  /// Who triggered/sent this alert
  final String senderId;

  /// Who should receive this alert
  final String receiverId;

  /// A shared ID for all alerts belonging to the same event flow
  /// (e.g., invitation request + invitation accepted)
  final String caseId;

  /// The alert processing state (AlertStatus.*)
  final String? status;

  /// True if the alert banner was opened/dismissed by the user
  final bool isOpened;

  /// Determines whether this alert requires user action (e.g., Accept/Reject)
  final bool requiresAction;

  /// Optional: related group identifier
  final String? groupId;

  /// Flexible structure for attaching additional data (e.g., lat/lng, names...)
  final Map<String, dynamic> payload;

  AlertModel({
    required this.id,
    required this.type,
    this.message,
    required this.sentAt,
    required this.senderId,
    required this.receiverId,
    required this.caseId,
    this.status,
    required this.isOpened,
    required this.requiresAction,
    this.groupId,
    Map<String, dynamic>? payload,
  }) : payload = payload ?? const {};

  /// Converts the model into Firestore-friendly map
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'senderId': senderId,
      'receiverId': receiverId,
      'caseId': caseId,
      'status': status,
      'isOpened': isOpened,
      'requiresAction': requiresAction,
      'groupId': groupId,
      'payload': payload,
    };
  }

  /// Reconstructs model from Firestore data
  factory AlertModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AlertModel(
      id: documentId,
      type: map['type'] ?? 'UNKNOWN',
      message: map['message'],
      sentAt: map['sentAt'] != null
          ? DateTime.parse(map['sentAt'])
          : DateTime.now(),
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      caseId: map['caseId'] ?? documentId,
      status: map['status'] ?? AlertStatus.pending,
      isOpened: map['isOpened'] ?? false,
      requiresAction: map['requiresAction'] ?? false,
      groupId: map['groupId'],
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
    );
  }
}

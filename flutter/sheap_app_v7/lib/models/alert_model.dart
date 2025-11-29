class AlertModel {
  final String id; // Document ID
  final String type; // 'SOS', 'GEOFENCE_EXIT', etc.
  final String message;
  final DateTime sentAt;
  final String senderId; // Who initiated it
  final bool isOpened;
  final String receiverId;

  AlertModel({
    required this.id,
    required this.type,
    required this.message,
    required this.sentAt,
    required this.senderId,
    required this.isOpened,
    required this.receiverId,
  });

  Map<String, dynamic> toMap() {
    return {
      // 'id' is not stored in the map, it's the document key
      'type': type,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'senderId': senderId,
      'isOpened': isOpened,
      'receiverId': receiverId,
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AlertModel(
      id: documentId,
      type: map['type'] ?? 'UNKNOWN',
      message: map['message'] ?? '',
      sentAt: map['sentAt'] != null
          ? DateTime.parse(map['sentAt'])
          : DateTime.now(),
      senderId: map['senderId'] ?? '',
      isOpened: map['isOpened'] ?? false,
      receiverId: map['receiverId'] ?? '',
    );
  }
}

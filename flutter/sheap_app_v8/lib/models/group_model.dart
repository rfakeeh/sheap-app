import 'geofence_model.dart';
import 'destination_model.dart';
import 'member_model.dart';

class GroupModel {
  final String groupId;
  final String groupName;
  final String qrCodeData;
  final bool isActive;

  /// Tracking mode:
  /// - 'ALL_VISIBLE': every member sees everyone
  /// - 'LEADERS_ONLY': members see leaders only
  final String trackingMode;

  /// Optional geofence configuration for the group.
  final GeofenceConfig? geofenceConfig;

  /// Optional destination configuration (static location or leader location).
  final DestinationConfig? destinationConfig;

  /// Strongly typed list of group members.
  final List<GroupMember> members;

  /// Convenience list of member ids (phoneNumbers) used for queries.
  final List<String> memberIds;

  /// Creator of the group (phone number).
  final String creatorId;

  /// Current leader of the group (phone number).
  final String leaderId;

  // ---------------------------------------------------------------------------
  // 1. PRIMARY CONSTRUCTOR
  // ---------------------------------------------------------------------------
  GroupModel({
    required this.groupId,
    required this.groupName,
    required this.qrCodeData,
    required this.isActive,
    required this.trackingMode,
    this.geofenceConfig,
    this.destinationConfig,
    required this.members,
    List<String>? memberIds,
    required this.creatorId,
    required this.leaderId,
  }) : memberIds = memberIds ?? members.map((m) => m.phoneNumber).toList();

  // ---------------------------------------------------------------------------
  // 2. INITIAL CONSTRUCTOR (used on group creation)
  // ---------------------------------------------------------------------------
  GroupModel.initial({
    required this.groupId,
    required this.groupName,
    required String creatorPhone,
  }) : qrCodeData = groupId,
       isActive = false,
       trackingMode = 'ALL_VISIBLE',
       geofenceConfig = null,
       destinationConfig = null,
       members = [
         GroupMember(
           phoneNumber: creatorPhone,
           roles: const ['CREATOR', 'LEADER'],
           joinedAt: DateTime.now(),
         ),
       ],
       memberIds = [creatorPhone],
       creatorId = creatorPhone,
       leaderId = creatorPhone;

  // ---------------------------------------------------------------------------
  // 3. TO MAP (Write to Firestore)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'qrCodeData': qrCodeData,
      'isActive': isActive,
      'trackingMode': trackingMode,
      'geofenceConfig': geofenceConfig?.toMap(),
      'destinationConfig': destinationConfig?.toMap(),
      'members': members.map((m) => m.toMap()).toList(),
      'memberIds': memberIds,
      'creatorId': creatorId,
      'leaderId': leaderId,
    };
  }

  // ---------------------------------------------------------------------------
  // 4. FROM MAP (Read from Firestore)
  // ---------------------------------------------------------------------------
  factory GroupModel.fromMap(Map<String, dynamic> map) {
    // Parse members list safely
    final membersList =
        (map['members'] as List<dynamic>?)
            ?.map(
              (e) => GroupMember.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        <GroupMember>[];

    return GroupModel(
      groupId: (map['groupId'] ?? '') as String,
      groupName: (map['groupName'] ?? '') as String,
      qrCodeData: (map['qrCodeData'] ?? '') as String,
      isActive: (map['isActive'] ?? false) as bool,
      trackingMode: (map['trackingMode'] ?? 'ALL_VISIBLE') as String,
      geofenceConfig: map['geofenceConfig'] != null
          ? GeofenceConfig.fromMap(
              Map<String, dynamic>.from(map['geofenceConfig']),
            )
          : null,
      destinationConfig: map['destinationConfig'] != null
          ? DestinationConfig.fromMap(
              Map<String, dynamic>.from(map['destinationConfig']),
            )
          : null,
      members: membersList,
      memberIds: map['memberIds'] != null
          ? List<String>.from(map['memberIds'] as List)
          : membersList.map((m) => m.phoneNumber).toList(),
      creatorId: (map['creatorId'] ?? '') as String,
      leaderId: (map['leaderId'] ?? '') as String,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. COPYWITH (Create modified immutable copies)
  // ---------------------------------------------------------------------------
  GroupModel copyWith({
    String? groupId,
    String? groupName,
    String? qrCodeData,
    bool? isActive,
    String? trackingMode,
    GeofenceConfig? geofenceConfig,
    DestinationConfig? destinationConfig,
    List<GroupMember>? members,
    List<String>? memberIds,
    String? creatorId,
    String? leaderId,
  }) {
    return GroupModel(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      isActive: isActive ?? this.isActive,
      trackingMode: trackingMode ?? this.trackingMode,
      geofenceConfig: geofenceConfig ?? this.geofenceConfig,
      destinationConfig: destinationConfig ?? this.destinationConfig,
      members: members ?? this.members,
      memberIds: memberIds ?? this.memberIds,
      creatorId: creatorId ?? this.creatorId,
      leaderId: leaderId ?? this.leaderId,
    );
  }
}

import 'geofence_model.dart';
import 'destination_model.dart';
import 'member_model.dart';

class GroupModel {
  final String groupId;
  final String groupName;
  final String qrCodeData;
  final bool isActive;
  final String trackingMode; // 'ALL_VISIBLE' or 'LEADERS_ONLY'

  // Nested Nullable Configs
  final GeofenceConfig? geofenceConfig;
  final DestinationConfig? destinationConfig;

  // Strongly typed list of members
  final List<GroupMember> members;
  // A computed list just for searching/querying
  final List<String> memberIds;
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
    String? leaderId,
  }) : memberIds = memberIds ?? members.map((m) => m.phoneNumber).toList(),
       // Logic: If passed, use it. If not, find the member with 'LEADER' role.
       leaderId =
           leaderId ??
           members
               .firstWhere(
                 (m) =>
                     m.roles.contains('LEADER') || m.roles.contains('CREATOR'),
                 orElse: () => members.first,
               )
               .phoneNumber;

  // ---------------------------------------------------------------------------
  // 2. NAMED CONSTRUCTOR: For Initial Creation
  // ---------------------------------------------------------------------------
  GroupModel.initial({
    required this.groupId,
    required this.groupName, // Direct assignment per your request
    required String creatorPhone,
  }) : qrCodeData = groupId,
       isActive = false,
       trackingMode = 'ALL_VISIBLE',
       geofenceConfig = null,
       destinationConfig = null,
       // Create the initial member list with the Creator
       members = [
         GroupMember(
           phoneNumber: creatorPhone,
           roles: ['CREATOR', 'LEADER'],
           joinedAt: DateTime.now(),
         ),
       ],
       // Set the computed fields immediately
       memberIds = [creatorPhone],
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
      'members': members.map((e) => e.toMap()).toList(),
      'memberIds': memberIds,
      'leaderId': leaderId,
    };
  }

  // ---------------------------------------------------------------------------
  // 4. FROM MAP (Read from Firestore)
  // ---------------------------------------------------------------------------
  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      qrCodeData: map['qrCodeData'] ?? '',
      isActive: map['isActive'] ?? false,
      trackingMode: map['trackingMode'] ?? 'ALL_VISIBLE',
      geofenceConfig: map['geofenceConfig'] != null
          ? GeofenceConfig.fromMap(map['geofenceConfig'])
          : null,
      destinationConfig: map['destinationConfig'] != null
          ? DestinationConfig.fromMap(map['destinationConfig'])
          : null,
      members:
          (map['members'] as List<dynamic>?)
              ?.map((e) => GroupMember.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      leaderId: map['leaderId'],
    );
  }
}

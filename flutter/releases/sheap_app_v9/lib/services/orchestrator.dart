import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/geofence_model.dart';
import '../models/member_geofence_model.dart';
import '../models/alert_model.dart';
import '../models/member_model.dart'; // for GroupMember

import '../repositories/user_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/member_geofence_repository.dart';
import '../repositories/alert_repository.dart';

import '../exceptions/invite_exception.dart';
import '../exceptions/alert_exception.dart';

class Orchestrator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final UserRepository _userRepo = UserRepository();
  final GroupRepository _groupRepo = GroupRepository();
  final MemberGeofenceRepository _memberGeofenceRepo =
      MemberGeofenceRepository();
  final AlertRepository _alertRepo = AlertRepository();

  // -----------------------------------------------------------
  // PUBLIC METHODS
  // -----------------------------------------------------------

  /// Creates user + initial group atomically
  Future<void> signUp({
    required String fullName,
    required String nationalId,
    required String phoneNumber,
    required String baseGroupName,
    required bool isArabic,
  }) async {
    final newUser = AppUser(
      phoneNumber: phoneNumber,
      fullName: fullName,
      nationalId: nationalId,
      createdAt: DateTime.now(),
      lastKnownLocation: null,
    );

    // Pre-compute group name before transaction
    final uniqueGroupName = await _generateUniqueName(baseGroupName, isArabic);

    // Build group object with shared helper
    final newGroup = _buildInitialGroup(
      creatorPhone: phoneNumber,
      groupName: uniqueGroupName,
    );

    await _firestore.runTransaction((transaction) async {
      final exists = await _userRepo.checkUserExists(
        phoneNumber,
        transaction: transaction,
      );

      if (exists) throw Exception('User already registered');

      await _userRepo.createUser(newUser, transaction: transaction);
      await _groupRepo.createGroup(newGroup, transaction: transaction);
    });
  }

  /// Creates a new initial group for an existing user.
  Future<void> createInitialGroupForUser({
    required String userPhone,
    required String baseGroupName,
    required bool isArabic,
  }) async {
    // Validate user exists
    final user = await _validateUserExists(userPhone);

    final uniqueGroupName = await _generateUniqueName(baseGroupName, isArabic);

    final group = _buildInitialGroup(
      creatorPhone: user.phoneNumber,
      groupName: uniqueGroupName,
    );

    await _groupRepo.createGroup(group);
  }

  /// Updates the geofenceConfig for a group AND immediately
  /// recalculates geofence violations for all target members.
  ///
  /// This ensures the UI (via MemberGeofenceProvider streams)
  /// receives up-to-date inside/outside states even if members
  /// are not currently moving.
  Future<void> updateGroupGeofenceConfigAndCcalculate(
    GroupModel group,
    GeofenceConfig newConfig,
  ) async {
    // 1) Update only geofenceConfig field on the group document
    await _groupRepo.updateGeofenceConfig(group.groupId, newConfig);

    // 2) Recalculate all members’ geofence states
    await calculateGeofenceForGroup(group.groupId);
  }

  /// Recalculate geofence violations for ALL target members in a group.
  ///
  /// This should be called right after you change the geofenceConfig
  /// of that group (radius, type, static center, targetMemberIds, etc.).
  ///
  /// It uses each member's lastKnownLocation (stored in users collection)
  /// to determine whether they are currently inside or outside the fence,
  /// and writes the result into:
  ///   groups/{groupId}/geofences/{memberId}
  Future<void> calculateGeofenceForGroup(String groupId) async {
    // 1) Load the group, including its geofenceConfig
    final group = await _groupRepo.getGroupById(groupId);
    if (group == null) {
      throw Exception('Group $groupId not found');
    }

    final config = group.geofenceConfig;
    if (config == null) {
      // No geofence configured: nothing to recompute
      return;
    }

    // 2) Determine the geofence center (static or dynamic leader)
    double? centerLat;
    double? centerLng;

    if (config.type == GeofenceType.dynamicLeader) {
      // Use the leader's lastKnownLocation as geofence center
      if (group.leaderId.isEmpty) {
        // No leader configured; cannot compute a dynamic leader geofence
        return;
      }

      final leader = await _userRepo.getUser(group.leaderId);
      if (leader == null || leader.lastKnownLocation == null) {
        // We don't know the leader's last position -> skip recalculation
        return;
      }

      centerLat = leader.lastKnownLocation!.latitude;
      centerLng = leader.lastKnownLocation!.longitude;
    } else {
      // Static geofence: use configured latitude/longitude
      centerLat = config.staticLatitude;
      centerLng = config.staticLongitude;
    }

    if (centerLat == null || centerLng == null) {
      // Invalid config: no usable center
      return;
    }

    // 3) Loop over all targeted members and recompute their fence status
    final List<String> targetMemberIds = config.targetMemberIds;

    for (final memberId in targetMemberIds) {
      // 3.1 Load each member's lastKnownLocation
      final user = await _userRepo.getUser(memberId);
      if (user == null || user.lastKnownLocation == null) {
        // No last position known for this user -> skip
        continue;
      }

      final userLat = user.lastKnownLocation!.latitude;
      final userLng = user.lastKnownLocation!.longitude;

      // 3.2 Compute distance from geofence center
      final distance = _distanceInMeters(
        userLat,
        userLng,
        centerLat,
        centerLng,
      );

      // 3.3 Decide if this member is outside the geofence
      final bool isOutside = distance > config.radiusInMeters;

      // 3.4 Build the MemberGeofence state object
      final geofenceState = MemberGeofence(
        groupId: group.groupId,
        memberId: memberId,
        isOutsideGeofence: isOutside,
        distanceMeters: distance,
        updatedAt: DateTime.now(),
      );

      // 3.5 Upsert the geofence document in Firestore
      try {
        await _memberGeofenceRepo.upsertMemberGeofence(geofenceState);
      } catch (e) {
        // Log and continue with other members
        // (We don't throw to avoid stopping the whole loop)
        // You can later replace this with a proper logger.
        // ignore: avoid_print
        print(
          'Failed to upsert geofence state for member $memberId in group ${group.groupId}: $e',
        );
      }
    }
  }

  /// Invites a user (by phone) to join a group.
  ///
  /// Validations:
  /// - Target user must exist.
  /// - Group must exist.
  /// - Target user must NOT already be a member of the group.
  ///
  /// Throws:
  /// - InviteMemberException(InviteMemberErrorCodes.userNotFound)
  /// - InviteMemberException(InviteMemberErrorCodes.groupNotFound)
  /// - InviteMemberException(InviteMemberErrorCodes.alreadyMember)
  Future<void> inviteMemberToGroup({
    required String groupId,
    required String creatorId,
    required String creatorName,
    required String targetPhone,
  }) async {
    // 1) Check target user exists
    final targetUser = await _userRepo.getUser(targetPhone);
    if (targetUser == null) {
      throw InviteException(InviteErrorCodes.userNotFound);
    }

    // 2) Check group exists
    final group = await _groupRepo.getGroupById(groupId);
    if (group == null) {
      throw InviteException(InviteErrorCodes.groupNotFound);
    }

    // 3) Check if already member
    if (group.memberIds.contains(targetPhone)) {
      throw InviteException(InviteErrorCodes.alreadyMember);
    }

    // 4) Check for previous pending invitation
    final duplicate = await _alertRepo.hasAlertTypeWithStatusAndGroup(
      groupId: group.groupId,
      receiverId: targetPhone,
      type: AlertType.invitationRequest,
      status: AlertStatus.pending,
    );

    if (duplicate) {
      throw AlertException(
        AlertErrorCodes.duplicatePendingAlert,
        'Pending invitation already exists.',
      );
    }

    // 5) Send the invitation alert
    await _alertRepo.sendAlert(
      type: AlertType.invitationRequest,
      senderId: creatorId,
      receiverId: targetPhone,
      groupId: group.groupId,
      requiresAction: true,
      status: AlertStatus.pending,
      payload: {'senderName': creatorName, 'groupName': group.groupName},
    );
  }

  /// Sends the same alert to all members of a group.
  ///
  /// - Uses one shared caseId for the entire flow (unless you pass a custom one).
  /// - If [excludeSender] is true, the user with [senderId] will not receive an alert.
  /// - Extra data can be passed in [payload] (e.g. memberName, lat/lng, destinationName...).
  Future<void> sendAlertToGroup({
    required String groupId,
    required String senderId,
    required String type,
    required String message,
    bool requiresAction = false,
    String status = AlertStatus.pending,
    bool excludeSender = true,
    String? caseId,
    Map<String, dynamic>? payload,
  }) async {
    // 1) Load the group document
    final group = await _groupRepo.getGroupById(groupId);
    if (group == null) {
      throw Exception('Group $groupId not found');
    }

    // 2) Compute receivers (optionally exclude the sender)
    final allMembers = group.memberIds;
    final receivers = allMembers
        .where((id) => !excludeSender || id != senderId)
        .toList();

    if (receivers.isEmpty) return;

    // 3) One caseId for the whole broadcast (if not provided)
    final String effectiveCaseId = caseId ?? _uuid.v4();

    // 4) Send alerts in parallel for all receivers
    await Future.wait(
      receivers.map(
        (receiverId) => _alertRepo.sendAlert(
          type: type,
          message: message,
          senderId: senderId,
          receiverId: receiverId,
          requiresAction: requiresAction,
          status: status,
          caseId: effectiveCaseId,
          groupId: groupId,
          payload: payload,
        ),
      ),
    );
  }

  /// Accepts a group invitation:
  /// - Joins the user to the group (if not already a member)
  /// - Updates all alerts of this caseId to "resolved"
  /// - Send a notification back to the original sender (group creator)
  Future<void> acceptGroupInvitation({
    required AlertModel alert,
    required String currentUserPhone,
    required String userName,
  }) async {
    if (alert.groupId == null) {
      throw Exception('Invitation alert has no groupId.');
    }

    // 1) Load group
    final group = await _groupRepo.getGroupById(alert.groupId!);
    if (group == null) {
      // If group disappeared, mark case as resolved
      await _alertRepo.updateStatusForCase(alert.caseId, AlertStatus.resolved);
      throw Exception('Group not found for this invitation.');
    }

    // 2) Join member if not already in the group
    final alreadyMember = group.memberIds.contains(currentUserPhone);
    if (!alreadyMember) {
      final member = GroupMember(
        phoneNumber: currentUserPhone,
        roles: [], // default roles
        joinedAt: DateTime.now(),
      );

      await _groupRepo.joinGroup(group: group, member: member);
    }

    // 3) Update whole case to RESOLVED
    await _alertRepo.updateStatusForCase(alert.caseId, AlertStatus.resolved);

    // 4) Send a notification back to the original sender (group creator)
    await _alertRepo.sendAlert(
      type: AlertType.invitationAccepted,
      senderId: currentUserPhone, // who accepted
      receiverId: alert.senderId, // creator who sent the request
      requiresAction: false, // no action required
      caseId: alert.caseId, // SAME CASE ID
      groupId: alert.groupId,
      payload: {
        'groupName': group.groupName,
        'memberId': currentUserPhone,
        'memberName': userName,
      },
    );
  }

  /// Rejects a group invitation:
  /// - Updates all alerts of this caseId to "resolved"
  /// - Send a notification back to the original sender (group creator)
  Future<void> rejectGroupInvitation({
    required AlertModel alert,
    required String currentUserPhone,
    required String groupName,
    required String userName,
  }) async {
    // 1) Update the status of the entire invitation case to RESOLVED
    await _alertRepo.updateStatusForCase(alert.caseId, AlertStatus.resolved);

    // 2) Send a notification back to the original sender (group leader)
    //    This informs the leader that the invitation was rejected.
    //    No action is required from the leader; it's just informational.
    await _alertRepo.sendAlert(
      type: AlertType.invitationRejected,
      senderId: currentUserPhone, // who rejected
      receiverId: alert.senderId, // creator who sent the request
      requiresAction: false, // no action required
      caseId: alert.caseId, // SAME CASE ID
      groupId: alert.groupId,
      payload: {
        'groupName': groupName,
        'memberId': currentUserPhone,
        'memberName': userName,
      },
    );
  }

  Future<void> leaveGroupAndNotify({
    required GroupModel group,
    required String userPhone,
    required String userName,
  }) async {
    // 1) Remove the member from the group
    await _groupRepo.removeMember(group: group, phoneNumber: userPhone);

    // 2) Mark all alerts related to this member in this group as opened and resolved
    final members = <String>{
      group.creatorId,
      group.leaderId,
      ...group.memberIds,
    };

    for (final memberPhone in members) {
      await _alertRepo.resolveSosAlertsBetweenTwoMembers(
        userA: userPhone,
        userB: memberPhone,
      );
    }

    // 3) Send a notification alert to the group creator
    await _alertRepo.sendAlert(
      type: AlertType.memberLeftGroup,
      senderId: userPhone, // The member who left
      receiverId: group.creatorId, // The creator of the group
      requiresAction: false,
      status: AlertStatus.resolved,
      groupId: group.groupId,
      payload: {'memberName': userName, 'groupName': group.groupName},
    );
  }

  /// Joins a member to the group (via QR) and notifies the group creator.
  Future<void> joineGroupAndNotify({
    required GroupModel group,
    required String memberPhone,
    required String memberName,
  }) async {
    // 1) Build the group member object
    final member = GroupMember(
      phoneNumber: memberPhone,
      roles: [], // Default roles for a new member
      joinedAt: DateTime.now(),
    );

    // 2) Join the group using the repository
    await _groupRepo.joinGroup(group: group, member: member);

    // 3) If the joining member is the creator, no need to send a notification
    if (group.creatorId == memberPhone) return;

    // 4) Send a notification to the group creator that a new member joined
    await _alertRepo.sendAlert(
      type: AlertType.memberJoinedGroup,
      senderId: memberPhone, // The member who joined
      receiverId: group.creatorId, // The group creator
      requiresAction: false,
      groupId: group.groupId,
      payload: {'memberName': memberName, 'groupName': group.groupName},
    );
  }

  /// Sends an SOS request from a member (or leader) to the group.
  /// - If trackingMode == LEADERS_ONLY:
  ///     → send SOS only to the leader.
  /// - If trackingMode == ALL_VISIBLE:
  ///     → send SOS to all members (except the sender) including the leader.
  /// - For the sender himself → send a local notification that the SOS is pending.
  Future<void> sendSosRequestAndNotify({
    required Map<String, dynamic> sosSender,
    required List<String> receivers,
  }) async {
    // 1) Check for previous pending SOS request
    for (final receiverId in receivers) {
      final duplicate = await _alertRepo.hasAlertTypeWithStatusAndSender(
        receiverId: receiverId,
        type: AlertType.sosRequest,
        status: AlertStatus.pending,
        senderId: sosSender['phone'],
      );
      print("duplicate => $duplicate");
      if (duplicate) {
        throw AlertException(
          AlertErrorCodes.duplicatePendingAlert,
          'Pending sos request already exists.',
        );
      }
    }

    // 2) Pre-generate a caseId for this whole SOS flow
    final String caseId = _uuid.v4();

    // 3) Send a local notification to the requester himself
    final sosSenderAlert = await _alertRepo.sendAlert(
      caseId: caseId,
      type: AlertType.sosRequestSent,
      senderId: sosSender['phone'],
      receiverId: sosSender['phone'],
      requiresAction: false,
      status: AlertStatus.pending,
      payload: {'receivers': receivers},
    );

    // 3) Send SOS alert to all receivers (leader + other members depending on mode)
    for (final receiverId in receivers) {
      await _alertRepo.sendAlert(
        caseId: caseId,
        type: AlertType.sosRequest,
        senderId: sosSender['phone'],
        receiverId: receiverId,
        requiresAction: true,
        status: AlertStatus.pending,
        payload: {'sosSender': sosSender, 'receivers': receivers},
      );
    }
  }

  Future<void> cancelSosRequestAndNotify({
    required String caseId,
    required Map<String, dynamic> sosSender,
    required List<String> receivers,
  }) async {
    // 1) Mark all alerts with this case as resolved
    await _alertRepo.resolveAlertsForCase(caseId: caseId);

    // 2) Send a notification alert to the receivers with the cancellation
    for (final receiverId in receivers) {
      await _alertRepo.sendAlert(
        caseId: caseId,
        type: AlertType.sosRequestCancelled,
        status: AlertStatus.resolved,
        senderId: sosSender['phone'],
        receiverId: receiverId,
        requiresAction: false,
        payload: {'sosSender': sosSender},
      );
    }
  }

  /// Called when a helper accepts an SOS request and chooses to navigate to the sender.
  /// - Marks the sender's SOS_REQUEST_SENT alert as opened.
  /// - Sends a new alert (SOS_MEMBER_COMING) to notify the sender that someone is coming.
  Future<void> acceptSosRequestAndNotify({
    required String caseId,
    required String helperAlertId,
    required String helperPhone,
    required String helperName,
    required Map<String, dynamic> sosSender,
    required List<String> receivers,
  }) async {
    // 1) Mark current 'SOS_REQUEST' of the helper as open and resolved
    await _alertRepo.markAlertAsOpenedAndResolved(helperAlertId);

    // 2) Send a local notification to the helper himself
    final helperAlert = await _alertRepo.sendAlert(
      caseId: caseId,
      type: AlertType.sosMemberComingSent,
      senderId: helperPhone,
      receiverId: helperPhone,
      requiresAction: false,
      status: AlertStatus.pending,
      payload: {'sosSender': sosSender, 'receivers': receivers},
    );

    // 3) Send a new alert to notify the SOS sender and other members that help is on the way
    for (final receiverId in receivers) {
      await _alertRepo.sendAlert(
        caseId: caseId,
        type: AlertType.sosMemberComing,
        status: AlertStatus.pending,
        senderId: helperPhone,
        receiverId: receiverId,
        requiresAction: true,
        payload: {
          'helperName': helperName,
          'sosSender': sosSender,
          'receivers': receivers,
        },
      );
    }
  }

  Future<void> arriveSosMemberOnTheWayAndNotify({
    required String caseId,
    required String helperAlertId,
    required String helperPhone,
    required String helperName,
    required Map<String, dynamic> sosSender,
    required List<String> receivers,
  }) async {
    // 1) Mark current 'SOS_MEMBER_COMING_SENT' of the helper as open and resolved
    await _alertRepo.markAlertAsOpenedAndResolved(helperAlertId);

    // 2) Mark all alerts sent by helper with this case and SOS_MEMBER_COMING type as resolved
    await _alertRepo.resolveAlertsForCaseAndTypeAndSender(
      caseId: caseId,
      type: AlertType.sosMemberComing,
      senderId: helperPhone,
    );

    // 3) Send a new alert to notify the SOS sender and other members that helper arrived
    for (final receiverId in receivers) {
      await _alertRepo.sendAlert(
        caseId: caseId,
        type: AlertType.sosMemberComingArrived,
        status: AlertStatus.pending,
        senderId: helperPhone,
        receiverId: receiverId,
        requiresAction: true,
        payload: {
          'helperName': helperName,
          'sosSender': sosSender,
          'receivers': receivers,
        },
      );
    }
  }

  Future<void> cancelSosMemberOnTheWayAndNotify({
    required String caseId,
    required String helperAlertId,
    required String helperPhone,
    required String helperName,
    required Map<String, dynamic> sosSender,
    required List<String> receivers,
  }) async {
    // 1) Mark current 'SOS_MEMBER_COMING_SENT' of the helper as open and resolved
    await _alertRepo.markAlertAsOpenedAndResolved(helperAlertId);

    // 2) Mark all alerts sent by helper with this case and SOS_MEMBER_COMING type as resolved
    await _alertRepo.resolveAlertsForCaseAndTypeAndSender(
      caseId: caseId,
      type: AlertType.sosMemberComing,
      senderId: helperPhone,
    );

    // 3) Send a new alert to notify the SOS sender and other members that helper arrived
    for (final receiverId in receivers) {
      await _alertRepo.sendAlert(
        caseId: caseId,
        type: AlertType.sosMemberComingCancelled,
        status: AlertStatus.resolved,
        senderId: helperPhone,
        receiverId: receiverId,
        requiresAction: true,
        payload: {
          'helperName': helperName,
          'sosSender': sosSender,
          'receivers': receivers,
        },
      );
    }
  }

  Future<void> closeSosRequestAndNotify({
    required String caseId,
    required Map<String, dynamic> sosSender,
    required List<String> receivers,
  }) async {
    // 1) Mark all alerts with this case as resolved
    await _alertRepo.resolveAlertsForCase(caseId: caseId);

    // 2) Send a notification alert to the receivers with the safety
    for (final receiverId in receivers) {
      await _alertRepo.sendAlert(
        caseId: caseId,
        type: AlertType.sosMemberSafe,
        status: AlertStatus.resolved,
        senderId: sosSender['phone'],
        receiverId: receiverId,
        requiresAction: false,
        payload: {'sosSender': sosSender},
      );
    }
  }

  // -----------------------------------------------------------
  // PRIVATE HELPERS (remove redundancy)
  // -----------------------------------------------------------

  /// Reusable helper to build an initial group
  GroupModel _buildInitialGroup({
    required String creatorPhone,
    required String groupName,
  }) {
    return GroupModel.initial(
      groupId: _uuid.v4(),
      groupName: groupName,
      creatorPhone: creatorPhone,
    );
  }

  /// Reusable helper to ensure user exists
  Future<AppUser> _validateUserExists(String phone) async {
    final user = await _userRepo.getUser(phone);
    if (user == null) throw Exception("User does not exist");
    return user;
  }

  /// Ensures group names are unique
  Future<String> _generateUniqueName(String baseName, bool isArabic) async {
    String current = baseName;
    int count = 0;

    while (await _groupRepo.checkGroupNameExists(current)) {
      count++;
      final suffix = count;
      current = "$baseName $suffix";
    }

    return current;
  }

  /// Haversine distance in meters between two lat/lng points.
  double _distanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}

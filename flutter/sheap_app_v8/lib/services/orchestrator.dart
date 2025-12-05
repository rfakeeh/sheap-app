import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/geofence_model.dart';
import '../models/member_geofence_model.dart';

import '../repositories/user_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/member_geofence_repository.dart';

class Orchestrator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final UserRepository _userRepo = UserRepository();
  final GroupRepository _groupRepo = GroupRepository();

  // write member geofence states
  final MemberGeofenceRepository _memberGeofenceRepo =
      MemberGeofenceRepository();

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
}

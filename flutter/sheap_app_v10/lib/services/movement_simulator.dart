import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/location_model.dart';
import '../models/group_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/group_repository.dart';
import '../services/orchestrator.dart';

class MovementSimulator {
  final FirebaseFirestore _firestore;
  final UserRepository _userRepository;
  final GroupRepository _groupRepository;
  final Orchestrator _orchestrator;

  final String currentUserPhone;
  final bool activeGroupsOnly;

  /// Centers of circles within which members will be randomly placed.
  final List<AppLocation> _centers = [];

  /// All member phone numbers that will be simulated (including current user).
  final List<String> _memberPhones = [];

  /// Only groups that:
  ///   - are active (if [activeGroupsOnly] = true)
  ///   - AND have geofenceConfig != null
  /// will be added here. We will recalc geofence only for these.
  final Set<String> _geofencedGroupIds = {};

  Timer? _timer;
  final math.Random _random = math.Random();

  MovementSimulator({
    required FirebaseFirestore firestore,
    required UserRepository userRepository,
    required GroupRepository groupRepository,
    required Orchestrator orchestrator,
    required this.currentUserPhone,
    this.activeGroupsOnly = true,
  }) : _firestore = firestore,
       _userRepository = userRepository,
       _groupRepository = groupRepository,
       _orchestrator = orchestrator;

  /// Initializes:
  /// - stores centers
  /// - loads groups related to current user
  /// - fills [_memberPhones]
  /// - fills [_geofencedGroupIds] ONLY with groups that have geofenceConfig
  Future<void> initialize(List<AppLocation> centers) async {
    _centers
      ..clear()
      ..addAll(centers);

    if (_centers.isEmpty) return;

    _memberPhones.clear();
    _geofencedGroupIds.clear();

    // Get all groups for this user using the same logic as GroupRepository.getUserGroups
    final querySnapshot = await _firestore
        .collection('groups')
        .where(
          Filter.or(
            Filter('memberIds', arrayContains: currentUserPhone),
            Filter('creatorId', isEqualTo: currentUserPhone),
          ),
        )
        .get();

    final Set<String> phones = {};

    for (final doc in querySnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final group = GroupModel.fromMap(data);

      if (activeGroupsOnly && !group.isActive) {
        continue;
      }

      // Collect members (for movement)
      for (final memberPhone in group.memberIds) {
        if (memberPhone.isNotEmpty) {
          phones.add(memberPhone);
        }
      }

      // Only groups that actually have geofenceConfig will be tracked
      if (group.geofenceConfig != null) {
        _geofencedGroupIds.add(group.groupId);
      }
    }

    // Ensure current user is also included
    phones.add(currentUserPhone);

    _memberPhones.addAll(phones);
  }

  void start() {
    if (_centers.isEmpty || _memberPhones.isEmpty) {
      return;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateAllMembersPositions();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }

  // ---------------------------------------------------------------------------
  // Internal logic
  // ---------------------------------------------------------------------------

  Future<void> _updateAllMembersPositions() async {
    if (_centers.isEmpty || _memberPhones.isEmpty) return;

    // 1) Update lastKnownLocation for all simulated members
    for (final phone in _memberPhones) {
      final AppLocation loc = _randomLocationInsideAnyCircle();
      await _userRepository.updateLastKnownLocation(phone, loc);
    }

    // 2) Recalculate geofence only for groups that:
    //    - were collected in [_geofencedGroupIds]
    if (_geofencedGroupIds.isEmpty) return;

    await Future.wait(
      _geofencedGroupIds.map(
        (groupId) => _orchestrator.calculateGeofenceForGroup(groupId),
      ),
    );
  }

  AppLocation _randomLocationInsideAnyCircle() {
    final AppLocation center = _centers[_random.nextInt(_centers.length)];

    const double radiusInMeters = 50.0;
    final double u = _random.nextDouble();
    final double r = radiusInMeters * math.sqrt(u);
    final double theta = 2 * math.pi * _random.nextDouble();

    final double dx = r * math.cos(theta);
    final double dy = r * math.sin(theta);

    const double earthRadius = 6378137.0;

    final double deltaLat = (dy / earthRadius) * (180 / math.pi);
    final double deltaLng =
        (dx / (earthRadius * math.cos(center.latitude * math.pi / 180))) *
        (180 / math.pi);

    final double newLat = center.latitude + deltaLat;
    final double newLng = center.longitude + deltaLng;

    return AppLocation(
      id: 'simulated',
      nameEn: null,
      nameAr: null,
      descriptionEn: null,
      descriptionAr: null,
      latitude: newLat,
      longitude: newLng,
    );
  }
}

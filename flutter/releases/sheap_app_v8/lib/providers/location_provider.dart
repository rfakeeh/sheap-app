import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_model.dart';
import '../models/group_model.dart';
import '../models/geofence_model.dart';
import '../models/member_geofence_model.dart';

import '../repositories/user_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/member_geofence_repository.dart';
import '../services/orchestrator.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = true;
  bool _permissionDenied = false;
  bool _serviceEnabled = false;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;

  final UserRepository _userRepository;
  final GroupRepository _groupRepository;
  final MemberGeofenceRepository _memberGeofenceRepository;
  final Orchestrator _orchestrator;

  String? _currentUserId;

  LocationProvider({
    UserRepository? userRepository,
    GroupRepository? groupRepository,
    MemberGeofenceRepository? memberGeofenceRepository,
    Orchestrator? orchestrator,
  }) : _userRepository = userRepository ?? UserRepository(),
       _groupRepository = groupRepository ?? GroupRepository(),
       _memberGeofenceRepository =
           memberGeofenceRepository ?? MemberGeofenceRepository(),
       _orchestrator = orchestrator ?? Orchestrator();

  // Public getters
  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get permissionDenied => _permissionDenied;
  bool get serviceEnabled => _serviceEnabled;

  bool get hasLocation => _currentPosition != null;

  /// Must be called after login to bind the provider to the current user.
  void setCurrentUser(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
  }

  Future<void> startLocationTracking() async {
    _isLoading = true;
    notifyListeners();

    _serviceEnabled = await Geolocator.isLocationServiceEnabled();

    _serviceStatusStream ??= Geolocator.getServiceStatusStream().listen((
      status,
    ) {
      _serviceEnabled = status == ServiceStatus.enabled;

      if (!_serviceEnabled) {
        _positionStream?.cancel();
        _positionStream = null;
      } else {
        _startPositionStream();
      }

      notifyListeners();
    });

    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      _permissionDenied = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _permissionDenied = false;

    await _startPositionStream();
  }

  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;

    _serviceStatusStream?.cancel();
    _serviceStatusStream = null;

    _currentPosition = null;

    _isLoading = false;
  }

  // Permissions
  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  // Start geolocator stream
  Future<void> _startPositionStream() async {
    if (_positionStream != null) return;

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _onPositionUpdate(last);
    } catch (_) {}

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (position) => _onPositionUpdate(position),
          onError: (err) {
            debugPrint("Location stream error: $err");
          },
        );
  }

  // Every new location update
  void _onPositionUpdate(Position position) {
    _currentPosition = position;
    _isLoading = false;
    notifyListeners();

    _updateUserLocationAndGeofences(position);
  }

  // Use repositories to update user location + geofence state
  Future<void> _updateUserLocationAndGeofences(Position pos) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // 1) Update user location using UserRepository
    final liveLoc = AppLocation(
      id: "live",
      nameEn: null,
      nameAr: null,
      latitude: pos.latitude,
      longitude: pos.longitude,
      descriptionEn: null,
      descriptionAr: null,
    );

    try {
      await _userRepository.updateLastKnownLocation(userId, liveLoc);
    } catch (e) {
      debugPrint("Failed to update user location: $e");
      return;
    }

    // 2) Fetch all groups for this user via GroupRepository
    List<GroupModel> allUserGroups = [];
    try {
      allUserGroups = await _groupRepository.getUserGroups(userId).first;
    } catch (e) {
      debugPrint("Failed to get user groups: $e");
      return;
    }

    // Filter only active groups where user is actually a member
    final activeMemberGroups = allUserGroups.where((group) {
      return group.isActive && group.memberIds.contains(userId);
    }).toList();

    // 3) For each group: check geofence if config exists and user is targeted
    for (final group in activeMemberGroups) {
      _orchestrator.calculateGeofenceForGroup(group.groupId);
      /*
      final config = group.geofenceConfig;
      if (config == null) continue;

      if (!config.targetMemberIds.contains(userId)) continue;

      double? centerLat;
      double? centerLng;

      if (config.type == GeofenceType.dynamicLeader) {
        // Use UserRepository to load leader location
        final leaderId = group.leaderId;
        if (leaderId.isEmpty) continue;

        final leader = await _userRepository.getUser(leaderId);
        if (leader == null || leader.lastKnownLocation == null) {
          continue;
        }

        centerLat = leader.lastKnownLocation!.latitude;
        centerLng = leader.lastKnownLocation!.longitude;
      } else {
        centerLat = config.staticLatitude;
        centerLng = config.staticLongitude;
      }

      if (centerLat == null || centerLng == null) continue;

      final distance = _distance(
        pos.latitude,
        pos.longitude,
        centerLat,
        centerLng,
      );

      final isOutside = distance > config.radiusInMeters;

      final geofenceState = MemberGeofence(
        groupId: group.groupId,
        memberId: userId,
        isOutsideGeofence: isOutside,
        distanceMeters: distance,
        updatedAt: DateTime.now(),
      );

      try {
        await _memberGeofenceRepository.upsertMemberGeofence(geofenceState);
      } catch (e) {
        debugPrint("Failed to update geofence state: $e");
      }
      */
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _serviceStatusStream?.cancel();
    super.dispose();
  }
}

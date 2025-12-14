import 'dart:async';
import 'package:flutter/material.dart';

import '../repositories/alert_repository.dart';
import 'group_provider.dart';

class SosCounterProvider with ChangeNotifier {
  final AlertRepository _alertRepo;

  SosCounterProvider({AlertRepository? alertRepository})
    : _alertRepo = alertRepository ?? AlertRepository();

  GroupProvider? _groupProvider;

  /// The logged-in user id (phone). We always track this user's SOS state.
  String? _currentUserId;

  /// Cache: memberId -> whether this member currently has a pending self SOS.
  final Map<String, bool> _memberHasPendingSelfSos = {};

  /// One Firestore stream subscription per tracked member.
  final Map<String, StreamSubscription> _memberSubs = {};

  /// Latest computed counters per groupId.
  final Map<String, int> _pendingCountByGroupId = {};

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns true if the current logged-in user has a pending self SOS.
  bool get isCurrentUserInSos {
    final id = _currentUserId;
    if (id == null) return false;
    return _memberHasPendingSelfSos[id] ?? false;
  }

  /// Returns pending self-SOS count for a group (0 if unknown).
  int pendingSelfSosCountForGroup(String groupId) {
    return _pendingCountByGroupId[groupId] ?? 0;
  }

  /// Returns true if a given member currently has a pending self SOS.
  bool hasPendingSelfSosForMember(String memberId) {
    return _memberHasPendingSelfSos[memberId] ?? false;
  }

  /// Connect this provider to GroupProvider (ProxyProvider should call this).
  void attachGroupProvider(GroupProvider gp) {
    _groupProvider = gp;
    _syncMembersFromGroups();
  }

  /// Set the currently logged-in user.
  /// We ensure this user is always tracked even if there are no active groups yet.
  void setCurrentUser(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _syncMembersFromGroups();
  }

  /// Recompute group counters using the latest member SOS cache.
  void _recomputeGroupCounters() {
    _pendingCountByGroupId.clear();

    final gp = _groupProvider;
    if (gp == null) {
      notifyListeners();
      return;
    }

    // Only count members in active groups.
    final groups = gp.allUserGroups.where((g) => g.isActive);

    for (final group in groups) {
      int count = 0;

      for (final memberId in group.memberIds) {
        if (_memberHasPendingSelfSos[memberId] == true) {
          count++;
        }
      }

      _pendingCountByGroupId[group.groupId] = count;
    }

    notifyListeners();
  }

  /// Ensures we have subscriptions for all members we need to track:
  /// - all members from active groups
  /// - the current logged-in user (always)
  void _syncMembersFromGroups() {
    final gp = _groupProvider;

    _error = null;

    // 1) Collect all members from active groups.
    final Set<String> targetMembers = {};

    if (gp != null) {
      final activeGroups = gp.allUserGroups.where((g) => g.isActive);
      for (final g in activeGroups) {
        targetMembers.addAll(g.memberIds);
      }
    }

    // 2) Always track current user, even if not in groups yet.
    if (_currentUserId != null) {
      targetMembers.add(_currentUserId!);
    }

    // 3) Remove subscriptions for members no longer needed.
    final existingMembers = _memberSubs.keys.toSet();
    final toRemove = existingMembers.difference(targetMembers);

    for (final memberId in toRemove) {
      _memberSubs[memberId]?.cancel();
      _memberSubs.remove(memberId);
      _memberHasPendingSelfSos.remove(memberId);
    }

    // 4) Add subscriptions for newly needed members.
    final toAdd = targetMembers.difference(existingMembers);

    if (toAdd.isNotEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    for (final memberId in toAdd) {
      // Default cache value until first snapshot arrives.
      _memberHasPendingSelfSos[memberId] =
          _memberHasPendingSelfSos[memberId] ?? false;

      _memberSubs[memberId] = _alertRepo
          .streamPendingSelfSosForMember(memberId)
          .listen(
            (alerts) {
              // If at least one alert exists, member has a pending self SOS.
              _memberHasPendingSelfSos[memberId] = alerts.isNotEmpty;

              // Update group counters after cache changes.
              _recomputeGroupCounters();
            },
            onError: (e) {
              _error = e.toString();
              notifyListeners();
            },
          );
    }

    _isLoading = false;

    // 5) Recompute immediately using current cache.
    _recomputeGroupCounters();
  }

  /// Manual refresh:
  /// - Re-sync members from groups (in case groups changed)
  /// - Recompute counters
  Future<void> refresh() async {
    _syncMembersFromGroups();
  }

  /// Cancel all subscriptions and clear caches (call on logout).
  void reset() {
    for (final sub in _memberSubs.values) {
      sub.cancel();
    }
    _memberSubs.clear();
    _memberHasPendingSelfSos.clear();
    _pendingCountByGroupId.clear();
    _isLoading = false;
    _error = null;
    _currentUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}

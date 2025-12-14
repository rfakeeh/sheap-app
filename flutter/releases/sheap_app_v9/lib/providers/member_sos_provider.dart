import 'dart:async';
import 'package:flutter/material.dart';

import '../repositories/alert_repository.dart';
import 'group_provider.dart';

class SosCounterProvider with ChangeNotifier {
  final AlertRepository _alertRepo;

  SosCounterProvider({AlertRepository? alertRepository})
    : _alertRepo = alertRepository ?? AlertRepository();

  GroupProvider? _groupProvider;

  // Cache: memberId -> whether this member currently has a pending self SOS.
  final Map<String, bool> _memberHasPendingSelfSos = {};

  // We keep one listener per member to receive real-time updates.
  final Map<String, StreamSubscription> _memberSubs = {};

  // Latest computed counters per groupId.
  final Map<String, int> _pendingCountByGroupId = {};

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get pending self-SOS count for a group (0 if unknown).
  int pendingSelfSosCountForGroup(String groupId) {
    return _pendingCountByGroupId[groupId] ?? 0;
  }

  /// Connect this provider to GroupProvider (ProxyProvider will call this).
  void attachGroupProvider(GroupProvider gp) {
    _groupProvider = gp;

    // Always re-sync because the instance is the same but its data changes.
    _syncMembersFromGroups();
  }

  /// Force a recompute of group counters using current cache.
  /// This is cheap and runs locally.
  void _recomputeGroupCounters() {
    _pendingCountByGroupId.clear();

    final gp = _groupProvider;
    if (gp == null) {
      notifyListeners();
      return;
    }

    final groups = gp.allUserGroups.where((g) => g.isActive);

    for (final group in groups) {
      int count = 0;

      // Count only members inside this group.
      for (final memberId in group.memberIds) {
        if (_memberHasPendingSelfSos[memberId] == true) {
          count++;
        }
      }

      _pendingCountByGroupId[group.groupId] = count;
    }

    notifyListeners();
  }

  /// Read groups from GroupProvider and ensure we have listeners for all members.
  void _syncMembersFromGroups() {
    final gp = _groupProvider;
    if (gp == null) return;

    _error = null;

    // 1) Collect all members from active groups.
    final Set<String> targetMembers = {};
    final activeGroups = gp.allUserGroups.where((g) => g.isActive);

    for (final g in activeGroups) {
      targetMembers.addAll(g.memberIds);
    }

    // 2) Remove listeners for members that are no longer needed.
    final existingMembers = _memberSubs.keys.toSet();
    final toRemove = existingMembers.difference(targetMembers);

    for (final memberId in toRemove) {
      _memberSubs[memberId]?.cancel();
      _memberSubs.remove(memberId);
      _memberHasPendingSelfSos.remove(memberId);
    }

    // 3) Add listeners for newly needed members.
    final toAdd = targetMembers.difference(existingMembers);

    if (toAdd.isNotEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    for (final memberId in toAdd) {
      _memberHasPendingSelfSos[memberId] = false;

      _memberSubs[memberId] = _alertRepo
          .streamPendingSelfSosForMember(memberId)
          .listen(
            (alerts) {
              // If at least one alert exists, then member has a pending self SOS.
              _memberHasPendingSelfSos[memberId] = alerts.isNotEmpty;

              // Update group counters after cache changes.
              _recomputeGroupCounters();
            },
            onError: (e) {
              // Keep last known cache value, but record error.
              _error = e.toString();
              notifyListeners();
            },
          );
    }

    _isLoading = false;

    // 4) Recompute immediately using current cache.
    _recomputeGroupCounters();
  }

  /// Manual refresh:
  /// - Re-sync members from groups (in case something changed)
  /// - Recompute counters from cache
  ///
  /// Note: streams are already real-time, so this is usually optional,
  /// but it's useful after SOS flows or when you suspect connectivity issues.
  Future<void> refresh() async {
    _syncMembersFromGroups();
  }

  /// Stop everything (call on logout).
  void reset() {
    for (final sub in _memberSubs.values) {
      sub.cancel();
    }
    _memberSubs.clear();
    _memberHasPendingSelfSos.clear();
    _pendingCountByGroupId.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}

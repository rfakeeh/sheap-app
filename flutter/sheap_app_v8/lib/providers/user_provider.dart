import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Phone -> AppUser object (live cache for all watched users)
  final Map<String, AppUser> _users = {};

  /// Phone -> Firestore subscription (users/{phone})
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _subs = {};

  /// Set of phone numbers we are currently watching
  Set<String> _watchedPhones = {};

  // ------------ PUBLIC GETTERS ------------

  /// All loaded AppUser objects
  List<AppUser> get allUsers => _users.values.toList();

  /// Get a specific user by phone number from cache (may be null if not loaded yet)
  AppUser? getUser(String phone) => _users[phone];

  /// For debugging: which phone numbers are being watched
  Set<String> get watchedPhones => _watchedPhones;

  /// Get all members of a given group (based on cached users only)
  List<AppUser> getGroupMembers(GroupModel group) {
    return group.memberIds
        .map((phone) => _users[phone])
        .whereType<AppUser>()
        .toList();
  }

  /// Get the leader user object of a group (if available in cache)
  AppUser? getGroupLeader(GroupModel group) {
    return _users[group.leaderId];
  }

  /// Get the creator user object of a group (if available in cache)
  AppUser? getGroupCreator(GroupModel group) {
    return _users[group.creatorId];
  }

  // ------------ PUBLIC API ------------

  /// Sync watched users based on current user and all their groups.
  ///
  /// This should be called whenever the group list changes.
  /// (We already do that from main.dart via ChangeNotifierProxyProvider).
  void syncWithGroups(String? currentUserPhone, List<GroupModel> groups) {
    // If there is no current user, stop watching everyone.
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      _updateWatchedPhones(<String>{});
      return;
    }

    final newPhones = <String>{};

    // 1) Always watch the current user
    newPhones.add(currentUserPhone);

    // 2) Watch all creators, leaders, and members from all related groups
    for (final group in groups) {
      if (group.creatorId.isNotEmpty) {
        newPhones.add(group.creatorId);
      }
      if (group.leaderId.isNotEmpty) {
        newPhones.add(group.leaderId);
      }
      newPhones.addAll(group.memberIds);
    }

    _updateWatchedPhones(newPhones);
  }

  // ------------ INTERNAL LOGIC ------------

  /// Update Firestore subscriptions according to the new set of phones.
  void _updateWatchedPhones(Set<String> newPhones) {
    // 1) Cancel subscriptions we no longer need
    final toRemove = _watchedPhones.difference(newPhones);
    for (final phone in toRemove) {
      _subs[phone]?.cancel();
      _subs.remove(phone);
      _users.remove(phone);
    }

    // 2) Add new subscriptions for newly added phone numbers
    final toAdd = newPhones.difference(_watchedPhones);
    for (final phone in toAdd) {
      final sub = _firestore.collection('users').doc(phone).snapshots().listen((
        snap,
      ) {
        if (!snap.exists || snap.data() == null) {
          // User document deleted or missing
          _users.remove(phone);
        } else {
          // Convert Firestore data to AppUser and store it in cache
          _users[phone] = AppUser.fromMap(snap.data()!);
        }
        notifyListeners(); // Any UI watching this provider will rebuild
      });

      _subs[phone] = sub;
    }

    // 3) Save the new watched set and notify listeners
    _watchedPhones = newPhones;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel all active subscriptions
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}

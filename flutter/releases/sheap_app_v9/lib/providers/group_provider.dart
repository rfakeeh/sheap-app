import 'dart:async';
import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../repositories/group_repository.dart';

class GroupProvider with ChangeNotifier {
  List<GroupModel> _groups = [];
  StreamSubscription<List<GroupModel>>? _groupsListener;
  final GroupRepository _groupRepository;

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserPhone;

  GroupProvider({GroupRepository? groupRepository})
    : _groupRepository = groupRepository ?? GroupRepository();

  // PUBLIC GETTERS
  //   all groups where (creatorId == phone || memberIds contains phone)
  List<GroupModel> get allUserGroups => _groups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUserPhone => _currentUserPhone;

  /// Groups where the user is the *creator* (even if not a member)
  List<GroupModel> get createdGroups {
    if (_currentUserPhone == null) return const [];
    return _groups.where((g) => g.creatorId == _currentUserPhone).toList();
  }

  /// Groups where the user is a *member but not the creator*
  List<GroupModel> get joinedGroups {
    if (_currentUserPhone == null) return const [];
    return _groups
        .where(
          (g) =>
              g.memberIds.contains(_currentUserPhone) &&
              g.creatorId != _currentUserPhone &&
              g.isActive,
        )
        .toList();
  }

  /// Start listening to all groups that belong to this user.
  /// Call this once after login (e.g. in AuthWrapper or Home initState).
  void startListening(String userPhone) {
    // If subscription exists and same user, do nothing
    if (_currentUserPhone == userPhone && _groupsListener != null) return;

    _currentUserPhone = userPhone;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Cancel old subscription if any
    _groupsListener?.cancel();

    _groupsListener = _groupRepository
        .getUserGroups(userPhone)
        .listen(
          (groupList) {
            _groups = groupList;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (error) {
            _isLoading = false;
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  /// Returns a unique set of all member IDs visible to the given user
  /// across all *active* groups that the provider already tracks.
  ///
  /// Important:
  /// `_groups` already contains only the groups where the current user
  /// is a creator or a member (based on getUserGroups in the repository),
  /// so no need to re-check if the user belongs to the group.
  ///
  /// Visibility rules:
  /// - Always include the group's creator.
  /// - If the tracking mode is LEADERS_ONLY → include only the leader.
  /// - If the tracking mode is ALL_VISIBLE → include all members.
  ///
  /// The current user's phone number is excluded from the final result.
  Set<String> getAllVisibleMembersFor(String currentUserPhone) {
    final ids = <String>{};

    // 1) Only consider active groups belonging to the current user
    final activeGroups = _groups.where((g) => g.isActive);

    for (final g in activeGroups) {
      // Always include creator
      ids.add(g.creatorId);

      if (g.trackingMode == TrackingMode.leaderOnly) {
        // Leaders-only → include leader only
        ids.add(g.leaderId);
      } else if (g.trackingMode == TrackingMode.allVisible) {
        // All-visible → include every member
        ids.addAll(g.memberIds);
      }
    }

    // Remove the current user from visibility list
    ids.remove(currentUserPhone);

    return ids;
  }

  /// Stop listening (e.g. on logout)
  void stopListening() {
    _groupsListener?.cancel();
    _groupsListener = null;
    _groups = [];
    _currentUserPhone = null;
    _isLoading = false;
    _errorMessage = null;
  }

  @override
  void dispose() {
    _groupsListener?.cancel();
    super.dispose();
  }
}

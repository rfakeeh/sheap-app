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

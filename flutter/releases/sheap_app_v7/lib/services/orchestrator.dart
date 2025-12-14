import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/group_repository.dart';

class Orchestrator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final UserRepository _userRepo = UserRepository();
  final GroupRepository _groupRepo = GroupRepository();

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

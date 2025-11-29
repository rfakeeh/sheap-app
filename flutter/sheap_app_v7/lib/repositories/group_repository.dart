import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/member_model.dart';

class GroupRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks if a group name already exists in the collection.
  /// (Used for generating unique names)
  Future<bool> checkGroupNameExists(String name) async {
    final query = await _firestore
        .collection('groups')
        .where('groupName', isEqualTo: name)
        .limit(1) // We only need to know if 1 exists
        .get();

    return query.docs.isNotEmpty;
  }

  /// Creates a group.
  /// If [transaction] is provided, writes within that transaction.
  Future<void> createGroup(GroupModel group, {Transaction? transaction}) async {
    DocumentReference ref = _firestore.collection('groups').doc(group.groupId);

    if (transaction != null) {
      transaction.set(ref, group.toMap());
    } else {
      await ref.set(group.toMap());
    }
  }

  // --- Standard Methods (No changes needed) ---
  Future<GroupModel?> getGroupById(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromMap(doc.data()!);
  }

  Stream<List<GroupModel>> getUserGroups(String userPhone) {
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: userPhone)
        .orderBy('isActive', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<void> toggleGroupStatus(String groupId, bool isActive) async {
    await _firestore.collection('groups').doc(groupId).update({
      'isActive': isActive,
    });
  }

  /// Deletes a group by its ID.
  /// If [transaction] is provided, the delete happens inside that transaction.
  Future<void> deleteGroup(String groupId, {Transaction? transaction}) async {
    final ref = _firestore.collection('groups').doc(groupId);

    if (transaction != null) {
      transaction.delete(ref);
    } else {
      await ref.delete();
    }
  }

  Future<void> updateGroup(GroupModel updatedGroup) async {
    final ref = _firestore.collection('groups').doc(updatedGroup.groupId);
    await ref.update(updatedGroup.toMap());
  }

  // ----------------------------
  // Add a new member to a group
  // ----------------------------
  Future<void> joinGroup({
    required GroupModel group,
    required GroupMember member,
  }) async {
    final ref = _firestore.collection('groups').doc(group.groupId);

    // Prevent adding the same member twice
    if (group.memberIds.contains(member.phoneNumber)) {
      return; // Already joined → no update needed
    }

    // Build updated members list
    final updatedMembers = [...group.members, member];

    // Build updated memberIds list
    final updatedIds = [...group.memberIds, member.phoneNumber];

    // Update only the affected fields in Firestore
    await ref.update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'memberIds': updatedIds,
    });
  }

  // ----------------------------
  // Remove a member from a group
  // ----------------------------
  Future<void> removeMember({
    required GroupModel group,
    required String phoneNumber,
  }) async {
    final ref = _firestore.collection('groups').doc(group.groupId);

    // Filter out the removed member from the 'members' list
    final updatedMembers = group.members
        .where((m) => m.phoneNumber != phoneNumber)
        .toList();

    // Filter out the removed member from 'memberIds'
    final updatedIds = group.memberIds
        .where((id) => id != phoneNumber)
        .toList();

    // Update only these two fields
    await ref.update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'memberIds': updatedIds,
    });
  }
}

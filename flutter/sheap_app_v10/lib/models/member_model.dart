class GroupMember {
  final String phoneNumber;
  final List<String> roles; // 'CREATOR', 'LEADER', 'MEMBER'
  final DateTime joinedAt; // Good for history and sorting

  GroupMember({
    required this.phoneNumber,
    required this.roles,
    required this.joinedAt,
  });

  bool get isCreator => roles.contains('CREATOR');
  bool get isLeader => roles.contains('LEADER');

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'roles': roles, // e.g. ['CREATOR', 'LEADER']
      'joinedAt': joinedAt.toIso8601String(), // Store as string
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      phoneNumber: map['phoneNumber'] ?? '',
      roles: List<String>.from(map['roles'] ?? []),
      // Parse string back to DateTime
      joinedAt: map['joinedAt'] != null
          ? DateTime.parse(map['joinedAt'])
          : DateTime.now(),
    );
  }
}

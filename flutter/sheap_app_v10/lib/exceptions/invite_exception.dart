class InviteErrorCodes {
  static const String userNotFound = 'USER_NOT_FOUND';
  static const String groupNotFound = 'GROUP_NOT_FOUND';
  static const String alreadyMember = 'ALREADY_MEMBER';
}

class InviteException implements Exception {
  final String code;
  final String? message;

  InviteException(this.code, [this.message]);

  @override
  String toString() => 'InviteException(code: $code, message: $message)';
}

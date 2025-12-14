class AlertErrorCodes {
  static const String duplicatePendingAlert = 'DUPLICATE_PENDING_ALERT';
}

class AlertException implements Exception {
  final String code;
  final String? message;

  AlertException(this.code, [this.message]);

  @override
  String toString() => 'AlertException(code: $code, message: $message)';
}

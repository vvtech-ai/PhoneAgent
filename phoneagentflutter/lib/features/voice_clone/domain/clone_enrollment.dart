enum CloneStep {
  consent,
  identity,
  collecting,
  checking,
  generating,
  candidateError,
  candidate,
  confirmed,
}

class CloneVerification {
  const CloneVerification(this.id, this.script);
  final String id, script;
}

/// The SDK only collects. The server independently decides verification/creation.
abstract interface class CloneEnrollmentPort {
  Future<bool> replacementRequired(String identityNumber);
  Future<CloneVerification> initialize(
    String name,
    String identityNumber,
    bool replacementConfirmed,
  );
  Future<void> collect(CloneVerification verification);
  Future<void> verify(CloneVerification verification);
  Future<void> generate(CloneVerification verification);
  Future<void> preview();
  void stopPreview();
  Future<void> confirm({required bool saveRecording});
  void close();
}

String normalizeCloneIdentityInput(String value, String previous) {
  final trimmed = value.trim().toUpperCase();
  final number = trimmed.length > 18 ? trimmed.substring(0, 18) : trimmed;
  return RegExp(r'^(?:[0-9]{0,17}|[0-9]{17}[0-9X])$').hasMatch(number)
      ? number
      : previous;
}

bool validCloneIdentityNumber(String value) {
  final number = value.trim().toUpperCase();
  if (!RegExp(r'^\d{17}[0-9X]$').hasMatch(number)) return false;
  final year = int.parse(number.substring(6, 10));
  final month = int.parse(number.substring(10, 12));
  final day = int.parse(number.substring(12, 14));
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return false;
  const weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += int.parse(number[i]) * weights[i];
  }
  return '10X98765432'[sum % 11] == number[17];
}

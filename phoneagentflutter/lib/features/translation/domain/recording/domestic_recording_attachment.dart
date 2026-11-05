/// Journal stores immutable metadata, never arbitrary local paths or audio.
class DomesticRecordingAttachment {
  DomesticRecordingAttachment({
    required this.durationMillis,
    required this.checksumSha256,
  }) {
    if (durationMillis <= 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksumSha256)) {
      throw const FormatException('Invalid domestic recording metadata');
    }
  }
  final int durationMillis;
  final String checksumSha256;
}

abstract interface class DomesticRecordingUploader {
  Future<void> upload({
    required String serverCallId,
    required String clientCallId,
    required DomesticRecordingAttachment recording,
  });
}

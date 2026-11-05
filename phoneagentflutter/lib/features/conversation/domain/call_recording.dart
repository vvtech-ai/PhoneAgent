import '../../translation_history/domain/recording_audio.dart';

/// Recording availability is independent from playback and the call outcome.
class CallRecordingInfo {
  const CallRecordingInfo({
    required this.callId,
    required this.status,
    this.durationMillis,
    this.sizeBytes,
  });
  final String callId, status;
  final int? durationMillis, sizeBytes;
  bool get processing =>
      status == 'RECORDING' || status == 'PROCESSING' || status == 'RESERVED';
}

abstract interface class CallRecordingRepository
    implements RecordingAudioRepository {
  Future<CallRecordingInfo> metadata();
}

import '../domain/translation_history.dart';
import '../domain/local_translation_recording.dart';

class LocalRecordingHistoryRepository implements TranslationHistoryRepository {
  const LocalRecordingHistoryRepository(this.remote, this.local);
  final TranslationHistoryRepository remote;
  final LocalTranslationRecording local;
  @override
  Future<TranslationHistory> load(String callId) async {
    final detail = await remote.load(callId);
    if (detail.recording != null || !await local.available(callId)) {
      return detail;
    }
    return TranslationHistory(
      callId: detail.callId,
      route: detail.route,
      targetName: detail.targetName,
      phoneNumber: detail.phoneNumber,
      myLanguage: detail.myLanguage,
      peerLanguage: detail.peerLanguage,
      connectedAt: detail.connectedAt,
      endedAt: detail.endedAt,
      durationMillis: detail.durationMillis,
      transcripts: detail.transcripts,
      localRecordingAvailable: true,
    );
  }
}

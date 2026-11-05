import 'package:phone_agent/features/translation_history/domain/translation_history.dart';

class OfflineTranslationHistory implements TranslationHistoryRepository {
  bool fail = false;
  int loads = 0;
  @override
  Future<TranslationHistory> load(String callId) async {
    loads++;
    if (fail) throw StateError('synthetic');
    return TranslationHistory(
      callId: callId,
      route: TranslationRoute.worldCall,
      targetName: '合成翻译对象',
      phoneNumber: '10000',
      myLanguage: 'zh',
      peerLanguage: 'en',
      connectedAt: '2026-09-16T08:00:00Z',
      endedAt: '2026-09-16T08:02:50Z',
      durationMillis: 170000,
      transcripts: const [
        TranslationTranscript(
          segmentId: '1',
          sourceLeg: 'remote',
          sourceLanguage: 'en',
          sourceText: 'Hello?',
          translatedLanguage: 'zh',
          translatedText: '你好，在吗？',
          isFinal: false,
        ),
        TranslationTranscript(
          segmentId: '2',
          sourceLeg: 'local',
          sourceLanguage: 'zh',
          sourceText: '我在的，有什么事吗？',
          translatedLanguage: 'en',
          translatedText: 'Yeah, can I help you?',
          isFinal: true,
        ),
        TranslationTranscript(
          segmentId: '3',
          sourceLeg: 'remote',
          sourceLanguage: 'en',
          sourceText: 'Are you free for dinner?',
          translatedLanguage: 'zh',
          translatedText: '有空一起吃晚饭吗？',
          isFinal: true,
        ),
      ],
    );
  }
}

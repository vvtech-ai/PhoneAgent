enum TranslationRoute { domesticSip, worldCall }

class TranslationTranscript {
  const TranslationTranscript({
    required this.segmentId,
    required this.sourceLeg,
    required this.sourceLanguage,
    required this.sourceText,
    required this.translatedLanguage,
    required this.translatedText,
    required this.isFinal,
  });
  final String segmentId,
      sourceLeg,
      sourceLanguage,
      sourceText,
      translatedLanguage,
      translatedText;
  final bool isFinal;
}

class TranslationRecording {
  const TranslationRecording({
    required this.source,
    this.clusterId,
    this.callSessionId,
    this.accessGrant,
    this.contentUrl,
    this.fileName = 'realtime-translation.m4a',
    this.cacheKey,
    this.checksum,
    this.sizeBytes,
  });
  final String source, fileName;
  final String? clusterId,
      callSessionId,
      accessGrant,
      contentUrl,
      cacheKey,
      checksum;
  final int? sizeBytes;
  // Do not implement toString with locator/grant. Not presentation state.
}

class TranslationHistory {
  const TranslationHistory({
    required this.callId,
    required this.route,
    required this.targetName,
    required this.phoneNumber,
    required this.myLanguage,
    required this.peerLanguage,
    required this.connectedAt,
    required this.endedAt,
    required this.durationMillis,
    required this.transcripts,
    this.recording,
    this.localRecordingAvailable = false,
  });
  final String callId,
      targetName,
      phoneNumber,
      myLanguage,
      peerLanguage,
      connectedAt,
      endedAt;
  final TranslationRoute route;
  final int durationMillis;
  final List<TranslationTranscript> transcripts;
  final TranslationRecording? recording;
  final bool localRecordingAvailable;
}

abstract interface class TranslationHistoryRepository {
  Future<TranslationHistory> load(String callId);
}

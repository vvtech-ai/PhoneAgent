import 'translation_call_view.dart';
import 'recording/domestic_recording_attachment.dart';

enum TranslationArchiveRoute { worldCall, domesticSip }

enum TranslationArchiveStage {
  active,
  draining,
  ready,
  recordingUpload,
  completed,
}

/// Only the locator required by the existing history API, never media tokens.
class TranslationArchiveLocator {
  const TranslationArchiveLocator(this.cluster, this.sessionId, this.grant);
  final String cluster, sessionId, grant;
}

class TranslationArchiveEntry {
  TranslationArchiveEntry({
    required this.accountId,
    required this.clientCallId,
    required this.targetName,
    required this.phone,
    required this.myLanguage,
    required this.peerLanguage,
    this.locator,
    this.recording,
    this.recordingPending = false,
    this.serverCallId,
    this.route = TranslationArchiveRoute.worldCall,
    this.connectedAt,
    this.lastObservedAt,
    this.endedAt,
    this.stage = TranslationArchiveStage.active,
    List<TranslationTranscript> transcripts = const [],
  }) : transcripts = List.unmodifiable(transcripts);
  final String accountId,
      clientCallId,
      targetName,
      phone,
      myLanguage,
      peerLanguage;
  final TranslationArchiveLocator? locator;
  final DomesticRecordingAttachment? recording;
  final bool recordingPending;
  final String? serverCallId;
  bool get canArchive =>
      stage == TranslationArchiveStage.ready ||
      stage == TranslationArchiveStage.recordingUpload ||
      stage == TranslationArchiveStage.completed;
  final TranslationArchiveRoute route;
  final int? connectedAt, lastObservedAt, endedAt;
  final TranslationArchiveStage stage;
  final List<TranslationTranscript> transcripts;

  TranslationArchiveEntry copy({
    TranslationArchiveLocator? locator,
    DomesticRecordingAttachment? recording,
    bool? recordingPending,
    String? serverCallId,
    int? connectedAt,
    int? lastObservedAt,
    int? endedAt,
    TranslationArchiveStage? stage,
    List<TranslationTranscript>? transcripts,
  }) => TranslationArchiveEntry(
    accountId: accountId,
    clientCallId: clientCallId,
    targetName: targetName,
    phone: phone,
    myLanguage: myLanguage,
    peerLanguage: peerLanguage,
    locator: locator ?? this.locator,
    recording: recording ?? this.recording,
    recordingPending: recordingPending ?? this.recordingPending,
    serverCallId: serverCallId ?? this.serverCallId,
    route: route,
    connectedAt: connectedAt ?? this.connectedAt,
    lastObservedAt: lastObservedAt ?? this.lastObservedAt,
    endedAt: endedAt ?? this.endedAt,
    stage: stage ?? this.stage,
    transcripts: transcripts ?? this.transcripts,
  );

  /// Once terminal is observed, only already-known segments may be completed.
  TranslationArchiveEntry merge(TranslationArchiveEntry next) {
    if (stage == TranslationArchiveStage.recordingUpload ||
        stage == TranslationArchiveStage.completed) {
      return this;
    }
    if (stage == TranslationArchiveStage.ready) {
      if (recordingPending &&
          !next.recordingPending &&
          next.clientCallId == clientCallId &&
          next.accountId == accountId &&
          next.route == route) {
        return copy(recording: next.recording, recordingPending: false);
      }
      return this;
    }
    if (stage != TranslationArchiveStage.draining) return next;
    final updates = {for (final item in next.transcripts) item.key: item};
    return copy(
      recording: next.recording,
      recordingPending: next.recordingPending,
      transcripts: [
        for (final item in transcripts)
          _finalized(updates[item.key] ?? item, item.isFinal),
      ],
    );
  }

  TranslationArchiveEntry seal() =>
      stage == TranslationArchiveStage.recordingUpload ||
          stage == TranslationArchiveStage.completed
      ? this
      : copy(
          stage: TranslationArchiveStage.ready,
          transcripts: [for (final item in transcripts) _finalized(item, true)],
        );

  TranslationArchiveEntry recover() {
    final connected = connectedAt;
    if (connected == null) return this;
    final end = endedAt ?? lastObservedAt ?? connected + 1;
    return copy(endedAt: end > connected ? end : connected + 1).seal();
  }

  static TranslationTranscript _finalized(
    TranslationTranscript item,
    bool finalValue,
  ) => TranslationTranscript(
    id: item.id,
    leg: item.leg,
    source: item.source,
    translated: item.translated,
    sourceLanguage: item.sourceLanguage,
    translatedLanguage: item.translatedLanguage,
    isFinal:
        item.isFinal ||
        (finalValue &&
            (item.source.trim().isNotEmpty ||
                item.translated.trim().isNotEmpty)),
  );
}

abstract interface class TranslationArchiveStore {
  Future<List<TranslationArchiveEntry>> load();
  Future<void> save(List<TranslationArchiveEntry> entries);
}

abstract interface class TranslationArchiveGateway {
  Future<String> archive(TranslationArchiveEntry entry);
}

/// Checkpoints separate the server upsert from the domestic recording upload.
abstract interface class TranslationArchivePhasedGateway
    implements TranslationArchiveGateway {
  Future<String> createRecord(TranslationArchiveEntry entry);
  Future<void> uploadRecording(
    TranslationArchiveEntry entry,
    String serverCallId,
  );
}

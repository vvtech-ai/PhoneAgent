import 'dart:convert';
import '../domain/translation_archive.dart';
import '../domain/recording/domestic_recording_attachment.dart';
import '../domain/translation_call_view.dart';

class TranslationArchiveCodec {
  static Map<String, Object?> entry(TranslationArchiveEntry value) => {
    'accountId': value.accountId,
    'route': value.route.name,
    'recordingPending': value.recordingPending,
    if (value.serverCallId != null) 'serverCallId': value.serverCallId,
    'clientCallId': value.clientCallId,
    'targetName': value.targetName,
    'phone': value.phone,
    'myLanguage': value.myLanguage,
    'peerLanguage': value.peerLanguage,
    'stage': value.stage.name,
    'connectedAt': value.connectedAt,
    'lastObservedAt': value.lastObservedAt,
    'endedAt': value.endedAt,
    if (value.locator case final locator?)
      'locator': {
        'cluster': locator.cluster,
        'sessionId': locator.sessionId,
        'grant': locator.grant,
      },
    if (value.recording case final recording?)
      'recording': {
        'durationMillis': recording.durationMillis,
        'checksumSha256': recording.checksumSha256,
      },
    'transcripts': [for (final item in value.transcripts) transcript(item)],
  };

  static Map<String, Object?> transcript(TranslationTranscript value) => {
    'segmentId': value.id,
    'sourceLeg': value.leg,
    'sourceLanguage': value.sourceLanguage,
    'sourceText': value.source,
    'translatedLanguage': value.translatedLanguage,
    'translatedText': value.translated,
    'final': value.isFinal,
  };

  static String encode(
    String scope,
    String account,
    List<TranslationArchiveEntry> values,
  ) {
    final raw = jsonEncode({
      'version': 1,
      'scope': scope,
      'entries': values.map(entry).toList(),
    });
    decode(scope, account, raw);
    return raw;
  }

  static List<TranslationArchiveEntry> decode(
    String scope,
    String account,
    String? raw,
  ) {
    if (raw == null) return [];
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      if (root['version'] != 1 || root['scope'] != scope) {
        throw const FormatException();
      }
      final ids = <String>{};
      return (root['entries'] as List).map((item) {
        final data = item as Map<String, dynamic>;
        final id = data['clientCallId'] as String;
        if (data['accountId'] != account ||
            !RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(id) ||
            !ids.add(id)) {
          throw const FormatException();
        }
        final locator = data['locator'] as Map<String, dynamic>?;
        final recording = data['recording'] as Map<String, dynamic>?;
        final value = TranslationArchiveEntry(
          accountId: account,
          serverCallId: data['serverCallId'] as String?,
          recordingPending: data['recordingPending'] as bool? ?? false,
          recording: recording == null
              ? null
              : DomesticRecordingAttachment(
                  durationMillis: recording['durationMillis'] as int,
                  checksumSha256: recording['checksumSha256'] as String,
                ),
          route: data['route'] == null
              ? TranslationArchiveRoute.worldCall
              : TranslationArchiveRoute.values.byName(data['route'] as String),
          clientCallId: id,
          targetName: data['targetName'] as String,
          phone: data['phone'] as String,
          myLanguage: data['myLanguage'] as String,
          peerLanguage: data['peerLanguage'] as String,
          stage: TranslationArchiveStage.values.byName(data['stage'] as String),
          connectedAt: data['connectedAt'] as int?,
          lastObservedAt: data['lastObservedAt'] as int?,
          endedAt: data['endedAt'] as int?,
          locator: locator == null
              ? null
              : TranslationArchiveLocator(
                  locator['cluster'] as String,
                  locator['sessionId'] as String,
                  locator['grant'] as String,
                ),
          transcripts: (data['transcripts'] as List)
              .map(
                (item) => TranslationTranscript(
                  id: item['segmentId'] as String,
                  leg: item['sourceLeg'] as String,
                  source: item['sourceText'] as String,
                  translated: item['translatedText'] as String,
                  sourceLanguage: item['sourceLanguage'] as String,
                  translatedLanguage: item['translatedLanguage'] as String,
                  isFinal: item['final'] as bool,
                ),
              )
              .toList(),
        );
        final checkpoint =
            value.stage == TranslationArchiveStage.recordingUpload ||
            value.stage == TranslationArchiveStage.completed;
        if ((value.serverCallId != null &&
                (value.serverCallId!.trim().isEmpty ||
                    value.serverCallId!.length > 512 ||
                    value.serverCallId!.contains(RegExp(r'[\r\n\x00]')) ||
                    !checkpoint)) ||
            (checkpoint &&
                (value.serverCallId == null || value.recordingPending)) ||
            (value.stage == TranslationArchiveStage.recordingUpload &&
                value.route != TranslationArchiveRoute.domesticSip) ||
            (value.recordingPending &&
                (value.route != TranslationArchiveRoute.domesticSip ||
                    value.recording != null)) ||
            (value.recording != null &&
                (value.route != TranslationArchiveRoute.domesticSip ||
                    value.connectedAt == null ||
                    value.endedAt == null ||
                    value.recording!.durationMillis !=
                        value.endedAt! - value.connectedAt!)) ||
            (value.route == TranslationArchiveRoute.domesticSip &&
                value.locator != null) ||
            value.phone.isEmpty ||
            value.myLanguage.isEmpty ||
            value.peerLanguage.isEmpty ||
            (value.connectedAt != null && value.connectedAt! < 0) ||
            (value.endedAt != null &&
                (value.connectedAt == null ||
                    value.endedAt! <= value.connectedAt!)) ||
            (value.stage != TranslationArchiveStage.active &&
                value.endedAt == null)) {
          throw const FormatException();
        }
        return value;
      }).toList();
    } catch (_) {
      // Never include the corrupt journal's contents (grants/transcripts).
      throw const FormatException('Invalid translation archive journal');
    }
  }
}

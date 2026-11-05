import 'dart:convert';
import '../domain/translation_archive.dart';
import '../domain/translation_call_view.dart';
import 'translation_archive_codec.dart';

/// v65 Gson journal -> current shared queue. No domestic files or media tokens.
class LegacyTranslationArchiveCodec {
  static List<TranslationArchiveEntry> decode(String account, String raw) {
    try {
      if (utf8.encode(raw).length > 8 * 1024 * 1024) {
        throw const FormatException();
      }
      final entries = <TranslationArchiveEntry>[];
      final ids = <String>{};
      for (final value in jsonDecode(raw) as List) {
        final data = value as Map<String, dynamic>;
        if (data['accountId'] != account) throw const FormatException();
        if (data['route'] == 'DOMESTIC_ANDROID') continue;
        if (data['route'] != 'WORLD_CALL') throw const FormatException();
        final stage = data['stage'];
        if (const {
          'PRE_CONNECT',
          'COMPLETED',
          'TERMINAL_FAILURE',
        }.contains(stage)) {
          continue;
        }
        final mappedStage = switch (stage) {
          'CONNECTED' => TranslationArchiveStage.active,
          'TERMINAL_DRAINING' => TranslationArchiveStage.draining,
          'READY_TO_ARCHIVE' || 'ARCHIVING' => TranslationArchiveStage.ready,
          _ => throw const FormatException(),
        };
        final identity = data['identity'] as Map<String, dynamic>;
        final id = _text(identity['clientCallId']);
        if (!ids.add(id)) throw const FormatException();
        final locator = identity['worldCallLocator'] as Map<String, dynamic>;
        final cluster = _text(locator['clusterId']);
        if (!const {'US', 'JP'}.contains(cluster)) {
          throw const FormatException();
        }
        final connected = _time(data['connectedAtMs']);
        final observed = _time(data['lastObservedAtMs']);
        final ended = _time(data['endedAtMs']);
        if (connected == null ||
            (observed != null && observed < connected) ||
            (stage == 'CONNECTED' && ended != null)) {
          throw const FormatException();
        }
        entries.add(
          TranslationArchiveEntry(
            accountId: account,
            clientCallId: id,
            targetName: _text(data['targetName'], allowEmpty: true),
            phone: _text(data['phoneNumber']),
            myLanguage: _text(data['myLanguage']),
            peerLanguage: _text(data['peerLanguage']),
            stage: mappedStage,
            connectedAt: connected,
            lastObservedAt: observed,
            endedAt: ended,
            locator: TranslationArchiveLocator(
              cluster,
              _text(locator['callSessionId']),
              _text(locator['recordingAccessGrant']),
            ),
            transcripts: [
              for (final item in data['transcripts'] as List)
                TranslationTranscript(
                  id: _text(item['segmentId']),
                  leg: _text(item['sourceLeg']),
                  source: _text(item['sourceText'], allowEmpty: true),
                  translated: _text(item['translatedText'], allowEmpty: true),
                  sourceLanguage: _text(
                    item['sourceLanguage'],
                    allowEmpty: true,
                  ),
                  translatedLanguage: _text(
                    item['translatedLanguage'],
                    allowEmpty: true,
                  ),
                  isFinal: item['final'] as bool,
                ),
            ],
          ),
        );
      }
      // Reuse target schema validation, including safe IDs and terminal times.
      TranslationArchiveCodec.encode('legacy-validation', account, entries);
      return entries;
    } catch (_) {
      throw const FormatException('Invalid legacy translation journal');
    }
  }

  static String _text(Object? value, {bool allowEmpty = false}) {
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw const FormatException();
    }
    return value;
  }

  static int? _time(Object? value) {
    if (value == null) return null;
    if (value is! int || value < 0 || value >= 8640000000000000) {
      throw const FormatException();
    }
    return value;
  }
}

import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/translation_history.dart';

class ApiTranslationHistoryRepository implements TranslationHistoryRepository {
  ApiTranslationHistoryRepository(this._api, {this.diagnostics});
  final DiagnosticSink? diagnostics;
  final AccountApi _api;
  @override
  Future<TranslationHistory> load(String callId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(callId)) {
      throw ApiFailure.invalidResponse;
    }
    final dto = AccountApi.object(
      await _api.request('api/realtime-translation-calls/$callId'),
    );
    return decode(dto, callId, diagnostics: diagnostics);
  }

  static String _text(Map<String, Object?> dto, String key) {
    final v = dto[key];
    if (v != null && v is! String) throw ApiFailure.invalidResponse;
    return v as String? ?? '';
  }

  static TranslationHistory decode(
    Map<String, Object?> dto,
    String expectedId, {
    DiagnosticSink? diagnostics,
  }) {
    if (_text(dto, 'callId') != expectedId) throw ApiFailure.invalidResponse;
    final route = switch (_text(dto, 'route').trim().toUpperCase()) {
      'DOMESTIC_ANDROID' => TranslationRoute.domesticSip,
      'WORLD_CALL' => TranslationRoute.worldCall,
      _ => throw ApiFailure.invalidResponse,
    };
    final duration = dto['durationMillis'], transcripts = dto['transcripts'];
    if (duration is! int || transcripts is! List) {
      throw ApiFailure.invalidResponse;
    }
    final segments = transcripts.map((value) {
      final item = AccountApi.object(value);
      if (item['final'] is! bool) throw ApiFailure.invalidResponse;
      return TranslationTranscript(
        segmentId: _text(item, 'segmentId'),
        sourceLeg: _text(item, 'sourceLeg'),
        sourceLanguage: _text(item, 'sourceLanguage'),
        sourceText: _text(item, 'sourceText'),
        translatedLanguage: _text(item, 'translatedLanguage'),
        translatedText: _text(item, 'translatedText'),
        isFinal: item['final'] as bool,
      );
    }).toList();
    TranslationRecording? recording;
    var rejected = false;
    try {
      if (dto['recording'] != null) {
        recording = _recording(AccountApi.object(dto['recording']));
      }
    } catch (_) {
      recording = null;
      rejected = true;
    }
    emitDiagnostic(
      diagnostics,
      DiagnosticEvent(
        operation: DiagnosticOperation.translationRecordingMetadata,
        result: rejected
            ? DiagnosticResult.failed
            : recording == null
            ? DiagnosticResult.received
            : DiagnosticResult.succeeded,
        failureKind: rejected ? DiagnosticFailureKind.format : null,
      ),
    );
    return TranslationHistory(
      callId: expectedId,
      route: route,
      targetName: _text(dto, 'targetName'),
      phoneNumber: _text(dto, 'phoneNumber'),
      myLanguage: _text(dto, 'myLanguage'),
      peerLanguage: _text(dto, 'peerLanguage'),
      connectedAt: _text(dto, 'connectedAt'),
      endedAt: _text(dto, 'endedAt'),
      durationMillis: duration < 0 ? 0 : duration,
      transcripts: List.unmodifiable(segments),
      recording: recording,
    );
  }

  static TranslationRecording _recording(Map<String, Object?> dto) {
    final source = _text(dto, 'source').trim().toUpperCase();
    final cluster = _text(dto, 'clusterId'),
        session = _text(dto, 'callSessionId'),
        grant = _text(dto, 'recordingAccessGrant');
    final checksum = _text(dto, 'checksumSha256'),
        cache = _text(dto, 'cacheKey'),
        url = _text(dto, 'contentUrl');
    final size = dto['sizeBytes'];
    if (size != null && (size is! int || size < 0)) {
      throw ApiFailure.invalidResponse;
    }
    if (checksum.isNotEmpty &&
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(checksum)) {
      throw ApiFailure.invalidResponse;
    }
    if (source == 'WORLD_CALL') {
      if ([cluster, session, grant].any((s) => s.trim().isEmpty)) {
        throw ApiFailure.invalidResponse;
      }
    } else if (source == 'PHONE_AGENT') {
      if (size == null || [checksum, cache, url].any((s) => s.trim().isEmpty)) {
        throw ApiFailure.invalidResponse;
      }
    } else {
      throw ApiFailure.invalidResponse;
    }
    final name = _text(dto, 'fileName');
    return TranslationRecording(
      source: source,
      clusterId: cluster,
      callSessionId: session,
      accessGrant: grant,
      fileName: name.isEmpty ? 'realtime-translation.m4a' : name,
      contentUrl: url,
      cacheKey: cache,
      checksum: checksum.toLowerCase(),
      sizeBytes: size as int?,
    );
  }
}

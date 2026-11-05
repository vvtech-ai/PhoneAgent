import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_translation_details.dart';

void main() {
  test('audio statistics roundtrip is whitelisted and bounded', () {
    final details = DiagnosticTranslationDetails('audioStats', '', '', {
      'sentFrames': 12,
      'localClippedSamples': -1,
      'voiceUnderflows': 3,
      'idleFrames': 10,
      'bufferingFrames': 2,
      'maxPcmQueuedMs': 160,
      'maxPcmChunkGapMs': 75,
      'pcmInputChunks': 6,
      'outputPlatform': 2,
      'outputMaxQueuedMs': 600,
      'outputEmptyTransitions': 1,
      'privatePhone': 1380000,
    });
    final restored = DiagnosticTranslationDetails.fromJson(details.toJson());
    expect(restored.statistics, {
      'sentFrames': 12,
      'localClippedSamples': 0,
      'voiceUnderflows': 3,
      'idleFrames': 10,
      'bufferingFrames': 2,
      'maxPcmQueuedMs': 160,
      'maxPcmChunkGapMs': 75,
      'pcmInputChunks': 6,
      'outputPlatform': 2,
      'outputMaxQueuedMs': 600,
      'outputEmptyTransitions': 1,
    });
  });
  test('playback failure categories survive diagnostic export', () {
    for (final reason in [
      'output_stalled',
      'output_focus_lost',
      'output_cancelled',
    ]) {
      final details = DiagnosticTranslationDetails(
        'media',
        'MEDIA_PREPARE_FAILED',
        reason,
      );
      expect(
        DiagnosticTranslationDetails.fromJson(details.toJson()).platformCode,
        reason,
      );
    }
  });
  test(
    'diagnostic export roundtrip keeps fixed reason and platform category',
    () {
      final event = DiagnosticEvent(
        operation: DiagnosticOperation.translationCall,
        result: DiagnosticResult.failed,
        sessionId: '12345678-1234-1234-1234-123456789abc',
        translation: DiagnosticTranslationDetails(
          'media',
          'MEDIA_PREPARE_FAILED',
          'call_audio_unavailable',
        ),
      );
      final decoded = DiagnosticEvent.fromJson(event.toJson());
      expect(decoded.translation!.code, 'MEDIA_PREPARE_FAILED');
      expect(decoded.translation!.platformCode, 'call_audio_unavailable');
      expect(decoded.sessionId, event.sessionId);
    },
  );
  test('unknown data cannot leak into exported stage or failure', () {
    final details = DiagnosticTranslationDetails(
      'private-number',
      'secret-provider-payload',
      'secret-native-message',
    ).toJson();
    expect(details, {'stage': 'unknown', 'code': 'UNKNOWN'});
    emitDiagnostic(
      (_) => throw StateError('sink failed'),
      DiagnosticEvent(
        operation: DiagnosticOperation.translationCall,
        result: DiagnosticResult.failed,
      ),
    );
  });
}

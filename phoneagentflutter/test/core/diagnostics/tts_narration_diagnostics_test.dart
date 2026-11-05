import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';

void main() {
  test(
    'TTS narration result decision keeps only a safe session and sequence',
    () {
      const session = 'a520d97ca512e8aeefc7f174fd0c9d69';
      final event = DiagnosticEvent.fromJson({
        'operation': 'ttsNarration',
        'result': 'failed',
        'time': '2026-10-22T18:55:52.915Z',
        'statusCode': 0,
        'elapsedMs': 0,
        'sessionId': session,
        'ttsNarration': {
          'sequence': 25,
          'decision': 'turnInterrupted',
          'text': '不得保存的播报正文',
        },
      });

      expect(event.sessionId, session);
      expect(event.toJson()['ttsNarration'], {
        'sequence': 25,
        'decision': 'turnInterrupted',
      });
      expect(event.toJson().toString(), isNot(contains('不得保存')));
    },
  );
}

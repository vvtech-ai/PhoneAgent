import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/task_voice_codec.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';

// Synthetic fixtures derived from v65 source, not recorded network traffic.
void main() {
  test('ASR and TTS formats are separate contracts', () {
    expect(TaskVoiceCodec.asrPcm.sampleRateHz, 16000);
    expect(TaskVoiceCodec.ttsPcm.sampleRateHz, 24000);
    expect(TaskVoiceCodec.asrPcm.bitsPerSample, 16);
    expect(TaskVoiceCodec.ttsPcm.channels, 1);
    expect(TaskVoiceCodec.asrFrameBytes, 640);
    expect(TaskVoiceCodec.asrPath, '/ws/assistant/task-voice/asr');
    expect(TaskVoiceCodec.ttsPath, '/ws/assistant/task-voice/tts');
  });

  test('Control messages preserve wire fields without invented turn IDs', () {
    expect(jsonDecode(TaskVoiceCodec.startCapture()), {
      'type': 'start_capture',
      'mode': 'open_listening',
    });
    expect(jsonDecode(TaskVoiceCodec.stopCapture(reason: 'release')), {
      'type': 'stop_capture',
      'reason': 'release',
    });
    expect(jsonDecode(TaskVoiceCodec.finish(reason: 'exit')), {
      'type': 'finish',
      'reason': 'exit',
    });
    expect(jsonDecode(TaskVoiceCodec.cancelSynthesis()), {'type': 'cancel'});
    expect(jsonDecode(TaskVoiceCodec.ping()), {'type': 'ping'});
  });

  test('Synthesis escapes text and preserves selected speaker', () {
    const text = '测试“你好”\n"line"';
    expect(jsonDecode(TaskVoiceCodec.synthesize(text: text, speaker: 'demo')), {
      'type': 'synthesize',
      'text': text,
      'speaker': 'demo',
    });
    expect(
      () => TaskVoiceCodec.synthesize(text: ' ', speaker: 'demo'),
      throwsArgumentError,
    );
    expect(
      () => TaskVoiceCodec.synthesize(text: 'test', speaker: ''),
      throwsArgumentError,
    );
  });

  test(
    'optional synthesis generation is encoded without changing legacy shape',
    () {
      expect(
        jsonDecode(
          TaskVoiceCodec.synthesize(
            text: 'test',
            speaker: 'demo',
            generation: 7,
          ),
        ),
        {
          'type': 'synthesize',
          'text': 'test',
          'speaker': 'demo',
          'generation': 7,
        },
      );
      expect(
        () => TaskVoiceCodec.synthesize(
          text: 'test',
          speaker: 'demo',
          generation: -1,
        ),
        throwsArgumentError,
      );
    },
  );

  test('ASR maps ready status speech boundaries partial and final', () {
    expect(TaskVoiceCodec.decodeAsr('{"type":"ready"}'), isA<VoiceReady>());
    expect(
      (TaskVoiceCodec.decodeAsr('{"type":"status","message":"ok"}')
              as VoiceStatus)
          .message,
      'ok',
    );
    for (final started in [true, false]) {
      final type = started ? 'speech_started' : 'speech_stopped';
      expect(
        (TaskVoiceCodec.decodeAsr('{"type":"$type"}') as VoiceSpeechBoundary)
            .started,
        started,
      );
    }
    for (final isFinal in [true, false]) {
      final type = isFinal ? 'final' : 'partial';
      final event =
          TaskVoiceCodec.decodeAsr('{"type":"$type","text":" 测试 "}')
              as VoiceTranscript;
      expect(event.isFinal, isFinal);
      expect(event.text, ' 测试 ');
    }
  });

  test('Blank ASR text does not fabricate transcript or status', () {
    for (final type in ['status', 'partial', 'final']) {
      expect(TaskVoiceCodec.decodeAsr('{"type":"$type"}'), isNull);
      expect(
        TaskVoiceCodec.decodeAsr('{"type":"$type","text":" ","message":" "}'),
        isNull,
      );
    }
  });

  test('TTS completion is typed separately and errors remain failures', () {
    expect(TaskVoiceCodec.decodeTts('{"type":"pong"}'), isA<VoiceHeartbeatPong>());
    expect(TaskVoiceCodec.decodeTts('{"type":"ready"}'), isA<VoiceReady>());
    expect(
      TaskVoiceCodec.decodeTts('{"type":"complete"}'),
      isA<VoiceSynthesisComplete>(),
    );
    expect(
      (TaskVoiceCodec.decodeTts('{"type":"started","generation":3}')
              as VoiceSynthesisStarted)
          .generation,
      3,
    );
    expect(
      (TaskVoiceCodec.decodeTts('{"type":"complete","generation":3}')
              as VoiceSynthesisComplete)
          .generation,
      3,
    );
    expect(
      (TaskVoiceCodec.decodeTts('{"type":"complete","extra":"ignored"}')
              as VoiceSynthesisComplete)
          .generation,
      isNull,
    );
    for (final decode in [TaskVoiceCodec.decodeAsr, TaskVoiceCodec.decodeTts]) {
      expect(
        (decode('{"type":"error","message":"failed"}') as VoiceGatewayFailure)
            .message,
        'failed',
      );
      expect(decode('{"type":"error"}'), isA<VoiceGatewayFailure>());
    }
  });

  test('Unknown and wrong-channel events are not treated as success', () {
    expect(TaskVoiceCodec.decodeAsr('{"type":"complete"}'), isNull);
    expect(TaskVoiceCodec.decodeTts('{"type":"final","text":"test"}'), isNull);
    expect(TaskVoiceCodec.decodeTts('{"type":"future"}'), isNull);
  });

  test('Malformed input fails without echoing source text', () {
    for (final source in [
      'secret',
      '[1]',
      'null',
      '{}',
      '{"type":3}',
      '{"type":"partial","text":4}',
      '{"type":"error","message":false}',
    ]) {
      try {
        TaskVoiceCodec.decodeAsr(source);
        fail('Expected FormatException');
      } on FormatException catch (error) {
        expect(error.source, isNull);
        expect(error.toString(), isNot(contains(source)));
      }
    }
    expect(
      () => TaskVoiceCodec.decodeTts('{"type":"complete","generation":"3"}'),
      throwsFormatException,
    );
  });
}

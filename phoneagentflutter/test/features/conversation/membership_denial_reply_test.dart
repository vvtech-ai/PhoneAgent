import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/voice/speech_prompt_policy.dart';

void main() {
  for (final code in [
    'BATCH_CONTACT_LIMIT',
    'BATCH_CONCURRENCY_LIMIT',
    'BATCH_ENTITLEMENT_LIMIT',
    'CALL_CONCURRENCY_LIMIT',
    'MODEL_ENTITLEMENT_DENIED',
    'ENTITLEMENT_DENIED',
  ]) {
    test(
      '$code becomes an assistant reply eligible for existing narration',
      () {
        final event = const AgentEventDecoder().decode(
          SseFrame(
            'task_failed',
            jsonEncode({
              'sessionId': 'session',
              'commandId': 'command',
              'displayMessage': 'private upstream diagnostic',
              'data': {'errorCode': code, 'recoveryAction': 'CHECK_MEMBERSHIP'},
            }),
          ),
        );
        expect(event.kind, AgentEventKind.finalResponse);
        expect(event.payload['type'], 'TEXT_REPLY');
        expect(event.payload['commandId'], 'command');
        expect(event.text, contains('会员'));
        expect(event.text, isNot(contains('private')));
        expect(SpeechPromptPolicy.prompt(event), event.text);
      },
    );
  }
  test('model membership denial explains how to continue safely', () {
    final event = const AgentEventDecoder().decode(
      SseFrame(
        'task_failed',
        jsonEncode({
          'displayMessage': 'private upstream diagnostic',
          'data': {'errorCode': 'MODEL_ENTITLEMENT_DENIED'},
        }),
      ),
    );
    expect(event.text, contains('开通或升级会员'));
    expect(event.text, contains('本次未拨出'));
    expect(event.text, isNot(contains('private')));
  });
  test('unrecognized failure remains an error', () {
    final event = const AgentEventDecoder().decode(
      SseFrame(
        'task_failed',
        jsonEncode({
          'data': {'code': 'MODEL_TIMEOUT'},
        }),
      ),
    );
    expect(event.kind, AgentEventKind.error);
  });
}

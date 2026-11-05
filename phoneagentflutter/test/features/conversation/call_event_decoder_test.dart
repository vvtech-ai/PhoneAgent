import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

void main() {
  for (final field in ['callResult', 'batchCallResult']) {
    test('structured task_failed preserves $field and command identity', () {
      final result = {
        'status': 'FAILED',
        'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
      };
      final event = const AgentEventDecoder().decode(
        SseFrame(
          'task_failed',
          jsonEncode({
            'sessionId': 's',
            'commandId': 'cmd',
            'data': {field: result},
          }),
        ),
      );
      expect(event.kind, AgentEventKind.finalResponse);
      expect(
        event.payload['type'],
        field == 'callResult' ? 'CALL_RESULT' : 'BATCH_CALL_RESULT',
      );
      expect(event.payload[field], result);
      expect(event.sessionId, 's');
      expect(event.payload['commandId'], 'cmd');
    });
  }

  test(
    'physical progress retains event attempt command and outcome marker',
    () {
      final event = const AgentEventDecoder().decode(
        SseFrame(
          'call_finished',
          jsonEncode({
            'sessionId': 's',
            'commandId': 'cmd',
            'callAttemptId': 'attempt',
            'data': {'outcomePush': true, 'status': 'ENDED'},
            'displayMessage': '通话结束',
          }),
        ),
      );
      expect(event.eventName, 'call_finished');
      expect(event.payload['commandId'], 'cmd');
      expect(event.payload['callAttemptId'], 'attempt');
      expect(event.payload['outcomePush'], true);
      expect(event.kind, AgentEventKind.status);
    },
  );
  test(
    'unclear outcome retains receipt and cancellation retains command identity',
    () {
      final decoder = const AgentEventDecoder();
      final unclear = decoder.decode(
        SseFrame(
          'task_outcome_unclear',
          jsonEncode({
            'sessionId': 's',
            'data': {
              'callResult': {'status': 'UNCLEAR'},
            },
          }),
        ),
      );
      expect(unclear.kind, AgentEventKind.finalResponse);
      expect(unclear.payload['type'], 'CALL_RESULT');
      final cancelled = decoder.decode(
        SseFrame(
          'task_cancelled',
          jsonEncode({
            'sessionId': 's',
            'data': {'commandId': 'c'},
          }),
        ),
      );
      expect(cancelled.kind, AgentEventKind.status);
      expect(cancelled.payload['commandId'], 'c');
      expect(cancelled.eventName, 'task_cancelled');
    },
  );
  test('slot progress is status rather than a final reply', () {
    final event = const AgentEventDecoder().decode(
      SseFrame(
        'slot_updated',
        jsonEncode({
          'sessionId': 's',
          'data': {'progressOnly': true, 'text': '正在沟通'},
        }),
      ),
    );
    expect(event.kind, AgentEventKind.status);
    expect(event.payload['progressOnly'], true);
  });
}

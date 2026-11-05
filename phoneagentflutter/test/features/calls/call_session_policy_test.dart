import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/domain/call_transcript.dart';

void main() {
  test(
    'only exact baseline transport terminal combinations defer Agent result',
    () {
      CallSessionSnapshot value(
        String state,
        String mode, {
        String result = '',
      }) => CallSessionSnapshot(
        callId: 'c',
        taskId: 's',
        callState: state,
        handoffMode: mode,
        resultCode: result,
      );
      expect(value('ENDED', 'COMPLETED').needsAgentOutcome('s'), isTrue);
      expect(value('failed', 'failed').needsAgentOutcome('s'), isTrue);
      expect(
        value(
          'ENDED',
          'COMPLETED',
          result: 'AGENT_UNCLEAR',
        ).needsAgentOutcome('s'),
        isFalse,
      );
      expect(value('ENDED', 'COMPLETED').needsAgentOutcome('other'), isFalse);
      expect(
        value(
          'ENDED',
          'COMPLETED',
        ).needsAgentOutcome('s', hasAgentOutcome: true),
        isFalse,
      );
      expect(value('CONNECTED', 'AI_ACTIVE').needsAgentOutcome('s'), isFalse);
      expect(value('NOT_FOUND', 'FAILED').needsAgentOutcome('s'), isFalse);
      expect(value('ENDED', 'AI_ACTIVE').needsAgentOutcome('s'), isFalse);
    },
  );

  test(
    'transcript parser preserves repeats, skips unknown and empty roles',
    () {
      final lines = CallTranscript.parse(
        ' assistant: 你好\nREMOTE: 好\nmerchant: 好\ncallee: \n总结\n未知：忽略\nuser: 忽略',
      );
      expect(lines.map((line) => line.text), ['你好', '好', '好']);
      expect(lines.map((line) => line.speaker), [
        CallSpeaker.assistant,
        CallSpeaker.remote,
        CallSpeaker.remote,
      ]);
    },
  );

  test(
    'transcript prefixes append, exact repeat is idempotent and empty retains content',
    () {
      final first = CallTranscript().merge('assistant: 你好\ncallee: 好');
      expect(identical(first.merge(first.source), first), isTrue);
      final next = first.merge('${first.source}\ncallee: 好');
      expect(next.lines.map((line) => line.text), ['你好', '好', '好']);
      final empty = next.merge('');
      expect(empty.lines, next.lines);
      expect(empty.source, isEmpty);
    },
  );

  test(
    'replacement snapshot preserves distinct seed and incoming duplicate speech',
    () {
      final previous = CallTranscript(
        lines: const [CallTranscriptLine(CallSpeaker.assistant, '种子')],
      ).merge('assistant: 原话');
      final next = previous.merge('assistant: 修订\ncallee: 好\ncallee: 好');
      expect(next.lines.map((line) => line.text), ['种子', '原话', '修订', '好', '好']);
      expect(next.merge('无角色结果').lines, next.lines);
    },
  );
}

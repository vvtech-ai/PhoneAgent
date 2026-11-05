import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import '../tool/previews/shell_call_preview.dart';
import '../tool/previews/shell_conversation_ports.dart';

void main() {
  test(
    'closed conversation cannot start calls in a still-live call scope',
    () async {
      final calls = ShellCallPorts();
      final conversations = ShellConversationPorts(calls: calls)..close();
      addTearDown(calls.close);
      final run = conversations.start(_command('closed', message: '演练单路通话'));
      expect(await run.events.toList(), isEmpty);
      expect(calls.tasks, isEmpty);
      expect(calls.flow('closed'), isNull);
    },
  );

  test(
    'sessions isolate status and reject wrong targets; continuation stays text',
    () async {
      final calls = ShellCallPorts();
      final conversations = ShellConversationPorts(calls: calls);
      addTearDown(calls.close);
      for (final id in ['a', 'b']) {
        await conversations
            .start(
              _command(id, message: id == 'a' ? 'ui-single-call' : '演练单路通话'),
            )
            .events
            .toList();
        await conversations
            .start(_command(id, action: 'confirm_call'))
            .events
            .toList();
      }
      await calls.hangUp(CallSessionTarget(taskId: 'a', callId: 'mock-call'));
      expect(calls.flow('a')!.hangups, 1);
      expect(calls.flow('b')!.hangups, 0);
      expect(
        (await calls.status(CallSessionTarget(taskId: 'b'))).isTerminal,
        isFalse,
      );
      for (final target in [
        CallSessionTarget(taskId: 'unknown'),
        CallSessionTarget(taskId: 'a', callId: 'other'),
      ]) {
        await expectLater(calls.status(target), throwsStateError);
        await expectLater(calls.hangUp(target), throwsStateError);
      }
      final before = calls.flow('a')!.commands.length;
      final restored = await conversations.restore('a');
      expect(
        restored.ledger!.events.any((e) => e.type == 'CALL_OUTCOME_REPORTED'),
        isTrue,
      );
      await conversations
          .start(_command('a', message: '再补充一个要求'))
          .events
          .toList();
      expect(calls.flow('a')!.commands.length, before);
      expect(
        (await conversations.load(
          TaskSource.conversations,
        )).where((row) => row.sessionId == 'a').length,
        1,
      );
      expect(
        (await conversations.restore('a')).ledger!.events.last.payload['text'],
        contains('已收到补充要求'),
      );
    },
  );

  test(
    'cancelled or closed unaccepted commands create no call tasks',
    () async {
      final ports = ShellCallPorts();
      final first = ports.start(_command('cancel', message: '演练单路通话'))!;
      first.cancel();
      expect(await first.events.toList(), isEmpty);
      expect(ports.tasks, isEmpty);
      final second = ports.start(_command('close', message: '演练单路通话'))!;
      ports.close();
      expect(await second.events.toList(), isEmpty);
      expect(ports.tasks, isEmpty);
      expect(() => ports.admission('new'), throwsStateError);
    },
  );
}

AgentCommand _command(String id, {String? message, String? action}) =>
    AgentCommand(
      sessionId: id,
      userId: 'synthetic',
      commandId: '$id:$message:$action',
      idempotencyKey: 'synthetic',
      traceId: 'synthetic',
      message: message,
      actionId: action,
    );

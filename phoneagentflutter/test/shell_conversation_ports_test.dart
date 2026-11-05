import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/shell_receipt_seeds.dart';

AgentCommand command(String session, String id, String message) => AgentCommand(
  sessionId: session,
  userId: 'synthetic',
  commandId: id,
  idempotencyKey: id,
  traceId: id,
  message: message,
);

void main() {
  test(
    'Chinese and ASCII UI batch fixtures stay pending without execution',
    () async {
      for (final message in ['演练扩展批量确认', 'UI_BATCH_CONFIRM']) {
        final ports = ShellConversationPorts();
        await ports
            .start(command('synthetic-batch', 'fixture', message))
            .events
            .drain<void>();
        final restored = await ports.restore('synthetic-batch');
        expect(restored.pendingTool!.payload['toolName'], 'confirmBatchTask');
        expect(ports.commands, hasLength(1));
        expect(
          (await ports.load(
            TaskSource.conversations,
          )).singleWhere((row) => row.sessionId == 'synthetic-batch').status,
          TaskStatus.incomplete,
        );
        expect(ports.phoneResults, isEmpty);
        expect(ports.nameResults, isEmpty);
        ports.close();
      }
    },
  );

  test(
    'receipt seed restore and continuation preserve original facts',
    () async {
      final ports = ShellConversationPorts();
      for (final session in ShellReceiptSeeds.ids) {
        final seed = await ports.restore(session);
        expect(ports.commands, isEmpty);
        expect(seed.ledger!.events, isNotEmpty);
        await ports
            .start(command(session, session, '继续补充'))
            .events
            .drain<void>();
        final restored = await ports.restore(session);
        expect(
          restored.ledger!.events
              .take(seed.ledger!.head)
              .map((e) => e.fingerprint),
          seed.ledger!.events.map((e) => e.fingerprint),
        );
        expect(restored.ledger!.events.last.payload['text'], contains('未拨号'));
        final rows = await ports.load(TaskSource.conversations);
        expect(rows.where((row) => row.sessionId == session), hasLength(1));
        ports.commands.clear();
      }
      expect(() => ShellReceiptSeeds.restore('unknown'), throwsStateError);
    },
  );

  test(
    'new sessions have independent pending choices and ordered history',
    () async {
      final ports = ShellConversationPorts();
      await ports.start(command('a', 'a1', '晚餐')).events.drain<void>();
      await ports.start(command('b', 'b1', '午餐')).events.drain<void>();
      final before = await ports.restore('a');
      expect(before.pendingTool?.payload['toolCallId'], 'choice:a');
      expect(
        (await ports.restore('b')).pendingTool?.payload['toolCallId'],
        'choice:b',
      );
      await ports.start(command('a', 'a2', '第 1 个')).events.drain<void>();
      final restored = await ports.restore('a');
      expect(restored.pendingTool, isNull);
      expect(restored.ledger!.events.map((e) => e.sequence), [1, 2, 3, 4, 5]);
      expect(restored.ledger!.events.last.payload['text'], '已收到你的选择。');
      expect(before.ledger!.events.length, 2, reason: '恢复快照不能被后续写入修改');
      expect((await ports.restore('b')).ledger!.head, 2);
      final rows = await ports.load(TaskSource.conversations);
      expect(rows.where((row) => row.sessionId == 'a').length, 1);
      expect(
        rows.singleWhere((row) => row.sessionId == 'a').title,
        'MOCK · 晚餐',
      );
      expect(
        rows.singleWhere((row) => row.sessionId == 'a').status,
        TaskStatus.incomplete,
      );
    },
  );

  test(
    'cancel before acceptance and disposed pending run do not create tasks',
    () async {
      for (final dispose in [false, true]) {
        final ports = ShellConversationPorts();
        final run = ports.start(command('cancelled', 'c1', '不应保存'));
        if (dispose) {
          ports.close();
        } else {
          run.cancel();
        }
        expect(await run.events.toList(), isEmpty);
        expect(
          (await ports.load(
            TaskSource.conversations,
          )).any((row) => row.sessionId == 'cancelled'),
          isFalse,
        );
      }
    },
  );

  test('continuing seed history preserves its original facts', () async {
    final ports = ShellConversationPorts();
    final seed = await ports.restore('closed');
    await ports.start(command('closed', 'next', '继续补充')).events.drain<void>();
    final restored = await ports.restore('closed');
    expect(
      restored.ledger!.events.take(2).map((e) => e.fingerprint),
      seed.ledger!.events.map((e) => e.fingerprint),
    );
    expect(
      restored.ledger!.events.last.payload['text'],
      '已收到补充要求，当前为 MOCK，未拨号。',
    );
    expect(
      (await ports.load(
        TaskSource.conversations,
      )).where((row) => row.sessionId == 'closed').length,
      1,
    );
  });
}

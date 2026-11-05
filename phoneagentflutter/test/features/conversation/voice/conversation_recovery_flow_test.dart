import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'turn_recovery_support.dart';

void main() {
  late RecoveryFixture ports;
  late ConversationController controller;
  var id = 0;
  setUp(() {
    id = 0;
    ports = RecoveryFixture();
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'synthetic',
      gateway: ports,
      history: ports,
      nextId: () => 'cmd${++id}',
    );
  });
  tearDown(() => controller.dispose());
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  test(
    'older history cannot override a newer committed fact already received',
    () async {
      controller.send('明天下午');
      final command = ports.commands.single.commandId;
      final accepted = recoveryFact(
        1,
        'USER_TURN_ACCEPTED',
        command,
        text: '明天下午',
      );
      final reply = recoveryFact(
        2,
        'ASSISTANT_TURN_COMMITTED',
        command,
        text: '已完成',
      );
      ports.emit(AgentEvent(AgentEventKind.committed, ledger: accepted));
      ports.emit(AgentEvent(AgentEventKind.committed, ledger: reply));
      ports.disconnect();
      await flush();
      ports.result = recoveredHistory([accepted]);
      controller.send('明天下午');
      await flush();
      expect(ports.commands.length, 1);
      expect(controller.recoverableInput, '明天下午');
      ports.result = recoveredHistory([accepted, reply]);
      controller.send('明天下午');
      await flush();
      expect(ports.commands.length, 1);
      expect(controller.recoverableInput, '');
    },
  );
  Future<String> failTurn({bool committed = false}) async {
    controller.send('明天下午');
    final original = ports.commands.single.commandId;
    ports.result = recoveredHistory([
      recoveryFact(1, 'USER_TURN_ACCEPTED', original, text: '明天下午'),
      if (committed)
        recoveryFact(2, 'ASSISTANT_TURN_COMMITTED', original, text: '安排已完成'),
    ]);
    ports.emit(const AgentEvent(AgentEventKind.text, text: '未完成的临时回复'));
    ports.disconnect();
    await flush();
    expect(controller.state.canSend, true);
    expect(controller.recoverableInput, '明天下午');
    expect(ports.commands.length, 1);
    return original;
  }

  test(
    'formal send reconciles then revises one user bubble with fresh identity',
    () async {
      final original = await failTurn();
      expect(
        controller.state.messages.where((m) => m.role == MessageRole.assistant),
        isEmpty,
      );
      expect(controller.send('下午开会'), true);
      expect(controller.send('重复点击'), false);
      expect(ports.commands.length, 1);
      await flush();
      final command = ports.commands.last;
      expect(command.supersedesCommandId, original);
      expect(command.commandId, isNot(original));
      expect(command.idempotencyKey, command.commandId);
      expect(command.message, '明天下午开会');
      expect(command.toJson()['channel'], 'voice');
      expect(
        controller.state.messages
            .where((m) => m.role == MessageRole.user)
            .map((m) => m.text),
        ['明天下午开会'],
      );
      ports.disconnect();
      await flush();
      expect(controller.recoverableInput, '明天下午开会');
    },
  );
  test(
    'already committed repeated sentence restores result without another POST',
    () async {
      await failTurn(committed: true);
      controller.send('明天下午');
      await flush();
      expect(ports.commands.length, 1);
      expect(controller.recoverableInput, '');
      expect(controller.state.messages.map((m) => m.text), ['明天下午', '安排已完成']);
      expect(controller.state.phase, ConversationPhase.ready);
    },
  );
  test(
    'committed original permits separate new followup after synchronization',
    () async {
      await failTurn(committed: true);
      controller.send('后天呢');
      await flush();
      expect(ports.commands.last.message, '后天呢');
      expect(ports.commands.last.supersedesCommandId, isNull);
      expect(
        controller.state.messages
            .where((m) => m.role == MessageRole.user)
            .length,
        2,
      );
    },
  );
  test(
    'failed or absent history never posts; later explicit input retries synchronization',
    () async {
      await failTurn();
      ports.historyFailure = true;
      controller.send('下午开会');
      await flush();
      expect(ports.commands.length, 1);
      expect(controller.recoverableInput, '明天下午');
      expect(controller.state.notice, contains('内容已保留'));
      ports.historyFailure = false;
      ports.result = const RestoredConversation(
        ConversationDetail(sessionId: 's', title: '', status: 'OPEN'),
      );
      controller.send('下午开会');
      await flush();
      expect(ports.commands.length, 1);
      ports.result = recoveredHistory([]);
      controller.send('下午开会');
      await flush();
      expect(ports.commands.length, 2);
    },
  );
  test(
    'close during reconciliation invalidates late history and clears text',
    () async {
      await failTurn();
      ports.gate = Completer<RestoredConversation>();
      controller.send('继续');
      controller.close();
      ports.gate!.complete(ports.result);
      await flush();
      expect(ports.commands.length, 1);
      expect(controller.recoverableInput, '');
      expect(controller.state.messages, isEmpty);
    },
  );
  test(
    'explicit history restore cancels pending reconciliation without replay',
    () async {
      await failTurn(committed: true);
      ports.gate = Completer<RestoredConversation>();
      controller.send('继续');
      final restore = controller.restore();
      ports.gate!.complete(ports.result);
      await restore;
      await flush();
      expect(ports.commands.length, 1);
      expect(controller.state.messages.last.text, '安排已完成');
    },
  );
}

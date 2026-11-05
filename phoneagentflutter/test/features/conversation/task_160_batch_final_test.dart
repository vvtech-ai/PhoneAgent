import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_event_flow.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

void main() {
  test('late batch final clears only its old unconfirmed notice', () async {
    for (final notice in ['批量外呼结果尚未确认，请稍后重新进入会话核对。', '其他业务提示']) {
      final batch = BatchProgressTracker();
      final messages = ConversationMessageStore();
      var state = ConversationState(
        entry: const ConversationEntry(sessionId: 's'),
        notice: notice,
      );
      batch.accept(
        const AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'b',
            'itemIndex': 1,
            'total': 1,
            'status': 'CALLING',
          },
        ),
        'c',
      );
      messages.batch('c', batch.snapshot(unconfirmed: true));
      state = messages.project(state);
      batch.stopObserving();
      final flow = ConversationEventFlow(
        read: () => state,
        write: (value) => state = value,
        current: (_) => true,
        messages: messages,
        batch: batch,
        observed: (_, __) {},
        commit: (_, __) async => true,
        signal: (_, __, ___) async {},
        status: (_, __, ___) {},
        done: (_, __) async {},
        failed: (_, __) {},
        batchFinished: () {},
        publish: () => state = messages.project(state),
        assistant: (_, __) {},
      );
      await flow.accept(
        const AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: 's',
          payload: {
            'type': 'BATCH_CALL_RESULT',
            'batchCallResult': {
              'batchId': 'b',
              'status': 'COMPLETED',
              'items': [
                {'itemId': 'first', 'status': 'SUCCESS'},
              ],
            },
          },
        ),
        'c',
        0,
      );
      expect(state.messages.single.batchReceipt!.isRunning, isFalse);
      expect(state.notice, notice.contains('结果尚未确认') ? isEmpty : '其他业务提示');
    }
  });
  test(
    'old final cannot close a different active batch or publish result',
    () async {
      final batch = BatchProgressTracker(),
          messages = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      var finished = 0;
      final flow = ConversationEventFlow(
        read: () => state,
        write: (value) => state = value,
        current: (_) => true,
        messages: messages,
        batch: batch,
        observed: (_, __) {},
        commit: (_, __) async => true,
        signal: (_, __, ___) async {},
        status: (_, __, ___) {},
        done: (_, __) async {},
        failed: (_, __) {},
        batchFinished: () => finished++,
        publish: () {},
        assistant: (_, __) {},
      );
      batch.accept(
        const AgentEvent(
          AgentEventKind.status,
          payload: {'batchId': 'current'},
        ),
        'c',
      );
      AgentEvent result(String id) => AgentEvent(
        AgentEventKind.finalResponse,
        sessionId: 's',
        payload: {
          'type': 'BATCH_CALL_RESULT',
          'batchCallResult': {
            'batchId': id,
            'status': 'COMPLETED',
            'totalCount': 1,
          },
        },
      );
      await flow.accept(result('old'), 'c', 0);
      expect(batch.batchId, 'current');
      expect(batch.active, isTrue);
      expect(finished, 0);
      expect(messages.messages, isEmpty);
      await flow.accept(result('current'), 'c', 0);
      expect(finished, 1);
      await flow.accept(result('current'), 'next', 0);
      expect(finished, 1);
    },
  );
}

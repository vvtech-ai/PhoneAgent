import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'batch_progress_tracker_test.dart' show progress;

void main() {
  const state = ConversationState(entry: ConversationEntry(sessionId: 's'));
  test('wire call status carries exact batch fields and display message', () {
    final event = const AgentEventDecoder().decode(
      const SseFrame(
        'call_finished',
        '{"sessionId":"s","displayMessage":"合成完成","data":{"batchId":"batch","itemIndex":"2","total":3,"status":"SUCCESS"}}',
      ),
    );
    expect(event.kind, AgentEventKind.status);
    final tracker = BatchProgressTracker();
    tracker.accept(event, 'c');
    expect(tracker.snapshot()!.items.single.id, 'progress_batch_2');
    expect(tracker.snapshot()!.items.single.detail, '合成完成');
  });
  for (final durableStatus in ['RUNNING', 'COMPLETED']) {
    test(
      'live progress overlays only nonterminal durable batch: $durableStatus',
      () {
        final store = ConversationMessageStore();
        store.facts['e'] = LedgerEvent(
          eventId: 'e',
          sessionId: 's',
          sequence: 1,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'c',
          payload: {
            'batchCallResult': {
              'batchId': 'batch',
              'status': durableStatus,
              'items': [
                {'itemId': 'durable', 'status': durableStatus},
              ],
            },
          },
        );
        final tracker = BatchProgressTracker();
        tracker.accept(progress(1, 'SUCCESS'), 'c');
        store.batch('c', tracker.snapshot());
        final result = store
            .project(state)
            .messages
            .where((m) => m.batchReceipt != null)
            .single
            .batchReceipt!;
        expect(
          result.items.single.id,
          durableStatus == 'RUNNING' ? 'progress_batch_1' : 'durable',
        );
      },
    );
  }
  test(
    'final remains at original provisional position and does not absorb ordinary text',
    () {
      final store = ConversationMessageStore();
      final tracker = BatchProgressTracker();
      tracker.accept(progress(1, 'CALLING'), 'c');
      store.batch('c', tracker.snapshot());
      store.assistant('c', '普通说明', [], null);
      store.finish({
        'type': 'BATCH_CALL_RESULT',
        'batchCallResult': {
          'batchId': 'batch',
          'status': 'COMPLETED',
          'items': [
            {'status': 'SUCCESS'},
          ],
        },
      }, 'c');
      expect(store.messages.first.batchReceipt, isNotNull);
      expect(store.messages.last.text, '普通说明');
    },
  );
  test(
    'points refusal removes provisional execution card instead of claiming calls happened',
    () {
      final store = ConversationMessageStore();
      final tracker = BatchProgressTracker();
      tracker.accept(progress(1, 'CALLING'), 'c');
      store.batch('c', tracker.snapshot());
      store.finish({
        'type': 'BATCH_CALL_RESULT',
        'batchCallResult': {
          'batchId': 'batch',
          'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
          'items': [
            {'attemptCount': 0},
          ],
        },
      }, 'c');
      expect(store.messages, isEmpty);
    },
  );
}

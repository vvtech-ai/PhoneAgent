import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt_projector.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';
import 'package:phone_agent/features/tasks/data/api_task_repository.dart';
import 'package:phone_agent/features/tasks/domain/visible_task_result_read.dart';
import '../../support/synthetic_account_api.dart';

// Synthetic data matching BatchCallResultFinalizer's wire contract.
Map<String, Object?> payload({
  String status = 'PENDING',
  String? execution = 'FINISHED',
  String second = 'UNCLEAR',
  String batchId = 'batch-synthetic',
}) => {
  'batchCallResult': {
    'batchId': batchId,
    'status': status,
    if (execution != null) 'executionStatus': execution,
    'items': [
      {'itemId': 'recipient_1', 'status': 'FAILED'},
      {'itemId': 'recipient_2', 'status': second},
    ],
  },
};

void main() {
  for (final history in [false, true]) {
    test('empty execution error is readable from history=$history', () async {
      final wire = SyntheticAccountApi();
      final owner = VisibleTaskResultRead(
        'synthetic-session',
        ApiTaskRepository(wire.api, 'a').markRead,
        () => true,
      );
      final result = {
        'text': '本次任务已结束，结果处理异常',
        'batchCallResult': {
          'status': 'PENDING',
          'executionStatus': 'EXECUTION_ERROR',
          'headline': '执行异常',
          'items': <Object>[],
        },
      };
      final messages = history
          ? ConversationMessages.project([
              LedgerEvent(
                eventId: 'execution-error',
                sessionId: 'synthetic-session',
                commandId: 'command',
                sequence: 1,
                type: 'ASSISTANT_TURN_COMMITTED',
                schemaVersion: 1,
                payload: result,
              ),
            ])
          : ReceiptMessageMapper.fromFinal(result, 'command');
      expect(
        messages.where((message) => message.batchReceipt != null),
        hasLength(1),
      );
      await owner.show(messages, visible: true);
      expect(wire.requests, hasLength(1));
    });
  }
  for (final history in [false, true]) {
    test('PENDING/FINISHED sends read PUT from history=$history', () async {
      final wire = SyntheticAccountApi();
      final owner = VisibleTaskResultRead(
        'synthetic-session',
        ApiTaskRepository(wire.api, 'a').markRead,
        () => true,
      );
      final messages = history
          ? [
              for (final projected in BatchReceiptProjector.project([
                LedgerEvent(
                  eventId: 'event',
                  sessionId: 'synthetic-session',
                  sequence: 53,
                  type: 'ASSISTANT_TURN_COMMITTED',
                  schemaVersion: 1,
                  payload: payload(),
                ),
              ]))
                ConversationMessage(
                  id: projected.anchor.eventId,
                  role: MessageRole.assistant,
                  text: '',
                  batchReceipt: projected.receipt,
                ),
            ]
          : ReceiptMessageMapper.fromFinal(payload(), 'command');
      expect(messages.single.batchReceipt!.status, 'PENDING');
      await owner.show(messages, visible: true);
      expect(wire.requests, hasLength(1));
      expect(wire.requests.single.method, 'PUT');
      expect(
        wire.requests.single.uri.path,
        '/api/assistant/task-list/items/AGENT_CONVERSATION/synthetic-session/read',
      );
      await owner.show(messages, visible: true);
      expect(wire.requests, hasLength(1));
    });
  }

  test(
    'execution gate protects progress, hidden pages and old accounts',
    () async {
      final wire = SyntheticAccountApi();
      var current = true;
      final owner = VisibleTaskResultRead(
        's',
        ApiTaskRepository(wire.api, 'a').markRead,
        () => current,
      );
      for (final data in [
        payload(execution: null),
        payload(execution: 'RUNNING'),
        payload(status: 'COMPLETED', execution: 'VERIFYING'),
        payload(status: 'COMPLETED', execution: 'UNKNOWN'),
        payload(second: 'DIALING'),
      ]) {
        await owner.show(
          ReceiptMessageMapper.fromFinal(data, 'c'),
          visible: true,
        );
      }
      final messages = ReceiptMessageMapper.fromFinal(payload(), 'c');
      await owner.show(messages, visible: false);
      current = false;
      await owner.show(messages, visible: true);
      expect(wire.requests, isEmpty);
      current = true;
      await owner.show(
        ReceiptMessageMapper.fromFinal(
          payload(status: 'INCOMPLETE', execution: null),
          'legacy',
        ),
        visible: true,
      );
      expect(wire.requests, hasLength(1));
    },
  );

  test(
    '503 remains retryable; successful batch deduplicates and new batch reads',
    () async {
      final wire = SyntheticAccountApi()..status = 503;
      final owner = VisibleTaskResultRead(
        's',
        ApiTaskRepository(wire.api, 'a').markRead,
        () => true,
      );
      final messages = ReceiptMessageMapper.fromFinal(payload(), 'c');
      await owner.show(messages, visible: true);
      expect(wire.requests, hasLength(1));
      wire.status = 200;
      await owner.show(messages, visible: false);
      await owner.show(messages, visible: true);
      await owner.show(messages, visible: true);
      expect(wire.requests, hasLength(2));
      await owner.show(
        ReceiptMessageMapper.fromFinal(payload(batchId: 'next-batch'), 'next'),
        visible: true,
      );
      expect(wire.requests, hasLength(3));
    },
  );

  test(
    'throwing diagnostics cannot prevent or replay successful PUT',
    () async {
      final wire = SyntheticAccountApi();
      final owner = VisibleTaskResultRead(
        's',
        ApiTaskRepository(wire.api, 'a').markRead,
        () => true,
        diagnostic: (_, _, _) => throw StateError('sink unavailable'),
      );
      final messages = ReceiptMessageMapper.fromFinal(
        payload(status: 'COMPLETED', execution: null),
        'c',
      );
      await owner.show(messages, visible: true);
      await owner.show(messages, visible: true);
      expect(wire.requests, hasLength(1));
    },
  );
}

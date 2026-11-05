import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';

void main() {
  Map<String, Object?> payload(String id, String status) => {
    'batchCallResult': {
      'batchId': id,
      'status': status,
      'items': [
        {'itemId': 'i', 'status': status},
      ],
    },
  };
  test(
    'task_completed preserves a failed batch result, generic task failure is still an error',
    () {
      const decoder = AgentEventDecoder();
      final event = decoder.decode(
        SseFrame(
          'task_completed',
          jsonEncode({
            'sessionId': 's',
            'displayMessage': '未完成',
            'data': payload('a', 'FAILED'),
          }),
        ),
      );
      expect(event.kind, AgentEventKind.finalResponse);
      expect(event.text, '未完成');
      expect(event.payload['type'], 'BATCH_CALL_RESULT');
      expect(
        decoder.decode(const SseFrame('task_failed', '{}')).kind,
        AgentEventKind.error,
      );
    },
  );
  test('ordinary assistant text coexists with anchored batch updates', () {
    LedgerEvent fact(int n, Map<String, Object?> data) => LedgerEvent(
      eventId: 'e$n',
      sessionId: 's',
      sequence: n,
      type: 'ASSISTANT_TURN_COMMITTED',
      schemaVersion: 1,
      commandId: 'c$n',
      payload: data,
    );
    final messages = ConversationMessages.project([
      fact(1, {...payload('a', 'RUNNING'), 'text': '开始处理'}),
      fact(2, {...payload('a', 'FAILED'), 'text': '批量已结束'}),
    ]);
    expect(messages.map((m) => m.id), [
      'ledger:batch:a',
      'ledger:e1',
      'ledger:e2',
    ]);
    expect(messages.first.batchReceipt!.status, 'FAILED');
    expect(messages.map((m) => m.text), ['', '开始处理', '批量已结束']);
    final merged = ConversationMessageMerge.merge(messages, [
      ...ReceiptMessageMapper.fromFinal(payload('a', 'RUNNING'), 'c2'),
      ...ReceiptMessageMapper.fromFinal(payload('b', 'RUNNING'), 'c2'),
      const ConversationMessage(
        id: 'ordinary',
        role: MessageRole.assistant,
        text: '不同轮次',
        commandId: 'other',
      ),
    ]);
    expect(merged.where((m) => m.batchReceipt != null), hasLength(2));
    expect(merged.any((m) => m.text == '不同轮次'), isTrue);
  });
  test(
    'reconciliation waits for its source page and updates one original card',
    () {
      final original = LedgerEvent(
        eventId: 'batch-error',
        sessionId: 's',
        sequence: 27,
        type: 'ASSISTANT_TURN_COMMITTED',
        schemaVersion: 1,
        commandId: 'command-a',
        payload: {
          'batchCallResult': {
            'batchId': 'batch-a',
            'status': 'PENDING',
            'executionStatus': 'EXECUTION_ERROR',
            'items': [
              {'itemId': 'first', 'status': 'UNCLEAR'},
            ],
          },
        },
      );
      final update = LedgerEvent(
        eventId: 'batch-reconciled',
        sessionId: 's',
        sequence: 28,
        type: 'BATCH_RESULT_RECONCILED',
        schemaVersion: 1,
        payload: {
          'batchId': 'batch-a',
          'sourceResultSequence': 27,
          'resolutionCode': 'BUSINESS_RESULT_UNAVAILABLE',
          'batchCallResult': {
            'batchId': 'batch-a',
            'status': 'INCOMPLETE',
            'executionStatus': 'FINISHED',
            'resultCode': 'BUSINESS_RESULT_UNAVAILABLE',
            'headline': '通话已结束，业务结果无法确认',
            'items': [
              {'itemId': 'first', 'status': 'UNCLEAR'},
            ],
          },
        },
      );

      expect(ConversationMessages.project([update]), isEmpty);
      final messages = ConversationMessages.project([update, original]);
      expect(messages.where((m) => m.batchReceipt != null), hasLength(1));
      expect(messages.single.id, 'ledger:batch:batch-a');
      expect(messages.single.commandId, 'command-a');
      expect(
        messages.single.batchReceipt!.resultCode,
        'BUSINESS_RESULT_UNAVAILABLE',
      );
    },
  );
  test(
    'newer progress result replaces old durable error without moving card',
    () {
      final oldResult = {
        'batchId': 'batch-a',
        'status': 'PENDING',
        'executionStatus': 'EXECUTION_ERROR',
        'items': [
          {'itemId': 'first', 'status': 'UNCLEAR'},
        ],
      };
      final newResult = {
        'batchId': 'batch-a',
        'status': 'INCOMPLETE',
        'executionStatus': 'FINISHED',
        'resultCode': 'BUSINESS_RESULT_UNAVAILABLE',
        'items': [
          {'itemId': 'first', 'status': 'UNCLEAR'},
        ],
      };
      final original = LedgerEvent(
        eventId: 'batch-error',
        sessionId: 's',
        sequence: 27,
        type: 'ASSISTANT_TURN_COMMITTED',
        schemaVersion: 1,
        commandId: 'command-a',
        payload: {'batchCallResult': oldResult},
      );
      final update = LedgerEvent(
        eventId: 'batch-reconciled',
        sessionId: 's',
        sequence: 28,
        type: 'BATCH_RESULT_RECONCILED',
        schemaVersion: 1,
        payload: {
          'batchId': 'batch-a',
          'sourceResultSequence': 27,
          'resolutionCode': 'BUSINESS_RESULT_UNAVAILABLE',
          'batchCallResult': newResult,
        },
      );

      final first = ConversationMessageMerge.merge(
        ConversationMessages.project([original]),
        ReceiptMessageMapper.fromFinal({
          'resultSequence': 28,
          'batchCallResult': newResult,
        }, 'command-a'),
      );
      expect(first.where((m) => m.batchReceipt != null), hasLength(1));
      expect(first.single.id, 'ledger:batch:batch-a');
      expect(
        first.single.batchReceipt!.resultCode,
        'BUSINESS_RESULT_UNAVAILABLE',
      );

      final second = ConversationMessageMerge.merge(
        ConversationMessages.project([original, update]),
        ReceiptMessageMapper.fromFinal({
          'resultSequence': 27,
          'batchCallResult': oldResult,
        }, 'command-a'),
      );
      expect(second.where((m) => m.batchReceipt != null), hasLength(1));
      expect(second.single.id, 'ledger:batch:batch-a');
      expect(
        second.single.batchReceipt!.resultCode,
        'BUSINESS_RESULT_UNAVAILABLE',
      );
    },
  );
  test(
    'live empty-running total hint is retained and zero-attempt points rejection is not a call',
    () {
      expect(
        ReceiptMessageMapper.fromFinal({
          'batchCallResult': {
            'batchId': 'a',
            'status': 'RUNNING',
            'totalCount': 3,
          },
        }, 'c').single.batchReceipt!.totalCount,
        3,
      );
      expect(
        ReceiptMessageMapper.fromFinal({
          'batchCallResult': {
            'batchId': 'a',
            'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
            'items': [
              {'attemptCount': 0},
              {'attemptCount': 0},
            ],
          },
        }, 'c'),
        isEmpty,
      );
    },
  );
}

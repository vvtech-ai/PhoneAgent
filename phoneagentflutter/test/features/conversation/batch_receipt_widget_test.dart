import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_receipt_text.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';

void main() {
  final receipt = BatchReceipt.fromJson({
    'status': 'RUNNING',
    'totalCount': 4,
    'items': [
      {
        'itemId': 'i1',
        'targetName': '合成甲',
        'status': 'SUCCESS',
        'receiptFields': [
          {'key': 'businessResult', 'label': '通知', 'value': '已送达'},
        ],
        'billingSummaries': [
          {
            'billingSessionId': 'b1',
            'billingState': 'SETTLED',
            'chargedPoints': 2,
          },
          {
            'billingSessionId': 'b2',
            'billingState': 'SETTLED',
            'chargedPoints': 3,
          },
        ],
      },
      {'itemId': 'i2', 'targetName': '合成乙', 'status': 'CALLING'},
      {'itemId': 'i3', 'targetName': '合成丙', 'status': 'NEEDS_RECALL'},
    ],
  }, fallbackId: 'synthetic');
  test('progress is number of returned outcomes, not success count', () {
    final text = CallReceiptText.formatBatch(receipt);
    expect(text, contains('2/4 已产生结果'));
    expect(text, contains('结果陆续返回'));
    expect(text, contains('状态：已送达'));
    expect(text, contains('状态：进行中'));
    expect(text, contains('状态：待确认'));
    expect(text, contains('第 1 次结算\n扣除积分：2'));
    expect(text, contains('第 2 次结算\n扣除积分：3'));
    expect(text, isNot(contains('首分钟')));
  });
  test('plain text keeps reconciled business outcome unconfirmed', () {
    final result = BatchReceipt.fromJson({
      'batchId': 'batch-evidence',
      'status': 'INCOMPLETE',
      'executionStatus': 'FINISHED',
      'resultCode': 'BUSINESS_RESULT_UNAVAILABLE',
      'headline': '通话已结束，业务结果无法确认',
      'items': [
        {'itemId': 'first', 'status': 'UNCLEAR'},
      ],
    }, fallbackId: 'batch-evidence');

    final text = CallReceiptText.formatBatch(result);
    expect(text, contains('状态：业务结果无法确认'));
    expect(text, isNot(contains('已产生结果')));
    expect(text, isNot(contains('路完成')));
  });
  testWidgets('local unconfirmed batch snapshot remains progress, not result', (
    tester,
  ) async {
    for (final secondStatus in ['CALLING', 'FAILED']) {
      final tracker = BatchProgressTracker();
      for (final (index, status) in [(1, 'SUCCESS'), (2, secondStatus)]) {
        tracker.accept(
          AgentEvent(
            AgentEventKind.status,
            payload: {
              'batchId': 'batch-awaiting-final',
              'itemIndex': index,
              'total': 2,
              'status': status,
            },
          ),
          'command-awaiting-final',
        );
      }
      final provisional = tracker.snapshot(unconfirmed: true)!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConversationMessageTile(
                message: ConversationMessage(
                  id: 'local:command-awaiting-final:batch-progress',
                  role: MessageRole.assistant,
                  text: '',
                  batchReceipt: provisional,
                ),
                optionsEnabled: false,
                onChoose: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('批量外呼进度'), findsOneWidget);
      expect(find.text('执行结果'), findsNothing);
      expect(find.text('结果回传'), findsNothing);
      expect(find.text('结果尚未确认'), findsOneWidget);
      expect(find.text('批量外呼结果尚未确认，请稍后重新进入会话核对'), findsOneWidget);
    }
  });

  testWidgets('committed execution error shows a result instead of waiting', (
    tester,
  ) async {
    final pending = BatchReceipt.fromJson({
      'batchId': 'batch-evidence',
      'status': 'PENDING',
      'executionStatus': 'EXECUTION_ERROR',
      'headline': '本次任务已结束，结果处理异常',
      'items': [
        for (var i = 0; i < 5; i++)
          {'itemId': 'recipient_$i', 'status': 'UNCLEAR'},
      ],
    }, fallbackId: 'batch-evidence');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConversationMessageTile(
              message: ConversationMessage(
                id: 'batch-evidence',
                role: MessageRole.assistant,
                text: '',
                batchReceipt: pending,
              ),
              optionsEnabled: false,
              onChoose: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('5/5 已产生结果'), findsOneWidget);
    expect(find.text('执行结果'), findsOneWidget);
    expect(find.text('执行异常'), findsOneWidget);
    expect(find.text('结果回传'), findsNothing);
    expect(find.text('本次任务已结束，结果处理异常'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reconciled result states business outcome is unavailable', (
    tester,
  ) async {
    final result = BatchReceipt.fromJson({
      'batchId': 'batch-evidence',
      'status': 'INCOMPLETE',
      'executionStatus': 'FINISHED',
      'resultCode': 'BUSINESS_RESULT_UNAVAILABLE',
      'headline': '通话已结束，业务结果无法确认',
      'items': [
        {'itemId': 'first', 'status': 'UNCLEAR'},
        {'itemId': 'second', 'status': 'USER_CANCELLED'},
      ],
    }, fallbackId: 'batch-evidence');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConversationMessageTile(
              message: ConversationMessage(
                id: 'batch-evidence',
                role: MessageRole.assistant,
                text: '',
                batchReceipt: result,
              ),
              optionsEnabled: false,
              onChoose: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('业务结果无法确认'), findsWidgets);
    expect(find.text('首轮完成'), findsNothing);
    expect(find.text('结果回传'), findsNothing);
    expect(find.text('2/2 已产生结果'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'execution error ends a batch card even if summary and item are running',
    (tester) async {
      final terminal = BatchReceipt.fromJson({
        'batchId': 'batch-running-summary',
        'status': 'RUNNING',
        'executionStatus': 'EXECUTION_ERROR',
        'headline': '本次任务已结束，结果处理异常',
        'items': [
          {'itemId': 'recipient_0', 'status': 'RUNNING'},
        ],
      }, fallbackId: 'batch-running-summary');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationMessageTile(
              message: ConversationMessage(
                id: 'batch-running-summary',
                role: MessageRole.assistant,
                text: '',
                batchReceipt: terminal,
              ),
              optionsEnabled: false,
              onChoose: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('执行结果'), findsOneWidget);
      expect(find.text('执行异常'), findsOneWidget);
      expect(find.text('本次任务已结束，结果处理异常'), findsOneWidget);
      expect(find.text('结果陆续返回'), findsNothing);
      expect(find.text('进行中'), findsNothing);
      expect(find.text('待核对'), findsOneWidget);
    },
  );

  testWidgets('history restores an empty execution error as a result card', (
    tester,
  ) async {
    final facts = [
      LedgerEvent(
        eventId: 'empty-error',
        sessionId: 'session-a',
        commandId: 'command-a',
        sequence: 1,
        type: 'ASSISTANT_TURN_COMMITTED',
        schemaVersion: 1,
        payload: {
          'text': '本次任务已结束，结果处理异常',
          'batchCallResult': {
            'status': 'PENDING',
            'executionStatus': 'EXECUTION_ERROR',
            'headline': '执行异常',
            'items': <Object>[],
          },
        },
      ),
    ];
    final result = ConversationMessages.project(
      facts,
    ).where((message) => message.batchReceipt != null).single;
    final live = ReceiptMessageMapper.fromFinal({
      'text': '本次任务已结束，结果处理异常',
      'batchCallResult': {
        'status': 'PENDING',
        'executionStatus': 'EXECUTION_ERROR',
        'headline': '执行异常',
        'items': <Object>[],
      },
    }, 'command-a');
    expect(
      ConversationMessageMerge.merge(
        ConversationMessages.project(facts),
        live,
      ).where((message) => message.batchReceipt != null),
      hasLength(1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationMessageTile(
            message: result,
            optionsEnabled: false,
            onChoose: (_) {},
          ),
        ),
      ),
    );

    expect(result.batchReceipt!.items, isEmpty);
    expect(find.text('执行结果'), findsOneWidget);
    expect(find.text('执行异常'), findsOneWidget);
    expect(find.text('本次任务已结束，结果处理异常'), findsOneWidget);
    expect(find.textContaining('0 路结果'), findsNothing);
    expect(find.textContaining('0/0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'batch card displays billing recovered from matching timeline fact',
    (tester) async {
      final facts = [
        LedgerEvent(
          eventId: 'batch-result',
          sessionId: 'session-a',
          sequence: 2,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          payload: {
            'batchCallResult': {
              'batchId': 'batch-a',
              'status': 'COMPLETED',
              'items': [
                {
                  'itemId': 'item-a',
                  'callAttemptId': 'attempt-a',
                  'status': 'FAILED',
                },
              ],
            },
          },
        ),
        LedgerEvent(
          eventId: 'call-outcome',
          sessionId: 'session-a',
          sequence: 1,
          type: 'CALL_OUTCOME_REPORTED',
          schemaVersion: 1,
          callAttemptId: 'attempt-a',
          payload: {
            'callReceipt': {
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'SETTLED',
                'chargedPoints': 160,
                'remainingPoints': 55,
              },
            },
          },
        ),
      ];
      final durable = ConversationMessages.project(facts);
      final live = ReceiptMessageMapper.fromFinal({
        'batchCallResult': {
          'batchId': 'batch-a',
          'status': 'COMPLETED',
          'items': [
            {
              'itemId': 'item-a',
              'callAttemptId': 'attempt-a',
              'status': 'FAILED',
            },
          ],
        },
      }, 'command-a');
      final projected = ConversationMessageMerge.merge(
        durable,
        live,
      ).singleWhere((message) => message.batchReceipt != null).batchReceipt!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConversationMessageTile(
                message: ConversationMessage(
                  id: 'batch-a',
                  role: MessageRole.assistant,
                  text: '',
                  batchReceipt: projected,
                ),
                optionsEnabled: false,
                onChoose: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('扣除积分'), findsOneWidget);
      expect(find.text('160'), findsOneWidget);
      expect(find.text('剩余积分'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'batch facts remain readable in existing small-screen message layout',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 240,
                child: ConversationMessageTile(
                  message: ConversationMessage(
                    id: 'batch',
                    role: MessageRole.assistant,
                    text: '',
                    batchReceipt: receipt,
                  ),
                  optionsEnabled: false,
                  onChoose: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('2/4 已产生结果'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

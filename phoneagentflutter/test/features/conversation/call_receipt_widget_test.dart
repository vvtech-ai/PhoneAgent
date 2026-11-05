import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_receipt_text.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';

void main() {
  final receipt = CallReceipt.fromResult({
    'status': 'COMPLETED',
    'headline': '已结束',
    'metadata': {
      'targetName': '合成餐厅',
      'agentOutcome': 'FAILED',
      'dialogueTranscript': 'AI：还有座位吗？\n商家：已满',
      'internal': 'do-not-render',
    },
    'receiptFields': [
      {'key': 'party', 'label': '人数', 'value': '三人'},
    ],
    'billingSummary': {
      'billingSessionId': 'private-id',
      'displayDurationSeconds': 12,
      'firstMinutePoints': 5,
      'blockDurationMs': 10000,
      'blockPoints': 2,
      'chargedPoints': 5,
      'remainingPoints': 12345,
    },
  });
  test(
    'readable fallback includes returned fields, rates and recognized dialogue only',
    () {
      final text = CallReceiptText.format(receipt);
      expect(text, contains('状态：未完成'));
      expect(text, contains('人数：三人'));
      expect(text, contains('AI：还有座位吗？\n对方：已满'));
      expect(text, contains('模型费率：首分钟 5，之后每 10 秒 2'));
      expect(text, contains('剩余积分：12,345'));
      expect(text, isNot(contains('do-not-render')));
      expect(text, isNot(contains('private-id')));
      final missing = CallReceiptText.format(
        CallReceipt(attemptId: 'a', status: 'COMPLETED'),
      );
      expect(missing, contains('结果未确认'));
      expect(missing, isNot(contains('扣除积分')));
    },
  );
  testWidgets(
    'receipt is accessible in existing message layout without dial buttons',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: SizedBox(
                  width: 240,
                  child: ConversationMessageTile(
                    message: ConversationMessage(
                      id: 'receipt',
                      role: MessageRole.assistant,
                      text: '',
                      receipt: receipt,
                    ),
                    optionsEnabled: false,
                    onChoose: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('状态'), findsOneWidget);
      expect(find.text('未完成'), findsOneWidget);
      expect(find.text('人数'), findsOneWidget);
      expect(find.text('三人'), findsOneWidget);
      expect(find.text('还有座位吗？'), findsOneWidget);
      expect(find.text('已满'), findsOneWidget);
      expect(find.text('剩余积分'), findsOneWidget);
      expect(find.text('12,345'), findsOneWidget);
      expect(find.textContaining('do-not-render'), findsNothing);
      expect(find.textContaining('private-id'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

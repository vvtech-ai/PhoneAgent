import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_receipt_text.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';

void main() {
  test(
    'plain call receipt masks spoken and written mobile numbers but keeps ordinary figures',
    () {
      final privateReceipt = CallReceipt(
        attemptId: 'privacy-fixture',
        status: 'COMPLETED',
        phoneNumber: '13800002222',
        headline: '请回拨 13800002222',
        detail: '下午2点，4人，预付100元',
        transcript: 'AI：号码一三八零零零零二二二二\n对方：另一个 138-0000-2222',
      );
      final text = CallReceiptText.format(privateReceipt);
      expect(text, contains('尾号 2222'));
      expect(text, isNot(contains('1380000')));
      expect(text, isNot(contains('一三八零零')));
      expect(text, contains('下午2点，4人，预付100元'));
      expect(privateReceipt.phoneNumber, '13800002222');
    },
  );

  test(
    'uncertain spoken number hides the entire candidate without guessing a suffix',
    () {
      final privateReceipt = CallReceipt(
        attemptId: 'privacy-uncertain',
        status: 'COMPLETED',
        transcript: 'AI：电话号码幺三八百零零零零二二二二',
      );
      final text = CallReceiptText.format(privateReceipt);
      expect(text, contains('电话号码已隐藏'));
      expect(text, isNot(contains('幺三八百')));
      expect(text, isNot(contains('尾号 2222')));
    },
  );

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
      'billingState': 'SETTLED',
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

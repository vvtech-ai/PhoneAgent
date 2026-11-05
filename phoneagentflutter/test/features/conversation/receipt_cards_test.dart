import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/preview_receipts.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

BatchReceipt batch({
  String status = 'SUCCESS',
  String transcript = 'AI：甲记录',
  bool reversed = false,
}) => BatchReceipt.fromJson({
  'batchId': 'batch',
  'status': 'COMPLETED',
  'items': [
    if (reversed) {'itemId': 'b', 'status': 'FAILED', 'transcript': '对方：乙记录'},
    {'itemId': 'a', 'status': status, 'transcript': transcript},
    if (!reversed) {'itemId': 'b', 'status': 'FAILED', 'transcript': '对方：乙记录'},
  ],
}, fallbackId: 'batch');

void main() {
  testWidgets('physical completion without semantic success remains unclear', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CallReceiptCard(
          receipt: CallReceipt(
            attemptId: 'a',
            status: 'COMPLETED',
            transcript: '备注：不应显示',
          ),
        ),
      ),
    );
    expect(find.text('结果确认中'), findsOneWidget);
    expect(find.text('结果未确认'), findsOneWidget);
    expect(find.text('通话转写'), findsNothing);
    expect(find.text('积分结算'), findsNothing);
    expect(find.textContaining('不应显示'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('unsettled billing numbers stay unconfirmed on execution error', (
    tester,
  ) async {
    CallReceipt result(String billingState) => CallReceipt(
      attemptId: 'attempt',
      status: 'EXECUTION_ERROR',
      detail: '本次任务已结束，结果处理异常',
      billing: ReceiptBilling(
        sessionId: 'billing',
        state: billingState,
        durationSeconds: 0,
        chargedPoints: 0,
      ),
    );
    await tester.pumpWidget(host(CallReceiptCard(receipt: result('PENDING'))));
    expect(find.text('待核对'), findsOneWidget);
    expect(find.text('扣除积分'), findsNothing);
    expect(find.text('计费时长'), findsNothing);
    await tester.pumpWidget(host(CallReceiptCard(receipt: result('RELEASED'))));
    expect(find.text('待核对'), findsNothing);
    expect(find.text('扣除积分'), findsOneWidget);
    expect(find.text('计费时长'), findsOneWidget);
  });

  testWidgets('booking execution error does not claim task failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CallReceiptCard(
          receipt: CallReceipt(
            attemptId: 'attempt',
            targetName: '合成餐厅',
            status: 'EXECUTION_ERROR',
            headline: '执行异常',
            detail: '本次任务已结束，结果处理异常',
          ),
        ),
      ),
    );
    expect(find.text('执行异常'), findsWidgets);
    expect(find.text('本次任务已结束，结果处理异常'), findsOneWidget);
    expect(find.text('任务失败'), findsNothing);
  });

  testWidgets('batch result count is not the number of successes', (
    tester,
  ) async {
    final receipt = previewReceipts().last.batchReceipt!;
    await tester.pumpWidget(host(BatchReceiptCard(receipt: receipt)));
    expect(find.text('3/3 已产生结果'), findsOneWidget);
    expect(find.text('3 路结果 · 1 路完成 · 2 路需关注'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    expect(find.text('这是合成甲的离线记录。'), findsNothing);
  });

  testWidgets('independent expand survives reordering and collapse is local', (
    tester,
  ) async {
    await tester.pumpWidget(host(BatchReceiptCard(receipt: batch())));
    final a = find.byKey(const ValueKey('receipt-transcript:a'));
    final b = find.byKey(const ValueKey('receipt-transcript:b'));
    await tester.ensureVisible(a);
    await tester.tap(a);
    await tester.pumpAndSettle();
    expect(find.text('甲记录'), findsOneWidget);
    expect(find.text('乙记录'), findsNothing);
    await tester.pumpWidget(
      host(BatchReceiptCard(receipt: batch(reversed: true))),
    );
    expect(find.text('甲记录'), findsOneWidget);
    await tester.ensureVisible(b);
    await tester.tap(b);
    await tester.pumpAndSettle();
    expect(find.text('乙记录'), findsOneWidget);
    await tester.ensureVisible(a);
    await tester.tap(a);
    await tester.pumpAndSettle();
    expect(find.text('甲记录'), findsNothing);
    expect(find.text('乙记录'), findsOneWidget);
  });

  for (final change in ['status', 'transcript', 'identity']) {
    testWidgets('$change update resets item expansion', (tester) async {
      Widget item(String id, String status, String transcript) => host(
        BatchReceiptItemCard(
          item: BatchReceiptItem.fromJson({
            'itemId': id,
            'status': status,
            'transcript': transcript,
          }, id),
        ),
      );
      await tester.pumpWidget(item('a', 'SUCCESS', 'AI：原记录'));
      await tester.tap(find.text('查看通话记录'));
      await tester.pumpAndSettle();
      expect(find.text('原记录'), findsOneWidget);
      await tester.pumpWidget(
        item(
          change == 'identity' ? 'b' : 'a',
          change == 'status' ? 'FAILED' : 'SUCCESS',
          change == 'transcript' ? 'AI：新记录' : 'AI：原记录',
        ),
      );
      expect(find.text('查看通话记录'), findsOneWidget);
      expect(find.text('收起通话记录'), findsNothing);
      expect(find.text('原记录'), findsNothing);
      expect(find.text('新记录'), findsNothing);
    });
  }

  testWidgets('missing transcript and billing do not create action or charge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(BatchReceiptCard(receipt: batch(transcript: '备注：仅总结'))),
    );
    expect(find.byKey(const ValueKey('receipt-transcript:a')), findsNothing);
    expect(find.text('积分结算'), findsNothing);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('long receipt content fits $width with larger text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final long = '长联系人和字段内容' * 20;
      final receipt = BatchReceipt.fromJson({
        'batchId': 'long',
        'status': 'COMPLETED',
        'items': [
          {
            'itemId': 'a',
            'status': 'SUCCESS',
            'targetName': long,
            'headline': long,
            'transcript': 'AI：$long',
            'receiptFields': [
              {'key': 'long', 'label': long, 'value': long},
            ],
          },
        ],
      }, fallbackId: 'long');
      await tester.pumpWidget(
        host(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Column(
              children: [
                CallReceiptCard(
                  receipt: CallReceipt(
                    attemptId: 'long',
                    status: 'FAILED',
                    targetName: long,
                    fields: [ReceiptField('long', long, long)],
                  ),
                ),
                BatchReceiptCard(receipt: receipt),
              ],
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('查看通话记录'));
      await tester.tap(find.text('查看通话记录'));
      await tester.pumpAndSettle();
      expect(find.text('收起通话记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

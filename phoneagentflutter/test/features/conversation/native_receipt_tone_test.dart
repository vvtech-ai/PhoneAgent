import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/receipt_sections.dart';

void main() {
  CallReceipt committedReceipt(Map<String, Object?> result) =>
      CallReceiptProjector.project([
        LedgerEvent(
          eventId: 'committed-ui',
          sessionId: 'ui',
          sequence: 1,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'ui-command',
          payload: {'callResult': result},
        ),
      ]).single.receipt;

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform shows execution error as a finished result card', (
      tester,
    ) async {
      final receipt = CallReceipt.fromResult({
        'status': 'EXECUTION_ERROR',
        'headline': '执行异常',
        'detail': '本次任务已结束，结果处理异常',
        'metadata': {'callAttemptId': 'attempt-1'},
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CallReceiptCard(receipt: receipt)),
        ),
      );
      expect(find.text('执行异常'), findsWidgets);
      expect(find.text('结果确认中'), findsNothing);
      expect(find.text('本次任务已结束，结果处理异常'), findsOneWidget);
      expect(
        tester.widget<ReceiptShell>(find.byType(ReceiptShell)).borderColor,
        const Color(0x33E14D46),
      );
    });
    testWidgets('$platform physical completion does not imply success tone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final (outcome, label, border) in [
        ('SUCCESS', '完成', const Color(0x3334C759)),
        ('FAILED', '未完成', const Color(0x33E14D46)),
        ('USER_CANCELLED', '未完成', const Color(0x33E14D46)),
        ('UNCLEAR', '未完成', const Color(0x33E14D46)),
      ]) {
        final receipt = committedReceipt({
          'status': 'COMPLETED',
          'metadata': {'agentOutcome': outcome, 'targetName': '合成联系人'},
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: CallReceiptCard(receipt: receipt),
                ),
              ),
            ),
          ),
        );
        expect(find.text(label), findsOneWidget);
        final shell = find.byType(ReceiptShell);
        expect(tester.widget<ReceiptShell>(shell).borderColor, border);
        final container = tester.widget<Container>(
          find.descendant(of: shell, matching: find.byType(Container)).first,
        );
        final gradient =
            (container.decoration! as BoxDecoration).gradient!
                as LinearGradient;
        expect(gradient.begin, Alignment.topLeft);
        expect(gradient.end, Alignment.bottomRight);
        final title = tester.widget<Text>(
          find.text(outcome == 'UNCLEAR' ? '通话未完成' : '执行结果'),
        );
        expect(title.style!.fontSize! * title.style!.height!, 18);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('batch transcript columns and reset $platform $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Future<void> show(String transcript) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 308,
                  child: BatchReceiptItemCard(
                    item: BatchReceiptItem.fromJson({
                      'targetName': '合成联系人',
                      'status': 'SUCCESS',
                      'headline': '合成结果',
                      'transcript': transcript,
                    }, 'synthetic'),
                  ),
                ),
              ),
            ),
          ),
        );
        await show('AI: 合成询问\n对方: 合成答复');
        expect(find.text('合成询问'), findsNothing);
        await tester.tap(find.text('查看通话记录'));
        await tester.pump();
        expect(find.text('AI'), findsOneWidget);
        final ai = tester.getRect(find.text('AI'));
        final remote = tester.getRect(find.text('对方'));
        final first = tester.getRect(find.text('合成询问'));
        final second = tester.getRect(find.text('合成答复'));
        expect(first.left - ai.left, closeTo(68, .01));
        expect(second.left - remote.left, closeTo(68, .01));
        final firstRow = find
            .ancestor(of: find.text('合成询问'), matching: find.byType(Row))
            .first;
        final secondRow = find
            .ancestor(of: find.text('合成答复'), matching: find.byType(Row))
            .first;
        expect(
          tester.getRect(secondRow).top - tester.getRect(firstRow).bottom,
          closeTo(11, .01),
        );
        final speaker = tester.widget<Text>(find.text('AI'));
        expect(speaker.style!.fontSize, 11);
        expect(speaker.style!.fontWeight, FontWeight.w800);
        expect(speaker.style!.color, const Color(0xFF0877D1));
        final body = tester.widget<SelectableText>(
          find.byWidgetPredicate(
            (w) => w is SelectableText && w.data == '合成询问',
          ),
        );
        expect(body.style!.height, 21 / 13);
        await tester.tap(find.text('收起通话记录'));
        await tester.pump();
        expect(find.text('合成询问'), findsNothing);
        await tester.tap(find.text('查看通话记录'));
        await tester.pump();
        await show('AI: 更新后的合成记录');
        expect(find.text('更新后的合成记录'), findsNothing);
        expect(find.text('查看通话记录'), findsOneWidget);
        final longText = List.filled(12, '合成的较长通话记录内容').join();
        await show('assistant: $longText');
        await tester.tap(find.text('查看通话记录'));
        await tester.pump();
        final longBody = find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == longText,
        );
        expect(longBody, findsOneWidget);
        expect(tester.getSize(longBody).height, greaterThan(first.height));
        expect(
          tester.widget<SelectableText>(longBody).selectionEnabled,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

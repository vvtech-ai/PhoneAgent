import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/native_batch_item_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform batch item shared fields at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Future<void> show({
          required String name,
          required String headline,
        }) async {
          final item = BatchReceiptItem.fromJson({
            'targetName': name,
            'phoneNumber': '12345',
            'status': 'SUCCESS',
            'headline': headline,
            'detail': '合成额外详情',
            'receiptFields': [
              {'key': 'businessResult', 'label': '业务结果', 'value': '确认参加'},
              {'key': 'purpose', 'label': '事项', 'value': '合成事项'},
            ],
          }, 'synthetic-shared-item');
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 308,
                      child: BatchReceiptItemCard(item: item),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(item.fields, hasLength(2));
          expect(item.phoneNumber, '12345');
        }

        await show(name: '合成联系人', headline: '合成结果：完成');
        expect(find.text('合成联系人'), findsOneWidget);
        expect(find.text('合成结果：完成'), findsOneWidget);
        expect(find.text('确认参加'), findsOneWidget);
        expect(find.text('12345'), findsNothing);
        expect(find.text('合成额外详情'), findsNothing);
        expect(find.text('事项'), findsNothing);
        expect(find.text('合成事项'), findsNothing);
        final header = find.byType(NativeBatchItemHeader);
        final box = find
            .ancestor(of: header, matching: find.byType(Container))
            .first;
        expect(
          tester.getRect(header).left - tester.getRect(box).left,
          closeTo(10, .01),
        );
        await show(name: '', headline: '');
        expect(find.text('12345'), findsOneWidget);
        expect(find.text('合成额外详情'), findsOneWidget);
        expect(find.text('确认参加'), findsOneWidget);
        expect(find.text('事项'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

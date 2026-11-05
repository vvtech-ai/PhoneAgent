import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/native_batch_item_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('batch heading fallback and right edge $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final scale in [1.0, 2.0]) {
        for (final phone in ['', ' 12345 ']) {
          await tester.pumpWidget(
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
                    width: 240,
                    child: BatchReceiptItemCard(
                      item: BatchReceiptItem.fromJson({
                        'targetName': '   ',
                        'phoneNumber': phone,
                        'status': 'SUCCESS',
                        'detail': '确认参加',
                        'receiptFields': [
                          {
                            'key': 'businessResult',
                            'label': '结果',
                            'value': '  ',
                          },
                        ],
                      }, 'fallback'),
                    ),
                  ),
                ),
              ),
            ),
          );
          final header = find.byType(NativeBatchItemHeader);
          expect(
            find.descendant(
              of: header,
              matching: find.text(phone.isEmpty ? '未命名联系人' : '12345'),
            ),
            findsOneWidget,
          );
          expect(find.text('确认参加'), findsOneWidget);
          final label = find.text('已完成');
          expect(label, findsOneWidget);
          expect(
            tester.getRect(header).right - tester.getRect(label).right,
            closeTo(8, .01),
          );
          expect(
            tester.getRect(label).left,
            greaterThan(tester.getRect(header).center.dx),
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}

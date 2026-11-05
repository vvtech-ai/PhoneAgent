import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/native_batch_item_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('batch status natural width $platform $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Future<void> show(String label) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 308,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: NativeBatchItemHeader(
                      name: '合成联系人',
                      summary: '合成结果：已完成',
                      label: label,
                      tint: const Color(0xFF187A3A),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await show('确认参加');
        final text = tester.widget<Text>(find.text('确认参加'));
        final painter = TextPainter(
          text: TextSpan(text: text.data, style: text.style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout(maxWidth: tester.getSize(find.text('确认参加')).width);
        expect(painter.computeLineMetrics(), hasLength(1));
        painter.dispose();
        final shortHeight = tester.getSize(find.text('确认参加')).height;
        expect(
          tester.getRect(find.byType(NativeBatchItemHeader)).right -
              tester.getRect(find.text('确认参加')).right,
          closeTo(8, .01),
        );
        expect(tester.takeException(), isNull);
        await show('需要进一步确认参加时间及人员安排');
        expect(
          tester.getSize(find.text('需要进一步确认参加时间及人员安排')).height,
          greaterThan(shortHeight),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

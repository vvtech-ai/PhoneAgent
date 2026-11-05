import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_detail_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform detail native line region scale=$scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(411, 820);
        addTearDown(tester.view.reset);
        var backs = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Column(
                  children: [
                    NativeDetailHeader(title: '语音大模型', onBack: () => backs++),
                    const SizedBox(key: ValueKey('detail-body'), height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
        final header = find.byType(NativeDetailHeader);
        expect(tester.getSize(find.text('语音大模型')).height, 40 * scale);
        expect(tester.getSize(header).height, 16 + 40 * scale);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('detail-body'))).dy,
          tester.getRect(header).bottom,
        );
        final back = find.byTooltip('返回');
        expect(tester.getSize(back), const Size.square(48));
        expect(
          tester.getCenter(back).dy,
          closeTo(tester.getCenter(find.text('语音大模型')).dy, .1),
        );
        await tester.tap(back);
        expect(backs, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

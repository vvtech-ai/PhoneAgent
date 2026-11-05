import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('long config retains safe footer $platform', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.reset);
      var dialed = 0, cleared = 0, closes = 0;
      var translation = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return DialerPage(
                state: const DialerState(input: '123'),
                translationEnabled: translation,
                configuration: const SizedBox(height: 700, child: Text('长配置')),
                onCountry: () {},
                onDigit: (_) {},
                onDelete: () {},
                onClear: () => cleared++,
                onDial: () => dialed++,
                onClose: () => closes++,
              );
            },
          ),
        ),
      );
      final call = find.byKey(const Key('dial-call'));
      final close = find.byKey(const Key('dial-close'));
      final delete = find.byKey(const Key('dial-delete'));
      final bottom = tester.getBottomRight(call).dy;
      expect(bottom, closeTo(568 - 34 - 32, .01));
      expect(tester.getSize(call), const Size.square(64));
      Material surface() => tester.widget<Material>(
        find.ancestor(of: call, matching: find.byType(Material)).first,
      );
      expect(surface().color, const Color(0xFF6C5CE7));
      await tester.tap(call);
      await tester.longPress(delete);
      await tester.tap(close);
      expect(dialed, 1);
      expect(cleared, 1);
      expect(closes, 1);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(call).dy, closeTo(bottom, .01));
      rebuild(() => translation = false);
      await tester.pump();
      expect(surface().color, const Color(0xFF34C759));
      expect(tester.takeException(), isNull);
    });
  }
}

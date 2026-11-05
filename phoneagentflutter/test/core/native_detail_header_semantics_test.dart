import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_detail_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform named detail back disabled and old callback exits once at 2x',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const NativeDetailHeader(title: '未开启返回', onBack: null),
                    TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (detailContext) => Scaffold(
                            body: NativeDetailHeader(
                              title: '详情',
                              onBack: () => Navigator.pop(detailContext),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('打开详情'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('返回')),
          matchesSemantics(
            label: '返回',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        await tester.tap(find.text('打开详情'));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.bySemanticsLabel('返回')),
          matchesSemantics(
            label: '返回',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        final button = find.descendant(
          of: find.byType(NativeDetailHeader),
          matching: find.byType(IconButton),
        );
        expect(tester.getSize(button), const Size.square(48));
        final old = tester.widget<IconButton>(button).onPressed!;
        old();
        old();
        await tester.pumpAndSettle();
        expect(find.text('打开详情'), findsOneWidget);
        expect(find.text('详情'), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}

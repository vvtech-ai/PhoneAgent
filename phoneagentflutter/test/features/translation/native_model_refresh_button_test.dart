import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_model_refresh_button.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final reduce in [false, true]) {
      testWidgets('refresh motion $platform reduce=$reduce', (tester) async {
        final semantics = tester.ensureSemantics();
        var busy = true;
        var taps = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: child!,
            ),
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: NativeModelRefreshButton(
                    busy: busy,
                    onRefresh: () => taps++,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 450));
        final rotating =
            (tester.widget<IconButton>(find.byType(IconButton)).icon
                    as RotationTransition)
                .turns;
        expect(rotating.value, closeTo(reduce ? 0 : .5, .001));
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
        expect(find.byTooltip('正在刷新模型状态'), findsOneWidget);
        expect(find.bySemanticsLabel('正在刷新模型状态'), findsOneWidget);
        await tester.tap(find.byType(IconButton));
        expect(taps, 0);
        rebuild(() => busy = false);
        await tester.pump();
        expect(rotating.value, 0);
        await tester.pumpAndSettle();
        expect(find.byTooltip('刷新模型状态'), findsOneWidget);
        expect(find.bySemanticsLabel('刷新模型状态'), findsOneWidget);
        await tester.tap(find.byType(IconButton));
        expect(taps, 1);
        rebuild(() => busy = true);
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}

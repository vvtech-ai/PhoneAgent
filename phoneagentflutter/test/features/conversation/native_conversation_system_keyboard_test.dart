import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_timeline.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform real Scaffold keyboard follows tail at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
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
              body: NativeConversationTimeline(
                reverse: true,
                children: List.generate(
                  30,
                  (i) => SizedBox(
                    height: 80,
                    child: Text(i == 0 ? '合成最新说明' : '合成历史 $i'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byKey(const ValueKey('conversation-timeline'));
        ScrollPosition position() => tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        await tester.drag(list, const Offset(0, 220));
        await tester.pumpAndSettle();
        expect(position().pixels, greaterThan(100));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(
          MediaQuery.viewInsetsOf(
            tester.element(find.byType(NativeConversationTimeline)),
          ).bottom,
          0,
        );
        expect(position().pixels, position().minScrollExtent);
        expect(find.text('合成最新说明').hitTestable(), findsOneWidget);
        await tester.drag(list, const Offset(0, 220));
        await tester.pumpAndSettle();
        final historyOffset = position().pixels;
        tester.view.viewInsets = const FakeViewPadding(bottom: 0);
        await tester.pumpAndSettle();
        expect(position().pixels, closeTo(historyOffset, .01));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

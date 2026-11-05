import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_status_dot.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform pulse endpoints and lifecycle restart', (
      tester,
    ) async {
      var completed = false, reduced = false, visible = true;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: TickerMode(
                  enabled: visible,
                  child: Center(
                    child: NativeConversationStatusDot(completed: completed),
                  ),
                ),
              );
            },
          ),
        ),
      );
      double opacity() => tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byType(NativeConversationStatusDot),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
      expect(opacity(), 1);
      await tester.pump(const Duration(milliseconds: 900));
      expect(opacity(), closeTo(.3, .001));
      await tester.pump(const Duration(milliseconds: 900));
      expect(opacity(), closeTo(1, .001));
      expect(
        tester.getSize(find.byType(NativeConversationStatusDot)),
        const Size(8, 8),
      );
      for (final stop in ['completed', 'reduced', 'hidden']) {
        await tester.pump(const Duration(milliseconds: 450));
        expect(opacity(), lessThan(1));
        change(() {
          completed = stop == 'completed';
          reduced = stop == 'reduced';
          visible = stop != 'hidden';
        });
        await tester.pump();
        expect(opacity(), 1);
        await tester.pump(const Duration(seconds: 2));
        expect(opacity(), 1);
        expect(tester.binding.hasScheduledFrame, isFalse);
        change(() {
          completed = false;
          reduced = false;
          visible = true;
        });
        await tester.pump();
        expect(opacity(), 1);
        await tester.pump(const Duration(milliseconds: 900));
        expect(opacity(), closeTo(.3, .001));
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(opacity(), 1);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(opacity(), 1);
      await tester.pump(const Duration(milliseconds: 900));
      expect(opacity(), closeTo(.3, .001));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

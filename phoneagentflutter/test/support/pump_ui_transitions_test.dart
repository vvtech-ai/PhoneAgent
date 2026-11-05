import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_status_dot.dart';
import 'pump_ui_transitions.dart';

void main() {
  testWidgets('waits for a finite transition beside the continuing pulse', (
    tester,
  ) async {
    var opacity = 0.0;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return Column(
              children: [
                const NativeConversationStatusDot(completed: false),
                AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 600),
                  child: const Text('finite transition'),
                ),
              ],
            );
          },
        ),
      ),
    );
    change(() => opacity = 1);
    await tester.pumpUntilUiSettled();
    final fade = find.descendant(
      of: find.byType(AnimatedOpacity),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('does not ignore an unrelated repeating controller', (
    tester,
  ) async {
    final other = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    )..repeat();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: NativeConversationStatusDot(completed: false)),
      ),
    );
    Object? failure;
    try {
      await tester.pumpUntilUiSettled();
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<FlutterError>());
    other.dispose();
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });
}

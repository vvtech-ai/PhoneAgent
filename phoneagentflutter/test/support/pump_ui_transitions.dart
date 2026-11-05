import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_status_dot.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_sparkles.dart';

extension PumpUiTransitions on WidgetTester {
  /// Wait for finite UI transitions while allowing known decorative tickers.
  /// Other repeating tickers still time out; no application animation is disabled.
  Future<void> pumpUntilUiSettled([
    Duration step = const Duration(milliseconds: 100),
  ]) async {
    final deadline = binding.clock.now().add(const Duration(seconds: 10));
    do {
      await pump(step);
      if (!binding.hasScheduledFrame) return;
      final fades = find.descendant(
        of: find.byType(NativeConversationStatusDot, skipOffstage: false),
        matching: find.byType(FadeTransition, skipOffstage: false),
        skipOffstage: false,
      );
      final pulses = widgetList<FadeTransition>(fades)
          .where(
            (fade) =>
                fade.opacity.status == AnimationStatus.forward ||
                fade.opacity.status == AnimationStatus.reverse,
          )
          .length;
      final thinking =
          widgetList<AnimatedBuilder>(
            find.descendant(
              of: find.byType(NativeThinkingSparkles, skipOffstage: false),
              matching: find.byType(AnimatedBuilder, skipOffstage: false),
              skipOffstage: false,
            ),
          ).where((builder) {
            final animation = builder.animation;
            return animation is Animation<double> &&
                (animation.status == AnimationStatus.forward ||
                    animation.status == AnimationStatus.reverse);
          }).length;
      // Each active controller schedules exactly one transient callback.
      // Like pumpAndSettle, accept one quiescent frame. Requiring consecutive
      // frames would miss iOS caret's zero-duration restart between blinks.
      if (pulses + thinking > 0 &&
          binding.transientCallbackCount == pulses + thinking) {
        // Scroll jumps can queue layout in a post-frame callback without adding
        // a ticker. Flush that layout before asserting visible content.
        await pump();
        return;
      }
      if (binding.clock.now().isAfter(deadline)) {
        throw FlutterError(
          'UI transitions did not settle within 10 seconds: '
          'pulse=$pulses callbacks=${binding.transientCallbackCount} '
          'dots=${find.byType(NativeConversationStatusDot, skipOffstage: false).evaluate().length}.',
        );
      }
    } while (true);
  }
}

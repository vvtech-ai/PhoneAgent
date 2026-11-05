import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_voice_finalizing_dots.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_hold_button.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final phase in [
      VoiceInputPhase.finalizing,
      VoiceInputPhase.stopping,
    ]) {
      testWidgets(
        '$platform $phase ignores repeated input and disposes animation',
        (tester) async {
          final semantics = tester.ensureSemantics();
          var pressed = 0, released = 0, cancelled = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: Center(
                  child: VoiceHoldButton(
                    binding: VoiceComposerBinding(
                      state: VoiceInputState(phase: phase),
                      onPress: () => pressed++,
                      onRelease: () => released++,
                      onCancel: () => cancelled++,
                    ),
                    enabled: true,
                    icon: const Icon(Icons.mic),
                    onUnavailable: () => pressed++,
                  ),
                ),
              ),
            ),
          );
          final node = tester.getSemantics(find.bySemanticsLabel('识别中'));
          expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
          expect(find.byType(NativeVoiceFinalizingDots), findsOneWidget);
          final dots = find.descendant(
            of: find.byType(NativeVoiceFinalizingDots),
            matching: find.byType(Container),
          );
          final initial = tester.getTopLeft(dots.first);
          await tester.pump(const Duration(milliseconds: 270));
          expect(tester.getTopLeft(dots.first).dy, lessThan(initial.dy));
          final control = find.byKey(
            const ValueKey('conversation-voice-button'),
          );
          final gesture = await tester.startGesture(tester.getCenter(control));
          await gesture.moveBy(const Offset(0, -58));
          await gesture.up();
          await tester.pump();
          await tester.tap(control);
          expect([pressed, released, cancelled], [0, 0, 0]);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.binding.transientCallbackCount, 0);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('$platform reduced motion stops the active waiting ticker', (
      tester,
    ) async {
      Future<void> render(bool reduceMotion) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: const Center(child: NativeVoiceFinalizingDots()),
          ),
        ),
      );
      await render(false);
      await tester.pump(const Duration(milliseconds: 270));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await render(true);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      final dots = find.byType(Container);
      final positions = [
        for (var i = 0; i < 3; i++) tester.getTopLeft(dots.at(i)),
      ];
      await tester.pump(const Duration(seconds: 2));
      expect([
        for (var i = 0; i < 3; i++) tester.getTopLeft(dots.at(i)),
      ], positions);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

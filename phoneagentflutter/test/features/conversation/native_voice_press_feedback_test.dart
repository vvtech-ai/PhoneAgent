import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_voice_press_feedback.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_hold_button.dart';

void main() {
  final control = find.byKey(const ValueKey('conversation-voice-button'));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform hint text and bottom tip fade together without moving',
      (tester) async {
        var hint = '按住说话';
        late StateSetter change;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (_, rebuild) {
                    change = rebuild;
                    return NativeVoicePressFeedback(
                      active: false,
                      cancel: false,
                      cancelEpoch: 0,
                      guideHint: hint,
                      child: const Icon(Icons.mic),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final position = tester.getRect(find.text('按住说话'));
        final tip = find.byKey(const ValueKey('voice-guide-down-arrow'));
        expect(tester.getSize(tip), const Size(14, 7));
        expect(tester.getRect(tip).top, greaterThan(position.bottom));
        change(() => hint = '');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        expect(find.text('按住说话'), findsOneWidget);
        expect(tester.getRect(find.text('按住说话')), position);
        expect(tip, findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('按住说话'), findsNothing);
        expect(tip, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    for (final waiting in [
      VoiceInputPhase.finalizing,
      VoiceInputPhase.stopping,
    ]) {
      testWidgets(
        '$platform external $waiting clears held pointer without finishing twice',
        (tester) async {
          var phase = VoiceInputPhase.idle;
          var pressed = 0, released = 0, cancelled = 0;
          late StateSetter change;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return Center(
                      child: VoiceHoldButton(
                        binding: VoiceComposerBinding(
                          state: VoiceInputState(phase: phase),
                          onPress: () => pressed++,
                          onRelease: () => released++,
                          onCancel: () => cancelled++,
                        ),
                        enabled: true,
                        icon: const Icon(Icons.mic),
                        onUnavailable: () {},
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          final gesture = await tester.startGesture(tester.getCenter(control));
          await tester.pump(const Duration(milliseconds: 120));
          expect(pressed, 1);
          expect(find.text('松开发送 · 上滑取消'), findsOneWidget);
          change(() => phase = waiting);
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            tester
                .widget<NativeVoicePressFeedback>(
                  find.byType(NativeVoicePressFeedback),
                )
                .active,
            isFalse,
          );
          expect(find.text('松开发送 · 上滑取消'), findsNothing);
          await gesture.up();
          await tester.pump();
          expect([pressed, released, cancelled], [1, 0, 0]);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '$platform slide cancellation shows native hint once and expires',
      (tester) async {
        var released = 0, cancelled = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Center(
                child: VoiceHoldButton(
                  binding: VoiceComposerBinding(
                    state: const VoiceInputState(),
                    onPress: () {},
                    onRelease: () => released++,
                    onCancel: () => cancelled++,
                  ),
                  enabled: true,
                  icon: const Icon(Icons.mic),
                  onUnavailable: () {},
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(control));
        await tester.pump(const Duration(milliseconds: 120));
        await gesture.moveBy(const Offset(0, -58));
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.text('松手取消'), findsOneWidget);
        expect(
          tester
              .widget<NativeVoicePressFeedback>(
                find.byType(NativeVoicePressFeedback),
              )
              .cancel,
          isTrue,
        );
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 120));
        expect([released, cancelled], [0, 1]);
        expect(find.text('已取消'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();
        expect(find.text('已取消'), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform reduced motion keeps press feedback without a repeating ticker',
      (tester) async {
        var released = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: VoiceHoldButton(
                  binding: VoiceComposerBinding(
                    state: const VoiceInputState(),
                    onPress: () {},
                    onRelease: () => released++,
                    onCancel: () {},
                  ),
                  enabled: true,
                  icon: const Icon(Icons.mic),
                  onUnavailable: () {},
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(control));
        await tester.pumpAndSettle();
        expect(find.text('松开发送 · 上滑取消'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(released, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

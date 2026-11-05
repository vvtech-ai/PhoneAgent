import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_outcome_scope.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_hold_button.dart';

void main() {
  testWidgets(
    'ordinary result wait preserves speech interruption, explicit stop disables it',
    (tester) async {
      var stopping = false, speechStops = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, change) {
                rebuild = change;
                return CallOutcomeScope(
                  awaiting: true,
                  child: ConversationPage(
                    state: const ConversationState(
                      entry: ConversationEntry(sessionId: 'synthetic'),
                    ),
                    modelName: '合成模型',
                    onClose: () {},
                    onToggle: () {},
                    onSend: (_) => false,
                    onChoose: (_, _) => false,
                    onRetry: () {},
                    onNotice: (_) {},
                    onModels: () {},
                    stopping: stopping,
                    voice: VoiceComposerBinding(
                      state: const VoiceInputState(),
                      canInterruptReply: true,
                      onStopSpeech: () => speechStops++,
                      onPress: () {},
                      onRelease: () {},
                      onCancel: () {},
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final stop = find.byKey(const ValueKey('stop-current-processing'));
      await tester.tap(stop);
      await tester.pump();
      expect(speechStops, 1);
      rebuild(() => stopping = true);
      await tester.pump();
      expect(tester.widget<IconButton>(stop).onPressed, isNull);
      await tester.tap(stop);
      await tester.pump();
      expect(speechStops, 1);
      rebuild(() => stopping = false);
      await tester.pump();
      await tester.tap(stop);
      await tester.pump();
      expect(speechStops, 2);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final voiceMode in [true, false]) {
      testWidgets(
        '$platform stopping blocks task control despite stale TTS, voice=$voiceMode',
        (tester) async {
          var stopping = true, speechStops = 0, taskStops = 0;
          late StateSetter rebuild;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (_, change) {
                    rebuild = change;
                    return ConversationComposer(
                      voiceMode: voiceMode,
                      canSend: !stopping,
                      modelName: '合成模型',
                      onToggle: () {},
                      onSend: (_) => false,
                      onNotice: (_) {},
                      onModels: () {},
                      stopping: stopping,
                      onStop: stopping ? () => taskStops++ : null,
                      voice: VoiceComposerBinding(
                        state: const VoiceInputState(),
                        canInterruptReply: true,
                        onStopSpeech: () => speechStops++,
                        onPress: () {},
                        onRelease: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          final stop = find.byKey(const ValueKey('stop-current-processing'));
          expect(tester.widget<IconButton>(stop).onPressed, isNull);
          await tester.tap(stop);
          await tester.pump();
          expect(taskStops, 0);
          expect(speechStops, 0);
          rebuild(() => stopping = false);
          await tester.pump();
          await tester.tap(stop);
          await tester.pump();
          expect(speechStops, 1);
          expect(taskStops, 0);
        },
      );
    }
    for (final busy in [true, false]) {
      testWidgets(
        '$platform speech hold starts input only without task work: busy=$busy',
        (tester) async {
          var speaking = true, presses = 0, releases = 0, stops = 0;
          Duration? guidePress, guideRelease;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (_, rebuild) => ConversationComposer(
                    voiceMode: true,
                    canSend: !busy,
                    modelName: '合成模型',
                    onToggle: () {},
                    onSend: (_) => false,
                    onNotice: (_) {},
                    onModels: () {},
                    onStop: busy ? () {} : null,
                    voice: VoiceComposerBinding(
                      state: const VoiceInputState(),
                      canInterruptReply: speaking,
                      onStopSpeech: () {
                        stops++;
                        rebuild(() => speaking = false);
                      },
                      onGesturePress: (time) => guidePress = time,
                      onGestureRelease: (time) {
                        guideRelease = time;
                        return true;
                      },
                      onPress: () => presses++,
                      onRelease: () => releases++,
                      onCancel: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          final gesture = await tester.startGesture(
            tester.getCenter(
              find.byKey(const ValueKey('stop-current-processing')),
            ),
          );
          await tester.pump(const Duration(milliseconds: 299));
          expect(presses, 0);
          await tester.pump(const Duration(milliseconds: 1));
          expect(presses, busy ? 0 : 1);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(releases, busy ? 0 : 1);
          expect(stops, busy ? 0 : 1);
          expect(guidePress, busy ? isNull : Duration.zero);
          expect(
            guideRelease,
            busy ? isNull : const Duration(milliseconds: 300),
          );
        },
      );
    }
    testWidgets(
      '$platform speaking shows original stop, idle guide points to mic',
      (tester) async {
        var speaking = true, presses = 0, stops = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, change) {
                  rebuild = change;
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: ConversationComposer(
                      voiceMode: true,
                      canSend: true,
                      modelName: 'QwenOmniPlus ×1.0',
                      onToggle: () {},
                      onSend: (_) => false,
                      onNotice: (_) {},
                      onModels: () {},
                      voice: VoiceComposerBinding(
                        state: const VoiceInputState(),
                        canInterruptReply: speaking,
                        onStopSpeech: () {
                          stops++;
                          rebuild(() => speaking = false);
                        },
                        guideHint: '按住说话',
                        onPress: () => presses++,
                        onRelease: () {},
                        onCancel: () {},
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        expect(find.byType(VoiceHoldButton), findsNothing);
        expect(find.text('按住说话'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stop-current-processing')));
        await tester.pumpAndSettle();
        expect(stops, 1);
        expect(presses, 0);
        expect(find.byType(VoiceHoldButton), findsOneWidget);
        expect(find.text('按住说话'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('voice-guide-down-arrow')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

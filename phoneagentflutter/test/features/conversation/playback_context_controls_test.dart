import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/conversation_tokens.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final voiceMode in [true, false]) {
      testWidgets(
        '$platform mode=$voiceMode generation locks but playback allows context',
        (tester) async {
          var stage = 0, models = 0, images = 0;
          late StateSetter update;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (_, rebuild) {
                    update = rebuild;
                    final generating = stage < 2;
                    return ConversationPage(
                      state: ConversationState(
                        entry: const ConversationEntry(sessionId: 'synthetic'),
                        phase: generating
                            ? ConversationPhase.sending
                            : ConversationPhase.ready,
                        voiceMode: voiceMode,
                      ),
                      modelName: '测试模型',
                      onClose: () {},
                      onToggle: () {},
                      onSend: (_) => false,
                      onChoose: (_, _) => false,
                      onRetry: () {},
                      onNotice: (_) {},
                      onModels: () => models++,
                      onAttachments: () => images++,
                      onStop: generating ? () {} : null,
                      voice: VoiceComposerBinding(
                        state: const VoiceInputState(),
                        canInterruptReply: stage == 1 || stage == 2,
                        onStopSpeech: () {},
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
          for (var next = 0; next < 4; next++) {
            update(() => stage = next);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump();
            final plus = find.widgetWithIcon(IconButton, Icons.add_rounded);
            expect(
              tester.widget<IconButton>(plus).onPressed,
              next < 2 ? isNull : isNotNull,
            );
            expect(
              tester.widget<Text>(find.text('测试模型')).style?.color,
              next < 2
                  ? ConversationTokens.inactiveLabel
                  : ConversationTokens.model,
            );
            if (next >= 2) {
              await tester.tap(find.text('测试模型'));
              await tester.tap(plus);
            }
          }
          expect(models, 2);
          expect(images, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final generating in [false, true]) {
      for (final expanded in [false, true]) {
        testWidgets(
          '$platform text stop preserves draft generating=$generating expanded=$expanded',
          (tester) async {
            var speaking = true,
                speechStops = 0,
                taskStops = 0,
                sends = 0,
                notices = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: StatefulBuilder(
                      builder: (_, rebuild) => ConversationComposer(
                        voiceMode: false,
                        canSend: !generating,
                        modelName: '测试模型',
                        onToggle: () {},
                        onModels: () {},
                        onNotice: (_) => notices++,
                        onSend: (_) {
                          sends++;
                          return true;
                        },
                        onStop: generating ? () => taskStops++ : null,
                        voice: VoiceComposerBinding(
                          state: const VoiceInputState(),
                          canInterruptReply: speaking,
                          onStopSpeech: () {
                            speechStops++;
                            rebuild(() => speaking = false);
                          },
                          onPress: () {},
                          onRelease: () {},
                          onCancel: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            const draft = '第一行草稿\n第二行草稿';
            await tester.enterText(
              find.byKey(const ValueKey('conversation-input')),
              draft,
            );
            await tester.pumpAndSettle();
            if (expanded) {
              await tester.tap(find.byKey(const ValueKey('task-input-expand')));
              await tester.pumpAndSettle();
            }
            final scope = expanded
                ? find.byKey(const ValueKey('conversation-expanded-sheet'))
                : find.byType(ConversationComposer);
            final stop = find.descendant(
              of: scope,
              matching: find.byKey(const ValueKey('stop-current-processing')),
            );
            expect(stop, findsOneWidget);
            expect(tester.widget<IconButton>(stop).onPressed, isNotNull);
            await tester.tap(stop);
            await tester.pumpAndSettle();
            expect(speechStops, 1);
            expect(taskStops, 0);
            expect(sends, 0);
            expect(notices, 0);
            final field = find.byKey(
              ValueKey(
                expanded ? 'conversation-expanded-input' : 'conversation-input',
              ),
            );
            expect(tester.widget<TextField>(field).controller!.text, draft);
            if (!generating) {
              final send = find.descendant(
                of: scope,
                matching: find.byKey(
                  ValueKey(expanded ? 'send-expanded-text' : 'send-text'),
                ),
              );
              expect(tester.widget<IconButton>(send).onPressed, isNotNull);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

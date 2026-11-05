import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/conversation_tokens.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_timeline.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_model_selector.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';

void main() {
  testWidgets(
    'input leaves pending card and following respects manual history',
    (tester) async {
      var input = 0, revision = 0;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) {
                change = update;
                return SizedBox(
                  height: 400,
                  child: NativeConversationTimeline(
                    reverse: true,
                    focusItemKey: const ValueKey('card'),
                    inputRevision: input,
                    tailRevision: revision,
                    children: [
                      const SizedBox(
                        key: ValueKey('latest'),
                        height: 180,
                        child: Text('最新回复'),
                      ),
                      const SizedBox(
                        key: ValueKey('card'),
                        height: 900,
                        child: Text('待确认卡'),
                      ),
                      const SizedBox(height: 1000, child: Text('更早历史')),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(scroll.pixels, greaterThan(0));
      change(() => input++);
      await tester.pumpAndSettle();
      expect(scroll.pixels, scroll.minScrollExtent);
      change(() => revision++);
      await tester.pumpAndSettle();
      expect(scroll.pixels, scroll.minScrollExtent);
      await tester.drag(find.byType(ListView), const Offset(0, 250));
      await tester.pumpAndSettle();
      final historyPosition = scroll.pixels;
      expect(historyPosition, greaterThan(0));
      change(() => revision++);
      await tester.pumpAndSettle();
      expect(scroll.pixels, historyPosition);
      change(() => input++);
      await tester.pumpAndSettle();
      expect(scroll.pixels, scroll.minScrollExtent);
    },
  );

  for (final voiceMode in [true, false]) {
    for (final speaking in [true, false]) {
      testWidgets(
        'mode=$voiceMode speaking=$speaking blocks contextual actions but keeps stop',
        (tester) async {
          var models = 0, attachments = 0, stops = 0;
          var busy = true;
          late StateSetter change;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (_, update) {
                    change = update;
                    return ConversationComposer(
                      voiceMode: voiceMode,
                      canSend: !busy,
                      modelName: '测试模型',
                      onToggle: () {},
                      onSend: (_) => true,
                      onNotice: (_) {},
                      onModels: () => models++,
                      onAttachments: () => attachments++,
                      onStop: busy && !speaking ? () => stops++ : null,
                      voice: VoiceComposerBinding(
                        state: const VoiceInputState(),
                        canInterruptReply: speaking && busy,
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
          await tester.pump();
          expect(
            tester
                .widget<NativeConversationModelSelector>(
                  find.byType(NativeConversationModelSelector),
                )
                .onPressed,
            isNull,
          );
          final plus = find.widgetWithIcon(IconButton, Icons.add_rounded);
          expect(tester.widget<IconButton>(plus).onPressed, isNull);
          Color? plusColor() => tester
              .widget<Icon>(
                find.descendant(
                  of: plus,
                  matching: find.byIcon(Icons.add_rounded),
                ),
              )
              .color;
          Color? modelColor() =>
              tester.widget<Text>(find.text('测试模型')).style?.color;
          expect(plusColor(), ConversationTokens.inactiveLabel);
          expect(modelColor(), ConversationTokens.inactiveLabel);
          await tester.tap(find.text('测试模型'));
          await tester.tap(plus);
          expect(models, 0);
          expect(attachments, 0);
          if (!speaking) {
            await tester.tap(
              find.byKey(const ValueKey('stop-current-processing')),
            );
            expect(stops, 1);
          }
          change(() => busy = false);
          await tester.pump();
          expect(plusColor(), ConversationTokens.ink);
          expect(modelColor(), ConversationTokens.model);
          await tester.tap(find.text('测试模型'));
          await tester.tap(plus);
          expect(models, 1);
          expect(attachments, 1);
        },
      );
    }
  }
}

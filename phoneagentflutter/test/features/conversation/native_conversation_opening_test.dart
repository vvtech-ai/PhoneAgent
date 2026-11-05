import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_timeline.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform opening remains above later messages at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          const opening = '这是已有开场文案，请告诉我时间和人数。其他要求也可以一起说。';
          var state = const ConversationState(
            entry: ConversationEntry(
              sessionId: 'synthetic-opening',
              opening: opening,
            ),
          );
          late StateSetter change;
          var sends = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    height: 268,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        change = setState;
                        return ConversationPage(
                          state: state,
                          modelName: 'QwenOmniPlus',
                          onClose: () {},
                          onToggle: () {},
                          onSend: (_) {
                            sends++;
                            return false;
                          },
                          onChoose: (_, _) => false,
                          onRetry: () {},
                          onNotice: (_) {},
                          onModels: () {},
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          final bubble = find.byKey(
            const ValueKey('conversation-entry-opening'),
          );
          await tester.scrollUntilVisible(
            bubble,
            40,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('conversation-timeline')),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpUntilUiSettled();
          expect(find.text(opening), findsOneWidget);
          final tile = tester.widget<ConversationMessageTile>(bubble);
          expect(tile.message.role, MessageRole.assistant);
          expect(tile.optionsEnabled, isFalse);
          expect(state.messages, isEmpty);
          expect(sends, 0);
          change(
            () => state = state.copy(
              messages: const [
                ConversationMessage(
                  id: 'actual-message',
                  role: MessageRole.assistant,
                  text: '后续消息',
                ),
              ],
            ),
          );
          await tester.pumpUntilUiSettled();
          final timeline = tester.widget<NativeConversationTimeline>(
            find.byType(NativeConversationTimeline),
          );
          expect(
            timeline.children.where(
              (child) => child.key == const ValueKey('conversation-entry-opening'),
            ),
            hasLength(1),
          );
          expect(find.text('后续消息'), findsOneWidget);
          expect(state.messages.length, 1);
          final scrollable = find.descendant(
            of: find.byKey(const ValueKey('conversation-timeline')),
            matching: find.byType(Scrollable),
          );
          // SelectableText owns another inner Scrollable; use the list owner.
          final position = tester
              .state<ScrollableState>(scrollable.first)
              .position;
          expect(position.pixels, position.minScrollExtent);
          change(() => state = state.copy(messages: const []));
          await tester.pumpUntilUiSettled();
          // The opening remains below the standby wave in the empty layout.
          await tester.scrollUntilVisible(
            bubble,
            40,
            scrollable: scrollable.first,
          );
          await tester.pumpUntilUiSettled();
          expect(bubble, findsOneWidget);
          // Pending layout placement must be harmless after the owner leaves.
          change(
            () => state = state.copy(
              messages: const [
                ConversationMessage(
                  id: 'late',
                  role: MessageRole.assistant,
                  text: '后续消息',
                ),
              ],
            ),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(sends, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

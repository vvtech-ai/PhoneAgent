import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform mixed cards share native row spacing at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final choices = <int>[];
        final messages = [
          const ConversationMessage(
            id: 'tool',
            role: MessageRole.assistant,
            text: '',
            toolCard: ConversationToolCard(
              id: 'synthetic-tool',
              toolName: 'search',
              methodLabel: 'search()',
              body: '合成条件',
              result: '合成结果',
              status: 'PENDING',
            ),
          ),
          const ConversationMessage(
            id: 'options',
            role: MessageRole.assistant,
            text: '合成候选',
            options: [
              ConversationOption('甲', '说明'),
              ConversationOption('乙', ''),
            ],
          ),
          ConversationMessage(
            id: 'confirmation',
            role: MessageRole.assistant,
            text: '',
            confirmation: CallConfirmation(
              targetName: '合成目标',
              phoneNumber: '',
              primaryGoal: '合成任务',
              summaryLines: const [],
            ),
          ),
          const ConversationMessage(
            id: 'tail',
            role: MessageRole.user,
            text: '合成尾部',
          ),
        ];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final message in messages)
                        KeyedSubtree(
                          key: ValueKey('row:${message.id}'),
                          child: ConversationMessageTile(
                            message: message,
                            optionsEnabled: true,
                            onChoose: choices.add,
                            onAcceptChoice: (index) {
                              choices.add(index);
                              return true;
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Rect decoration(String id) {
          final surfaces = find.descendant(
            of: find.byKey(ValueKey('row:$id')),
            // Options use a Material surface; its first DecoratedBox is
            // an inner option badge, not the card boundary.
            matching: find.byType(id == 'options' ? Material : DecoratedBox),
          );
          // A confirmation row ends with the original ordinary AI question.
          final first = tester.getRect(surfaces.first);
          return id == 'confirmation'
              ? first.expandToInclude(tester.getRect(surfaces.last))
              : first;
        }

        for (var index = 0; index < messages.length - 1; index++) {
          expect(
            decoration(messages[index + 1].id).top -
                decoration(messages[index].id).bottom,
            closeTo(10, .01),
            reason: messages[index].id,
          );
        }
        expect(find.text('执行任务'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('option:options:1')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('option:options:0')));
        await tester.pump();
        expect(choices, [1]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

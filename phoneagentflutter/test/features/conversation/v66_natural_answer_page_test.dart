import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_questions.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform question uses original composer; stop keeps draft', (
      tester,
    ) async {
      var stopping = false, stopAvailable = true, stops = 0;
      final sent = <String>[];
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return ConversationPage(
                  state: ConversationState(
                    entry: const ConversationEntry(sessionId: 'synthetic'),
                    voiceMode: false,
                    messages: const [
                      ConversationMessage(
                        id: 'question',
                        role: MessageRole.assistant,
                        text: '怎么安排？',
                        questions: ConversationQuestions('补充需求', [
                          ConversationQuestion(
                            id: 'choice',
                            prompt: '您选哪天？',
                            type: 'single_choice',
                            choices: ['今天', '明天'],
                          ),
                        ]),
                      ),
                    ],
                  ),
                  modelName: '测试模型',
                  onClose: () {},
                  onToggle: () {},
                  onSend: (text) {
                    sent.add(text);
                    return true;
                  },
                  onChoose: (_, __) => false,
                  onRetry: () {},
                  onNotice: (_) {},
                  onModels: () {},
                  stopping: stopping,
                  onStop: stopAvailable
                      ? () => change(() {
                          stopping = true;
                          stops++;
                        })
                      : null,
                );
              },
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(
        find.byKey(const ValueKey('submit-question-answers')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('questions:question')), findsNothing);
      expect(find.text('停止任务'), findsNothing);
      final input = find.byKey(const ValueKey('conversation-input'));
      await tester.enterText(input, '明天下午');
      await tester.pump();
      final stop = find.byKey(const ValueKey('stop-current-processing'));
      expect(tester.getCenter(stop).dy, closeTo(tester.getCenter(input).dy, 1));
      await tester.tap(stop);
      await tester.pump();
      await tester.tap(stop);
      await tester.pump();
      expect(stops, 1);
      expect(sent, isEmpty);
      expect(tester.widget<TextField>(input).controller!.text, '明天下午');
      change(() {
        stopping = false;
        stopAvailable = false;
      });
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-text')));
      await tester.pump();
      expect(sent, ['明天下午']);
      expect(tester.takeException(), isNull);
    });
  }
}

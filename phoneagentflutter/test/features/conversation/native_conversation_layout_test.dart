import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_wave.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform short thread stays below fixed status row at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(390, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var state = const ConversationState(
            entry: ConversationEntry(sessionId: 'synthetic-layout'),
            messages: [
              ConversationMessage(
                id: 'short',
                role: MessageRole.assistant,
                text: '合成短消息',
              ),
              ConversationMessage(
                id: 'short-user',
                role: MessageRole.user,
                text: '合成用户回复',
              ),
            ],
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
                    height: 820,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        change = setState;
                        return _page(
                          state,
                          onSend: (_) {
                            sends++;
                            return false;
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpUntilUiSettled();
          expect(find.text('电话智能体 - 你的语音分身'), findsOneWidget);
          final wave = find.byType(NativeConversationWave);
          final initialWave = tester.getRect(wave);
          final header = tester.getRect(find.byType(ConversationHeader));
          final bubble = tester.getRect(
            find.byKey(const ValueKey('message:short')),
          );
          expect(initialWave.bottom, lessThanOrEqualTo(header.bottom));
          expect(initialWave.size, const Size(26, 27));
          expect(bubble.top, closeTo(header.bottom + 10, .01));
          expect(bubble.left, closeTo(16, .01));
          Rect decorated(String id) => tester.getRect(
            find
                .descendant(
                  of: find.byKey(ValueKey('message:$id')),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect(
            decorated('short-user').top - decorated('short').bottom,
            closeTo(10, .01),
          );
          expect(
            bubble.bottom,
            lessThan(
              tester
                  .getRect(find.byKey(const ValueKey('conversation-model')))
                  .top,
            ),
          );
          change(
            () => state = state.copy(
              messages: List.generate(
                30,
                (i) => ConversationMessage(
                  id: 'history-$i',
                  role: MessageRole.assistant,
                  text: '合成长历史 $i，需要滚动读取，但波形保持位置。',
                ),
              ),
            ),
          );
          await tester.pumpUntilUiSettled();
          final list = find.byKey(const ValueKey('conversation-timeline'));
          await tester.drag(list, const Offset(0, 180));
          await tester.pumpUntilUiSettled();
          expect(tester.getRect(wave), initialWave);
          expect(
            find.byKey(const ValueKey('close-conversation')).hitTestable(),
            findsOneWidget,
          );
          change(
            () => state = state.copy(
              phase: ConversationPhase.sending,
              activity: '正在思考…',
            ),
          );
          await tester.pump();
          expect(wave, findsOneWidget);
          expect(sends, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('$platform short keyboard layout keeps controls reachable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: SizedBox(
                height: 268,
                child: _page(
                  const ConversationState(
                    entry: ConversationEntry(
                      sessionId: 'synthetic-keyboard',
                      opening: '合成开场，可滚动阅读。',
                    ),
                    voiceMode: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpUntilUiSettled();
      expect(
        find.byKey(const ValueKey('close-conversation')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('conversation-input'))).bottom,
        lessThanOrEqualTo(268),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _page(ConversationState state, {bool Function(String)? onSend}) =>
    ConversationPage(
      state: state,
      modelName: 'QwenOmniPlus',
      onClose: () {},
      onToggle: () {},
      onSend: onSend ?? (_) => false,
      onChoose: (_, _) => false,
      onRetry: () {},
      onNotice: (_) {},
      onModels: () {},
    );

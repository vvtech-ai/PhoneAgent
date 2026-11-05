import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform new content and keyboard follow tail at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var state = ConversationState(
          entry: const ConversationEntry(sessionId: 'synthetic-tail'),
          messages: List.generate(
            30,
            (i) =>
                i == 28 ? _tool('合成初始结果') : _message('history-$i', '合成历史 $i。'),
          ),
        );
        late StateSetter change;
        var keyboard = 0.0;
        var model = 'QwenOmniPlus';
        var reduced = false;
        var sends = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  change = setState;
                  return MediaQuery(
                    data: MediaQueryData(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: reduced,
                      viewInsets: EdgeInsets.only(bottom: keyboard),
                    ),
                    child: SizedBox(
                      height: 820 - keyboard,
                      child: ConversationPage(
                        state: state,
                        modelName: model,
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpUntilUiSettled();
        final list = find.byKey(const ValueKey('conversation-timeline'));
        ScrollPosition position() => tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        void expectVisible(String text) {
          final target = find.text(text);
          expect(target, findsOneWidget);
          expect(tester.getRect(target).overlaps(tester.getRect(list)), isTrue);
        }

        Future<void> readHistory() async {
          await tester.drag(list, const Offset(0, 220));
          await tester.pumpUntilUiSettled();
          expect(position().pixels, greaterThan(100));
        }

        await readHistory();
        final oldOffset = position().pixels;
        change(() {
          model = '合成模型名称';
          state = state.copy(activity: '合成状态', messages: [...state.messages]);
        });
        await tester.pumpUntilUiSettled();
        expect(position().pixels, closeTo(oldOffset, .01));
        change(
          () => state = state.copy(
            messages: [
              ...state.messages.take(28),
              _tool('合成初始结果'),
              state.messages.last,
            ],
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(position().pixels, closeTo(oldOffset, .01));
        change(
          () => state = state.copy(
            messages: [
              ...state.messages.take(28),
              _tool('合成新增工具结果'),
              state.messages.last,
            ],
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(position().pixels, position().minScrollExtent);
        expect(find.textContaining('合成新增工具结果').hitTestable(), findsOneWidget);
        await readHistory();
        change(
          () => state = state.copy(
            messages: [
              ...state.messages.take(28),
              _options('合成初始候选详情'),
              state.messages.last,
            ],
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(position().pixels, position().minScrollExtent);
        await readHistory();
        final candidateOffset = position().pixels;
        change(
          () => state = state.copy(
            messages: [
              ...state.messages.take(28),
              _options('合成初始候选详情'),
              state.messages.last,
            ],
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(position().pixels, closeTo(candidateOffset, .01));
        change(
          () => state = state.copy(
            messages: [
              ...state.messages.take(28),
              _options('合成候选详情更新'),
              state.messages.last,
            ],
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(position().pixels, position().minScrollExtent);
        for (final batch in [false, true]) {
          var decision = BatchConfirmationDecision.pending;
          ConversationMessage confirmation(String value) => ConversationMessage(
            id: 'confirmation-original-position',
            role: MessageRole.assistant,
            text: '',
            confirmation: batch
                ? null
                : CallConfirmation(
                    targetName: '合成目标',
                    phoneNumber: '',
                    primaryGoal: value,
                    summaryLines: const [],
                  ),
            batchConfirmation: batch
                ? BatchConfirmation(
                    snapshotId: 'synthetic-confirmation',
                    version: 1,
                    title: '',
                    sections: const [],
                    recipients: const [],
                    issues: const [],
                    rules: [ConfirmationRow('合成规则', value)],
                    assistantText: '',
                    decision: decision,
                  )
                : null,
          );
          void update(String value) => change(
            () => state = state.copy(
              messages: [
                ...state.messages.take(28),
                confirmation(value),
                state.messages.last,
              ],
            ),
          );
          update('合成初始确认');
          await tester.pumpUntilUiSettled();
          await readHistory();
          final confirmationOffset = position().pixels;
          update('合成初始确认');
          await tester.pumpUntilUiSettled();
          expect(position().pixels, closeTo(confirmationOffset, .01));
          update('合成更新确认');
          await tester.pumpUntilUiSettled();
          if (batch) {
            final card = tester.getRect(
              find.byKey(const ValueKey('confirmation-original-position')),
            );
            final viewport = tester.getRect(list);
            expect(card.top, greaterThanOrEqualTo(viewport.top));
            expect(card.top, lessThan(viewport.bottom));
          } else {
            expect(position().pixels, position().minScrollExtent);
          }
          expect(find.text('合成更新确认').hitTestable(), findsOneWidget);
          if (batch) {
            change(() => decision = BatchConfirmationDecision.confirmed);
            update('合成更新确认');
            await tester.pumpUntilUiSettled();
            expect(position().pixels, position().minScrollExtent);
          }
        }
        await readHistory();
        change(
          () => state = state.copy(
            messages: [...state.messages, _message('new', '合成新消息')],
          ),
        );
        await tester.pump();
        final animationStart = position().pixels;
        expect(animationStart, greaterThan(0));
        await tester.pump(); // Start the ticker after the post-layout request.
        await tester.pump(const Duration(milliseconds: 90));
        expect(position().pixels, lessThan(animationStart));
        await tester.pumpUntilUiSettled();
        expect(position().pixels, position().minScrollExtent);
        expectVisible('合成新消息');

        await readHistory();
        change(
          () => state = state.copy(
            messages: [
              ...state.messages.take(30),
              _message('new', '合成新消息继续增长'),
            ],
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(position().pixels, position().minScrollExtent);
        expectVisible('合成新消息继续增长');

        await readHistory();
        change(() {
          reduced = true;
          state = state.copy(
            messages: [...state.messages, _message('reduced', '合成减少动效消息')],
            voiceMode: false,
          );
        });
        await tester.pumpUntilUiSettled();
        expect(position().pixels, position().minScrollExtent);
        expectVisible('合成减少动效消息');
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '合成保留草稿',
        );
        await readHistory();
        change(() => keyboard = 300);
        await tester.pumpUntilUiSettled();
        expect(position().pixels, position().minScrollExtent);
        expectVisible('合成减少动效消息');
        expect(find.text('合成保留草稿'), findsOneWidget);
        await readHistory();
        change(() => keyboard = 0);
        await tester.pumpUntilUiSettled();
        expect(position().pixels, greaterThan(0));

        // Competing placement requests and disposal cannot use stale layout.
        change(
          () => state = state.copy(
            messages: [...state.messages, _message('late', '合成晚到消息')],
          ),
        );
        await tester.pump();
        change(
          () => state = state.copy(
            messages: [...state.messages, _message('latest', '合成最后消息')],
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpUntilUiSettled();
        expect(sends, 0);
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  }
}

ConversationMessage _message(String id, String text) =>
    ConversationMessage(id: id, role: MessageRole.assistant, text: text);

ConversationMessage _tool(String result) => ConversationMessage(
  id: 'tool-original-position',
  role: MessageRole.assistant,
  text: '',
  toolCard: ConversationToolCard(
    id: 'synthetic-tool',
    toolName: 'search',
    methodLabel: 'search()',
    body: '合成条件',
    result: result,
    status: 'PENDING',
  ),
);
ConversationMessage _options(String detail) => ConversationMessage(
  id: 'options-original-position',
  role: MessageRole.assistant,
  text: '合成候选',
  options: [ConversationOption('合成候选名称', detail)],
);

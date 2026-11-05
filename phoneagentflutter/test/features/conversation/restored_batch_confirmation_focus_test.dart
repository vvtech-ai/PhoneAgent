import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation_focus.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_timeline_attachment.dart';
import '../../support/pump_ui_transitions.dart';

ConversationMessage _card(
  String id, {
  BatchConfirmationDecision decision = BatchConfirmationDecision.pending,
}) => ConversationMessage(
  id: id,
  role: MessageRole.assistant,
  text: '',
  toolCallId: 'tool:$id',
  batchConfirmation: BatchConfirmation(
    snapshotId: 'tool:$id',
    version: 1,
    title: '合成确认',
    sections: const [],
    recipients: const [],
    issues: const [],
    rules: const [],
    assistantText: '',
    decision: decision,
  ),
);
ConversationMessage _text(
  String id, {
  MessageRole role = MessageRole.assistant,
}) => ConversationMessage(id: id, role: role, text: '请核对后明确回复。' * 100);

void main() {
  test(
    'focus keeps the last pending original message identity before a prompt',
    () {
      final old = _card('old'), pending = _card('original');
      expect(
        pendingBatchConfirmationFocus([old, pending, _text('prompt')]),
        'original',
      );
      expect(pending.toolCallId, 'tool:original');
      expect(pending.batchConfirmation!.snapshotId, 'tool:original');
    },
  );
  test('user replies, later decisions and results invalidate older focus', () {
    final pending = _card('original');
    final blockers = [
      _text('answer', role: MessageRole.user),
      _card('confirmed', decision: BatchConfirmationDecision.confirmed),
      ConversationMessage(
        id: 'result',
        role: MessageRole.assistant,
        text: '',
        batchReceipt: BatchReceipt.fromJson({
          'batchId': 'b',
          'status': 'COMPLETED',
        }, fallbackId: 'b'),
      ),
    ];
    for (final blocker in blockers) {
      expect(
        pendingBatchConfirmationFocus([pending, blocker, _text('prompt')]),
        isNull,
      );
    }
    expect(
      pendingBatchConfirmationFocus([
        _card('confirmed', decision: BatchConfirmationDecision.confirmed),
      ]),
      isNull,
    );
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final restore in [true, false]) {
      testWidgets(
        '$platform ${restore ? 'restored' : 'live'} long pending card aligns its top without sending',
        (tester) async {
          tester.view.physicalSize = const Size(390, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var sends = 0;
          var state = ConversationState(
            entry: ConversationEntry(
              sessionId: 'synthetic-focus',
              restore: restore,
            ),
            messages: [_text('history'), _card('original'), _text('prompt')],
          );
          late StateSetter change;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (_, setState) {
                    change = setState;
                    return ConversationPage(
                      state: state,
                      attachments: const [
                        ConversationTimelineAttachment(
                          'synthetic-ocr',
                          1,
                          SizedBox(height: 90),
                        ),
                      ],
                      confirmationBuilder: (message, _) => SizedBox(
                        height: 1200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('确认卡顶部:${message.id}'),
                            const Spacer(),
                            const Text('确认卡底部'),
                          ],
                        ),
                      ),
                      modelName: '合成模型',
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
          );
          await tester.pumpUntilUiSettled();
          final timeline = find.byKey(const ValueKey('conversation-timeline'));
          final title = find.text('确认卡顶部:original');
          expect(title, findsOneWidget);
          final bounds = tester.getRect(timeline), card = tester.getRect(title);
          expect(card.top, greaterThanOrEqualTo(bounds.top));
          expect(card.bottom, lessThan(bounds.bottom));
          expect(sends, 0);
          ScrollPosition position() => tester
              .state<ScrollableState>(
                find
                    .descendant(of: timeline, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          change(() => state = state.copy(voiceMode: false));
          await tester.pumpUntilUiSettled();
          expect(position().pixels, position().minScrollExtent);
          change(() => state = state.copy(voiceMode: true));
          await tester.pumpUntilUiSettled();
          expect(position().pixels, position().minScrollExtent);
          change(() => state = state.copy(phase: ConversationPhase.sending));
          await tester.pumpUntilUiSettled();
          expect(position().pixels, position().minScrollExtent);
          change(() => state = state.copy(phase: ConversationPhase.ready));
          await tester.pumpUntilUiSettled();
          expect(tester.getRect(title).top, greaterThanOrEqualTo(bounds.top));
          change(
            () => state = state.copy(
              messages: [
                ...state.messages,
                _text('answer', role: MessageRole.user),
              ],
            ),
          );
          await tester.pumpUntilUiSettled();
          expect(position().pixels, position().minScrollExtent);
          expect(sends, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

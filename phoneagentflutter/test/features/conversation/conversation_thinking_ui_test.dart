import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_thinking.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';

void main() {
  testWidgets('interrupted batch keeps its execution card', (tester) async {
    final state = ConversationState(
      entry: const ConversationEntry(sessionId: 'interrupted-batch'),
      phase: ConversationPhase.ready,
      activity: '外呼请求失败，正在核对拨号状态，请稍后刷新',
      messages: [
        const ConversationMessage(
          id: 'user',
          role: MessageRole.user,
          text: '同时呼叫两路',
        ),
        ConversationMessage(
          id: 'interrupted-batch:batch-progress',
          role: MessageRole.assistant,
          text: '',
          transient: true,
          batchReceipt: BatchReceipt.fromJson({
            'batchId': 'batch',
            'status': 'RUNNING',
            'totalCount': 2,
            'items': [
              {'itemId': 'first', 'status': 'SUCCESS'},
              {'itemId': 'second', 'status': 'VERIFYING'},
            ],
          }, fallbackId: 'batch'),
        ),
      ],
    );
    Future<void> show(ConversationState value) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationPage(
              state: value,
              modelName: '合成模型',
              onClose: () {},
              onToggle: () {},
              onSend: (_) => false,
              onChoose: (_, _) => false,
              onRetry: () {},
              onNotice: (_) {},
              onModels: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await show(state);

    final header = find.byType(ConversationHeaderDetails);
    expect(
      find.descendant(of: header, matching: find.text('正在核对拨号状态')),
      findsOneWidget,
    );
    expect(find.byType(NativeThinkingCard), findsOneWidget);
    final cardElement = tester.element(find.byType(NativeThinkingCard));
    expect(
      tester
          .widget<NativeThinkingCard>(find.byType(NativeThinkingCard))
          .processing,
      isTrue,
    );

    await show(
      state.copy(
        messages: [
          state.messages.first,
          ConversationMessage(
            id: 'interrupted-batch:batch-progress',
            role: MessageRole.assistant,
            text: '',
            transient: true,
            batchReceipt: BatchReceipt.fromJson({
              'batchId': 'batch',
              'status': 'VERIFYING',
              'totalCount': 2,
              'items': [
                {'itemId': 'first', 'status': 'SUCCESS'},
                {'itemId': 'second', 'status': 'VERIFYING'},
              ],
            }, fallbackId: 'batch'),
          ),
        ],
      ),
    );
    expect(
      find.descendant(of: header, matching: find.text('结果待核对')),
      findsOneWidget,
    );
    expect(find.byType(NativeThinkingCard), findsOneWidget);
    expect(
      identical(cardElement, tester.element(find.byType(NativeThinkingCard))),
      isTrue,
    );
    expect(
      tester
          .widget<NativeThinkingCard>(find.byType(NativeThinkingCard))
          .processing,
      isFalse,
    );
    expect(find.textContaining('结果尚未确认，请稍后同步'), findsOneWidget);
  });

  testWidgets('completed thinking leaves a visible gap before the reply', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationPage(
            state: const ConversationState(
              entry: ConversationEntry(sessionId: 'synthetic-gap'),
              messages: [
                ConversationMessage(
                  id: 'thinking',
                  role: MessageRole.assistant,
                  text: '',
                  thinking: ConversationThinking(
                    text: '核对任务信息',
                    processing: false,
                  ),
                ),
                ConversationMessage(
                  id: 'reply',
                  role: MessageRole.assistant,
                  text: '请补充会议时间',
                ),
              ],
            ),
            modelName: '合成模型',
            onClose: () {},
            onToggle: () {},
            onSend: (_) => false,
            onChoose: (_, _) => false,
            onRetry: () {},
            onNotice: (_) {},
            onModels: () {},
          ),
        ),
      ),
    );
    await tester.pumpUntilUiSettled();
    final thought = tester.getRect(find.byType(NativeThinkingCard));
    final reply = tester.getRect(find.byKey(const ValueKey('reply')));
    expect(reply.top - thought.bottom, greaterThanOrEqualTo(12));
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform thinking is transient and does not alter messages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const initial = ConversationState(
        entry: ConversationEntry(sessionId: 'synthetic-thinking'),
        phase: ConversationPhase.sending,
        activity: '正在思考…',
        messages: [
          ConversationMessage(id: 'user', role: MessageRole.user, text: '合成任务'),
        ],
      );
      Future<void> show(ConversationState state) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: ConversationPage(
                  state: state,
                  modelName: 'QwenOmniPlus',
                  onClose: () {},
                  onToggle: () {},
                  onSend: (_) => false,
                  onChoose: (_, _) => false,
                  onRetry: () {},
                  onNotice: (_) {},
                  onModels: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      }

      await show(initial);
      expect(find.byType(NativeThinkingCard), findsOneWidget);
      expect(find.text('合成任务'), findsOneWidget);
      expect(initial.messages, hasLength(1));
      for (final activity in ['', '正在查询本机联系人…', '正在理解文档']) {
        await show(initial.copy(activity: activity));
        expect(find.byType(NativeThinkingCard), findsOneWidget);
        if (activity.isNotEmpty) {
          expect(find.text('· $activity'), findsOneWidget);
        }
      }
      for (final state in [
        initial.copy(phase: ConversationPhase.ready),
        initial.copy(phase: ConversationPhase.recoveryRequired),
        initial.copy(phase: ConversationPhase.restoring),
        initial.copy(phase: ConversationPhase.closed),
      ]) {
        await show(state);
        expect(find.byType(NativeThinkingCard), findsNothing);
        expect(state.messages, same(initial.messages));
      }
      final pending = initial.copy(
        activity: '正在执行多路外呼…',
        messages: [
          ConversationMessage(
            id: 'live-batch',
            role: MessageRole.assistant,
            text: '',
            transient: true,
            batchReceipt: BatchReceipt.fromJson({
              'batchId': 'synthetic-batch',
              'status': 'RUNNING',
              'totalCount': 2,
              'items': [
                {'status': 'SUCCESS'},
                {'status': 'FAILED'},
              ],
            }, fallbackId: 'synthetic-batch'),
          ),
        ],
      );
      await show(pending);
      expect(find.byType(NativeThinkingCard), findsOneWidget);
      expect(find.text('· 正在整理通话结果'), findsOneWidget);
      await show(pending.copy(phase: ConversationPhase.ready));
      expect(find.byType(NativeThinkingCard), findsOneWidget);
      expect(find.text('· 正在整理通话结果'), findsOneWidget);
      await show(
        pending.copy(
          phase: ConversationPhase.ready,
          messages: [
            ConversationMessage(
              id: 'committed-batch',
              role: MessageRole.assistant,
              text: '',
              batchReceipt: BatchReceipt.fromJson({
                'batchId': 'synthetic-batch',
                'status': 'COMPLETED',
                'executionStatus': 'FINISHED',
                'items': [
                  {'status': 'SUCCESS'},
                  {'status': 'FAILED'},
                ],
              }, fallbackId: 'synthetic-batch'),
            ),
          ],
        ),
      );
      expect(find.byType(NativeThinkingCard), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
}

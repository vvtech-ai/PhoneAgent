import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_thinking.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_event_flow.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_sparkles.dart';

void main() {
  test('wire tokens preserve whitespace and envelope start/done fields', () {
    const decoder = AgentEventDecoder();
    var thinking = const ConversationThinking();
    for (final frame in [
      const SseFrame('thinking_delta', '{"text":"分析"}'),
      const SseFrame('thinking_delta', '{"text":" "}'),
      const SseFrame('thinking_delta', '{"data":{"text":"目标"}}'),
    ]) {
      thinking = thinking.accept(decoder.decode(frame));
    }
    expect(thinking.text, '分析 目标');
    thinking = thinking.accept(
      decoder.decode(
        const SseFrame(
          'thinking_delta',
          '{"data":{"text":"下一阶段","start":true}}',
        ),
      ),
    );
    expect(thinking.text, '分析 目标\n下一阶段');
    final done = decoder.decode(
      const SseFrame('thinking_done', '{"data":{"durationMs":800}}'),
    );
    expect(done.payload['durationMs'], 800);
    expect(thinking.accept(done).processing, isFalse);
  });
  test(
    'native thought tokens append continuously and separate new segments',
    () {
      var thinking = const ConversationThinking();
      thinking = thinking.accept(
        const AgentEvent(
          AgentEventKind.thinking,
          text: '分析',
          payload: {'append': true, 'start': true},
        ),
      );
      thinking = thinking.accept(
        const AgentEvent(
          AgentEventKind.thinking,
          text: '目标',
          payload: {'append': true},
        ),
      );
      expect(thinking.text, '分析目标');
      thinking = thinking.accept(const AgentEvent(AgentEventKind.thinkingDone));
      expect(thinking.processing, isFalse);
      thinking = thinking.accept(
        const AgentEvent(
          AgentEventKind.thinking,
          text: '整理',
          payload: {'append': true},
        ),
      );
      thinking = thinking.accept(
        const AgentEvent(
          AgentEventKind.thinking,
          text: '下一步',
          payload: {'append': true, 'start': true},
        ),
      );
      thinking = thinking.accept(
        const AgentEvent(AgentEventKind.thinking, text: ' 独立阶段 '),
      );
      expect(thinking.text, '分析目标\n整理\n下一步\n独立阶段');
      expect(thinking.processing, isTrue);
    },
  );

  testWidgets(
    'thinking tokens survive completion and commit without spinning',
    (tester) async {
      final store = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
        phase: ConversationPhase.sending,
      );
      store.upsert(
        const ConversationMessage(
          id: 'user',
          role: MessageRole.user,
          text: '测试',
          commandId: 'c',
        ),
      );
      final flow = ConversationEventFlow(
        read: () => state,
        write: (value) => state = value,
        current: (generation) => generation == 1,
        messages: store,
        batch: BatchProgressTracker(),
        observed: (_, __) {},
        commit: (_, __) async => true,
        signal: (_, __, ___) async {},
        status: (_, __, ___) {},
        done: (_, __) async {
          state = state.copy(phase: ConversationPhase.ready);
        },
        failed: (_, __) {},
        batchFinished: () {},
        publish: () => state = store.project(state),
        assistant: (_, __) {},
      );
      Future<void> accept(AgentEvent event) => flow.accept(event, 'c', 1);
      Future<void> show() async {
        state = store.project(state);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationPage(
                state: state,
                modelName: '测试模型',
                onClose: () {},
                onToggle: () {},
                onSend: (_) => false,
                onChoose: (_, __) => false,
                onRetry: () {},
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }

      const decoder = AgentEventDecoder();
      await accept(
        decoder.decode(
          const SseFrame(
            'thinking_delta',
            '{"sessionId":"s","text":"正在分析","start":true}',
          ),
        ),
      );
      await accept(
        decoder.decode(
          const SseFrame(
            'thinking_delta',
            '{"sessionId":"s","data":{"text":"目标"}}',
          ),
        ),
      );
      await show();
      expect(find.byType(NativeThinkingCard), findsOneWidget);
      expect(find.text('· 正在分析目标'), findsOneWidget);
      expect(find.text('AI 思考过程'), findsOneWidget);
      await accept(
        const AgentEvent(
          AgentEventKind.thinkingDone,
          payload: {'durationMs': 250},
        ),
      );
      await accept(const AgentEvent(AgentEventKind.done));
      await show();
      expect(find.text('· 正在分析目标'), findsOneWidget);
      expect(find.byType(NativeThinkingSparkles), findsNothing);
      store.facts['committed'] = LedgerEvent(
        eventId: 'committed',
        sessionId: 's',
        sequence: 1,
        schemaVersion: 1,
        type: 'ASSISTANT_TURN_COMMITTED',
        commandId: 'c',
        payload: {'text': '处理完成'},
      );
      await show();
      expect(find.text('· 正在分析目标'), findsOneWidget);
      expect(find.text('处理完成'), findsOneWidget);
      expect(state.messages.where((m) => m.thinking != null), hasLength(1));
      // Late events from other sessions/generations cannot modify this content.
      await flow.accept(
        const AgentEvent(AgentEventKind.thinking, text: '旧事件'),
        'c',
        0,
      );
      await accept(
        const AgentEvent(
          AgentEventKind.thinking,
          sessionId: 'other',
          text: '异会话',
        ),
      );
      await show();
      expect(find.textContaining('旧事件'), findsNothing);
      expect(find.textContaining('异会话'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'large text shows latest three physical lines and scrolls on append',
    (tester) async {
      Future<void> show(List<String> steps) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: NativeThinkingCard(steps: steps, processing: false),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      final lines = List.generate(7, (i) => '第${i + 1}阶段：分析联系人并整理多路任务执行结果');
      await show(lines);
      final scrollView = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('thinking-lines')),
      );
      final scroll = scrollView.controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(scroll.offset, scroll.position.maxScrollExtent);
      final viewport = tester.getSize(
        find.byKey(const ValueKey('thinking-lines')),
      );
      expect(viewport.height, closeTo(3 * 18 * 2, 3));
      expect(find.byType(NativeThinkingSparkles), findsNothing);
      await show([...lines, '准备汇总']);
      expect(scroll.offset, scroll.position.maxScrollExtent);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_thinking.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_event_flow.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_sparkles.dart';

void main() {
  test('rebinds completed thinking to a continuation command', () {
    final store = ConversationMessageStore();
    store.think(
      'original',
      const AgentEvent(
        AgentEventKind.thinking,
        text: '查询联系人',
        payload: {'append': true},
      ),
    );
    store.rebindThinking('original', 'continuation');
    expect(store.messages, hasLength(1));
    expect(store.messages.single.commandId, 'continuation');
    expect(store.messages.single.id, 'local:continuation:thinking');
    expect(store.messages.single.thinking!.text, '查询联系人');
  });

  test(
    'thinking survives done, confirmation and committed answer in turn order',
    () async {
      final messages = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      messages.upsert(
        const ConversationMessage(
          id: 'local-user:c',
          commandId: 'c',
          role: MessageRole.user,
          text: '合成输入',
          transient: true,
        ),
      );
      void publish() => state = messages.project(state);
      final flow = ConversationEventFlow(
        read: () => state,
        write: (value) => state = value,
        current: (_) => true,
        messages: messages,
        batch: BatchProgressTracker(),
        observed: (_, __) {},
        commit: (_, _) async => true,
        signal: (_, _, _) async {},
        status: (_, _, _) {},
        done: (_, _) async {},
        failed: (_, _) {},
        batchFinished: () {},
        publish: publish,
        assistant: (command, text) {
          messages.assistant(command, text, [], null);
          publish();
        },
      );
      await flow.accept(
        const AgentEvent(
          AgentEventKind.thinking,
          text: '核对',
          payload: {'append': true},
        ),
        'c',
        1,
      );
      await flow.accept(
        const AgentEvent(
          AgentEventKind.thinking,
          text: '任务',
          payload: {'append': true},
        ),
        'c',
        1,
      );
      await flow.accept(
        const AgentEvent(
          AgentEventKind.thinkingDone,
          payload: {
            'data': {'durationMs': 1200},
          },
        ),
        'c',
        1,
      );
      messages.confirmation('c', 'call', {
        'targetName': '合成目标',
        'phoneNumber': '10086',
      });
      messages.facts['answer'] = LedgerEvent(
        eventId: 'answer',
        sessionId: 's',
        sequence: 2,
        schemaVersion: 1,
        commandId: 'c',
        type: 'ASSISTANT_TURN_COMMITTED',
        payload: {'text': '请确认'},
      );
      publish();
      final thinking = state.messages.singleWhere((m) => m.thinking != null);
      expect(thinking.thinking!.text, '核对任务');
      expect(thinking.thinking!.processing, isFalse);
      expect(
        state.messages.where((m) => m.role == MessageRole.user),
        hasLength(1),
      );
      expect(state.messages.indexOf(thinking), 1);
      expect(
        state.messages.indexWhere((m) => m.confirmation != null),
        greaterThan(1),
      );
      expect(state.messages.indexWhere((m) => m.text == '请确认'), greaterThan(1));
      messages.discardPartialReply('c');
      publish();
      expect(state.messages.any((m) => m.thinking?.text == '核对任务'), isTrue);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform completed thinking remains visible without animation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ConversationMessageTile(
                message: const ConversationMessage(
                  id: 'thinking',
                  role: MessageRole.assistant,
                  text: '',
                  thinking: ConversationThinking(
                    text: '合成思考内容',
                    processing: false,
                  ),
                ),
                optionsEnabled: false,
                onChoose: (_) {},
              ),
            ),
          ),
        );
        expect(find.text('· 合成思考内容'), findsOneWidget);
        expect(find.text('AI 思考过程'), findsOneWidget);
        expect(find.text('Phone Agent'), findsOneWidget);
        expect(find.byType(NativeThinkingSparkles), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

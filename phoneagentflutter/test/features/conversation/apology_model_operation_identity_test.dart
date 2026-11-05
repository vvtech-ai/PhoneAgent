import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

import '../../../tool/previews/shell_conversation_fakes.dart';

const _a = ApologyVoice('a', '模型甲', 'asset-a', active: true);
const _b = ApologyVoice('b', '模型乙', 'asset-b', active: true);

class _Voices implements ApologyVoicePort {
  List<ApologyVoice> available = const [_a, _b];
  Completer<List<ApologyVoice>>? delayed;
  int queries = 0;

  @override
  Future<List<ApologyVoice>> voices() async {
    queries++;
    return delayed?.future ?? available;
  }

  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {}
}

class _Agent implements AgentGateway {
  final events = StreamController<AgentEvent>.broadcast();
  final commands = <AgentCommand>[];

  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(events.stream, () {});
  }

  AgentEvent fact(int sequence, String type, String command, String text) =>
      AgentEvent(
        AgentEventKind.committed,
        ledger: LedgerEvent(
          eventId: 'operation-fact-$sequence',
          sessionId: 'model-operation',
          sequence: sequence,
          schemaVersion: 1,
          type: type,
          commandId: command,
          payload: {'text': text},
        ),
      );
}

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ConversationController _controller(_Voices voices, _Agent agent) {
  final controller = ConversationController(
    entry: const ConversationEntry(
      sessionId: 'model-operation',
      skillId: 'apology_master',
      opening: '后台开场不能替代专用 Consent',
    ),
    accountId: 'synthetic',
    gateway: agent,
    history: OfflineHistory(),
    apologyVoice: ApologyVoiceDependencies(
      port: voices,
      model: () => 'a',
      modelName: () => '模型甲',
      modelNameFor: (id) => id == 'a' ? '模型甲' : '模型乙',
    ),
  );
  addTearDown(() async {
    controller.dispose();
    await agent.events.close();
  });
  return controller;
}

void _preservesPrefix(
  ConversationController controller,
  List<ConversationMessage> before,
) {
  final prefix = controller.state.messages.take(before.length).toList();
  expect(prefix.map((m) => m.id), before.map((m) => m.id));
  expect(prefix.map((m) => m.text), before.map((m) => m.text));
  expect(
    prefix.map((m) => (m.optionsLocked, m.selectedOptionIndex)),
    before.map((m) => (m.optionsLocked, m.selectedOptionIndex)),
  );
}

void main() {
  test(
    'MODEL-01 A B A B appends each feedback without rewriting history',
    () async {
      final voices = _Voices();
      final agent = _Agent();
      final controller = _controller(voices, agent);
      final consent = controller.state.activeOptionsId!;
      expect(controller.choose(consent, 0), isTrue);
      await _flush();
      final promptIds = <String>{controller.apology!.voice.prompt!.id};

      for (final model in ['b', 'a', 'b']) {
        final before = controller.state.messages.toList();
        controller.apology!.voice.modelChanged(model);
        await _flush();
        _preservesPrefix(controller, before);
        expect(controller.state.messages.length, before.length + 1);
        expect(
          controller.state.messages.last.text,
          startsWith(model == 'a' ? '已切换为模型甲' : '已切换为模型乙'),
        );
        expect(controller.apology!.voice.selection?.modelId, model);
        expect(promptIds.add(controller.apology!.voice.prompt!.id), isTrue);

        final once = controller.state.messages.toList();
        final queries = voices.queries;
        controller.apology!.voice.modelChanged(model);
        await _flush();
        _preservesPrefix(controller, once);
        expect(controller.state.messages.length, once.length);
        expect(voices.queries, queries);
      }

      final feedback = controller.state.messages
          .where((m) => m.id.startsWith('local:apology:voice-ready:'))
          .toList();
      expect(feedback.map((m) => m.text), [
        ApologyVoicePolicy.ready,
        '已切换为模型乙，本次电话使用您的克隆音色。请继续当前道歉对话。',
        '已切换为模型甲，本次电话使用您的克隆音色。请继续当前道歉对话。',
        '已切换为模型乙，本次电话使用您的克隆音色。请继续当前道歉对话。',
      ]);
      expect(feedback.map((m) => m.id).toSet(), hasLength(4));
      expect(controller.state.messages.first.text, ApologyVoicePolicy.consent);
      expect(controller.choose(consent, 1), isFalse);
      expect(agent.commands, isEmpty);
    },
  );

  test(
    'MODEL-01 returning through the same model choice keeps both locked cards',
    () async {
      final voices = _Voices()..available = const [_a];
      final agent = _Agent();
      final controller = _controller(voices, agent);
      controller.choose(controller.state.activeOptionsId!, 0);
      await _flush();
      final selectedCards = <ConversationMessage>[];

      for (var repeat = 0; repeat < 2; repeat++) {
        controller.apology!.voice.modelChanged('b');
        await _flush();
        final before = controller.state.messages.toList();
        final currentCard = controller.state.activeOptionsId!;
        expect(controller.choose(currentCard, 0), isTrue);
        expect(controller.choose(currentCard, 0), isFalse);
        await _flush();
        _preservesPrefix(controller, before.take(before.length - 1).toList());
        expect(controller.apology!.voice.selection?.modelId, 'a');
        expect(controller.state.activeOptionsId, isNull);
        final card = controller.state.messages.lastWhere(
          (m) => m.options.isNotEmpty,
        );
        expect(card.optionsLocked, isTrue);
        expect(card.selectedOptionIndex, 0);
        expect(card.optionsTitleVisible, isFalse);
        expect(controller.choose(card.id, 1), isFalse);
        selectedCards.add(card);
      }

      expect(selectedCards.map((m) => m.id).toSet(), hasLength(2));
      expect(
        controller.state.messages.where((m) => m.text == '已选择：模型甲'),
        hasLength(2),
      );
      for (final old in selectedCards) {
        final position = controller.state.messages.indexWhere(
          (m) => m.id == old.id,
        );
        expect(position, greaterThan(0));
        expect(controller.state.messages[position - 1].options, isEmpty);
        expect(
          controller.state.messages[position - 1].text,
          contains('模型乙没有您的可用克隆音色'),
        );
        expect(controller.state.messages[position + 1].text, '已选择：模型甲');
        expect(
          controller.state.messages[position + 2].text,
          startsWith('已切换为模型甲'),
        );
      }
      expect(agent.commands, isEmpty);
      final beforeSubmit = controller.state.messages.toList();
      expect(controller.send('帮我向联系人道歉'), isTrue);
      final command = agent.commands.single;
      final openingCommand = 'initial-opening:model-operation';
      final openingFacts = [
        agent.fact(
          3,
          'ASSISTANT_TURN_COMMITTED',
          openingCommand,
          command.initialOpening!,
        ),
        agent.fact(
          1,
          'ASSISTANT_TURN_COMMITTED',
          openingCommand,
          command.initialAssistantPrompt!,
        ),
        agent.fact(
          2,
          'USER_TURN_ACCEPTED',
          openingCommand,
          command.initialUserSelection!,
        ),
      ];
      for (final fact in [...openingFacts, openingFacts.first]) {
        agent.events.add(fact);
        await _flush();
        expect(controller.state.messages.map((m) => m.text), [
          ...beforeSubmit.map((m) => m.text),
          '帮我向联系人道歉',
        ]);
        for (final old in selectedCards) {
          final card = controller.state.messages.singleWhere(
            (m) => m.id == old.id,
          );
          expect(card.selectedOptionIndex, 0);
          expect(card.optionsLocked, isTrue);
          expect(controller.choose(card.id, 1), isFalse);
        }
      }
    },
  );

  test(
    'HISTORY-01 initial opening reconciles only the final repeated feedback',
    () async {
      final voices = _Voices();
      final agent = _Agent();
      final controller = _controller(voices, agent);
      controller.choose(controller.state.activeOptionsId!, 0);
      await _flush();
      for (final model in ['b', 'a', 'b']) {
        controller.apology!.voice.modelChanged(model);
        await _flush();
      }
      final before = controller.state.messages.toList();
      final feedback = before
          .where((m) => m.text.startsWith('已切换为模型乙'))
          .toList();
      expect(feedback, hasLength(2));
      expect(controller.send('帮我向联系人道歉'), isTrue);
      final command = agent.commands.single;
      expect(command.initialOpening, feedback.last.text);
      final opening = agent.fact(
        1,
        'ASSISTANT_TURN_COMMITTED',
        'initial-opening:model-operation',
        command.initialOpening!,
      );
      for (var duplicate = 0; duplicate < 2; duplicate++) {
        agent.events.add(opening);
        await _flush();
        expect(controller.state.messages.map((m) => m.text), [
          ...before.map((m) => m.text),
          '帮我向联系人道歉',
        ]);
        expect(
          controller.state.messages.any((m) => m.id == feedback.first.id),
          isTrue,
        );
        expect(
          controller.state.messages.any((m) => m.id == feedback.last.id),
          isFalse,
        );
      }
      agent.events.add(
        agent.fact(
          2,
          'USER_TURN_ACCEPTED',
          command.commandId,
          command.message!,
        ),
      );
      agent.events.add(
        AgentEvent(AgentEventKind.finalResponse, text: feedback.last.text),
      );
      agent.events.add(
        agent.fact(
          3,
          'ASSISTANT_TURN_COMMITTED',
          command.commandId,
          feedback.last.text,
        ),
      );
      agent.events.add(const AgentEvent(AgentEventKind.done));
      await _flush();
      expect(controller.state.messages.map((m) => m.text), [
        ...before.map((m) => m.text),
        '帮我向联系人道歉',
        feedback.last.text,
      ]);
    },
  );

  for (final fails in [false, true]) {
    test(
      'MODEL-02 stale query success or failure cannot consume pending: fails=$fails',
      () async {
        final voices = _Voices();
        final agent = _Agent();
        final controller = _controller(voices, agent);
        controller.choose(controller.state.activeOptionsId!, 0);
        await _flush();
        expect(controller.send('帮我向联系人道歉'), isTrue);
        agent.events.add(
          const AgentEvent(
            AgentEventKind.signal,
            text: '请选择联系人',
            payload: {
              'type': 'SHOW_OPTIONS',
              'pendingToolCallId': 'original-tool',
              'options': {
                'items': [
                  {'label': '合成联系人'},
                ],
              },
            },
          ),
        );
        agent.events.add(const AgentEvent(AgentEventKind.done));
        await _flush();
        final pendingCard = controller.state.activeOptionsId!;
        final before = controller.state.messages.toList();
        final stale = Completer<List<ApologyVoice>>();
        voices.delayed = stale;
        controller.apology!.voice.modelChanged('b');
        expect(controller.apology!.voice.blocked, isTrue);
        expect(controller.apology!.voice.prompt, isNull);
        expect(controller.state.pendingToolCallId, 'original-tool');
        expect(controller.state.activeOptionsId, isNull);
        voices.delayed = null;
        controller.apology!.voice.modelChanged('a');
        await _flush();
        _preservesPrefix(controller, before);
        final current = controller.state.messages.toList();
        final currentPrompt = controller.apology!.voice.prompt!.id;
        if (fails) {
          stale.completeError(StateError('old query failed'));
        } else {
          stale.complete(const [_b]);
        }
        await _flush();
        _preservesPrefix(controller, current);
        expect(controller.state.messages.length, current.length);
        expect(controller.apology!.voice.prompt!.id, currentPrompt);
        expect(controller.apology!.voice.selection?.assetId, 'asset-a');
        expect(controller.state.pendingToolCallId, 'original-tool');
        expect(controller.state.activeOptionsId, pendingCard);
        expect(agent.commands, hasLength(1));
      },
    );
  }
}

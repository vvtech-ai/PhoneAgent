import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_text_bubble.dart';

import '../../../tool/previews/shell_conversation_fakes.dart';

class _Voices implements ApologyVoicePort {
  _Voices(this.available);
  final List<ApologyVoice> available;
  Completer<List<ApologyVoice>>? waiting;

  @override
  Future<List<ApologyVoice>> voices() async => waiting?.future ?? available;

  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {}
}

class _Agent implements AgentGateway {
  final events = StreamController<AgentEvent>.broadcast();
  late AgentCommand command;
  int sequence = 0;

  @override
  AgentRun start(AgentCommand value) {
    command = value;
    return AgentRun(events.stream, () {});
  }

  void fact(String type, String commandId, String text) {
    final number = ++sequence;
    events.add(
      AgentEvent(
        AgentEventKind.committed,
        ledger: LedgerEvent(
          eventId: 'event-$number',
          sessionId: command.sessionId,
          sequence: number,
          schemaVersion: 1,
          type: type,
          commandId: commandId,
          payload: {'text': text},
        ),
      ),
    );
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ConversationController _controller(_Voices voices, _Agent agent) =>
    ConversationController(
      entry: const ConversationEntry(
        sessionId: 'apology-committed',
        skillId: 'apology_master',
        opening: '后台配置开场',
      ),
      accountId: 'synthetic',
      gateway: agent,
      history: OfflineHistory(),
      apologyVoice: ApologyVoiceDependencies(
        port: voices,
        model: () => '1',
        modelName: () => '千问',
        modelNameFor: (id) => id == '2' ? '豆包' : '千问',
      ),
    );

void main() {
  test(
    'checking has no prompt available for delayed voice-host playback',
    () async {
      final voices = _Voices([])..waiting = Completer<List<ApologyVoice>>();
      final agent = _Agent();
      final controller = _controller(voices, agent);
      addTearDown(() async {
        controller.dispose();
        voices.waiting!.complete([]);
        await agent.events.close();
      });

      controller.choose(controller.state.activeOptionsId!, 0);
      expect(controller.apology!.voice.stage, ApologyVoiceStage.checking);
      expect(controller.apology!.voice.prompt, isNull);
      expect(controller.state.messages.map((m) => m.text), [
        ApologyVoicePolicy.consent,
        '确认使用',
      ]);
    },
  );

  for (final switchModel in [false, true]) {
    test(
      'opening facts and final reply preserve every prior choice: switch=$switchModel',
      () async {
        final voices = _Voices([
          ApologyVoice(
            switchModel ? '2' : '1',
            switchModel ? '豆包' : '千问',
            'asset',
          ),
        ]);
        final agent = _Agent();
        final controller = _controller(voices, agent);
        addTearDown(() async {
          controller.dispose();
          await agent.events.close();
        });
        controller.choose(controller.state.activeOptionsId!, 0);
        await _flush();
        if (switchModel) {
          controller.choose(controller.state.activeOptionsId!, 0);
          await _flush();
          controller.choose(controller.state.activeOptionsId!, 0);
          await _flush();
        }
        final before = controller.state.messages.toList();
        final selectedCards = before
            .where((m) => m.options.isNotEmpty)
            .toList();
        expect(selectedCards.every((m) => m.selectedOptionIndex == 0), isTrue);
        expect(controller.send('帮我向小王道歉'), isTrue);
        final command = agent.command;
        final openingCommand = 'initial-opening:${command.sessionId}';
        final openingFacts = <(String, String)>[
          if (command.initialAssistantPrompt != null)
            ('ASSISTANT_TURN_COMMITTED', command.initialAssistantPrompt!),
          if (command.initialUserSelection != null)
            ('USER_TURN_ACCEPTED', command.initialUserSelection!),
          ('ASSISTANT_TURN_COMMITTED', command.initialOpening!),
        ];
        for (final (type, text) in openingFacts) {
          agent.fact(type, openingCommand, text);
          await _flush();
          expect(
            controller.state.messages.first.text,
            ApologyVoicePolicy.consent,
          );
          expect(controller.state.messages[1].text, '确认使用');
        }
        agent.fact('USER_TURN_ACCEPTED', command.commandId, command.message!);
        await _flush();
        agent.events.add(
          const AgentEvent(AgentEventKind.finalResponse, text: '道歉任务已处理完毕。'),
        );
        await _flush();
        agent.fact('ASSISTANT_TURN_COMMITTED', command.commandId, '道歉任务已处理完毕。');
        agent.events.add(const AgentEvent(AgentEventKind.done));
        await _flush();

        final visible = controller.state.messages;
        expect(visible.map((m) => m.text), [
          ...before.map((m) => m.text),
          command.message,
          '道歉任务已处理完毕。',
        ]);
        for (final old in selectedCards) {
          final card = visible.singleWhere((m) => m.id == old.id);
          expect(card.selectedOptionIndex, old.selectedOptionIndex);
          expect(card.optionsLocked, isTrue);
          expect(controller.choose(card.id, 1), isFalse);
        }
        expect(controller.apology!.voice.prompt, isNull);
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform committed history retains selected style after page recreation',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final agent = _Agent();
        final controller = _controller(
          _Voices([const ApologyVoice('1', '千问', 'asset')]),
          agent,
        );
        addTearDown(() async {
          controller.dispose();
          await agent.events.close();
        });
        final cardId = controller.state.activeOptionsId!;
        controller.choose(cardId, 0);
        await tester.pump();
        final answerId = controller.state.messages[1].id;
        controller.send('帮我向小王道歉');
        final command = agent.command;
        agent.fact(
          'ASSISTANT_TURN_COMMITTED',
          'initial-opening:${command.sessionId}',
          command.initialOpening!,
        );
        agent.fact('USER_TURN_ACCEPTED', command.commandId, command.message!);
        agent.fact('ASSISTANT_TURN_COMMITTED', command.commandId, '道歉任务已处理完毕。');
        agent.events.add(const AgentEvent(AgentEventKind.done));
        await tester.pump();
        await tester.pump();

        Widget page() => MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: ConversationPage(
              state: controller.state,
              modelName: '千问',
              onClose: () {},
              onToggle: () {},
              onSend: (_) => false,
              onChoose: controller.choose,
              onRetry: () {},
              onNotice: (_) {},
              onModels: () {},
            ),
          ),
        );
        for (var rebuild = 0; rebuild < 2; rebuild++) {
          await tester.pumpWidget(page());
          await tester.pumpAndSettle();
          expect(find.text('后台配置开场'), findsNothing);
          expect(find.text(ApologyVoicePolicy.ready), findsOneWidget);
          final question = find.widgetWithText(
            NativeConversationTextBubble,
            ApologyVoicePolicy.consent,
          );
          final card = find.byKey(ValueKey('message:$cardId'));
          final answer = find.byKey(ValueKey('message:$answerId'));
          final ready = find.text(ApologyVoicePolicy.ready);
          final ending = find.text('道歉任务已处理完毕。');
          expect(
            tester.getBottomLeft(question).dy,
            lessThanOrEqualTo(tester.getTopLeft(card).dy),
          );
          expect(
            tester.getBottomLeft(card).dy,
            lessThanOrEqualTo(tester.getTopLeft(answer).dy),
          );
          expect(
            tester.getBottomLeft(answer).dy,
            lessThan(tester.getTopLeft(ready).dy),
          );
          expect(
            tester.getTopLeft(ready).dy,
            lessThan(tester.getTopLeft(ending).dy),
          );
          final selected = find.byKey(ValueKey('option:$cardId:0'));
          final material = tester.widget<Material>(
            find.ancestor(of: selected, matching: find.byType(Material)).first,
          );
          expect(material.color, const Color(0xFFEAF3FF));
          final shape = material.shape! as RoundedRectangleBorder;
          expect(shape.side.color, const Color(0xFF087FF5));
          expect(tester.widget<InkWell>(selected).onTap, isNull);
          expect(find.textContaining('正在查询'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }
}

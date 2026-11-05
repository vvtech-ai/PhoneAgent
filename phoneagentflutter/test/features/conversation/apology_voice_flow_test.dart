import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_voice_controller.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import '../../support/confirm_rendered_call.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';

class _Voices implements ApologyVoicePort {
  List<ApologyVoice> value = const [
    ApologyVoice('1', 'Qwen', 'synthetic-asset'),
  ];
  Completer<List<ApologyVoice>>? delayed;
  int confirms = 0;
  @override
  Future<List<ApologyVoice>> voices() async => delayed?.future ?? value;
  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {
    confirms++;
    value = [ApologyVoice(voice.modelId, voice.name, voice.assetId)];
  }
}

class _ApologyHistory extends OfflineHistory {
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final original = await super.restore(sessionId);
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: '道歉',
        status: 'ACTIVE',
        pinnedSkillId: 'apology_master',
        taskCallModelId: '1',
      ),
      ledger: original.ledger,
    );
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('normal consent shows the spoken ready text once', () async {
    final controller = ConversationController(
      entry: const ConversationEntry(
        sessionId: 'apology-ready-text',
        skillId: 'apology_master',
      ),
      accountId: 'synthetic',
      gateway: OfflineAgent(),
      history: OfflineHistory(),
      apologyVoice: ApologyVoiceDependencies(
        port: _Voices(),
        model: () => '1',
        modelName: () => 'Qwen',
      ),
    );
    addTearDown(controller.dispose);
    expect(controller.choose(controller.state.activeOptionsId!, 0), isTrue);
    await _flush();
    expect(controller.apology!.voice.stage, ApologyVoiceStage.ready);
    final spoken = controller.apology!.voice.prompt!.text;
    expect(spoken, ApologyVoicePolicy.ready);
    expect(controller.state.messages.map((m) => m.text), [
      ApologyVoicePolicy.consent,
      '确认使用',
      spoken,
    ]);
    expect(
      controller.state.messages.where((m) => m.text == spoken),
      hasLength(1),
    );
    expect(controller.state.activeOptionsId, isNull);
  });

  test(
    'confirmed apology keeps the old card, answer, and later result in order',
    () async {
      final port = _Voices()..delayed = Completer<List<ApologyVoice>>();
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'apology-entry',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: OfflineAgent(),
        history: OfflineHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: port,
          model: () => '1',
          modelName: () => 'Qwen',
        ),
      );
      addTearDown(controller.dispose);
      expect(controller.state.messages.single.text, ApologyVoicePolicy.consent);
      expect(controller.choose(controller.state.activeOptionsId!, 0), isTrue);
      expect(controller.apology!.voice.stage, ApologyVoiceStage.checking);
      expect(controller.state.messages, hasLength(2));
      expect(controller.state.messages[0].text, ApologyVoicePolicy.consent);
      expect(controller.state.messages[0].optionsLocked, isTrue);
      expect(controller.state.messages[0].selectedOptionIndex, 0);
      expect(controller.state.messages[1].role, MessageRole.user);
      expect(controller.state.messages[1].text, '确认使用');
      expect(controller.state.activeOptionsId, isNull);
      expect(
        controller.state.messages.any((m) => m.text.contains('正在查询')),
        isFalse,
      );

      port.delayed!.complete(const []);
      await _flush();
      expect(controller.apology!.voice.stage, ApologyVoiceStage.needsVoice);
      expect(controller.state.messages, hasLength(3));
      expect(controller.state.messages.map((m) => m.role), [
        MessageRole.assistant,
        MessageRole.user,
        MessageRole.assistant,
      ]);
      expect(controller.state.messages[2].text, contains('没有您的可用克隆音色'));
      expect(controller.state.activeOptionsId, controller.state.messages[2].id);
      expect(controller.choose(controller.state.messages[0].id, 1), isFalse);
    },
  );
  test('typed consent echoes once and keeps its selected card', () async {
    final port = _Voices()..delayed = Completer<List<ApologyVoice>>();
    final controller = ConversationController(
      entry: const ConversationEntry(
        sessionId: 'apology-typed',
        skillId: 'apology_master',
      ),
      accountId: 'synthetic',
      gateway: OfflineAgent(),
      history: OfflineHistory(),
      apologyVoice: ApologyVoiceDependencies(
        port: port,
        model: () => '1',
        modelName: () => 'Qwen',
      ),
    );
    addTearDown(controller.dispose);
    expect(controller.send('确认使用'), isTrue);
    expect(controller.send('确认使用'), isTrue);
    expect(controller.state.messages.map((m) => m.text), [
      ApologyVoicePolicy.consent,
      '确认使用',
    ]);
    expect(controller.state.messages.first.selectedOptionIndex, 0);
    port.delayed!.complete(const []);
    await _flush();
  });
  test(
    'selected clone model record stays ordered and becomes the durable opening',
    () async {
      final port = _Voices()
        ..value = const [ApologyVoice('2', '豆包', 'synthetic-asset')];
      final gateway = OfflineAgent();
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'apology-model-choice',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: OfflineHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: port,
          model: () => '1',
          modelName: () => 'Qwen',
          modelNameFor: (id) => id == '2' ? '豆包' : id,
        ),
      );
      addTearDown(controller.dispose);
      expect(controller.choose(controller.state.activeOptionsId!, 0), isTrue);
      await _flush();
      final modelPrompt = controller.state.activeOptionsId!;
      expect(controller.choose(modelPrompt, 0), isTrue);
      await _flush();
      expect(controller.apology!.voice.stage, ApologyVoiceStage.modelConsent);
      expect(controller.choose(controller.state.activeOptionsId!, 0), isTrue);
      await _flush();
      expect(controller.state.messages, hasLength(8));
      expect(controller.state.messages[0].text, ApologyVoicePolicy.consent);
      expect(controller.state.messages[1].text, '确认使用');
      expect(controller.state.messages[2].text, contains('没有您的可用克隆音色'));
      expect(controller.state.messages[2].options, isEmpty);
      expect(controller.state.messages[3].options, hasLength(2));
      expect(controller.state.messages[3].optionsLocked, isTrue);
      expect(controller.state.messages[3].optionsTitleVisible, isFalse);
      expect(controller.state.messages[3].selectedOptionIndex, 0);
      expect(controller.state.messages[4].text, '已选择：豆包');
      expect(controller.state.messages[4].role, MessageRole.user);
      expect(
        controller.state.messages[7].text,
        contains('已切换为豆包，本次电话使用您的克隆音色。'),
      );
      expect(controller.send('给联系人打电话'), isTrue);
      expect(
        gateway.commands.single.initialOpening,
        controller.state.messages
            .firstWhere(
              (message) => message.id.startsWith('local:apology:voice-ready:'),
            )
            .text,
      );
      expect(
        gateway.commands.single.initialAssistantPrompt,
        controller.state.messages[2].text,
      );
      expect(gateway.commands.single.initialUserSelection, '已选择：豆包');
      final messages = controller.state.messages;
      final choiceIndex = messages.indexWhere(
        (message) =>
            message.role == MessageRole.user && message.text == '已选择：豆包',
      );
      final readyIndex = messages.indexWhere(
        (message) => message.text.contains('已切换为豆包，本次电话使用您的克隆音色。'),
      );
      final userIndex = messages.lastIndexWhere(
        (message) => message.role == MessageRole.user,
      );
      expect(choiceIndex, greaterThanOrEqualTo(0));
      expect(readyIndex, greaterThan(choiceIndex));
      expect(userIndex, greaterThanOrEqualTo(0));
      expect(readyIndex, lessThan(userIndex));
    },
  );

  test(
    'restored pinned apology preserves server voice until an explicit model switch',
    () async {
      final port = _Voices();
      final gateway = OfflineAgent();
      var model = '3';
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 's', restore: true),
        accountId: 'synthetic',
        gateway: gateway,
        history: _ApologyHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: port,
          model: () => model,
          modelName: () => model,
        ),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(controller.apology, isNotNull);
      expect(controller.apology!.voice.modelId, '1');
      expect(controller.apology!.voice.prompt, isNull);
      expect(controller.apology!.voice.blocked, isFalse);
      port.value = const [ApologyVoice('3', '第三模型', 'third')];
      controller.apology!.voice.modelChanged('3');
      await _flush();
      expect(controller.apology!.voice.stage, ApologyVoiceStage.modelConsent);
      controller.send('确认使用');
      await _flush();
      expect(controller.apology!.voice.selection!.modelId, '3');
    },
  );
  testWidgets(
    'model switch during confirmation countdown pauses without consuming the call',
    (tester) async {
      final port = _Voices();
      final flow = PreviewCallFlow(CallFlowScenario.single);
      var model = '1';
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'mock-call-flow',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: flow,
        history: flow,
        callAdmission: flow.admission,
        callSessions: flow,
        apologyVoice: ApologyVoiceDependencies(
          port: port,
          model: () => model,
          modelName: () => model,
        ),
      );
      addTearDown(controller.dispose);
      controller.send('确认使用');
      await tester.pump();
      expect(controller.send('合成道歉请求'), isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(controller.state.phase, ConversationPhase.ready);
      confirmRenderedCall(controller);
      port.value = const [ApologyVoice('2', '豆包', 'second')];
      model = '2';
      controller.apology!.voice.modelChanged(model);
      await tester.pump(const Duration(seconds: 2));
      expect(flow.commands, hasLength(1));
      expect(controller.calls!.snapshot.call, isNull);
      controller.send('确认使用');
      await tester.pump();
      confirmRenderedCall(controller);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(flow.commands, hasLength(2));
      expect(flow.commands.last.callVoiceSelection?['modelId'], '2');
      controller.close();
    },
  );
  test(
    'confirmed apology resumes held input and sends session voice without global voice activation',
    () async {
      final port = _Voices();
      final gateway = OfflineAgent();
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 's',
          skillId: 'apology_master',
          opening: '旧开场',
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: OfflineHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: port,
          model: () => '1',
          modelName: () => 'Qwen',
        ),
      );
      addTearDown(controller.dispose);
      controller.send('昨天迟到了，帮我向伴侣道歉', source: ContactInputSource.asr);
      expect(gateway.commands, isEmpty);
      final prompt = controller.state.activeOptionsId!;
      expect(controller.choose(prompt, 0), isTrue);
      await _flush();
      final command = gateway.commands.single.toJson();
      expect(command['initialSkillId'], 'apology_master');
      expect(command['initialOpening'], ApologyVoicePolicy.ready);
      expect(command['callVoiceSelection'], {
        'modelId': '1',
        'providerAssetId': 'synthetic-asset',
      });
      expect(command['message'], '昨天迟到了，帮我向伴侣道歉');
      expect(controller.inputSource, ContactInputSource.asr);
      expect(port.confirms, 0);
      final selected = controller.state.messages.firstWhere(
        (message) => message.id == prompt,
      );
      expect(selected.optionsLocked, isTrue);
      expect(selected.selectedOptionIndex, 0);
      expect(
        controller.state.messages.where(
          (message) =>
              message.role == MessageRole.user && message.text == '确认使用',
        ),
        hasLength(1),
      );
      expect(
        controller.apology!.voice.prompt,
        isNull,
        reason:
            'a submitted task cannot replay a stale local ready prompt later',
      );
      expect(
        controller.choose(prompt, 0),
        isFalse,
        reason: 'old consent cannot be reused',
      );
    },
  );

  test('decline prevents all subsequent task submissions', () async {
    final gateway = OfflineAgent();
    final controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's', skillId: 'apology_master'),
      accountId: 'synthetic',
      gateway: gateway,
      history: OfflineHistory(),
    );
    addTearDown(controller.dispose);
    controller.choose(controller.state.activeOptionsId!, 1);
    await _flush();
    controller.send('直接拨打给对方');
    expect(gateway.commands, isEmpty);
    expect(controller.apology!.voice.stage, ApologyVoiceStage.stopped);
    expect(controller.state.messages.last.text, contains('已停止'));
  });

  test(
    'changing models requires renewed consent, preserves pending tool and uses fresh voice',
    () async {
      final port = _Voices();
      final gateway = OfflineAgent();
      var model = '1';
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 's',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: OfflineHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: port,
          model: () => model,
          modelName: () => model,
        ),
      );
      addTearDown(controller.dispose);
      controller.send('确认使用');
      await _flush();
      controller.state = controller.state.copy(
        pendingToolCallId: 'server-tool',
      );
      port.value = const [ApologyVoice('2', '豆包', 'synthetic-new')];
      model = '2';
      controller.apology!.voice.modelChanged(model);
      await _flush();
      expect(controller.apology!.voice.stage, ApologyVoiceStage.modelConsent);
      controller.send('确认使用');
      await _flush();
      expect(controller.state.pendingToolCallId, 'server-tool');
      expect(controller.apology!.voice.selection!.modelId, '2');
    },
  );

  test(
    'candidate requires explicit confirmation and requery; stale query cannot replace new model',
    () async {
      final port = _Voices()
        ..value = const [
          ApologyVoice('1', 'Qwen', 'candidate', candidate: true),
        ];
      var model = '1';
      late ApologyVoiceController controller;
      controller = ApologyVoiceController(
        port: port,
        currentModel: () => model,
        currentModelName: () => model,
        isCurrent: () => true,
        present: (_) {},
        interrupt: () {},
        cancelTask: () async {},
        resume: (_) {},
      );
      addTearDown(controller.close);
      controller.begin();
      controller.choose('confirm');
      await _flush();
      expect(controller.stage, ApologyVoiceStage.modelConsent);
      expect(port.confirms, 0);
      controller.choose('confirm');
      await _flush();
      expect(port.confirms, 1);
      expect(controller.selection!.candidate, isFalse);
      final old = Completer<List<ApologyVoice>>();
      port.delayed = old;
      model = '2';
      controller.modelChanged(model);
      port.delayed = null;
      port.value = const [ApologyVoice('3', '第三模型', 'third', active: true)];
      model = '3';
      controller.modelChanged(model);
      await _flush();
      old.complete(const [ApologyVoice('2', '旧模型', 'late', active: true)]);
      await _flush();
      expect(controller.selection!.modelId, '3');
    },
  );

  test('call confirmation includes task voice inside actionPayload', () {
    const command = AgentCommand(
      sessionId: 's',
      userId: 'u',
      commandId: 'c',
      idempotencyKey: 'c',
      traceId: 't',
      actionId: 'confirm_call',
      actionPayload: {'pendingToolCallId': 'tool'},
    );
    final wire = command.withCallVoiceSelection(const {
      'modelId': '1',
      'providerAssetId': 'asset',
    }).toJson();
    expect(wire['actionPayload'], {
      'pendingToolCallId': 'tool',
      'callVoiceSelection': {'modelId': '1', 'providerAssetId': 'asset'},
    });
  });
}

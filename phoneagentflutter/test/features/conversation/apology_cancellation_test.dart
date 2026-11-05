import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';

class _Voices implements ApologyVoicePort {
  @override
  Future<List<ApologyVoice>> voices() async => const [
    ApologyVoice('1', '模型1', 'synthetic'),
  ];
  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {}
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  final streams = <StreamController<AgentEvent>>[];
  final cancelled = <int>[];
  @override
  AgentRun start(AgentCommand command) {
    final index = commands.length;
    commands.add(command);
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () => cancelled.add(index));
  }
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'declining a started apology cancels old delivery and awaits matching server acknowledgement',
    () async {
      final gateway = _Gateway();
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
          port: _Voices(),
          model: () => model,
          modelName: () => model,
        ),
      );
      addTearDown(controller.dispose);
      controller.send('确认使用');
      await flush();
      controller.send('开始本次道歉');
      model = '2';
      controller.apology!.voice.modelChanged(model);
      await flush();
      controller.send('不使用');
      await flush();
      expect(gateway.commands.last.actionId, 'cancel');
      expect(gateway.cancelled, contains(0));
      final cancel = gateway.commands.last;
      gateway.streams.last.add(
        AgentEvent(
          AgentEventKind.status,
          eventName: 'task_cancelled',
          sessionId: 's',
          payload: {'commandId': cancel.commandId},
        ),
      );
      await gateway.streams.last.close();
      await flush();
      expect(controller.state.phase, ConversationPhase.ready);
      expect(controller.state.messages.last.text, '好的，已停止本次道歉任务。');
      gateway.streams.first.add(
        const AgentEvent(AgentEventKind.text, text: '迟到的旧轮次'),
      );
      await gateway.streams.first.close();
      await flush();
      expect(controller.state.messages.any((m) => m.text == '迟到的旧轮次'), isFalse);
    },
  );
}

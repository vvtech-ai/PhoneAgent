import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../support/confirm_rendered_call.dart';

class _HeldCall extends PreviewCallFlow {
  _HeldCall() : super(CallFlowScenario.single);
  final execution = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) {
    if (command.actionId != 'confirm_call') return super.start(command);
    commands.add(command);
    return AgentRun(execution.stream, () {});
  }

  void progress() => execution.add(
    const AgentEvent(
      AgentEventKind.toolCard,
      payload: {
        'toolName': 'make_call',
        'methodLabel': 'make_call()',
        'result': '合成提交中',
      },
    ),
  );
}

void main() {
  testWidgets(
    'physical end retires progress before SSE ends, then close cleans late progress',
    (tester) async {
      final ports = _HeldCall();
      var id = 0;
      final c = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        nextId: () => 'command-${id++}',
      );
      addTearDown(c.dispose);
      c.send('合成需求');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      confirmRenderedCall(c);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      ports.progress();
      await tester.pump();
      expect(c.state.messages.any((m) => m.toolCard != null), isTrue);
      ports.ended = true;
      ports.outcomeReady = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(c.state.phase, ConversationPhase.ready);
      expect(c.state.messages.any((m) => m.receipt != null), isTrue);
      expect(c.state.messages.any((m) => m.confirmation != null), isTrue);
      expect(c.state.messages.where((m) => m.toolCard != null), isEmpty);
      ports.progress();
      await tester.pump();
      expect(c.state.messages.where((m) => m.toolCard != null), isEmpty);
      await ports.execution.close();
      await tester.pump();
      await tester.pump();
      expect(c.state.messages.where((m) => m.toolCard != null), isEmpty);
      expect(ports.commands, hasLength(2));
      expect(ports.hangups, 0);
      c.close();
    },
  );
}

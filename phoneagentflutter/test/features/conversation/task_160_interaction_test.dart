import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../support/confirm_rendered_call.dart';

class _Events extends PreviewCallFlow {
  _Events() : super(CallFlowScenario.single);
  final streams = <StreamController<AgentEvent>>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () {});
  }
}

void main() {
  testWidgets(
    'new question without pending id invalidates scheduled confirmation',
    (tester) async {
      final ports = _Events();
      final c = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
      );
      addTearDown(c.dispose);
      c.send('合成任务');
      ports.streams.single.add(
        const AgentEvent(
          AgentEventKind.signal,
          sessionId: 's',
          payload: {
            'type': 'MAKE_CALL_REQUEST',
            'pendingToolCallId': 'call',
            'callSpec': {'targetName': '合成目标', 'phoneNumber': '10086'},
          },
        ),
      );
      ports.streams.single.add(const AgentEvent(AgentEventKind.done));
      await tester.pump();
      markCallCardPresented(c);
      expect(c.send('确认拨打'), isTrue);
      ports.streams.single.add(
        const AgentEvent(
          AgentEventKind.signal,
          sessionId: 's',
          payload: {
            'type': 'ASK_USER',
            'questions': {'title': '请补充时间', 'items': []},
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(ports.commands, hasLength(1));
      expect(c.calls!.snapshot.launch.request, isNull);
      c.close();
      for (final stream in ports.streams) {
        unawaited(stream.close());
      }
      await tester.pump();
    },
  );
}

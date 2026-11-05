import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_event_flow.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

AgentEvent _decode(String frame, String type) =>
    const AgentEventDecoder().decode(
      SseFrame(
        frame,
        jsonEncode({
          'sessionId': 'session',
          'type': type,
          'text': '准备前言',
          'pendingToolCallId': 'pending-$type',
          if (type == 'ASK_USER')
            'questions': {'title': '是否查询联系人？', 'items': []},
          if (type == 'SHOW_OPTIONS')
            'options': {
              'title': '请选择',
              'items': [
                {'label': '合成目标', 'phone': '10086'},
              ],
            },
          if (type == 'MAKE_CALL_REQUEST')
            'callSpec': {'targetName': '合成目标', 'phoneNumber': '10086'},
        }),
      ),
    );

class _Flow {
  _Flow() {
    flow = ConversationEventFlow(
      read: () => state,
      write: (value) => state = value,
      current: (generation) => generation == 1,
      messages: ConversationMessageStore(),
      batch: BatchProgressTracker(),
      observed: (event, _) => observed.add(event),
      commit: (_, __) async => true,
      signal: (event, command, generation) async => interactions.add(event),
      status: (_, __, ___) {},
      done: (_, __) async {},
      failed: (_, __) {},
      batchFinished: () {},
      publish: () {},
      assistant: (_, text) => replies.add(text),
      suppressInteractions: () => stopped,
    );
  }
  var state = const ConversationState(
    entry: ConversationEntry(sessionId: 'session'),
  );
  final interactions = <AgentEvent>[], observed = <AgentEvent>[];
  final replies = <String>[];
  var stopped = false;
  late final ConversationEventFlow flow;
  Future<void> accept(String frame, String type) =>
      flow.accept(_decode(frame, type), 'command', 1);
}

class _Gateway extends PreviewCallFlow {
  _Gateway() : super(CallFlowScenario.single);
  final streams = <StreamController<AgentEvent>>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () => unawaited(stream.close()));
  }
}

void main() {
  for (final type in ['ASK_USER', 'SHOW_OPTIONS', 'MAKE_CALL_REQUEST']) {
    test('raw final $type reaches the existing interaction owner', () async {
      final f = _Flow();
      await f.accept('final', type);
      expect(f.interactions, hasLength(1));
      expect(f.interactions.single.payload['type'], type);
      expect(
        f.interactions.single.payload['pendingToolCallId'],
        'pending-$type',
      );
      expect(f.replies, isEmpty, reason: 'interactive title owns visible text');
    });
    test(
      'signal plus final $type executes and narrates the interaction once',
      () async {
        final f = _Flow();
        await f.accept('signal', type);
        await f.accept('final', type);
        expect(f.interactions, hasLength(1));
        expect(f.observed, hasLength(1));
        expect(f.replies, isEmpty);
      },
    );
    test(
      'raw final $type preserves the real conversation interaction contract',
      () async {
        final ports = _Gateway();
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'session'),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callAdmission: ports.admission,
          callSessions: ports,
        );
        addTearDown(() {
          controller.dispose();
          for (final stream in ports.streams) {
            unawaited(stream.close());
          }
        });
        controller.send('合成任务');
        ports.streams.single.add(_decode('final', type));
        ports.streams.single.add(const AgentEvent(AgentEventKind.done));
        await Future<void>.delayed(Duration.zero);
        if (type == 'MAKE_CALL_REQUEST') {
          expect(
            controller.calls!.snapshot.launch.request?.toolId,
            'pending-$type',
          );
          expect(
            controller.state.messages.where((m) => m.confirmation != null),
            hasLength(1),
          );
          expect(
            ports.commands,
            hasLength(1),
            reason: 'a final card cannot dial without user confirmation',
          );
        } else {
          expect(controller.state.pendingToolCallId, 'pending-$type');
          if (type == 'ASK_USER') {
            expect(
              controller.state.messages.any((m) => m.text == '是否查询联系人？'),
              isTrue,
            );
            expect(controller.send('可以'), isTrue);
            expect(ports.commands.last.message, '可以');
          } else {
            expect(
              controller.choose(controller.state.activeOptionsId!, 0),
              isTrue,
            );
            expect(ports.commands.last.message, '第 1 个');
          }
          expect(ports.commands.last.pendingToolCallId, 'pending-$type');
          expect(ports.commands.last.actionId, isNull);
        }
        controller.close();
      },
    );
  }
  test(
    'stopped turn cannot execute or narrate a late final interaction',
    () async {
      final f = _Flow()..stopped = true;
      await f.accept('final', 'MAKE_CALL_REQUEST');
      expect(f.interactions, isEmpty);
      expect(f.observed, isEmpty);
      expect(f.replies, isEmpty);
    },
  );
}

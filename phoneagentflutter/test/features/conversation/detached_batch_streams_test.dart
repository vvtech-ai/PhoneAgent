import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_event_stream.dart';
import 'package:phone_agent/features/conversation/presentation/controller/detached_batch_streams.dart';

void main() {
  late _Gateway gateway;
  late ConversationEventStream stream;
  late DetachedBatchStreams detached;
  late List<AgentEvent> visible;
  int finishes = 0;
  final command = AgentCommand(
    sessionId: 's',
    userId: 'synthetic',
    commandId: 'c',
    idempotencyKey: 'k',
    traceId: 't',
  );
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  void start({Future<void> Function(AgentEvent)? accept}) => stream.start(
    command,
    isCurrent: () => true,
    accept: accept ?? (e) async => visible.add(e),
    onError: (_) {},
    onDone: () {},
  );
  setUp(() {
    gateway = _Gateway();
    stream = ConversationEventStream(gateway);
    visible = [];
    finishes = 0;
    detached = DetachedBatchStreams(onFinished: () => finishes++);
  });
  tearDown(() {
    detached.close();
    stream.cancel();
  });
  test(
    'detached stream drains without UI or tool callbacks until done',
    () async {
      start();
      expect(detached.retain(stream), isTrue);
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.signal,
          payload: {'type': 'REQUEST_PERMISSION'},
        ),
      );
      await flush();
      expect(visible, isEmpty);
      expect(detached.hasActive, isTrue);
      expect(gateway.cancelled, 0);
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.finalResponse,
          payload: {'type': 'BATCH_CALL_RESULT'},
        ),
      );
      await flush();
      expect(detached.hasActive, isFalse);
      expect(detached.count, 1);
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(detached.count, 0);
      expect(finishes, 1);
      expect(gateway.cancelled, 1);
    },
  );
  test('network error and duplicate termination release once', () async {
    start();
    detached.retain(stream);
    gateway.events.addError(AgentTransportFailure.network);
    gateway.events.add(const AgentEvent(AgentEventKind.done));
    await flush();
    expect(detached.count, 0);
    expect(finishes, 1);
    expect(visible, isEmpty);
  });
  test(
    'account close cancels all owned runs and does not refresh a new account',
    () async {
      start();
      detached.retain(stream);
      detached.close();
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(gateway.cancelled, 1);
      expect(finishes, 0);
      expect(detached.retain(stream), isFalse);
    },
  );
  test(
    'mismatched session cannot deliver old data even while detached',
    () async {
      start();
      detached.retain(stream);
      gateway.events.add(
        const AgentEvent(AgentEventKind.status, sessionId: 'other'),
      );
      await flush();
      expect(detached.count, 0);
      expect(finishes, 1);
      expect(visible, isEmpty);
    },
  );
  test(
    'pending callback may finish but queued events use detached delivery',
    () async {
      final gate = Completer<void>();
      start(
        accept: (event) async {
          visible.add(event);
          await gate.future;
        },
      );
      gateway.events.add(const AgentEvent(AgentEventKind.committed));
      await flush();
      detached.retain(stream);
      gateway.events.add(const AgentEvent(AgentEventKind.signal));
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      gate.complete();
      await flush();
      expect(visible, hasLength(1));
      expect(finishes, 1);
    },
  );
  test('normal stream closes without retaining a finished run', () async {
    start();
    await gateway.events.close();
    await flush();
    expect(detached.retain(stream), isFalse);
    expect(detached.count, 0);
  });
}

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  int cancelled = 0;
  @override
  AgentRun start(AgentCommand command) =>
      AgentRun(events.stream, () => cancelled++);
}

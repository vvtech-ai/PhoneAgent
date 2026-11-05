import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_failure.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/recovery/batch_entitlement_refresh_gateway.dart';

const _command = AgentCommand(
  sessionId: 'session',
  userId: 'synthetic',
  commandId: 'command',
  idempotencyKey: 'intent',
  traceId: 'trace',
);

class _Gateway implements AgentGateway {
  final source = StreamController<AgentEvent>();
  int starts = 0, cancellations = 0;
  @override
  AgentRun start(AgentCommand command) {
    starts++;
    expect(command, same(_command));
    return AgentRun(source.stream, () => cancellations++);
  }
}

AgentEvent _failure(String code, {String key = 'errorCode'}) =>
    const AgentEventDecoder().decode(
      SseFrame(
        'task_failed',
        jsonEncode({
          'sessionId': 'session',
          'commandId': 'command',
          'data': {key: code},
        }),
      ),
    );

void main() {
  for (final code in [
    'BATCH_CONTACT_LIMIT',
    'BATCH_CONCURRENCY_LIMIT',
    'BATCH_ENTITLEMENT_LIMIT',
  ]) {
    test(
      '$code refreshes once and preserves original assistant event',
      () async {
        final source = _Gateway();
        var refreshes = 0;
        final gateway = BatchEntitlementRefreshGateway(
          source,
          refresh: () => refreshes++,
          isCurrent: () => true,
        );
        final event = _failure(code);
        final output = gateway.start(_command).events.toList();
        source.source
          ..add(event)
          ..add(event);
        await source.source.close();
        expect(await output, [same(event), same(event)]);
        expect(event.kind, AgentEventKind.finalResponse);
        expect(event.text, contains('会员'));
        expect(refreshes, 1);
        expect(source.starts, 1);
        gateway.close();
      },
    );
  }

  test('ordinary reply, points and unrelated failure do not refresh', () async {
    final source = _Gateway();
    var refreshes = 0;
    final gateway = BatchEntitlementRefreshGateway(
      source,
      refresh: () => refreshes++,
      isCurrent: () => true,
    );
    final events = [
      const AgentEvent(AgentEventKind.text, text: 'BATCH_CONTACT_LIMIT'),
      _failure('POINTS_INSUFFICIENT'),
      _failure('CALL_CONCURRENCY_LIMIT'),
      _failure('ENTITLEMENT_DENIED'),
    ];
    final output = gateway.start(_command).events.toList();
    events.forEach(source.source.add);
    await source.source.close();
    expect(await output, events);
    expect(refreshes, 0);
    gateway.close();
  });

  for (final inactive in ['cancel', 'close', 'accountChanged']) {
    test('$inactive prevents late refresh without swallowing events', () async {
      final source = _Gateway();
      var refreshes = 0, current = true;
      final gateway = BatchEntitlementRefreshGateway(
        source,
        refresh: () => refreshes++,
        isCurrent: () => current,
      );
      final run = gateway.start(_command);
      final output = run.events.toList();
      if (inactive == 'cancel') run.cancel();
      if (inactive == 'close') gateway.close();
      if (inactive == 'accountChanged') current = false;
      final event = _failure('BATCH_CONTACT_LIMIT', key: 'code');
      source.source.add(event);
      await source.source.close();
      expect(await output, [same(event)]);
      expect(refreshes, 0);
      expect(source.cancellations, inactive == 'cancel' ? 1 : 0);
      gateway.close();
    });
  }

  test('typed error is forwarded with original stack and no retry', () async {
    final source = _Gateway();
    var refreshes = 0;
    final gateway = BatchEntitlementRefreshGateway(
      source,
      refresh: () => refreshes++,
      isCurrent: () => true,
    );
    const error = AgentFailure(errorCode: 'BATCH_CONTACT_LIMIT');
    final stack = StackTrace.current;
    Object? received;
    StackTrace? receivedStack;
    final done = Completer<void>();
    gateway
        .start(_command)
        .events
        .listen(
          (_) {},
          onError: (Object e, StackTrace s) {
            received = e;
            receivedStack = s;
          },
          onDone: done.complete,
        );
    source.source.addError(error, stack);
    await source.source.close();
    await done.future;
    expect(received, same(error));
    expect(receivedStack, same(stack));
    expect(refreshes, 1);
    expect(source.starts, 1);
    gateway.close();
  });

  test('refresh failure does not replace original denial', () async {
    final source = _Gateway();
    final gateway = BatchEntitlementRefreshGateway(
      source,
      refresh: () => throw StateError('refresh unavailable'),
      isCurrent: () => true,
    );
    final event = _failure('BATCH_CONTACT_LIMIT', key: 'code');
    final output = gateway.start(_command).events.toList();
    source.source.add(event);
    await source.source.close();
    expect(await output, [same(event)]);
    gateway.close();
  });
}

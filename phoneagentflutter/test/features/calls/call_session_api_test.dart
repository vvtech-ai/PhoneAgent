import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/calls/data/api_call_session_repository.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  late SyntheticAccountApi server;
  late ApiCallSessionRepository repository;
  setUp(() {
    server = SyntheticAccountApi()..data = _snapshot();
    repository = ApiCallSessionRepository(server.api, 'a');
  });
  tearDown(() => server.api.close());

  test(
    'status posts bound owner and precise target, preserves transport fields',
    () async {
      final snapshot = await repository.status(
        CallSessionTarget(taskId: ' task '),
      );
      final request = server.requests.single;
      expect(request.uri.path, '/api/assistant/realtime/call/session/status');
      expect(request.method, 'POST');
      expect(request.data, {'userId': 'a', 'taskId': 'task'});
      expect(request.headers['X-Account-Id'], 'a');
      expect(snapshot.callId, 'call');
      expect(snapshot.dialogueDetail, 'assistant: 合成文本');
      expect(snapshot.resultText, '合成结果');
      expect(snapshot.appRtcRequired, isTrue);
    },
  );

  test('hangup is explicit one-shot and uses original reason', () async {
    await repository.hangUp(CallSessionTarget(callId: 'call'));
    expect(
      server.requests.single.uri.path,
      '/api/assistant/realtime/call/hangup',
    );
    expect(server.requests.single.data, {
      'userId': 'a',
      'callId': 'call',
      'reason': '用户在 App 端挂断通话',
    });
    server.status = 500;
    await expectLater(
      repository.hangUp(CallSessionTarget(callId: 'call')),
      throwsA(ApiFailure.rejected),
    );
    expect(server.requests.length, 2);
  });

  test('launchReady requires explicit boolean proof from the server', () async {
    for (final proof in [null, false, 'true', 1, true]) {
      server.data = {..._snapshot(), if (proof != null) 'launchReady': proof};
      final snapshot = await repository.status(
        CallSessionTarget(taskId: 'task'),
      );
      expect(snapshot.launchReady, proof == true);
    }
  });

  test('empty target and monitor without call id make no requests', () async {
    await expectLater(
      repository.status(CallSessionTarget()),
      throwsA(ApiFailure.invalidResponse),
    );
    await expectLater(
      repository.hangUp(CallSessionTarget()),
      throwsA(ApiFailure.invalidResponse),
    );
    await expectLater(
      repository.monitorTicket(CallSessionTarget(taskId: 'task')),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(server.requests, isEmpty);
  });

  test('mismatched task/call and invalid flags reject response', () async {
    for (final change in [
      {'taskId': 'other'},
      {'callId': 'other'},
      {'callId': ''},
      {'backendCallEnabled': 'true'},
      {'callState': ''},
      {'dialogueDetail': 4},
    ]) {
      server.data = {..._snapshot(), ...change};
      await expectLater(
        repository.status(CallSessionTarget(taskId: 'task', callId: 'call')),
        throwsA(ApiFailure.invalidResponse),
      );
    }
  });

  test(
    'backend NOT_FOUND returns empty callId for known and pending calls',
    () async {
      server.data = {..._snapshot(), 'callId': '', 'callState': 'NOT_FOUND'};
      expect(
        (await repository.status(CallSessionTarget(taskId: 'task'))).isNotFound,
        isTrue,
      );
      expect(
        (await repository.status(
          CallSessionTarget(taskId: 'task', callId: 'call'),
        )).isNotFound,
        isTrue,
      );
    },
  );

  test('unknown transport status is retained, not inferred terminal', () async {
    server.data = {..._snapshot(), 'callState': 'FUTURE_STATUS'};
    final value = await repository.status(CallSessionTarget(taskId: 'task'));
    expect(value.callState, 'FUTURE_STATUS');
    expect(value.isTerminal, isFalse);
  });

  test(
    'monitor credentials retain format, default only absent fields and redact toString',
    () async {
      server.data = {
        'ticket': 'synthetic-ticket',
        'expiresAt': '2030-01-01T00:00:00Z',
      };
      final token = await repository.monitorTicket(
        CallSessionTarget(callId: 'call'),
      );
      expect(token.sampleRate, 16000);
      expect(token.channels, 1);
      expect(token.encoding, 'PCM_S16LE');
      expect(token.toString(), isNot(contains('synthetic-ticket')));
      expect(server.requests.single.uri.path, '/api/agent-calls/monitor/token');
      for (final change in [
        {'ticket': ''},
        {'expiresAt': 'bad'},
        {'channels': 0},
        {'sampleRate': '16000'},
      ]) {
        server.data = {
          'ticket': 'synthetic-ticket',
          'expiresAt': '2030-01-01T00:00:00Z',
          ...change,
        };
        await expectLater(
          repository.monitorTicket(CallSessionTarget(callId: 'call')),
          throwsA(ApiFailure.invalidResponse),
        );
      }
    },
  );

  test('old repository refuses a new account before network', () async {
    server.credentials = const AccountCredentials('b', 'synthetic-b', 2);
    await expectLater(
      repository.status(CallSessionTarget(taskId: 'task')),
      throwsA(ApiFailure.sessionChanged),
    );
    expect(server.requests, isEmpty);
  });

  test(
    'account switch during an outstanding HTTP response rejects late data',
    () async {
      final received = Completer<void>(), release = Completer<void>();
      server.beforeResponse = (_) async {
        received.complete();
        await release.future;
      };
      final pending = repository.status(CallSessionTarget(taskId: 'task'));
      await received.future;
      expect(server.requests.length, 1);
      server.credentials = const AccountCredentials('b', 'synthetic-b', 2);
      release.complete();
      await expectLater(pending, throwsA(ApiFailure.sessionChanged));
      expect(server.requests.length, 1);
    },
  );
}

Map<String, Object?> _snapshot() => {
  'callId': 'call',
  'taskId': 'task',
  'callState': 'CONNECTED',
  'handoffMode': 'AI_ACTIVE',
  'backendCallEnabled': true,
  'handoffSupported': false,
  'appRtcRequired': true,
  'dialogueDetail': 'assistant: 合成文本',
  'resultText': '合成结果',
  'updatedAt': '2026-09-16T10:00:00',
};

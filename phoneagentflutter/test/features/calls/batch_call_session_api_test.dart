import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/calls/data/api_call_session_repository.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  late SyntheticAccountApi server;
  setUp(() => server = SyntheticAccountApi());
  tearDown(() => server.api.close());
  Map<String, Object?> snapshot(Object? ready) => {
    'taskId': 'batch',
    'callId': 'physical',
    'callState': 'RINGING',
    'backendCallEnabled': true,
    'handoffSupported': false,
    'appRtcRequired': false,
    if (ready != null) 'launchReady': ready,
  };

  test(
    'batch observation binds session, batch and attempt and keeps readiness strict',
    () async {
      final repo = ApiCallSessionRepository(
        server.api,
        'owner',
      ).forBatch('session', 'batch', 'attempt');
      for (final ready in [null, false, 'true', 1, true]) {
        server.data = snapshot(ready);
        final result = await repo.status(
          CallSessionTarget(taskId: 'batch', attemptId: 'attempt'),
        );
        expect(result.launchReady, ready == true);
        final request = server.requests.last;
        expect(
          request.uri.path,
          '/api/agent/conversations/session/batch/batch/call/attempt/status',
        );
        expect(request.method, 'GET');
        expect(request.uri.queryParameters['userId'], 'owner');
      }
      expect(
        server.requests.any(
          (r) => r.uri.path.endsWith('begin') || r.uri.path.endsWith('confirm'),
        ),
        isFalse,
      );
    },
  );
  test('cross-batch snapshot is rejected', () async {
    server.data = {...snapshot(true), 'taskId': 'other'};
    final repo = ApiCallSessionRepository(
      server.api,
      'owner',
    ).forBatch('session', 'batch', 'attempt');
    await expectLater(
      repo.status(CallSessionTarget(taskId: 'batch', attemptId: 'attempt')),
      throwsA(ApiFailure.invalidResponse),
    );
  });
  test(
    'hangup stops the owned batch then reads physical state; monitoring keeps the batch task identity',
    () async {
      final repo = ApiCallSessionRepository(
        server.api,
        'owner',
      ).forBatch('session', 'batch', 'attempt');
      final target = CallSessionTarget(
        taskId: 'batch',
        attemptId: 'attempt',
        callId: 'physical',
      );
      server.beforeResponse = (request) async {
        if (request.uri.path.endsWith('/batch/stop')) {
          server.data = {
            'sessionId': 'session',
            'batchId': 'batch',
            'status': 'STOPPING',
            'matchedCalls': 1,
            'failedCalls': 0,
          };
        } else if (request.uri.path.endsWith('/monitor/token')) {
          server.data = {
            'ticket': 'synthetic',
            'expiresAt': '2099-01-01T00:00:00Z',
          };
        } else {
          server.data = {...snapshot(true), 'callState': 'CANCELLING'};
        }
      };
      expect((await repo.hangUp(target)).callState, 'CANCELLING');
      expect(server.requests.first.method, 'POST');
      expect(
        server.requests.first.uri.path,
        '/api/agent/conversations/session/batch/stop',
      );
      expect(server.requests.first.data, {
        'userId': 'owner',
        'batchId': 'batch',
      });
      await repo.monitorTicket(target);
      expect(server.requests.last.data, {
        'userId': 'owner',
        'taskId': 'batch',
        'callId': 'physical',
      });
      expect(
        server.requests.where((r) => r.uri.path.endsWith('/hangup')),
        isEmpty,
      );
    },
  );
  test('partial batch stop failure remains a failure', () async {
    final repo = ApiCallSessionRepository(
      server.api,
      'owner',
    ).forBatch('session', 'batch', 'attempt');
    server.data = {
      'sessionId': 'session',
      'batchId': 'batch',
      'status': 'STOPPING',
      'matchedCalls': 1,
      'failedCalls': 1,
    };
    await expectLater(
      repo.hangUp(CallSessionTarget(taskId: 'batch', attemptId: 'attempt')),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(server.requests, hasLength(1));
  });
}

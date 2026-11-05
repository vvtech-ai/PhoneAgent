import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/conversation/data/recovery/api_task_error_status_gateway.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';
import '../support/synthetic_account_api.dart';

void main() {
  late SyntheticAccountApi fixture;
  late ApiTaskErrorStatusGateway gateway;
  final command = TaskErrorStatusCommand(
    'session-1',
    TaskErrorStatusReason.exited,
    'cmd-1',
  );
  setUp(() {
    fixture = SyntheticAccountApi()
      ..data = {'sessionId': 'session-1', 'status': 'COMPLETED'};
    gateway = ApiTaskErrorStatusGateway(fixture.api, 'a');
  });
  tearDown(() => fixture.api.close());

  test(
    'v65 protected POST uses stable identity and accepts terminal suppression',
    () async {
      expect(await gateway.send(command), 'COMPLETED');
      expect(await gateway.send(command), 'COMPLETED');
      final request = fixture.requests.first;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/agent/conversations/session-1/interrupt');
      expect(request.headers['X-Account-Id'], 'a');
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.data, {
        'userId': 'a',
        'reason': 'execution_error_exit',
        'commandId': 'cmd-1',
        'idempotencyKey': 'cmd-1',
        'traceId': 'cmd-1',
      });
      expect(fixture.requests.last.data, request.data);
    },
  );
  test(
    'recovery uses explicit reason, not generic interrupt or reset',
    () async {
      fixture.data = {'sessionId': 'session-1', 'status': 'RUNNING'};
      await gateway.send(
        TaskErrorStatusCommand(
          'session-1',
          TaskErrorStatusReason.recovered,
          'cmd-2',
        ),
      );
      expect(
        (fixture.requests.single.data as Map)['reason'],
        'execution_error_recovered',
      );
    },
  );
  test(
    'wrong session, malformed and absent status cannot acknowledge command',
    () async {
      for (final data in [
        {'sessionId': 'other', 'status': 'RUNNING'},
        {'sessionId': 'session-1'},
        {'sessionId': 'session-1', 'status': ''},
        {'sessionId': 'session-1', 'status': 3},
        {'sessionId': 'session-1', 'status': 'private server message'},
      ]) {
        fixture.data = data;
        await expectLater(
          gateway.send(command),
          throwsA(ApiFailure.invalidResponse),
        );
      }
    },
  );
  test('HTTP failure is not retried as a new status command', () async {
    fixture.status = 503;
    await expectLater(gateway.send(command), throwsA(ApiFailure.rejected));
    expect(fixture.requests, hasLength(1));
  });
  test('old account API lease cannot submit using new login', () async {
    fixture.credentials = const AccountCredentials('b', 'new-synthetic', 2);
    await expectLater(
      gateway.send(command),
      throwsA(ApiFailure.sessionChanged),
    );
    expect(fixture.requests, isEmpty);
  });
}

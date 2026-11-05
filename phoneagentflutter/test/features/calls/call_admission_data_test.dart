import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/calls/data/api_call_admission_notice_repository.dart';
import 'package:phone_agent/features/calls/data/secure_call_admission_notice_store.dart';
import 'package:phone_agent/features/calls/domain/call_admission.dart';
import '../../support/call_admission_fixture.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'notice posts protected idempotency hash/count, never raw spec or call action',
    () async {
      final server = SyntheticAccountApi()..data = _receipt();
      addTearDown(server.api.close);
      final repo = ApiCallAdmissionNoticeRepository(server.api);
      final request = callRequest();
      final receipt = await repo.commit(request);
      final http = server.requests.single;
      expect(
        http.uri.path,
        '/api/agent/conversations/session/task-call-points-notices',
      );
      expect(http.method, 'POST');
      expect(http.headers['Authorization'], 'Bearer synthetic');
      expect(http.data, {
        'confirmationKey': sha256
            .convert(utf8.encode(request.stableAlias))
            .toString(),
        'recipientCount': 1,
      });
      expect(receipt.eventId, 'event');
      expect(receipt.created, isTrue);
      expect(receipt.sequence, 2);
    },
  );
  test(
    'malformed or foreign receipt rejects, no automatic HTTP retry',
    () async {
      final server = SyntheticAccountApi();
      addTearDown(server.api.close);
      final repo = ApiCallAdmissionNoticeRepository(server.api);
      for (final patch in [
        {'sessionId': 'other'},
        {'eventId': ''},
        {'sequence': 0},
        {'sequence': 1.5},
        {'created': 'true'},
      ]) {
        server.data = {..._receipt(), ...patch};
        await expectLater(
          repo.commit(callRequest()),
          throwsA(CallAdmissionNoticeFailure.terminal),
        );
      }
      expect(server.requests.length, 5);
    },
  );
  test('invalid path and changed login cannot send', () async {
    final server = SyntheticAccountApi()..data = _receipt();
    addTearDown(server.api.close);
    final repo = ApiCallAdmissionNoticeRepository(server.api);
    await expectLater(
      repo.commit(callRequest(session: '../other')),
      throwsA(CallAdmissionNoticeFailure.terminal),
    );
    server.credentials = const AccountCredentials('b', 'synthetic-b', 2);
    await expectLater(
      repo.commit(callRequest()),
      throwsA(CallAdmissionNoticeFailure.terminal),
    );
    expect(server.requests, isEmpty);
  });
  test(
    'server unavailable may retry but auth/not found/conflict are terminal',
    () async {
      final server = SyntheticAccountApi()..status = 503;
      addTearDown(server.api.close);
      final repo = ApiCallAdmissionNoticeRepository(server.api);
      await expectLater(
        repo.commit(callRequest()),
        throwsA(CallAdmissionNoticeFailure.retryable),
      );
      for (final status in [403, 404, 409, 422]) {
        server.status = status;
        await expectLater(
          repo.commit(callRequest()),
          throwsA(CallAdmissionNoticeFailure.terminal),
        );
      }
    },
  );
  test(
    'markers survive new store instance and isolate environment/account/session',
    () async {
      SecureCallAdmissionNoticeStore store([
        String env = 'dev',
        String owner = 'a',
      ]) => SecureCallAdmissionNoticeStore(environment: env, accountId: owner);
      final aliases = callRequest().aliases;
      await store().markNotified('session', aliases);
      expect(await store().wasNotified('session', aliases), isTrue);
      expect(await store('prod').wasNotified('session', aliases), isFalse);
      expect(await store('dev', 'b').wasNotified('session', aliases), isFalse);
      expect(await store().wasNotified('other', aliases), isFalse);
      final entries = await const FlutterSecureStorage().readAll();
      expect(entries.length, 2);
      expect(entries.values.toSet(), {'1'});
      expect(
        entries.keys.every(
          (key) => RegExp(
            r'^phoneagent.call-admission.v1.[a-f0-9]{64}$',
          ).hasMatch(key),
        ),
        isTrue,
      );
      expect(entries.toString(), isNot(contains('5550101')));
    },
  );
  test(
    'concurrent marker writes retain all aliases and reject absent scope',
    () async {
      final store = SecureCallAdmissionNoticeStore(
        environment: 'dev',
        accountId: 'a',
      );
      await Future.wait([
        store.markNotified('s', ['one']),
        store.markNotified('s', ['two']),
      ]);
      expect(await store.wasNotified('s', ['one']), isTrue);
      expect(await store.wasNotified('s', ['two']), isTrue);
      expect(
        () => SecureCallAdmissionNoticeStore(environment: '', accountId: 'a'),
        throwsArgumentError,
      );
      await expectLater(store.markNotified('', ['one']), throwsArgumentError);
    },
  );
}

Map<String, Object?> _receipt() => {
  'sessionId': 'session',
  'eventId': 'event',
  'sequence': 2,
  'created': true,
};

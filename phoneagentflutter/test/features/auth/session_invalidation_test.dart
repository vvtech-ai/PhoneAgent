import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';

const login = LoginOutcome(
  phone: '13800000000',
  accountId: 'synthetic-a',
  accessToken: 'synthetic-token',
  inviteRequired: false,
);

class Store implements SessionStore {
  AuthSession? value;
  int clears = 0;
  bool fail = false;
  Completer<void>? clearGate, writeGate;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession v) async {
    await writeGate?.future;
    value = v;
  }

  @override
  Future<void> clear() async {
    clears++;
    await clearGate?.future;
    if (fail) throw AuthFailure.storage;
    value = null;
  }
}

class Adapter implements HttpClientAdapter {
  Object code = 'AC0010';
  int status = 403;
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? cancel,
  ) async {
    await gate?.future;
    return ResponseBody.fromString(
      jsonEncode({'code': code, 'message': 'synthetic', 'data': null}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Store store;
  late SessionController session;
  setUp(() async {
    store = Store();
    session = SessionController(store);
    await session.accept(login);
  });
  tearDown(() => session.dispose());
  test(
    'concurrent expiry has one cleanup, release and consumable notice',
    () async {
      final owner = session.credentials!;
      store.clearGate = Completer<void>();
      var releases = 0;
      session.addReleaseListener(() async {
        releases++;
      });
      final calls = List.generate(
        12,
        (_) => session.invalidateSession(
          owner,
          SessionInvalidationReason.cancellationPending,
        ),
      );
      expect(store.clears, 1);
      expect(session.credentials, isNull);
      expect(session.state.businessBlocked, isTrue);
      store.clearGate!.complete();
      await Future.wait(calls);
      expect(releases, 1);
      expect(session.isSignedOut, isTrue);
      expect(
        session.takeInvalidationNotice(),
        SessionInvalidationReason.cancellationPending,
      );
      expect(session.takeInvalidationNotice(), isNull);
      await session.invalidateSession(owner, SessionInvalidationReason.revoked);
      expect(store.clears, 1);
    },
  );
  test(
    'old account and refreshed token cannot invalidate current credentials',
    () async {
      final old = session.credentials!;
      await session.replaceToken(old, 'synthetic-refreshed');
      await session.invalidateSession(old, SessionInvalidationReason.revoked);
      expect(store.clears, 0);
      expect(session.credentials!.token, 'synthetic-refreshed');
      await session.accept(
        const LoginOutcome(
          phone: '13900000000',
          accountId: 'synthetic-b',
          accessToken: 'new',
          inviteRequired: false,
        ),
      );
      await session.invalidateSession(old, SessionInvalidationReason.cancelled);
      expect(store.clears, 0);
      expect(session.credentials!.accountId, 'synthetic-b');
    },
  );
  test(
    'failed cleanup blocks business; duplicate responses do not retry; explicit retry works',
    () async {
      final old = session.credentials!;
      store.fail = true;
      await session.invalidateSession(old, SessionInvalidationReason.revoked);
      expect(session.state.businessBlocked, isTrue);
      expect(session.credentials, isNull);
      expect(session.takeInvalidationNotice(), isNull);
      await session.invalidateSession(old, SessionInvalidationReason.revoked);
      expect(store.clears, 1);
      store.fail = false;
      store.clearGate = Completer<void>();
      final retry = session.retryInvalidation();
      final duplicate = session.retryInvalidation();
      expect(store.clears, 2);
      store.clearGate!.complete();
      await Future.wait([retry, duplicate]);
      expect(session.isSignedOut, isTrue);
      expect(
        session.takeInvalidationNotice(),
        SessionInvalidationReason.revoked,
      );
    },
  );
  test(
    'cancellation result owner wins and does not show generic invalidation notice',
    () async {
      final old = session.credentials!;
      final release = session.deferInvalidationForCancellation();
      await session.invalidateSession(
        old,
        SessionInvalidationReason.cancellationPending,
      );
      expect(store.clears, 0);
      expect(session.credentials, isNotNull);
      session.blockBusinessForCancellation();
      await session.signOut();
      release();
      expect(store.clears, 1);
      expect(session.takeInvalidationNotice(), isNull);
    },
  );
  test(
    'unresolved cancellation guard retains original query; releasing applies queued expiry once',
    () async {
      final old = session.credentials!;
      final release = session.deferInvalidationForCancellation();
      await session.invalidateSession(old, SessionInvalidationReason.revoked);
      await session.invalidateSession(old, SessionInvalidationReason.revoked);
      expect(store.clears, 0);
      release();
      release();
      await Future<void>.delayed(Duration.zero);
      expect(store.clears, 1);
      expect(session.isSignedOut, isTrue);
    },
  );
  test(
    'invalidation racing a successful token write does not clear refreshed login',
    () async {
      final old = session.credentials!;
      store.writeGate = Completer<void>();
      final write = session.replaceToken(old, 'new-token');
      await session.invalidateSession(old, SessionInvalidationReason.revoked);
      store.writeGate!.complete();
      await write;
      expect(store.clears, 0);
      expect(session.credentials!.token, 'new-token');
    },
  );
  for (final stream in [false, true]) {
    test(
      'JSON and stream handshake lifecycle denial both enter unified exit (stream=$stream)',
      () async {
        final adapter = Adapter();
        final api = AccountApi(
          AppConfig.parse(
            environment: 'dev',
            apiBaseUrl: 'https://example.test',
          ),
          session,
          client: Dio()..httpClientAdapter = adapter,
        );
        addTearDown(api.close);
        final action = stream
            ? api.openAgentStream({}, CancelToken())
            : api.request('api/points/account');
        await expectLater(action, throwsA(ApiFailure.sessionChanged));
        expect(store.clears, 1);
        expect(session.isSignedOut, isTrue);
      },
    );
  }
  test(
    'generic forbidden, disabled/mismatch and a success response never force logout',
    () async {
      final adapter = Adapter()..code = 'AC0003';
      final api = AccountApi(
        AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test'),
        session,
        client: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(api.close);
      await expectLater(
        api.request('api/points/account'),
        throwsA(ApiFailure.rejected),
      );
      expect(store.clears, 0);
      expect(session.credentials, isNotNull);
      adapter.status = 200;
      adapter.code = 'AC0010';
      await expectLater(
        api.request('api/points/account'),
        throwsA(ApiFailure.rejected),
      );
      expect(store.clears, 0);
    },
  );
  test('late HTTP response cannot logout a new login', () async {
    final adapter = Adapter()..gate = Completer<void>();
    final api = AccountApi(
      AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test'),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final request = api.request('api/points/account');
    final assertion = expectLater(request, throwsA(ApiFailure.sessionChanged));
    await Future<void>.delayed(Duration.zero);
    await session.accept(
      const LoginOutcome(
        phone: '13900000000',
        accountId: 'synthetic-b',
        accessToken: 'new',
        inviteRequired: false,
      ),
    );
    adapter.gate!.complete();
    await assertion;
    expect(store.clears, 0);
  });
}

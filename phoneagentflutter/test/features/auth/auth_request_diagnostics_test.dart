import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_auth_details.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'package:phone_agent/features/auth/data/auth_request_diagnostics.dart';
import 'package:phone_agent/features/auth/data/dio_auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';

const _phone = '13800000000';
const _submission = LoginSubmission(
  phone: _phone,
  code: '739281',
  activationCode: 'secret-invite',
  loginChallenge: 'secret-challenge',
);
final _config = AppConfig.parse(
  environment: 'dev',
  apiBaseUrl: 'https://example.test/secret-path/',
);

void main() {
  final events = <DiagnosticEvent>[];
  late _Adapter adapter;
  late DioAuthGateway gateway;
  setUp(() {
    events.clear();
    adapter = _Adapter();
    gateway = DioAuthGateway(
      _config,
      client: Dio()..httpClientAdapter = adapter,
      diagnostics: () => events.add,
    );
  });
  tearDown(() => gateway.close());

  test(
    'full responses distinguish accepted code, invite and credentials',
    () async {
      adapter.reply = (_) async => _body(_code());
      await gateway.sendCode(_phone);
      adapter.reply = (_) async => _body({
        'phone': _phone,
        'inviteRequired': true,
        'loginChallenge': 'secret-challenge',
      });
      await gateway.login(_submission);
      adapter.reply = (_) async => _body(_login());
      await gateway.login(_submission);
      expect(events.map((e) => e.operation), [
        DiagnosticOperation.authSendCode,
        DiagnosticOperation.authLogin,
        DiagnosticOperation.authLogin,
      ]);
      expect(events.map((e) => e.auth!.outcome), [
        DiagnosticAuthOutcome.codeAccepted,
        DiagnosticAuthOutcome.inviteRequired,
        DiagnosticAuthOutcome.credentialsReturned,
      ]);
      expect(events.every((e) => e.statusCode == 200), isTrue);
      expect(events.every((e) => e.elapsedMs >= 0), isTrue);
      expect(
        events.every((e) => e.result == DiagnosticResult.succeeded),
        isTrue,
      );
      expect(adapter.requests, 3);
      _expectPrivate(jsonEncode(events.map((e) => e.toJson()).toList()));
    },
  );

  test(
    'HTTP 200 is failure when full send-code/login DTO is invalid',
    () async {
      for (final data in [
        <String, Object?>{'phone': _phone},
        {..._login(), 'phone': '13900000000'},
        {..._login(), 'points': <String, Object?>{}},
        {..._login(), 'grantEvents': 'secret-token'},
      ]) {
        adapter.reply = (_) async => _body(data);
        await expectLater(
          gateway.login(_submission),
          throwsA(AuthFailure.invalidResponse),
        );
        expect(
          events.last.auth!.outcome,
          DiagnosticAuthOutcome.invalidResponse,
        );
        expect(events.last.result, DiagnosticResult.failed);
        expect(events.last.statusCode, 200);
      }
      adapter.reply = (_) async =>
          _body({..._code(), 'expireSeconds': 'private'});
      await expectLater(
        gateway.sendCode(_phone),
        throwsA(AuthFailure.invalidResponse),
      );
      expect(events.last.auth!.outcome, DiagnosticAuthOutcome.invalidResponse);
      expect(events.length, 5);
      expect(adapter.requests, 5);
    },
  );

  for (final status in [200, 400]) {
    test(
      'business failure categories retained at HTTP $status without retry',
      () async {
        final cases = {
          '验证码已过期': AuthFailure.codeExpired,
          '验证码不正确': AuthFailure.incorrectCode,
          '请求频繁': AuthFailure.rateLimited,
          '邀请码错误': AuthFailure.invalidInvite,
          '挑战已失效': AuthFailure.challengeExpired,
        };
        for (final entry in cases.entries) {
          adapter.reply = (_) async =>
              _raw({'code': 1, 'message': entry.key}, status);
          await expectLater(gateway.login(_submission), throwsA(entry.value));
          expect(events.last.auth!.outcome.name, entry.value.name);
          expect(events.last.statusCode, status);
          expect(events.last.result, DiagnosticResult.failed);
        }
        adapter.reply = (_) async =>
            _raw({'code': 1, 'message': 'secret-token'}, status);
        await expectLater(
          gateway.login(_submission),
          throwsA(isA<AuthMessageFailure>()),
        );
        expect(events.last.auth!.outcome, DiagnosticAuthOutcome.unknown);
        expect(events.length, cases.length + 1);
        expect(adapter.requests, cases.length + 1);
        _expectPrivate(jsonEncode(events.map((e) => e.toJson()).toList()));
      },
    );
  }

  test('offline diagnostic retains fixed network category', () async {
    final request = AuthRequestDiagnostics(
      DiagnosticOperation.authLogin,
      () => events.add,
    );
    await expectLater(
      request.run<void>(
        () async => throw AuthFailure.offline,
        (_) => DiagnosticAuthOutcome.credentialsReturned,
      ),
      throwsA(AuthFailure.offline),
    );
    expect(events.single.auth!.outcome, DiagnosticAuthOutcome.network);
    _expectPrivate(jsonEncode(events.single.toJson()));
  });

  test('transport failure has no invented HTTP response or payload', () async {
    adapter.reply = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.connectionTimeout,
      error: StateError('secret-token'),
    );
    await expectLater(gateway.sendCode(_phone), throwsA(AuthFailure.timeout));
    expect(events.single.statusCode, 0);
    expect(events.single.auth!.outcome, DiagnosticAuthOutcome.network);
    expect(adapter.requests, 1);
    _expectPrivate(jsonEncode(events.single.toJson()));
  });

  test(
    'per-request sink and status survive concurrent out-of-order completion',
    () async {
      final first = Completer<ResponseBody>();
      final second = Completer<ResponseBody>();
      final started = Completer<void>();
      final accountB = <DiagnosticEvent>[];
      var selected = events;
      var selections = 0;
      gateway.close();
      gateway = DioAuthGateway(
        _config,
        client: Dio()..httpClientAdapter = adapter,
        diagnostics: () {
          selections++;
          return selected.add;
        },
      );
      adapter.reply = (request) {
        if (adapter.requests == 2) started.complete();
        return request.uri.path.endsWith('send-code')
            ? first.future
            : second.future;
      };
      final send = gateway.sendCode(_phone);
      selected = accountB;
      final login = gateway.login(_submission);
      await started.future;
      second.complete(_body(_login(), 201));
      await login;
      first.complete(_body(_code(), 202));
      await send;
      expect(selections, 2);
      expect(events.single.operation, DiagnosticOperation.authSendCode);
      expect(events.single.statusCode, 202);
      expect(accountB.single.operation, DiagnosticOperation.authLogin);
      expect(accountB.single.statusCode, 201);
    },
  );

  test(
    'selecting/writing diagnostics cannot change result or original error',
    () async {
      for (final select in <DiagnosticSink? Function()>[
        () => throw StateError('secret-token'),
        () =>
            (_) => throw StateError('secret-token'),
      ]) {
        gateway.close();
        gateway = DioAuthGateway(
          _config,
          client: Dio()..httpClientAdapter = adapter,
          diagnostics: select,
        );
        adapter.reply = (_) async => _body(_login());
        expect((await gateway.login(_submission)).accountId, 'secret-account');
        adapter.reply = (_) async =>
            _raw({'code': 1, 'message': '验证码不正确'}, 400);
        await expectLater(
          gateway.login(_submission),
          throwsA(AuthFailure.incorrectCode),
        );
      }
      final original = StateError('secret-token');
      final diagnostic = AuthRequestDiagnostics(
        DiagnosticOperation.authLogin,
        () => events.add,
      );
      await expectLater(
        diagnostic.run<Object>(
          () async => throw original,
          (_) => DiagnosticAuthOutcome.credentialsReturned,
        ),
        throwsA(same(original)),
      );
      expect(events.single.auth!.outcome, DiagnosticAuthOutcome.unknown);
    },
  );

  test(
    'journal reconstruction and real ZIP retain categories, no secrets',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(store);
      gateway.close();
      gateway = DioAuthGateway(
        _config,
        client: Dio()..httpClientAdapter = adapter,
        diagnostics: () => journal.record,
      );
      adapter.reply = (_) async => _body(_code());
      await gateway.sendCode(_phone);
      adapter.reply = (_) async => _body(_login());
      await gateway.login(_submission);
      await journal.flush();
      journal.close();
      _expectPrivate(store.value!);
      final rebuilt = DiagnosticJournal(store);
      addTearDown(rebuilt.close);
      final bundle = await ZipLogRepository(
        rebuilt,
        uploadBundle: (_) async => fail('No upload'),
      ).prepare();
      expect(bundle.count, 2);
      final archive = ZipDecoder().decodeBytes(bundle.bytes, verify: true);
      final payload = utf8.decode(archive.files.single.content as List<int>);
      final rows = payload
          .split('\n')
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
      expect(rows.first['auth'], {'outcome': 'codeAccepted'});
      expect(rows.last['auth'], {'outcome': 'credentialsReturned'});
      _expectPrivate(payload);
    },
  );

  test(
    'legacy events readable and unknown auth JSON cannot leak raw fields',
    () {
      final old = DiagnosticEvent(
        operation: DiagnosticOperation.accountRequest,
        result: DiagnosticResult.succeeded,
      ).toJson();
      expect(DiagnosticEvent.fromJson(old).auth, isNull);
      final event = DiagnosticEvent.fromJson({
        ...old,
        'auth': {
          'outcome': 'secret-token',
          'phone': _phone,
          'response': 'secret-challenge',
        },
      });
      expect(event.auth!.outcome, DiagnosticAuthOutcome.unknown);
      _expectPrivate(jsonEncode(event.toJson()));
      expect(event.toJson()['auth'], {'outcome': 'unknown'});
    },
  );
}

Map<String, Object?> _login() => {
  'phone': _phone,
  'accountId': 'secret-account',
  'voiceCloneAccessToken': 'secret-token',
  'displayName': 'secret-name',
  'inviteRequired': false,
};
Map<String, Object?> _code() => {
  'phone': _phone,
  'expireSeconds': 300,
  'resendCooldownSeconds': 60,
  'eventId': 'secret-event',
};
ResponseBody _body(Object? data, [int status = 200]) =>
    _raw({'code': 0, 'data': data}, status);
ResponseBody _raw(Object? data, int status) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
void _expectPrivate(String text) {
  for (final secret in [
    _phone,
    '739281',
    'secret-',
    'example.test',
    '验证码',
    '邀请码',
    '挑战',
  ]) {
    expect(text, isNot(contains(secret)));
  }
}

class _Adapter implements HttpClientAdapter {
  int requests = 0;
  late Future<ResponseBody> Function(RequestOptions) reply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    requests++;
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async => value = text;
}

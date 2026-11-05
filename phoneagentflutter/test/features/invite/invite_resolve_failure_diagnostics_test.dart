import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/invite/data/api_invite_repository.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';

class _Response implements HttpClientAdapter {
  _Response(this.body, {this.status = 200, this.network = false, this.gate});
  final Object body;
  final int status;
  final bool network;
  final Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (gate != null) await gate!.future;
    if (network) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionTimeout,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PublicInviteResolver _resolver(
  _Response response,
  DiagnosticSink? Function() sink,
) {
  final value = PublicInviteResolver(
    AppConfig.parse(
      environment: 'dev',
      apiBaseUrl: 'https://agent.test/',
      sdkApiBaseUrl: 'https://sdk.test/',
    ),
    client: Dio()..httpClientAdapter = response,
    diagnostics: sink,
  );
  addTearDown(value.close);
  return value;
}

Map<String, Object?> body({Object? activity, String status = 'ACTIVE'}) => {
  'code': '000000',
  'data': {
    'code': 'ABCD',
    'status': status,
    if (activity != null) 'activity': activity,
  },
};

void main() {
  final cases = <(String, Object, int, String, DiagnosticInviteResolveOutcome)>[
    (
      'missing activity',
      body(),
      200,
      'CONFIG_NOT_PUBLISHED',
      DiagnosticInviteResolveOutcome.configNotPublished,
    ),
    (
      'bad activity',
      body(activity: []),
      200,
      'CONFIG_NOT_PUBLISHED',
      DiagnosticInviteResolveOutcome.configNotPublished,
    ),
    (
      'missing points',
      body(activity: <String, Object?>{}),
      200,
      'INVALID_RESPONSE',
      DiagnosticInviteResolveOutcome.invalidResponse,
    ),
    (
      'negative points',
      body(activity: {'inviteePoints': -1}),
      200,
      'INVALID_RESPONSE',
      DiagnosticInviteResolveOutcome.invalidResponse,
    ),
    (
      'unknown status',
      body(status: 'untrusted-response-text'),
      200,
      'INVALID_RESPONSE',
      DiagnosticInviteResolveOutcome.invalidResponse,
    ),
    (
      'bad data',
      {'code': '000000', 'data': []},
      200,
      'INVALID_RESPONSE',
      DiagnosticInviteResolveOutcome.invalidResponse,
    ),
    (
      'bad envelope',
      'synthetic-private-response',
      200,
      'INVALID_RESPONSE',
      DiagnosticInviteResolveOutcome.invalidResponse,
    ),
    (
      'server unavailable',
      'synthetic-private-response',
      503,
      'UNAVAILABLE',
      DiagnosticInviteResolveOutcome.serviceUnavailable,
    ),
    (
      'HTTP business error',
      {
        'code': 'error',
        'data': {'errorCode': 'INVITE_EXPIRED'},
      },
      409,
      'INVITE_EXPIRED',
      DiagnosticInviteResolveOutcome.expired,
    ),
    (
      'pending config',
      {
        'code': 'error',
        'data': {'errorCode': 'CONFIG_SYNC_PENDING'},
      },
      200,
      'CONFIG_SYNC_PENDING',
      DiagnosticInviteResolveOutcome.configSyncPending,
    ),
    (
      'unknown error',
      {
        'code': 'sensitive-code',
        'data': {'errorCode': 'synthetic-private-response'},
      },
      200,
      'UNAVAILABLE',
      DiagnosticInviteResolveOutcome.serviceUnavailable,
    ),
    (
      'ended activity',
      body(status: 'ACTIVITY_RETIRED'),
      200,
      'INVITE_ACTIVITY_RETIRED',
      DiagnosticInviteResolveOutcome.activityRetired,
    ),
    (
      'expired code',
      body(status: 'EXPIRED'),
      200,
      'INVITE_EXPIRED',
      DiagnosticInviteResolveOutcome.expired,
    ),
    (
      'exhausted code',
      body(status: 'EXHAUSTED'),
      200,
      'INVITE_EXHAUSTED',
      DiagnosticInviteResolveOutcome.exhausted,
    ),
  ];
  for (final value in cases) {
    test('classifies and safely records ${value.$1}', () async {
      final events = <DiagnosticEvent>[];
      await expectLater(
        _resolver(
          _Response(value.$2, status: value.$3),
          () => events.add,
        ).resolve('ABCD'),
        throwsA(isA<InviteFailure>().having((e) => e.code, 'code', value.$4)),
      );
      expect(events.map((e) => e.result), [
        DiagnosticResult.started,
        DiagnosticResult.failed,
      ]);
      final last = events.last;
      expect(last.statusCode, value.$3);
      expect(last.inviteResolve!.outcome, value.$5);
      final roundTrip = DiagnosticEvent.fromJson(last.toJson()).toJson();
      expect(roundTrip, last.toJson());
      final json = jsonEncode(events.map((e) => e.toJson()).toList());
      for (final secret in [
        'ABCD',
        'sdk.test',
        'agent.test',
        'sensitive-code',
        'synthetic-private-response',
        'untrusted-response-text',
      ]) {
        expect(json, isNot(contains(secret)));
      }
    });
  }
  test('network remains network and never exposes exception or URL', () async {
    final events = <DiagnosticEvent>[];
    await expectLater(
      _resolver(_Response({}, network: true), () => events.add).resolve('ABCD'),
      throwsA(isA<InviteFailure>().having((e) => e.code, 'code', 'NETWORK')),
    );
    expect(events.last.statusCode, 0);
    expect(
      events.last.inviteResolve!.outcome,
      DiagnosticInviteResolveOutcome.network,
    );
    expect(events.last.inviteResolve!.apiCode, DiagnosticInviteApiCode.unknown);
  });
  test(
    'request completion stays with starting owner after account switch',
    () async {
      final a = <DiagnosticEvent>[], b = <DiagnosticEvent>[];
      DiagnosticSink selected = a.add;
      final gate = Completer<void>();
      final request = _resolver(
        _Response(body(activity: {'inviteePoints': 20}), gate: gate),
        () => selected,
      ).resolve('ABCD');
      expect(a.single.result, DiagnosticResult.started);
      selected = b.add;
      gate.complete();
      expect(await request, 20);
      expect(
        a.last.inviteResolve!.outcome,
        DiagnosticInviteResolveOutcome.active,
      );
      expect(
        a.last.inviteResolve!.apiCode,
        DiagnosticInviteApiCode.stringSuccess,
      );
      expect(a.length, 2);
      expect(b, isEmpty);
    },
  );
  test(
    'diagnostic lookup and sink errors never prevent a valid query',
    () async {
      for (final lookup in <DiagnosticSink? Function()>[
        () => throw StateError('synthetic lookup'),
        () =>
            (_) => throw StateError('synthetic sink'),
      ]) {
        expect(
          await _resolver(
            _Response(body(activity: {'inviteePoints': 20})),
            lookup,
          ).resolve('ABCD'),
          20,
        );
      }
    },
  );
  test('unknown restored diagnostic fields are discarded', () {
    final value = DiagnosticInviteResolveDetails.fromJson({
      'outcome': 'private-body',
      'apiCode': 'private-code',
      'url': 'https://private.test/',
    });
    expect(value.toJson(), {'outcome': 'unknown', 'apiCode': 'unknown'});
  });
}

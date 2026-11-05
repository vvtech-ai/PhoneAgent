import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/conversation/data/tools/api_contact_lookup_continuation.dart';
import 'package:phone_agent/features/conversation/data/tools/api_name_contact_lookup_continuation.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

void main() {
  late _Adapter adapter;
  late _Session session;
  late AccountApi api;
  late ApiContactLookupContinuation continuation;
  setUp(() {
    adapter = _Adapter();
    session = _Session();
    api = AccountApi(
      AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test/'),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
    continuation = ApiContactLookupContinuation(api, 'a');
  });
  tearDown(() => api.close());
  Future<AgentEvent> send() => continuation.submit(
    sessionId: 's',
    toolCallId: 't',
    result: {'found': false, 'reason': 'PERMISSION_DENIED'},
  );
  test(
    'names use dedicated endpoint and voice channel with exact candidates',
    () async {
      final results = <Map<String, Object?>>[
        {
          'name': '合成',
          'requestedName': '合成',
          'status': 'MULTIPLE_CANDIDATES',
          'inputSource': 'typed',
          'candidates': [
            {
              'displayName': '合成',
              'resolvedName': '合成',
              'phoneNumber': '2025550101',
            },
          ],
        },
      ];
      await ApiNameContactLookupContinuation(
        api,
        'a',
      ).submitNames(sessionId: 's', toolCallId: 't', results: results);
      final request = adapter.requests.single;
      expect(
        request.uri.path,
        '/api/assistant/agent/device-contacts-lookup-result',
      );
      expect(request.data, {
        'sessionId': 's',
        'pendingToolCallId': 't',
        'userId': 'a',
        'results': results,
        'channel': 'voice',
      });
      expect(request.headers['X-Account-Id'], 'a');
    },
  );
  test('command-aware callbacks carry the continuation command id', () async {
    await continuation.submitWithCommand(
      sessionId: 's',
      toolCallId: 't',
      commandId: 'turn-1:contact:t',
      result: {'found': false},
    );
    expect(adapter.requests.single.data, {
      'sessionId': 's',
      'pendingToolCallId': 't',
      'userId': 'a',
      'result': {'found': false},
      'commandId': 'turn-1:contact:t',
    });
  });

  test(
    'name command-aware callbacks carry the continuation command id',
    () async {
      await ApiNameContactLookupContinuation(api, 'a').submitNamesWithCommand(
        sessionId: 's',
        toolCallId: 't',
        commandId: 'turn-1:contact:t',
        results: const [
          {'name': '合成', 'status': 'NOT_FOUND'},
        ],
      );
      expect(adapter.requests.single.data['commandId'], 'turn-1:contact:t');
    },
  );

  test('empty names result rejected before POST', () async {
    await expectLater(
      ApiNameContactLookupContinuation(
        api,
        'a',
      ).submitNames(sessionId: 's', toolCallId: 't', results: []),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(adapter.requests, isEmpty);
  });
  test(
    'exact v65 path body and account; no chat replay or added channel',
    () async {
      final response = await send();
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/assistant/agent/contact-lookup-result');
      expect(request.headers['X-Account-Id'], 'a');
      expect(request.data, {
        'sessionId': 's',
        'pendingToolCallId': 't',
        'userId': 'a',
        'result': {'found': false, 'reason': 'PERMISSION_DENIED'},
      });
      expect(response.kind, AgentEventKind.finalResponse);
      expect(response.text, '合成续接');
    },
  );
  test('interactive, receipt and error responses retain payload', () async {
    for (final type in [
      'ASK_USER',
      'SHOW_OPTIONS',
      'LOOKUP_CONTACT_REQUEST',
      'MAKE_CALL_REQUEST',
      'CALL_RESULT',
      'BATCH_CALL_RESULT',
      'ERROR',
    ]) {
      adapter.data = {
        'sessionId': 's',
        'type': type,
        'text': null,
        'pendingToolCallId': 'next',
        'lookupContactPhone': '2025550101',
      };
      final event = await send();
      expect(event.payload['pendingToolCallId'], 'next');
      expect(event.payload['lookupContactPhone'], '2025550101');
      expect(
        event.kind,
        type == 'ERROR'
            ? AgentEventKind.error
            : type.endsWith('RESULT')
            ? AgentEventKind.finalResponse
            : AgentEventKind.signal,
      );
    }
  });
  test('bad response and wrong session fail closed', () async {
    for (final data in [
      {'sessionId': 'other', 'type': 'TEXT_REPLY'},
      {'sessionId': 's', 'type': ''},
      {'sessionId': 's', 'type': 'TEXT_REPLY', 'text': 1},
    ]) {
      adapter.data = data;
      await expectLater(send(), throwsA(ApiFailure.invalidResponse));
    }
  });
  test('server rejection never retries a mutation', () async {
    adapter.status = 500;
    await expectLater(send(), throwsA(ApiFailure.rejected));
    expect(adapter.requests, hasLength(1));
  });
  test(
    'account change while result is pending rejects late response',
    () async {
      adapter.gate = Completer<void>();
      final pending = expectLater(send(), throwsA(ApiFailure.sessionChanged));
      await Future<void>.delayed(Duration.zero);
      session.value = const AccountCredentials('b', 'synthetic-b', 2);
      adapter.gate!.complete();
      await pending;
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, Object?> data = {
    'sessionId': 's',
    'type': 'TEXT_REPLY',
    'text': '合成续接',
  };
  int status = 200;
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (gate != null) await gate!.future;
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Session implements AccountSession {
  AccountCredentials? value = const AccountCredentials('a', 'synthetic', 1);
  @override
  AccountCredentials? get credentials => value;
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

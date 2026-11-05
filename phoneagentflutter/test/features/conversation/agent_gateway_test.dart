import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/conversation/data/stream/dio_agent_gateway.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/context/agent_context_builder.dart';
import 'agent_context_builder_test.dart' show FakeClock, FakePermissions;

class _Signing implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async => const C1Credentials(
    apiKey: 'public-fixture',
    secret: 'public-secret',
    clientContext: 'e30',
    deviceId: '33333333-3333-4333-8333-333333333333',
  );
}

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'secret-not-used',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials)) return false;
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }

  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  bool rejectHandshake = false;
  bool signatureFailure = false;
  int handshakeStatus = 200;
  String handshakeBody = '{"code":"INTERNAL"}';
  String text =
      'event: text_delta\ndata: {"text":"你好"}\n\nevent: done\ndata: {}\n\n';
  String contentType = 'text/event-stream';
  final requests = <RequestOptions>[];
  Stream<Uint8List>? source;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? s,
    Future<void>? cancel,
  ) async {
    requests.add(r);
    if (r.path.endsWith('/refresh')) {
      return ResponseBody.fromString(
        '{"code":"000000","data":{"voiceCloneAccessToken":"refreshed"}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (rejectHandshake && r.headers['Authorization'] != 'Bearer refreshed') {
      return ResponseBody.fromString(
        '{"code":"${signatureFailure ? 'AC0009' : 'AC0002'}"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (handshakeStatus != 200) {
      return ResponseBody.fromString(
        handshakeBody,
        handshakeStatus,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody(
      source ??
          Stream.fromIterable(
            utf8.encode(text).map((b) => Uint8List.fromList([b])),
          ),
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const command = AgentCommand(
  sessionId: 'session',
  userId: 'synthetic',
  commandId: 'command',
  idempotencyKey: 'intent',
  traceId: 'trace',
  message: '测试',
  initialSkillId: 'skill',
);
void main() {
  test(
    'task permission finishes before fresh context and sends the original turn once',
    () async {
      final session = _Session(), adapter = _Adapter();
      final config = AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api',
      );
      final api = AccountApi(
        config,
        session,
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(_Signing()),
      );
      final order = <String>[];
      final grant = Completer<void>();
      final gateway = DioAgentGateway(
        config,
        session,
        api: api,
        beforeContext: (original, current) async {
          expect(identical(original, command), isTrue);
          expect(current(), isTrue);
          order.add('permission');
          await grant.future;
        },
        userContextProvider: () async {
          order.add('context');
          return {
            'permissionStatus': {'location': 'OK'},
            'lat': 31.2,
            'lng': 121.4,
          };
        },
      );
      final result = gateway.start(command).events.toList();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.requests, isEmpty);
      grant.complete();
      await result;
      expect(order, ['permission', 'context']);
      expect(adapter.requests, hasLength(1));
      final payload = jsonDecode(adapter.requests.single.data as String) as Map;
      expect(payload['commandId'], command.commandId);
      expect(payload['message'], command.message);
      expect((payload['userContext'] as Map)['lat'], 31.2);
      gateway.close();
      api.close();
    },
  );
  test(
    'signed SSE refreshes only a rejected handshake and preserves command identity',
    () async {
      final session = _Session(), adapter = _Adapter()..rejectHandshake = true;
      final config = AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api',
        sdkApiBaseUrl: 'https://example.test/aiassistant-sdk-api',
      );
      final api = AccountApi(
        config,
        session,
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(_Signing()),
      );
      final gateway = DioAgentGateway(config, session, api: api);
      expect(await gateway.start(command).events.toList(), hasLength(2));
      expect(adapter.requests, hasLength(3));
      expect(
        adapter.requests[1].uri.path,
        '/aiassistant-sdk-api/api/auth/voice-clone/refresh',
      );
      expect(adapter.requests.first.data, adapter.requests.last.data);
      expect(
        adapter.requests.first.headers['X-Sign'],
        isNot(adapter.requests.last.headers['X-Sign']),
      );
      gateway.close();
      api.close();
    },
  );
  test('SSE signature failure never refreshes or starts a run', () async {
    final session = _Session(),
        adapter = _Adapter()
          ..rejectHandshake = true
          ..signatureFailure = true;
    final config = AppConfig.parse(
      environment: 'dev',
      apiBaseUrl: 'https://example.test/aiassistant-api',
    );
    final api = AccountApi(
      config,
      session,
      client: Dio()..httpClientAdapter = adapter,
      signing: C1Transport(_Signing()),
    );
    final gateway = DioAgentGateway(config, session, api: api);
    await expectLater(
      gateway.start(command).events.toList(),
      throwsA(AgentTransportFailure.rejected),
    );
    expect(adapter.requests, hasLength(1));
    expect(session.credentials?.token, 'secret-not-used');
    gateway.close();
    api.close();
  });
  late _Session session;
  late _Adapter adapter;
  late DioAgentGateway gateway;
  final diagnostics = <DiagnosticEvent>[];
  var diagnosticFails = false;
  Future<Map<String, Object?>> Function()? location;
  setUp(() {
    diagnostics.clear();
    diagnosticFails = false;
    location = null;
    session = _Session();
    adapter = _Adapter();
    gateway = DioAgentGateway(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
      userContextProvider: () async => await location?.call() ?? const {},
      diagnostics: (event) {
        if (diagnosticFails) throw StateError('synthetic sink error');
        diagnostics.add(event);
      },
    );
  });
  tearDown(() => gateway.close());
  for (final handshake in [
    (502, '{"code":"BAD_GATEWAY"}'),
    (503, '{"code":"INTERNAL"}'),
    (504, '{"data":{"errorCode":"MODEL_TIMEOUT"}}'),
  ]) {
    test('HTTP ${handshake.$1} keeps POST acceptance uncertain', () async {
      adapter.handshakeStatus = handshake.$1;
      adapter.handshakeBody = handshake.$2;
      await expectLater(
        gateway.start(command).events.toList(),
        throwsA(AgentTransportFailure.network),
      );
      expect(adapter.requests, hasLength(1));
      expect(
        diagnostics
            .where(
              (event) =>
                  event.operation == DiagnosticOperation.agentStream &&
                  event.result == DiagnosticResult.failed,
            )
            .single
            .statusCode,
        handshake.$1,
      );
    });
  }
  test('transport loss has no HTTP handshake status', () async {
    adapter.source = Stream<Uint8List>.error(
      DioException(
        requestOptions: RequestOptions(path: '/synthetic'),
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      gateway.start(command).events.toList(),
      throwsA(AgentTransportFailure.network),
    );
    expect(
      diagnostics
          .where(
            (event) =>
                event.operation == DiagnosticOperation.agentStream &&
                event.result == DiagnosticResult.failed,
          )
          .single
          .statusCode,
      0,
    );
  });
  test('HTTP 422 still reports explicit handshake rejection', () async {
    adapter.handshakeStatus = 422;
    await expectLater(
      gateway.start(command).events.toList(),
      throwsA(AgentTransportFailure.rejected),
    );
    expect(adapter.requests, hasLength(1));
  });
  test(
    'shared builder reaches real Dio serialization on ordinary and tool turns',
    () async {
      final clock = FakeClock();
      final builder = AgentContextBuilder(
        location: () async => {'lat': 22.5, 'lng': 114.0},
        clock: clock,
        permissions: FakePermissions(),
      );
      location = builder.prepare;
      await gateway.start(command).events.toList();
      const tool = AgentCommand(
        sessionId: 'session',
        userId: 'synthetic',
        commandId: 'tool-command',
        idempotencyKey: 'tool-intent',
        traceId: 'trace',
        actionId: 'permission_result',
        actionPayload: {'granted': true},
        userContext: {
          'ocrAttachments': ['synthetic'],
        },
      );
      await gateway.start(tool).events.toList();
      for (final request in adapter.requests) {
        final context = (request.data as Map)['userContext'] as Map;
        expect(context['currentTime'], clock.value.toContext());
        expect((context['permissionStatus'] as Map)['document_picker'], 'OK');
        expect(context['lat'], 22.5);
      }
      final first = adapter.requests.first.data as Map,
          last = adapter.requests.last.data as Map;
      expect(first['initialSkillId'], 'skill');
      expect((last['userContext'] as Map)['ocrAttachments'], ['synthetic']);
      expect(last['idempotencyKey'], 'tool-intent');
      expect(last['actionPayload'], {'granted': true});
      expect(clock.reads, 2);
    },
  );
  test(
    'location enriches OCR and tool command without changing wire identity',
    () async {
      location = () async => {'lat': 22.5, 'lng': 114.0};
      const request = AgentCommand(
        sessionId: 'session',
        userId: 'synthetic',
        commandId: 'command',
        idempotencyKey: 'intent',
        traceId: 'trace',
        actionId: 'permission_result',
        actionPayload: {'granted': true},
        userContext: {
          'ocrAttachments': ['synthetic'],
        },
      );
      await gateway.start(request).events.toList();
      final payload = adapter.requests.single.data as Map;
      expect(payload['userContext'], {
        'ocrAttachments': ['synthetic'],
        'lat': 22.5,
        'lng': 114.0,
      });
      expect(payload['actionPayload'], {'granted': true});
      expect(payload['idempotencyKey'], 'intent');
      expect(payload['channel'], 'voice');
      expect(request.userContext, {
        'ocrAttachments': ['synthetic'],
      });
    },
  );
  test('location failure still sends original request once', () async {
    location = () async => throw StateError('Synthetic location failure');
    await gateway.start(command).events.toList();
    expect(adapter.requests.single.data, command.toJson());
  });
  test('cancel while locating never sends late HTTP', () async {
    final pending = Completer<Map<String, Object?>>();
    location = () => pending.future;
    final run = gateway.start(command);
    final result = run.events.toList();
    await Future<void>.delayed(Duration.zero);
    run.cancel();
    pending.complete({'lat': 22.5, 'lng': 114.0});
    expect(await result, isEmpty);
    expect(adapter.requests, isEmpty);
  });
  test(
    'login replacement while locating never sends old account HTTP',
    () async {
      final pending = Completer<Map<String, Object?>>();
      location = () => pending.future;
      final result = expectLater(
        gateway.start(command).events.toList(),
        throwsA(AgentTransportFailure.sessionChanged),
      );
      await Future<void>.delayed(Duration.zero);
      session.credentials = const AccountCredentials('other', 'unused', 2);
      pending.complete({'lat': 22.5, 'lng': 114.0});
      await result;
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'stream diagnostics omit arbitrary IDs, message, token and event text',
    () async {
      await gateway.start(command).events.toList();
      expect(diagnostics.map((e) => e.result), [
        DiagnosticResult.started,
        DiagnosticResult.succeeded,
      ]);
      final encoded = jsonEncode(diagnostics.map((e) => e.toJson()).toList());
      for (final sensitive in [
        '你好',
        '测试',
        'secret-not-used',
        'synthetic',
        '"session"',
      ]) {
        expect(encoded, isNot(contains(sensitive)));
      }
    },
  );
  test('stream incomplete is failure, not success in diagnostics', () async {
    adapter.text = 'event: text_delta\ndata: {"text":"partial"}\n\n';
    await expectLater(
      gateway.start(command).events.toList(),
      throwsA(AgentTransportFailure.incomplete),
    );
    expect(diagnostics.last.result, DiagnosticResult.failed);
  });
  test('diagnostic exception never changes stream output', () async {
    diagnosticFails = true;
    final events = await gateway.start(command).events.toList();
    expect(events.first.text, '你好');
    expect(events.last.kind, AgentEventKind.done);
    expect(adapter.requests.length, 1);
  });
  test('voice channel context identity and no automatic POST replay', () async {
    final events = await gateway.start(command).events.toList();
    expect(events.first.text, '你好');
    expect(events.last.kind, AgentEventKind.done);
    final r = adapter.requests.single;
    expect(r.uri.path, '/aiassistant-api/api/agent/chat/stream');
    expect((r.data as Map)['channel'], 'voice');
    expect((r.data as Map)['idempotencyKey'], 'intent');
    expect((r.data as Map)['initialSkillId'], 'skill');
    expect(r.headers['X-Account-Id'], 'synthetic');
    expect(r.headers['Authorization'], 'Bearer secret-not-used');
    expect(r.followRedirects, false);
  });
  test(
    'EOF without any terminal event requires recovery; final response is sufficient',
    () async {
      adapter.text = 'event: text_delta\ndata: {"text":"partial"}\n\n';
      await expectLater(
        gateway.start(command).events.toList(),
        throwsA(AgentTransportFailure.incomplete),
      );
      expect(adapter.requests.length, 1);
      adapter.text =
          'event: final\ndata: {"sessionId":"session","type":"TEXT_REPLY","text":"ok"}\n\n';
      expect(
        (await gateway.start(command).events.toList()).single.kind,
        AgentEventKind.finalResponse,
      );
    },
  );
  test('wrong content type and foreign session fail closed', () async {
    adapter.contentType = 'application/json';
    await expectLater(
      gateway.start(command).events.toList(),
      throwsA(AgentTransportFailure.malformed),
    );
    adapter.contentType = 'text/event-stream';
    adapter.text = 'event: final\ndata: {"sessionId":"other","text":"x"}\n\n';
    await expectLater(
      gateway.start(command).events.toList(),
      throwsA(AgentTransportFailure.malformed),
    );
  });
  test('account change rejects old live stream events', () async {
    final source = StreamController<Uint8List>();
    adapter.source = source.stream;
    final result = expectLater(
      gateway.start(command).events.toList(),
      throwsA(AgentTransportFailure.sessionChanged),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    session.credentials = const AccountCredentials('other', 'other', 2);
    source.add(Uint8List.fromList(utf8.encode('event: done\ndata: {}\n\n')));
    await result;
    await source.close();
  });
  test(
    'cancel stops transport without reporting business success or an error',
    () async {
      final source = StreamController<Uint8List>();
      adapter.source = source.stream;
      final run = gateway.start(command);
      final events = <AgentEvent>[], errors = <Object>[];
      final sub = run.events.listen(events.add, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      run.cancel();
      await sub.cancel();
      await source.close();
      expect(events, isEmpty);
      expect(errors, isEmpty);
      expect(adapter.requests.length, 1);
    },
  );
  test(
    'ask/options/call-ready remain typed signals and done is not task success',
    () {
      const decoder = AgentEventDecoder();
      for (final entry in {
        'ask_user': 'ASK_USER',
        'options_available': 'SHOW_OPTIONS',
        'call_ready': 'MAKE_CALL_REQUEST',
      }.entries) {
        final e = decoder.decode(
          SseFrame(
            entry.key,
            jsonEncode({
              'sessionId': 'session',
              'displayMessage': 'message',
              'data': {'pendingToolCallId': 'tool'},
            }),
          ),
        );
        expect(e.kind, AgentEventKind.signal);
        expect(e.payload['type'], entry.value);
        expect(e.payload['pendingToolCallId'], 'tool');
      }
      expect(
        decoder.decode(const SseFrame('done', '{}')).kind,
        AgentEventKind.done,
      );
      final failed = decoder.decode(
        const SseFrame(
          'task_failed',
          '{"displayMessage":"失败","data":{"category":"NETWORK"}}',
        ),
      );
      expect(failed.kind, AgentEventKind.error);
      expect(failed.payload['category'], 'NETWORK');
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/conversation/data/artifacts/api_task_artifact_repository.dart';
import 'package:phone_agent/features/conversation/data/confirmation/api_call_confirmation_reply_repository.dart';
import 'package:phone_agent/features/conversation/data/confirmation/api_confirmation_supplement_repository.dart';
import 'package:phone_agent/features/conversation/data/stopping/api_conversation_stop_repository.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/confirmation_supplement.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'task_artifact_test.dart' show descriptor;

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'old',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials)) return false;
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }

  @override
  Future<void> rejectSession(AccountCredentials expected) async {
    credentials = null;
  }
}

class _Keys implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async => const C1Credentials(
    apiKey: 'public-fixture',
    secret: 'public-fixture-secret',
    deviceId: '33333333-3333-4333-8333-333333333333',
    clientContext: 'e30',
  );
}

class _Wire implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? body;
  bool denyOld = false;
  String type =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  Completer<void>? held;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (held != null) await held!.future;
    if (options.path.endsWith('/refresh')) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': '000000',
          'data': {'voiceCloneAccessToken': 'new'},
        }),
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    if (denyOld && options.headers['Authorization'] == 'Bearer old') {
      return ResponseBody.fromString(
        '{}',
        401,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/content')) {
      return ResponseBody.fromBytes(
        [80, 75, 3, 4],
        200,
        headers: {
          'content-type': [type],
          'content-length': ['4'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'code': '000000', 'data': body}),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Session session;
  late _Wire wire;
  late AccountApi api;
  setUp(() {
    session = _Session();
    wire = _Wire();
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/agent',
        sdkApiBaseUrl: 'https://example.test/sdk',
      ),
      session,
      client: Dio()..httpClientAdapter = wire,
      signing: C1Transport(_Keys()),
    );
  });
  tearDown(() => api.close());
  test(
    'binary template download uses Agent C1 and refreshes through SDK with a fresh signature',
    () async {
      wire.denyOld = true;
      final bytes = await ApiTaskArtifactRepository(
        api,
      ).download(TaskArtifact.parse(descriptor)!);
      expect(bytes, [80, 75, 3, 4]);
      expect(wire.requests.map((r) => r.uri.path), [
        '/agent/api/agent-artifacts/skill-template:visa:v1/content',
        '/sdk/api/auth/voice-clone/refresh',
        '/agent/api/agent-artifacts/skill-template:visa:v1/content',
      ]);
      expect(wire.requests.last.headers['Authorization'], 'Bearer new');
      expect(
        wire.requests.first.headers['X-Sign'],
        isNot(wire.requests.last.headers['X-Sign']),
      );
      expect(
        wire.requests.first.headers['X-Reqid'],
        isNot(wire.requests.last.headers['X-Reqid']),
      );
      expect(wire.requests.every((r) => !r.followRedirects), isTrue);
    },
  );
  test(
    'wrong content type and late account download fail before saving',
    () async {
      final repo = ApiTaskArtifactRepository(api),
          artifact = TaskArtifact.parse(descriptor)!;
      wire.type = 'text/html';
      await expectLater(
        repo.download(artifact),
        throwsA(ApiFailure.invalidResponse),
      );
      wire.type = artifact.mimeType;
      wire.held = Completer<void>();
      final pending = repo.download(artifact);
      await Future<void>.delayed(Duration.zero);
      session.credentials = const AccountCredentials('other', 'new', 2);
      wire.held!.complete();
      await expectLater(pending, throwsA(ApiFailure.sessionChanged));
    },
  );
  test(
    'classification, supplements and stop carry the existing account/session contract',
    () async {
      wire.body = {'decision': 'QUESTION', 'answer': '将在指定时间执行'};
      final reply = await ApiCallConfirmationReplyRepository(api).classify((
        accountId: 'synthetic',
        sessionId: 'session',
        toolId: 'tool',
        specSignature: 'spec',
        generation: 1,
        cardText: '任务信息',
      ), '何时执行');
      expect(reply.decision, CallReplyDecision.question);
      expect(
        jsonDecode(wire.requests.last.data as String)['pendingToolCallId'],
        'tool',
      );
      wire.body = {'recordId': 'record', 'eventId': 'event'};
      await ApiConfirmationSupplementRepository(api).save(
        'session',
        const ConfirmationSupplement(
          id: 'record',
          toolId: 'tool',
          userText: '问题',
          assistantText: '回答',
        ),
      );
      wire.body = {'status': 'BATCH_CONFIRMATION_REQUIRED', 'batchId': 'batch'};
      final repo = ApiConversationStopRepository(api, 'synthetic');
      expect(
        (await repo.stop('session', 'command')).status,
        TurnStopStatus.batchConfirmationRequired,
      );
      expect(jsonDecode(wire.requests.last.data as String), {
        'userId': 'synthetic',
        'targetCommandId': 'command',
      });
      wire.body = {
        'sessionId': 'session',
        'batchId': 'batch',
        'status': 'STOPPING',
        'matchedCalls': 2,
        'failedCalls': 1,
      };
      expect((await repo.stopBatch('session', 'batch')).failedCalls, 1);
      wire.body = {
        'sessionId': 'other',
        'batchId': 'batch',
        'status': 'STOPPING',
        'matchedCalls': 2,
        'failedCalls': 1,
      };
      await expectLater(
        repo.stopBatch('session', 'batch'),
        throwsA(ApiFailure.invalidResponse),
      );
    },
  );
}

import 'package:phone_agent/features/voice_clone/domain/clone_request_failure.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/clone_diagnostics.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_verification_repository.dart';
import 'package:phone_agent/features/voice_clone/data/diagnosed_clone_verification.dart';
import 'clone_request_diagnostics_test.dart'
    show EnvelopeApi, identity, initialized, flowId;

class _Credentials implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async => const C1Credentials(
    apiKey: 'public-fixture',
    secret: 'public-secret',
    deviceId: '33333333-3333-4333-8333-333333333333',
    clientContext: 'e30',
  );
}

AccountApi configured(
  EnvelopeApi fake,
  List<DiagnosticEvent> events,
  String prefix,
) => AccountApi(
  AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/aiassistant-api/',
    sdkApiBaseUrl: 'https://example.test$prefix',
  ),
  fake,
  client: Dio()..httpClientAdapter = fake,
  diagnostics: events.add,
  signing: C1Transport(_Credentials()),
);

class _RefreshApi extends EnvelopeApi {
  _RefreshApi(super.events);
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    final refresh = request.uri.path.endsWith('/api/auth/voice-clone/refresh');
    final expired = request.headers['Authorization'] == 'Bearer synthetic';
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data': refresh
            ? {'voiceCloneAccessToken': 'refreshed'}
            : initialized(),
      }),
      refresh || !expired ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }
}

void main() {
  for (final platform in ['iOS', 'android']) {
    for (final prefix in [
      '/',
      '/aiassistant-sdk-api/',
      '/gateway/v2/aiassistant-sdk-api/',
    ]) {
      test(
        '$platform $prefix init400 has endpoint, reason, model flag and actual signed request ID',
        () async {
          final events = <DiagnosticEvent>[];
          final fake = EnvelopeApi(events)
            ..status = 400
            ..envelope = {'code': 400, 'message': 'modelId不能为空'};
          final api = configured(fake, events, prefix);
          addTearDown(api.close);
          addTearDown(fake.api.close);
          final repo = DiagnosedCloneVerification(
            ApiCloneVerificationRepository(api, modelId: 'QWEN_OMNI_PLUS'),
            CloneDiagnostics(events.add, sessionId: flowId, platform: platform),
          );
          await expectLater(
            repo.initialize(identity, 'secret-meta'),
            throwsA(CloneRequestFailure.modelRequired),
          );
          expect(fake.requests, hasLength(1));
          final request = fake.requests.single;
          expect(
            request.uri.path,
            '${prefix}api/account/settings/voice-clone/verification/init',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic');
          final http = events
              .where(
                (e) => e.operation == DiagnosticOperation.voiceCloneRequest,
              )
              .toList();
          expect(http.map((e) => e.result), [
            DiagnosticResult.started,
            DiagnosticResult.failed,
          ]);
          final failure = http.last;
          expect(failure.statusCode, 400);
          expect(
            failure.cloneFlow!.stage,
            DiagnosticCloneStage.verificationInit,
          );
          expect(
            failure.cloneFlow!.reason,
            DiagnosticCloneReason.modelRequired,
          );
          expect(failure.cloneFlow!.requestModelPresent, true);
          expect(failure.sessionId, flowId);
          expect(failure.traceId, request.headers['X-Reqid']);
          expect(failure.cloneFlow!.platform, platform);
          final json = jsonEncode(events.map((v) => v.toJson()).toList());
          for (final secret in [
            'secret-meta',
            identity.number,
            'Bearer',
            'example.test',
            'aiassistant-sdk-api',
            'X-Sign',
          ]) {
            expect(json, isNot(contains(secret)));
          }
        },
      );
    }
  }
  test(
    'gateway init model presence is logged as boolean without model value',
    () async {
      final events = <DiagnosticEvent>[];
      final fake = EnvelopeApi(events)
        ..envelope = {'code': 0, 'data': initialized()};
      final api = configured(fake, events, '/aiassistant-sdk-api/');
      addTearDown(api.close);
      await api.request(
        'api/account/settings/voice-clone/verification/init',
        method: 'POST',
        body: {'modelId': 'private-model', 'metaInfo': 'private-meta'},
      );
      final response = events.last;
      expect(response.cloneFlow!.requestModelPresent, true);
      expect(jsonEncode(response.toJson()), isNot(contains('private')));
      expect(
        DiagnosticEvent.fromJson(
          response.toJson(),
        ).cloneFlow!.requestModelPresent,
        true,
      );
    },
  );
  for (final scenario in [
    'business200',
    'unknown400',
    'timeout',
    'signature',
  ]) {
    test(
      'gateway $scenario retains rejection classification and never replays init',
      () async {
        final events = <DiagnosticEvent>[];
        final fake = EnvelopeApi(events)
          ..status = scenario == 'unknown400' ? 400 : 200
          ..timeout = scenario == 'timeout'
          ..envelope = scenario == 'signature'
              ? {'code': 'AC0007', 'message': 'private-message'}
              : {'code': 400, 'message': 'private-message'};
        final api = configured(fake, events, '/aiassistant-sdk-api/');
        addTearDown(api.close);
        await expectLater(
          api.request(
            'api/account/settings/voice-clone/verification/init',
            method: 'POST',
          ),
          throwsA(
            scenario == 'timeout' ? ApiFailure.network : ApiFailure.rejected,
          ),
        );
        expect(fake.requests, hasLength(1));
        final failed = events.last;
        expect(
          failed.operation,
          scenario == 'timeout'
              ? DiagnosticOperation.accountRequest
              : DiagnosticOperation.voiceCloneRequest,
        );
        final http = events.lastWhere(
          (v) => v.operation == DiagnosticOperation.voiceCloneRequest,
        );
        expect(
          http.cloneFlow!.reason,
          scenario == 'timeout'
              ? DiagnosticCloneReason.timeout
              : scenario == 'signature'
              ? DiagnosticCloneReason.signatureRejected
              : DiagnosticCloneReason.serverRejected,
        );
        expect(http.traceId, fake.requests.single.headers['X-Reqid']);
        expect(jsonEncode(http.toJson()), isNot(contains('private-message')));
      },
    );
  }
  test(
    'gateway401 refresh keeps signed wire path and per-attempt request IDs',
    () async {
      final events = <DiagnosticEvent>[];
      final fake = _RefreshApi(events);
      final api = configured(fake, events, '/aiassistant-sdk-api/');
      addTearDown(api.close);
      final log = CloneDiagnostics(events.add, sessionId: flowId);
      await log.run(
        DiagnosticCloneStage.verificationInit,
        () => api.request(
          'api/account/settings/voice-clone/verification/init',
          method: 'POST',
        ),
      );
      expect(fake.requests.map((v) => v.uri.path), [
        '/aiassistant-sdk-api/api/account/settings/voice-clone/verification/init',
        '/aiassistant-sdk-api/api/auth/voice-clone/refresh',
        '/aiassistant-sdk-api/api/account/settings/voice-clone/verification/init',
      ]);
      final http = events
          .where((e) => e.operation == DiagnosticOperation.voiceCloneRequest)
          .toList();
      expect(http, hasLength(4));
      expect(http.map((e) => e.sessionId).toSet(), {flowId});
      expect(http[1].statusCode, 401);
      expect(http[3].statusCode, 200);
      expect(http[1].traceId, fake.requests[0].headers['X-Reqid']);
      expect(http[3].traceId, fake.requests[2].headers['X-Reqid']);
      expect(http[1].traceId, isNot(http[3].traceId));
    },
  );
  test('logical route uses longest configured base and rejects unknown origin', () {
    final routes = ServiceRoutes(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/gateway/',
        sdkApiBaseUrl: 'https://example.test/gateway/sdk/',
      ),
    );
    expect(
      routes.logicalPathOf(
        Uri.parse(
          'https://example.test/gateway/sdk/api/account/settings/voice-clone/models',
        ),
      ),
      'api/account/settings/voice-clone/models',
    );
    expect(
      () => routes.logicalPathOf(
        Uri.parse(
          'https://other.test/gateway/sdk/api/account/settings/voice-clone/models',
        ),
      ),
      throwsA(ApiFailure.invalidResponse),
    );
  });
}

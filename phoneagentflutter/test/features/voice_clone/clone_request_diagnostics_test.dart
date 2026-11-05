import 'package:phone_agent/features/voice_clone/domain/clone_request_failure.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/clone_diagnostics.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_verification_repository.dart';
import 'package:phone_agent/features/voice_clone/data/diagnosed_clone_verification.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';
import '../../support/synthetic_account_api.dart';

const identity = VerificationIdentity(
  name: 'Synthetic',
  number: '000000200001010005',
);
const flowId = '12345678-1234-4234-8234-123456789abc';
const traceId = '87654321-4321-4321-8321-abcdef123456';

class EnvelopeApi extends SyntheticAccountApi {
  EnvelopeApi(List<DiagnosticEvent> events) : super(diagnostics: events.add);
  Object? envelope = {'code': 0, 'data': {}};
  bool timeout = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (timeout) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
        message: 'secret-exception-text',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(envelope),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, Object?> initialized() => {
  'attemptId': 'attempt',
  'certifyId': 'secret-certify',
  'status': 'INITIATED',
  'expiresAt': '2030-01-01T00:00:00',
  'scriptText': 'secret-script',
};
void main() {
  test(
    'init HTTP400 records exact stage and safe reason without retry or material',
    () async {
      final events = <DiagnosticEvent>[];
      final fake = EnvelopeApi(events)
        ..status = 400
        ..envelope = {'code': 400, 'message': '当前身份已认证，如需更换认证人，请先删除原身份后重新认证'};
      addTearDown(fake.api.close);
      final repo = DiagnosedCloneVerification(
        ApiCloneVerificationRepository(fake.api, modelId: 'QWEN_OMNI_PLUS'),
        CloneDiagnostics(events.add, sessionId: flowId, platform: 'iOS'),
      );
      await expectLater(
        repo.initialize(identity, 'secret-meta'),
        throwsA(CloneRequestFailure.identityLocked),
      );
      expect(fake.requests, hasLength(1));
      final http = events
          .where((v) => v.operation == DiagnosticOperation.voiceCloneRequest)
          .toList();
      expect(http.map((v) => v.result), [
        DiagnosticResult.started,
        DiagnosticResult.failed,
      ]);
      expect(http.last.statusCode, 400);
      expect(http.last.cloneFlow!.stage, DiagnosticCloneStage.verificationInit);
      expect(
        http.last.cloneFlow!.reason,
        DiagnosticCloneReason.identityReplacementRequired,
      );
      expect(
        http.every(
          (v) => v.sessionId == flowId && v.cloneFlow!.platform == 'iOS',
        ),
        true,
      );
      final json = jsonEncode(events.map((v) => v.toJson()).toList());
      for (final value in [
        'Synthetic',
        identity.number,
        'secret-meta',
        '当前身份已认证',
        'Bearer',
        'certNo',
      ]) {
        expect(json, isNot(contains(value)));
      }
    },
  );
  test(
    'unknown server text never escapes; HTTP200 business rejection is failed',
    () async {
      final events = <DiagnosticEvent>[];
      final fake = EnvelopeApi(events)
        ..envelope = {'code': 400, 'message': 'secret-user-token-and-id'};
      addTearDown(fake.api.close);
      await expectLater(
        fake.api.request('api/account/settings/voice-clone/verification/init'),
        throwsA(ApiFailure.rejected),
      );
      final last = events.last;
      expect(last.result, DiagnosticResult.failed);
      expect(last.statusCode, 200);
      expect(last.cloneFlow!.reason, DiagnosticCloneReason.serverRejected);
      expect(jsonEncode(last.toJson()), isNot(contains('secret-user')));
    },
  );
  test(
    'string success envelope and non-clone paths retain existing handling',
    () async {
      final events = <DiagnosticEvent>[];
      final fake = EnvelopeApi(events)
        ..envelope = {'code': '000000', 'data': 5};
      addTearDown(fake.api.close);
      expect(
        await fake.api.request('api/account/settings/voice-clone/models'),
        5,
      );
      expect(events.last.result, DiagnosticResult.succeeded);
      events.clear();
      await fake.api.request('api/points/balance');
      expect(events.map((v) => v.operation), [
        DiagnosticOperation.accountRequest,
      ]);
    },
  );
  test('timeout stays network failure while recording timeout stage', () async {
    final events = <DiagnosticEvent>[];
    final fake = EnvelopeApi(events)..timeout = true;
    addTearDown(fake.api.close);
    await expectLater(
      fake.api.request('api/account/settings/voice-clone/verification/init'),
      throwsA(ApiFailure.network),
    );
    final event = events.firstWhere(
      (v) => v.cloneFlow?.reason == DiagnosticCloneReason.timeout,
    );
    expect(event.cloneFlow!.stage, DiagnosticCloneStage.verificationInit);
    expect(jsonEncode(event.toJson()), isNot(contains('secret-exception')));
    expect(fake.requests, hasLength(1));
  });
  for (final entry in {
    'attemptId': 5,
    'certifyId': null,
    'scriptText': [],
    'expiresAt': 'bad-expiry',
    'status': 'secret-status',
  }.entries) {
    test('init decode reports only field/type: ${entry.key}', () async {
      final events = <DiagnosticEvent>[];
      final fake = EnvelopeApi(events)
        ..envelope = {
          'code': 0,
          'data': initialized()..[entry.key] = entry.value,
        };
      addTearDown(fake.api.close);
      await expectLater(
        DiagnosedCloneVerification(
          ApiCloneVerificationRepository(fake.api, modelId: 'QWEN_OMNI_PLUS'),
          CloneDiagnostics(events.add, sessionId: flowId),
        ).initialize(identity, 'secret-meta'),
        throwsA(ApiFailure.invalidResponse),
      );
      final decode = events.where((v) => v.clone != null).single;
      expect(decode.clone!.field.name, entry.key);
      expect(decode.sessionId, flowId);
      final json = jsonEncode(events.map((v) => v.toJson()).toList());
      expect(json, isNot(contains('secret-certify')));
      expect(json, isNot(contains('bad-expiry')));
      expect(json, isNot(contains('secret-status')));
      expect(fake.requests, hasLength(1));
    });
  }
}

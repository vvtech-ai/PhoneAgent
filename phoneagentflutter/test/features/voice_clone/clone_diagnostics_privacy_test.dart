import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/clone_diagnostics.dart';
import 'package:phone_agent/core/diagnostics/clone_request_diagnostics.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import '../../support/synthetic_account_api.dart';

class _Credentials implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async => const C1Credentials(
    apiKey: 'secret-api-key',
    secret: 'secret-signing-key',
    deviceId: '12345678-1234-4234-8234-123456789abc',
    clientContext: 'e30',
  );
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  test(
    'actual signed request trace survives journal recreation without signed material',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(store);
      addTearDown(journal.close);
      final fake = SyntheticAccountApi();
      final api = AccountApi(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/',
        ),
        fake,
        diagnostics: journal.record,
        client: Dio()..httpClientAdapter = fake,
        signing: C1Transport(
          _Credentials(),
          requestId: () => '87654321-4321-4321-8321-abcdef123456',
        ),
      );
      addTearDown(api.close);
      final log = CloneDiagnostics(
        journal.record,
        sessionId: '12345678-1234-4234-8234-123456789abc',
      );
      await log.run(
        DiagnosticCloneStage.modelDirectory,
        () => api.request('api/account/settings/voice-clone/models'),
      );
      await journal.flush();
      final reopened = DiagnosticJournal(store);
      addTearDown(reopened.close);
      final events = (await reopened.snapshot()).events;
      final response = events.singleWhere(
        (e) =>
            e.operation == DiagnosticOperation.voiceCloneRequest &&
            e.result == DiagnosticResult.succeeded,
      );
      expect(response.traceId, fake.requests.single.headers['X-Reqid']);
      expect(response.sessionId, log.sessionId);
      expect(response.cloneFlow!.stage, DiagnosticCloneStage.modelDirectory);
      final json = jsonEncode(events.map((v) => v.toJson()).toList());
      for (final value in [
        'secret-',
        'Authorization',
        'X-Sign',
        'synthetic',
        'example.test',
        'api/account',
      ]) {
        expect(json, isNot(contains(value)));
      }
    },
  );
  test('imported clone details scrub arbitrary strings and unknown fields', () {
    final original = DiagnosticEvent(
      operation: DiagnosticOperation.voiceCloneFlow,
      result: DiagnosticResult.failed,
      cloneFlow: DiagnosticCloneFlowDetails(
        stage: DiagnosticCloneStage.sdkCapture,
      ),
    ).toJson();
    original['cloneFlow'] = {
      'stage': 'sdkCapture',
      'platform': 'private-platform',
      'state': 'private-id',
      'issue': 'private-reason',
      'sdkSubCode': 'secret-token',
      'sdkCode': 1000000,
      'pollCount': -1,
      'metaInfo': 'secret-meta',
      'message': 'secret-message',
    };
    final safe = DiagnosticEvent.fromJson(original).toJson();
    expect(jsonEncode(safe), isNot(contains('private')));
    expect(jsonEncode(safe), isNot(contains('secret')));
    expect((safe['cloneFlow'] as Map)['sdkCode'], 9999);
    expect((safe['cloneFlow'] as Map)['pollCount'], 0);
  });
  test(
    'all clone route aliases discard model and attempt IDs; neighboring route is ignored',
    () {
      final events = <DiagnosticEvent>[];
      const root = '/api/account/settings/voice-clone';
      final paths = {
        '$root/verification/private-attempt':
            DiagnosticCloneStage.verificationRead,
        '$root/verification/private-attempt/client-observation':
            DiagnosticCloneStage.observation,
        '$root/verification/private-attempt/certified-recording':
            DiagnosticCloneStage.recordingDownload,
        '$root/models/private-model/candidates/from-verification/private-attempt':
            DiagnosticCloneStage.generationVerification,
        '$root/models/private-model/candidates/from-recording':
            DiagnosticCloneStage.generationRecording,
        '$root/models/private-model/candidate/confirm':
            DiagnosticCloneStage.confirmation,
        '$root/models/private-model/clone':
            DiagnosticCloneStage.managementDelete,
        '$root/models/private-model/clone/preview':
            DiagnosticCloneStage.previewDownload,
      };
      for (final entry in paths.entries) {
        CloneRequestDiagnostics(events.add, entry.key).response(
          400,
          {'message': 'unknown-private-message'},
          20,
          'private-trace',
        );
        expect(events.last.cloneFlow!.stage, entry.value);
      }
      final length = events.length;
      CloneRequestDiagnostics(
        events.add,
        '${root}x/models',
      ).response(400, null, 0, '');
      expect(events, hasLength(length));
      expect(
        jsonEncode(events.map((v) => v.toJson()).toList()),
        isNot(contains('private')),
      );
    },
  );
  test(
    'native permission and audio setup diagnoses do not retain messages',
    () {
      for (final entry in {
        'Camera and microphone permission required':
            DiagnosticCloneReason.permissionDenied,
        'Identity audio preparation failed':
            DiagnosticCloneReason.audioPreparation,
        'Identity preparation failed': DiagnosticCloneReason.sdkPreparation,
        'Identity capture failed': DiagnosticCloneReason.sdkCapture,
      }.entries) {
        final events = <DiagnosticEvent>[];
        CloneDiagnostics(events.add).failed(
          DiagnosticCloneStage.sdkCapture,
          PlatformException(
            code: 'capture_unavailable',
            message: entry.key,
            details: 'secret',
          ),
          1,
        );
        expect(events.single.cloneFlow!.reason, entry.value);
        expect(jsonEncode(events.single.toJson()), isNot(contains(entry.key)));
        expect(jsonEncode(events.single.toJson()), isNot(contains('secret')));
      }
    },
  );
}

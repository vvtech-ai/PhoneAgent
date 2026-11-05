import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_candidate_repository.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import '../../support/synthetic_account_api.dart';

class _QualityApi extends SyntheticAccountApi {
  _QualityApi({super.diagnostics});
  String code = 'AC0001';
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode({
        'code': code,
        'message': '录音质量未达标',
        'data': {'stage': 'AUDIO_QUALITY'},
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test(
    'original quality envelope reaches safe clone guidance and diagnostics',
    () async {
      final events = <DiagnosticEvent>[];
      final transport = _QualityApi(diagnostics: events.add)..status = 400;
      addTearDown(transport.api.close);
      await expectLater(
        ApiCloneCandidateRepository(
          transport.api,
          expectedPricePoints: 300,
        ).fromVerification('4', 'attempt', 'request'),
        throwsA(
          isA<CloneGenerationException>().having(
            (e) => e.failure,
            'failure',
            CloneGenerationFailure.audioQuality,
          ),
        ),
      );
      expect(
        events
            .where((e) => e.operation == DiagnosticOperation.voiceCloneRequest)
            .map((e) => e.toJson().toString())
            .join(),
        contains('audioQuality'),
      );
    },
  );
  test(
    'HTTP400 AC0001 exposes only endpoint-allowlisted quality stage',
    () async {
      final transport = _QualityApi()..status = 400;
      addTearDown(transport.api.close);
      await expectLater(
        transport.api.request(
          'api/account/settings/voice-clone',
          exposedDataStages: {'AUDIO_QUALITY'},
        ),
        throwsA(
          isA<ApiCodeFailure>().having((e) => e.code, 'stage', 'AUDIO_QUALITY'),
        ),
      );
      await expectLater(
        transport.api.request('api/account/settings/voice-clone'),
        throwsA(ApiFailure.rejected),
      );
    },
  );

  test(
    'authentication and signing failures never expose a spoofed quality stage',
    () async {
      final transport = _QualityApi()..status = 400;
      addTearDown(transport.api.close);
      for (final code in ['AC0007', 'AC0008', 'AC0009']) {
        transport.code = code;
        await expectLater(
          transport.api.request(
            'api/account/settings/voice-clone',
            exposedDataStages: {'AUDIO_QUALITY'},
          ),
          throwsA(ApiFailure.rejected),
        );
      }
      transport.code = 'AC0001';
      for (final status in [401, 403, 500]) {
        transport.status = status;
        await expectLater(
          transport.api.request(
            'api/account/settings/voice-clone',
            exposedDataStages: {'AUDIO_QUALITY'},
          ),
          throwsA(ApiFailure.rejected),
        );
      }
    },
  );
}

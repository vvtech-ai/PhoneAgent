import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_candidate_repository.dart';
import '../../support/synthetic_account_api.dart';
import 'clone_candidate_api_test.dart' show candidateJson, grantJson, model;

void main() {
  test(
    'HTTP success and optional recording format failure are distinguishable',
    () async {
      final events = <DiagnosticEvent>[];
      final wire = SyntheticAccountApi(diagnostics: events.add);
      addTearDown(wire.api.close);
      wire.data = {
        'candidate': candidateJson(),
        'recording': (grantJson()
          ..['grant'] = 'private-sensitive-grant'
          ..['attemptId'] = 'wrong-attempt'),
      };
      final result = await ApiCloneCandidateRepository(
        wire.api,
        expectedPricePoints: 300,
      ).fromVerification(model, 'attempt-1', 'request-1');
      expect(result.recording, isNull);
      expect(
        events.any(
          (e) =>
              e.operation == DiagnosticOperation.accountRequest &&
              e.result == DiagnosticResult.succeeded,
        ),
        isTrue,
      );
      final grant = events.singleWhere(
        (e) => e.operation == DiagnosticOperation.voiceCloneRecordingGrant,
      );
      expect(grant.result, DiagnosticResult.failed);
      expect(grant.failureKind, DiagnosticFailureKind.format);
      expect(events.last.operation, DiagnosticOperation.voiceCloneGeneration);
      expect(events.last.result, DiagnosticResult.succeeded);
      expect(
        events.map((e) => e.toJson()).toString(),
        isNot(contains('private-sensitive-grant')),
      );
    },
  );
  test('clone stage is typed and survives diagnostic serialization', () {
    final event = DiagnosticEvent(
      operation: DiagnosticOperation.voiceCloneGeneration,
      result: DiagnosticResult.failed,
      voiceCloneStage: DiagnosticVoiceCloneStage.audioQuality,
    );
    final restored = DiagnosticEvent.fromJson(event.toJson());
    expect(restored.voiceCloneStage, DiagnosticVoiceCloneStage.audioQuality);
  });
}

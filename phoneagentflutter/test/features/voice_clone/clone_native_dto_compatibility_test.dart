import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/clone_candidate_mapper.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_candidate_repository.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_completion_port.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_candidate_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_completion_controller.dart';
import '../../support/synthetic_account_api.dart';
import 'clone_candidate_api_test.dart' show candidateJson, model;

void main() {
  test('native scalar strings, missing text and signed Long amounts', () {
    final value = CloneCandidateMapper.candidate({
      'candidateId': 123,
      'displayName': false,
      'chargedPoints': '300',
      'remainingPoints': '-1',
      'lastError': null,
    }, model);
    expect(value.id, '123');
    expect(value.displayName, 'false');
    expect(value.lastError, '');
    expect(value.modelId, model);
    expect(value.chargedPoints, 300);
    expect(value.remainingPoints, -1);
    expect(value.status, CloneCandidateStatus.unknown);
    expect(value.source, CloneCandidateSource.unknown);
    expect(value.billing, CloneBillingStatus.unknown);
    expect(value.ready, false);
    for (final raw in [
      '9007199254740992',
      '9223372036854775807',
      '-9223372036854775808',
      '3e2',
      '300.0',
    ]) {
      final parsed = CloneCandidateMapper.candidate({
        'chargedPoints': raw,
      }, model);
      expect(
        parsed.chargedPoints.toString(),
        raw == '3e2' || raw == '300.0' ? '300' : raw,
      );
    }
    expect(
      CloneCandidateMapper.candidate(<String, dynamic>{}, model).chargedPoints,
      0,
    );
    expect(
      CloneCandidateMapper.candidate(
        <String, dynamic>{},
        model,
      ).remainingPoints,
      null,
    );
  });

  test('unknown wire states remain non-ready and only PROCESSING polls', () {
    for (final status in [null, '', 'NEXT_STATE', 'GENERATING']) {
      final value = CloneCandidateMapper.candidate({
        'status': status,
        'billingStatus': 'NEXT_BILLING',
        'source': 'NEXT_SOURCE',
      }, model);
      expect(value.ready, false);
      expect(value.processing, false);
    }
  });

  test(
    'colon candidate survives generation, poll and confirmation without extra writes',
    () async {
      final wire = SyntheticAccountApi();
      addTearDown(wire.api.close);
      const opaqueId = 'synthetic-account:qwen_omni_plus';
      wire.data = {'candidate': candidateJson()..['candidateId'] = opaqueId};
      final controller = CloneCandidateController(
        repository: ApiCloneCandidateRepository(
          wire.api,
          expectedPricePoints: 300,
        ),
        modelId: model,
        delay: (_) async {
          wire.data = candidateJson()
            ..['candidateId'] = opaqueId
            ..['status'] = 'READY'
            ..['billingStatus'] = 'CHARGED'
            ..['chargedPoints'] = '300';
        },
      );
      addTearDown(controller.dispose);
      await controller.createFromVerification('attempt-1', 'request-1');
      expect(controller.state.candidate!.ready, true);
      expect(controller.state.candidate!.id, opaqueId);
      expect(controller.state.issue, CandidateIssue.none);
      // Native confirmation commits from the endpoint response, not extra READY/CHARGED checks.
      wire.data = {'candidateId': opaqueId};
      final completion = CloneCompletionController(
        candidate: controller.state.candidate!,
        port: ApiCloneCompletionPort(wire.api),
        isCurrent: () => true,
        saveRecording: (_) async {},
      );
      addTearDown(completion.dispose);
      await completion.confirm(save: false);
      expect(completion.state.phase, CloneCompletionPhase.confirmed);
      expect(wire.requests.map((r) => r.method), ['POST', 'GET', 'POST']);
      expect(wire.requests.every((r) => !r.path.contains(opaqueId)), true);
      expect(wire.requests.first.headers['X-Idempotency-Key'], 'attempt-1');
    },
  );

  test(
    'malformed field diagnostic roundtrips without leaking response values',
    () async {
      for (final field in [
        'candidateId',
        'status',
        'source',
        'billingStatus',
        'chargedPoints',
        'updatedAt',
      ]) {
        final events = <DiagnosticEvent>[];
        final wire = SyntheticAccountApi(diagnostics: events.add);
        addTearDown(wire.api.close);
        wire.data = {
          'candidate': candidateJson()..[field] = {'secret': 'private-value'},
        };
        await expectLater(
          ApiCloneCandidateRepository(
            wire.api,
            expectedPricePoints: 300,
          ).fromVerification(model, 'attempt-1', 'request-1'),
          throwsA(ApiFailure.invalidResponse),
        );
        final event = events.singleWhere(
          (e) => e.operation == DiagnosticOperation.voiceCloneCandidateDecode,
        );
        expect(event.clone!.field.name, field);
        expect(event.clone!.type, DiagnosticJsonType.object);
        expect(
          DiagnosticEvent.fromJson(event.toJson()).clone!.field.name,
          field,
        );
        expect(
          events.map((e) => e.toJson()).toString(),
          isNot(contains('private-value')),
        );
        expect(
          events.map((e) => e.toJson()).toString(),
          isNot(contains('secret')),
        );
      }
    },
  );
}

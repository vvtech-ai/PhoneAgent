import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/feedback/data/api_call_evaluation_repository.dart';
import 'package:phone_agent/features/feedback/data/api_task_rating_repository.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  const target = FeedbackTarget(FeedbackTargetKind.call, 'call-1');
  const draft = TaskRatingDraft(
    taskUnderstanding: 5,
    aiCallPerformance: 4,
    taskCompletion: 3,
  );
  Map<String, Object?> eligible({
    String anchor = 'call-1',
    String type = 'CALL',
  }) => {
    'eligible': true,
    'eligibilityId': 'e-1',
    'taskType': 'CALL',
    'taskId': 'task-1',
    'receiptAnchorType': type,
    'receiptAnchorId': anchor,
    'cloneVoiceAvailable': false,
    'rewardEnabled': true,
    'rewardPoints': 10,
  };
  late SyntheticAccountApi wire;
  late ApiTaskRatingRepository ratings;
  setUp(() {
    wire = SyntheticAccountApi();
    ratings = ApiTaskRatingRepository(wire.api);
  });
  tearDown(() => wire.api.close());
  test(
    'GOOD/BAD evaluation uses PUT; call latency and batch range stay separate',
    () async {
      final repo = ApiCallEvaluationRepository(wire.api);
      wire.data = {
        'callId': 'call-1',
        'modelName': ' 模型 ',
        'averageLatencyMs': 90,
        'rating': 'good',
      };
      final call = await repo.load(target);
      expect(call.visible, isTrue);
      expect(call.latencyText, '90ms');
      expect(call.rating, CallRating.good);
      wire.data = {
        'batchId': 'batch-1',
        'modelName': '模型',
        'minimumLatencyMs': 300,
        'maximumLatencyMs': 100,
        'rating': 'BAD',
      };
      final batch = await repo.rate(
        const FeedbackTarget(FeedbackTargetKind.batch, 'batch-1'),
        CallRating.bad,
      );
      expect(batch.latencyText, '100ms～300ms');
      expect(
        wire.requests.last.uri.path,
        '/api/agent-calls/batches/batch-1/evaluation',
      );
      expect(wire.requests.last.method, 'PUT');
      expect(wire.requests.last.data, {'rating': 'BAD'});
      expect(wire.requests.last.headers['Authorization'], 'Bearer synthetic');
      expect(wire.requests.last.headers['X-Account-Id'], 'a');
    },
  );
  test(
    'invalid ID blocks requests; wrong evaluation response is rejected',
    () async {
      final repo = ApiCallEvaluationRepository(wire.api);
      await expectLater(
        repo.load(const FeedbackTarget(FeedbackTargetKind.call, '../b')),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(wire.requests, isEmpty);
      wire.data = {'callId': 'other'};
      await expectLater(repo.load(target), throwsA(ApiFailure.invalidResponse));
    },
  );
  test(
    'rating eligible requires matching stable receipt anchor and bearer/clientVersion',
    () async {
      wire.data = eligible(anchor: 'other');
      expect(
        (await ratings.eligibility(target, clientVersion: '65.0.0')).eligible,
        isFalse,
      );
      wire.data = eligible(type: 'BATCH');
      expect(
        (await ratings.eligibility(target, clientVersion: '65.0.0')).eligible,
        isFalse,
      );
      wire.data = eligible();
      expect(
        (await ratings.eligibility(target, clientVersion: '65.0.0')).eligible,
        isTrue,
      );
      expect(wire.requests.last.uri.queryParameters, {
        'clientVersion': '65.0.0',
      });
      expect(wire.requests.last.headers['Authorization'], 'Bearer synthetic');
    },
  );
  test(
    'scores/Unicode suggestions valid; clone exclusion mutually exclusive',
    () {
      expect(draft.valid(cloneVoiceAvailable: false), isTrue);
      expect(draft.valid(cloneVoiceAvailable: true), isFalse);
      final emoji = TaskRatingDraft(
        taskUnderstanding: 5,
        aiCallPerformance: 4,
        taskCompletion: 3,
        suggestion: '😀' * 300,
      );
      expect(emoji.valid(cloneVoiceAvailable: false), isTrue);
      expect(
        TaskRatingDraft(
          taskUnderstanding: 5,
          aiCallPerformance: 4,
          taskCompletion: 3,
          suggestion: '😀' * 301,
        ).valid(cloneVoiceAvailable: false),
        isFalse,
      );
      expect(
        const TaskRatingDraft(
          taskUnderstanding: 0,
          aiCallPerformance: 4,
          taskCompletion: 3,
        ).valid(cloneVoiceAvailable: false),
        isFalse,
      );
      expect(
        const TaskRatingDraft(
          taskUnderstanding: 5,
          aiCallPerformance: 4,
          taskCompletion: 3,
          cloneVoiceNotEvaluated: true,
          cloneVoicePerformance: 5,
        ).valid(cloneVoiceAvailable: true),
        isFalse,
      );
    },
  );
  test(
    'submit needs currentSubmission; explicit retry preserves caller key, no local reward',
    () async {
      wire.data = eligible();
      final permission = await ratings.eligibility(
        target,
        clientVersion: '65.0.0',
      );
      wire.status = 500;
      await expectLater(
        ratings.submit(permission, draft, idempotencyKey: 'fixed-key'),
        throwsA(ApiFailure.rejected),
      );
      wire.status = 200;
      await expectLater(
        ratings.submit(permission, draft, idempotencyKey: 'fixed-key'),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(
        wire.requests
            .skip(1)
            .every((r) => (r.data as Map)['idempotencyKey'] == 'fixed-key'),
        isTrue,
      );
      expect(
        (wire.requests.last.data as Map)['cloneVoiceNotEvaluated'],
        isTrue,
      );
      expect((wire.requests.last.data as Map)['cloneVoicePerformance'], isNull);
      wire.data = {
        ...eligible(),
        'currentSubmission': {
          'version': 1,
          'taskUnderstanding': 5,
          'aiCallPerformance': 4,
          'taskCompletion': 3,
          'cloneVoiceNotEvaluated': true,
          'rewardGranted': false,
        },
      };
      final saved = await ratings.submit(
        permission,
        draft,
        idempotencyKey: 'fixed-key',
      );
      expect(saved.version, 1);
      expect(saved.rewardGranted, isFalse);
      expect(
        wire.requests.last.uri.path,
        '/api/task-ratings/eligibilities/e-1/submissions',
      );
      final submitted = await ratings.eligibility(
        target,
        clientVersion: '65.0.0',
      );
      expect(submitted.readOnly, isTrue);
      expect(submitted.grantedPoints, isNull);
      final requestCount = wire.requests.length;
      await expectLater(
        ratings.submit(submitted, draft, idempotencyKey: 'new-key'),
        throwsArgumentError,
      );
      expect(wire.requests.length, requestCount);
    },
  );
  test(
    'batch qualification uses batch anchor, never reuses single-call eligibility',
    () async {
      wire.data = eligible(anchor: 'batch-1', type: 'BATCH');
      final allowed = await ratings.eligibility(
        const FeedbackTarget(FeedbackTargetKind.batch, 'batch-1'),
        clientVersion: '65.0.0',
      );
      expect(allowed.eligible, isTrue);
      expect(wire.requests.last.uri.path, '/api/task-ratings/batches/batch-1');
      wire.data = {...eligible(), 'eligible': false};
      final hidden = await ratings.eligibility(target, clientVersion: '65.0.0');
      final count = wire.requests.length;
      await expectLater(
        ratings.submit(hidden, draft, idempotencyKey: 'key'),
        throwsArgumentError,
      );
      expect(wire.requests.length, count);
    },
  );
}

import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/call_evaluation.dart';
import '../domain/task_rating.dart';
import 'feedback_json.dart';

class ApiTaskRatingRepository implements TaskRatingRepository {
  ApiTaskRatingRepository(this._api);
  final AccountApi _api;
  @override
  Future<TaskRatingEligibility> eligibility(
    FeedbackTarget target, {
    required String clientVersion,
  }) async {
    final id = FeedbackJson.safeId(target.id);
    if (clientVersion.trim().isEmpty) {
      throw ArgumentError('Missing client version');
    }
    final m = AccountApi.object(
      await _api.request(
        'api/task-ratings/${target.collection}/$id',
        query: {'clientVersion': clientVersion},
      ),
    );
    final dto = FeedbackJson(m);
    final stableId = dto.text('eligibilityId'),
        taskType = dto.text('taskType'),
        taskId = dto.text('taskId');
    return TaskRatingEligibility(
      target: target,
      eligible:
          dto.flag('eligible') &&
          stableId.isNotEmpty &&
          taskType.isNotEmpty &&
          taskId.isNotEmpty &&
          dto.text('receiptAnchorType').toUpperCase() == target.anchorType &&
          dto.text('receiptAnchorId') == target.id,
      id: stableId,
      taskType: taskType,
      taskId: taskId,
      status: dto.text('status'),
      cloneVoiceAvailable: dto.flag('cloneVoiceAvailable'),
      rewardEnabled: dto.flag('rewardEnabled'),
      rewardPoints: dto.integer('rewardPoints'),
      currentSubmission: m['currentSubmission'] == null
          ? null
          : _submission(m['currentSubmission']),
    );
  }

  @override
  Future<TaskRatingSubmission> submit(
    TaskRatingEligibility eligibility,
    TaskRatingDraft draft, {
    required String idempotencyKey,
  }) async {
    final id = FeedbackJson.safeId(eligibility.id);
    if (!eligibility.eligible ||
        eligibility.readOnly ||
        idempotencyKey.trim().isEmpty ||
        !draft.valid(cloneVoiceAvailable: eligibility.cloneVoiceAvailable)) {
      throw ArgumentError('Invalid rating submission');
    }
    final m = AccountApi.object(
      await _api.request(
        'api/task-ratings/eligibilities/$id/submissions',
        method: 'POST',
        body: {
          'taskUnderstanding': draft.taskUnderstanding,
          'aiCallPerformance': draft.aiCallPerformance,
          'taskCompletion': draft.taskCompletion,
          'cloneVoicePerformance': eligibility.cloneVoiceAvailable
              ? draft.cloneVoicePerformance
              : null,
          'cloneVoiceNotEvaluated':
              !eligibility.cloneVoiceAvailable || draft.cloneVoiceNotEvaluated,
          'suggestion': draft.suggestion.trim().isEmpty
              ? null
              : draft.suggestion.trim(),
          'idempotencyKey': idempotencyKey,
        },
      ),
    );
    final returnedId = FeedbackJson(m).text('eligibilityId');
    if (returnedId.isNotEmpty && returnedId != id) {
      throw ApiFailure.invalidResponse;
    }
    return _submission(m['currentSubmission']);
  }

  TaskRatingSubmission _submission(Object? data) {
    final m = FeedbackJson(AccountApi.object(data));
    return TaskRatingSubmission(
      version: m.integer('version') ?? 0,
      draft: TaskRatingDraft(
        taskUnderstanding: m.integer('taskUnderstanding'),
        aiCallPerformance: m.integer('aiCallPerformance'),
        taskCompletion: m.integer('taskCompletion'),
        cloneVoicePerformance: m.integer('cloneVoicePerformance'),
        cloneVoiceNotEvaluated: m.flag('cloneVoiceNotEvaluated'),
        suggestion: m.text('suggestion'),
      ),
      rewardGranted: m.flag('rewardGranted'),
      rewardStatus: m.text('rewardStatus').isEmpty
          ? 'NOT_APPLICABLE'
          : m.text('rewardStatus'),
    );
  }
}

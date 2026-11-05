import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';

// Explicit in-memory demonstration. No HTTP clients, account or persistent store.
class PreviewEvaluationRepository implements CallEvaluationRepository {
  CallRating? _rating;
  @override
  Future<CallEvaluation> load(FeedbackTarget target) async => CallEvaluation(
    target: target,
    modelName: 'MOCK 模型',
    minimumLatencyMs: 120,
    maximumLatencyMs: 240,
    rating: _rating,
  );
  @override
  Future<CallEvaluation> rate(FeedbackTarget target, CallRating rating) async {
    _rating = rating;
    return load(target);
  }
}

class PreviewTaskRatingRepository implements TaskRatingRepository {
  bool failNext = true;
  TaskRatingSubmission? _submitted;
  @override
  Future<TaskRatingEligibility> eligibility(
    FeedbackTarget target, {
    required String clientVersion,
  }) async => TaskRatingEligibility(
    target: target,
    eligible: true,
    id: 'mock-eligibility',
    taskId: 'mock-task',
    taskType: 'SINGLE',
    cloneVoiceAvailable: true,
    rewardEnabled: true,
    rewardPoints: 7,
    currentSubmission: _submitted,
  );
  @override
  Future<TaskRatingSubmission> submit(
    TaskRatingEligibility eligibility,
    TaskRatingDraft draft, {
    required String idempotencyKey,
  }) async {
    if (failNext) {
      failNext = false;
      throw StateError('MOCK first submit failure');
    }
    return _submitted = TaskRatingSubmission(
      version: 1,
      draft: draft,
      rewardGranted: true,
    );
  }
}

class PreviewRatingDraftStore implements TaskRatingDraftStore {
  SavedRatingDraft? _saved;
  @override
  Future<SavedRatingDraft?> read(TaskRatingEligibility eligibility) async =>
      _saved;
  @override
  Future<void> save(
    TaskRatingEligibility eligibility,
    SavedRatingDraft draft,
  ) async {
    _saved = draft;
  }

  @override
  Future<void> clear(TaskRatingEligibility eligibility) async {
    _saved = null;
  }
}

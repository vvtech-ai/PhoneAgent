import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import 'shell_receipt_seeds.dart';

/// Synthetic external service and draft store, strictly keyed by receipt target.
/// Never changes the wallet balance; reward fields are sample responses only.
class ShellFeedbackPorts
    implements
        CallEvaluationRepository,
        TaskRatingRepository,
        TaskRatingDraftStore {
  final _ratings = <FeedbackTarget, CallRating>{};
  final _drafts = <FeedbackTarget, SavedRatingDraft>{};
  final _submitted = <FeedbackTarget, TaskRatingSubmission>{};
  final submitKeys = <String>[];
  bool _failNext = true, _closed = false;

  void close() {
    _closed = true;
    _ratings.clear();
    _drafts.clear();
    _submitted.clear();
    submitKeys.clear();
  }

  void _check(FeedbackTarget target) {
    if (_closed ||
        !const [
          ShellReceiptSeeds.singleTarget,
          ShellReceiptSeeds.batchTarget,
        ].contains(target)) {
      throw StateError('Unknown or closed MOCK feedback target');
    }
  }

  @override
  Future<CallEvaluation> load(FeedbackTarget target) async {
    _check(target);
    return CallEvaluation(
      target: target,
      modelName: 'MOCK 模型',
      minimumLatencyMs: 120,
      maximumLatencyMs: 240,
      rating: _ratings[target],
    );
  }

  @override
  Future<CallEvaluation> rate(FeedbackTarget target, CallRating rating) async {
    _check(target);
    _ratings[target] = rating;
    return load(target);
  }

  @override
  Future<TaskRatingEligibility> eligibility(
    FeedbackTarget target, {
    required String clientVersion,
  }) async {
    _check(target);
    final eligible = target == ShellReceiptSeeds.singleTarget;
    return TaskRatingEligibility(
      target: target,
      eligible: eligible,
      id: 'mock-eligibility-${target.id}',
      taskId: 'mock-task-${target.id}',
      taskType: eligible ? 'SINGLE' : 'BATCH',
      cloneVoiceAvailable: eligible,
      rewardEnabled: eligible,
      rewardPoints: eligible ? 7 : null,
      currentSubmission: _submitted[target],
    );
  }

  @override
  Future<TaskRatingSubmission> submit(
    TaskRatingEligibility eligibility,
    TaskRatingDraft draft, {
    required String idempotencyKey,
  }) async {
    _check(eligibility.target);
    if (eligibility.target != ShellReceiptSeeds.singleTarget ||
        !draft.valid(cloneVoiceAvailable: true)) {
      throw StateError('Invalid MOCK rating');
    }
    submitKeys.add(idempotencyKey);
    if (_submitted[eligibility.target] case final existing?) return existing;
    if (_failNext) {
      _failNext = false;
      throw StateError('MOCK first submission failure');
    }
    return _submitted[eligibility.target] = TaskRatingSubmission(
      version: 1,
      draft: draft,
      rewardStatus: 'GRANTED',
      rewardGranted: true,
    );
  }

  @override
  Future<SavedRatingDraft?> read(TaskRatingEligibility eligibility) async {
    _check(eligibility.target);
    return _drafts[eligibility.target];
  }

  @override
  Future<void> save(
    TaskRatingEligibility eligibility,
    SavedRatingDraft draft,
  ) async {
    _check(eligibility.target);
    _drafts[eligibility.target] = draft;
  }

  @override
  Future<void> clear(TaskRatingEligibility eligibility) async {
    _check(eligibility.target);
    _drafts.remove(eligibility.target);
  }
}

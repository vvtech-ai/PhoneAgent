import 'dart:async';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';

const ratingTarget = FeedbackTarget(FeedbackTargetKind.call, 'synthetic-call');
const completeRating = TaskRatingDraft(
  taskUnderstanding: 4,
  aiCallPerformance: 3,
  taskCompletion: 5,
  cloneVoiceNotEvaluated: true,
);
TaskRatingEligibility ratingEligibility({
  bool eligible = true,
  bool clone = false,
  TaskRatingSubmission? submission,
}) => TaskRatingEligibility(
  target: ratingTarget,
  eligible: eligible,
  id: 'synthetic-eligibility',
  taskType: 'SINGLE',
  taskId: 'synthetic-task',
  cloneVoiceAvailable: clone,
  rewardEnabled: true,
  rewardPoints: 7,
  currentSubmission: submission,
);

class FakeRatingRepository implements TaskRatingRepository {
  TaskRatingEligibility result = ratingEligibility();
  bool fail = false, grant = true;
  Completer<TaskRatingSubmission>? gate;
  final keys = <String>[];
  @override
  Future<TaskRatingEligibility> eligibility(
    FeedbackTarget target, {
    required String clientVersion,
  }) async => result;
  @override
  Future<TaskRatingSubmission> submit(
    TaskRatingEligibility eligibility,
    TaskRatingDraft draft, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (fail) throw StateError('synthetic failure');
    return gate?.future ??
        Future.value(
          TaskRatingSubmission(version: 1, draft: draft, rewardGranted: grant),
        );
  }
}

class FakeRatingDraftStore implements TaskRatingDraftStore {
  SavedRatingDraft? saved;
  bool failSave = false, failClear = false;
  @override
  Future<SavedRatingDraft?> read(TaskRatingEligibility eligibility) async =>
      saved;
  @override
  Future<void> save(
    TaskRatingEligibility eligibility,
    SavedRatingDraft draft,
  ) async {
    if (failSave) throw StateError('synthetic storage failure');
    saved = draft;
  }

  @override
  Future<void> clear(TaskRatingEligibility eligibility) async {
    if (failClear) throw StateError('synthetic clear failure');
    saved = null;
  }
}

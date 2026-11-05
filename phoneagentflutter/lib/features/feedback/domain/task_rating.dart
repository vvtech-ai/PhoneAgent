import 'call_evaluation.dart';

class TaskRatingSubmission {
  const TaskRatingSubmission({
    required this.version,
    required this.draft,
    this.rewardStatus = 'NOT_APPLICABLE',
    this.rewardGranted = false,
  });
  final int version;
  final TaskRatingDraft draft;
  final String rewardStatus;
  final bool rewardGranted;
}

class TaskRatingEligibility {
  const TaskRatingEligibility({
    required this.target,
    required this.eligible,
    this.id = '',
    this.taskType = '',
    this.taskId = '',
    this.status = '',
    this.cloneVoiceAvailable = false,
    this.rewardEnabled = false,
    this.rewardPoints,
    this.currentSubmission,
  });
  final FeedbackTarget target;
  final bool eligible, cloneVoiceAvailable, rewardEnabled;
  final String id, taskType, taskId, status;
  final int? rewardPoints;
  final TaskRatingSubmission? currentSubmission;
  bool get readOnly => currentSubmission != null;
  int? get grantedPoints =>
      rewardEnabled &&
          currentSubmission?.rewardGranted == true &&
          (rewardPoints ?? 0) > 0
      ? rewardPoints
      : null;
}

class TaskRatingDraft {
  const TaskRatingDraft({
    this.taskUnderstanding,
    this.aiCallPerformance,
    this.taskCompletion,
    this.cloneVoicePerformance,
    this.cloneVoiceNotEvaluated = false,
    this.suggestion = '',
  });
  final int? taskUnderstanding,
      aiCallPerformance,
      taskCompletion,
      cloneVoicePerformance;
  final bool cloneVoiceNotEvaluated;
  final String suggestion;
  bool valid({required bool cloneVoiceAvailable}) {
    bool score(int? n) => n != null && n >= 1 && n <= 5;
    return score(taskUnderstanding) &&
        score(aiCallPerformance) &&
        score(taskCompletion) &&
        suggestion.runes.length <= 300 &&
        (!cloneVoiceAvailable ||
            (cloneVoiceNotEvaluated
                ? cloneVoicePerformance == null
                : score(cloneVoicePerformance)));
  }
}

abstract interface class TaskRatingRepository {
  Future<TaskRatingEligibility> eligibility(
    FeedbackTarget target, {
    required String clientVersion,
  });
  Future<TaskRatingSubmission> submit(
    TaskRatingEligibility eligibility,
    TaskRatingDraft draft, {
    required String idempotencyKey,
  });
}

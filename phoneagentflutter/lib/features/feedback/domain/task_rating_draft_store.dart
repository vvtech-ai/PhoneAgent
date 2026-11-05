import 'task_rating.dart';

enum RatingDimension { understanding, call, clone, completion }

extension EditTaskRatingDraft on TaskRatingDraft {
  TaskRatingDraft edit({
    RatingDimension? dimension,
    int? score,
    bool? skipClone,
    String? text,
  }) => TaskRatingDraft(
    taskUnderstanding: dimension == RatingDimension.understanding
        ? score
        : taskUnderstanding,
    aiCallPerformance: dimension == RatingDimension.call
        ? score
        : aiCallPerformance,
    taskCompletion: dimension == RatingDimension.completion
        ? score
        : taskCompletion,
    cloneVoicePerformance: skipClone == true
        ? null
        : dimension == RatingDimension.clone
        ? score
        : cloneVoicePerformance,
    cloneVoiceNotEvaluated: dimension == RatingDimension.clone
        ? false
        : skipClone ?? cloneVoiceNotEvaluated,
    suggestion: text ?? suggestion,
  );
}

class SavedRatingDraft {
  const SavedRatingDraft(this.draft, {this.submissionKey = ''});
  final TaskRatingDraft draft;
  final String submissionKey;
}

abstract interface class TaskRatingDraftStore {
  Future<SavedRatingDraft?> read(TaskRatingEligibility eligibility);
  Future<void> save(TaskRatingEligibility eligibility, SavedRatingDraft draft);
  Future<void> clear(TaskRatingEligibility eligibility);
}

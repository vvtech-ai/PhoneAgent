import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/call_evaluation.dart';

class CallEvaluationState {
  const CallEvaluationState({
    this.evaluation,
    this.saving = false,
    this.error = '',
  });
  final CallEvaluation? evaluation;
  final bool saving;
  final String error;
}

class CallEvaluationController extends StateNotifier<CallEvaluationState> {
  CallEvaluationController(this.target, this._repository)
    : super(const CallEvaluationState());
  final FeedbackTarget target;
  final CallEvaluationRepository _repository;
  int _generation = 0;

  Future<void> load() async {
    if (!mounted || state.saving) return;
    final generation = ++_generation;
    try {
      final evaluation = await _repository.load(target);
      if (!mounted || generation != _generation) return;
      if (evaluation.target != target) {
        throw StateError('Evaluation owner mismatch');
      }
      state = CallEvaluationState(evaluation: evaluation);
    } catch (_) {
      // v65 hides an unavailable card; it never invents a model or latency.
      if (mounted && generation == _generation) {
        state = const CallEvaluationState();
      }
    }
  }

  Future<void> rate(CallRating rating) async {
    if (!mounted) return;
    final previous = state.evaluation;
    if (state.saving || previous?.visible != true) return;
    final generation = ++_generation;
    state = CallEvaluationState(
      saving: true,
      evaluation: CallEvaluation(
        target: target,
        modelName: previous!.modelName,
        minimumLatencyMs: previous.minimumLatencyMs,
        maximumLatencyMs: previous.maximumLatencyMs,
        rating: rating,
      ),
    );
    try {
      final result = await _repository.rate(target, rating);
      if (!mounted || generation != _generation) return;
      if (result.target != target) {
        throw StateError('Evaluation owner mismatch');
      }
      state = CallEvaluationState(evaluation: result);
    } catch (_) {
      if (mounted && generation == _generation) {
        state = CallEvaluationState(evaluation: previous, error: '评价提交失败，请重试');
      }
    }
  }
}

enum FeedbackTargetKind { call, batch }

class FeedbackTarget {
  const FeedbackTarget(this.kind, this.id);
  final FeedbackTargetKind kind;
  final String id;
  @override
  bool operator ==(Object other) =>
      other is FeedbackTarget && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
  String get anchorType => kind == FeedbackTargetKind.call ? 'CALL' : 'BATCH';
  String get collection =>
      kind == FeedbackTargetKind.call ? 'calls' : 'batches';
}

enum CallRating { good, bad }

extension CallRatingWire on CallRating {
  String get wire => this == CallRating.good ? 'GOOD' : 'BAD';
}

class CallEvaluation {
  const CallEvaluation({
    required this.target,
    required this.modelName,
    this.minimumLatencyMs,
    this.maximumLatencyMs,
    this.rating,
  });
  final FeedbackTarget target;
  final String modelName;
  final int? minimumLatencyMs, maximumLatencyMs;
  final CallRating? rating;
  bool get visible => modelName.isNotEmpty;
  String get latencyText {
    final values = [
      minimumLatencyMs,
      maximumLatencyMs,
    ].whereType<int>().where((n) => n >= 0).toList()..sort();
    if (values.isEmpty) return '--';
    return values.first == values.last
        ? '${values.first}ms'
        : '${values.first}ms～${values.last}ms';
  }
}

abstract interface class CallEvaluationRepository {
  Future<CallEvaluation> load(FeedbackTarget target);
  Future<CallEvaluation> rate(FeedbackTarget target, CallRating rating);
}

import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/call_evaluation.dart';
import 'feedback_json.dart';

class ApiCallEvaluationRepository implements CallEvaluationRepository {
  ApiCallEvaluationRepository(this._api);
  final AccountApi _api;
  @override
  Future<CallEvaluation> load(FeedbackTarget target) => _request(target);
  @override
  Future<CallEvaluation> rate(FeedbackTarget target, CallRating rating) =>
      _request(target, rating);
  Future<CallEvaluation> _request(
    FeedbackTarget target, [
    CallRating? rating,
  ]) async {
    final id = FeedbackJson.safeId(target.id);
    final batch = target.kind == FeedbackTargetKind.batch;
    final dto = FeedbackJson(
      AccountApi.object(
        await _api.request(
          'api/agent-calls/${batch ? 'batches/' : ''}$id/evaluation',
          method: rating == null ? 'GET' : 'PUT',
          body: rating == null ? null : {'rating': rating.wire},
        ),
      ),
    );
    if (dto.text(batch ? 'batchId' : 'callId') != id) {
      throw ApiFailure.invalidResponse;
    }
    final value = dto.text('rating').toUpperCase();
    return CallEvaluation(
      target: target,
      modelName: dto.text('modelName'),
      minimumLatencyMs: dto.integer(
        batch ? 'minimumLatencyMs' : 'averageLatencyMs',
      ),
      maximumLatencyMs: dto.integer(
        batch ? 'maximumLatencyMs' : 'averageLatencyMs',
      ),
      rating: value == 'GOOD'
          ? CallRating.good
          : value == 'BAD'
          ? CallRating.bad
          : null,
    );
  }
}

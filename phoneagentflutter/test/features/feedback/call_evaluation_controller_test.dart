import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/presentation/controller/call_evaluation_controller.dart';

const target = FeedbackTarget(FeedbackTargetKind.call, 'synthetic-call');
CallEvaluation evaluation({
  CallRating? rating,
  FeedbackTarget owner = target,
}) => CallEvaluation(target: owner, modelName: '合成模型', rating: rating);

void main() {
  test(
    'equal server anchors share identity; call and batch remain distinct',
    () {
      expect(
        target,
        const FeedbackTarget(FeedbackTargetKind.call, 'synthetic-call'),
      );
      final anchors = <FeedbackTarget>{target};
      anchors.add(
        const FeedbackTarget(FeedbackTargetKind.call, 'synthetic-call'),
      );
      expect(anchors, hasLength(1));
      expect(
        target,
        isNot(const FeedbackTarget(FeedbackTargetKind.batch, 'synthetic-call')),
      );
    },
  );
  test(
    'unavailable and mismatched load hide card, never invent data',
    () async {
      final repo = _Repository()..failLoad = true;
      final controller = CallEvaluationController(target, repo);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.evaluation, isNull);
      repo.failLoad = false;
      repo.owner = const FeedbackTarget(FeedbackTargetKind.call, 'other');
      await controller.load();
      expect(controller.state.evaluation, isNull);
      await controller.rate(CallRating.good);
      expect(repo.ratings, isEmpty);
    },
  );
  test(
    'optimistic selection is single flight and server response wins',
    () async {
      final repo = _Repository()..pending = Completer<CallEvaluation>();
      final controller = CallEvaluationController(target, repo);
      addTearDown(controller.dispose);
      await controller.load();
      final saving = controller.rate(CallRating.good);
      expect(controller.state.saving, isTrue);
      expect(controller.state.evaluation!.rating, CallRating.good);
      await controller.rate(CallRating.bad);
      await controller.load();
      expect(repo.loads, 1);
      expect(repo.ratings, [CallRating.good]);
      repo.pending!.complete(evaluation(rating: CallRating.good));
      await saving;
      expect(controller.state.saving, isFalse);
      expect(controller.state.evaluation!.rating, CallRating.good);
    },
  );
  test(
    'failed submission restores previous selection; explicit retry allowed',
    () async {
      final repo = _Repository()..failRate = true;
      final controller = CallEvaluationController(target, repo);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.rate(CallRating.bad);
      expect(controller.state.evaluation!.rating, isNull);
      expect(controller.state.error, isNotEmpty);
      repo.failRate = false;
      await controller.rate(CallRating.good);
      expect(controller.state.error, isEmpty);
      expect(controller.state.evaluation!.rating, CallRating.good);
    },
  );
  test(
    'wrong owner response is rejected; late completion after dispose is ignored',
    () async {
      final repo = _Repository();
      final controller = CallEvaluationController(target, repo);
      await controller.load();
      repo.owner = const FeedbackTarget(FeedbackTargetKind.batch, 'other');
      await controller.rate(CallRating.good);
      expect(controller.state.error, isNotEmpty);
      expect(controller.state.evaluation!.target, target);
      repo.pending = Completer<CallEvaluation>();
      final saving = controller.rate(CallRating.bad);
      controller.dispose();
      repo.pending!.complete(evaluation(rating: CallRating.bad));
      await saving;
      await controller.load();
      await controller.rate(CallRating.good);
      expect(repo.ratings, [CallRating.good, CallRating.bad]);
    },
  );
}

class _Repository implements CallEvaluationRepository {
  bool failLoad = false, failRate = false;
  int loads = 0;
  FeedbackTarget owner = target;
  Completer<CallEvaluation>? pending;
  final ratings = <CallRating>[];
  @override
  Future<CallEvaluation> load(FeedbackTarget target) async {
    loads++;
    if (failLoad) throw StateError('synthetic load failure');
    return evaluation(owner: owner);
  }

  @override
  Future<CallEvaluation> rate(FeedbackTarget target, CallRating rating) async {
    ratings.add(rating);
    if (failRate) throw StateError('synthetic submit failure');
    return pending?.future ??
        Future.value(evaluation(owner: owner, rating: rating));
  }
}

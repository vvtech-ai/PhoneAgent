import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import '../../support/rating_fakes.dart';

void main() {
  late FakeRatingRepository repo;
  late FakeRatingDraftStore store;
  late TaskRatingController controller;
  var refreshed = 0, key = 0;
  setUp(() {
    repo = FakeRatingRepository();
    store = FakeRatingDraftStore();
    refreshed = 0;
    key = 0;
    controller = TaskRatingController(
      target: ratingTarget,
      repository: repo,
      drafts: store,
      clientVersion: '1.0.0',
      newKey: () => 'synthetic-${++key}',
      onSubmitted: () async {
        refreshed++;
      },
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test(
    'eligibility controls visibility and duplicate card has a single owner',
    () async {
      final a = Object(), b = Object();
      controller.claim(a);
      controller.claim(b);
      await controller.load();
      expect(controller.state.owner, same(a));
      controller.release(b);
      expect(controller.state.owner, same(a));
      controller.release(a);
      controller.claim(b);
      expect(controller.state.owner, same(b));
      repo.result = ratingEligibility(eligible: false);
      await controller.load();
      expect(controller.state.visible, isFalse);
      controller.open();
      expect(controller.state.sheetOpen, isFalse);
    },
  );
  test(
    'no default scores; clone mutually exclusive; Unicode limit enforced',
    () async {
      repo.result = ratingEligibility(clone: true);
      await controller.load();
      controller.open();
      expect(controller.state.canSubmit, isFalse);
      for (final d in RatingDimension.values) {
        controller.rate(d, 4);
      }
      expect(controller.state.canSubmit, isTrue);
      controller.skipClone(true);
      expect(controller.state.draft.cloneVoicePerformance, isNull);
      controller.rate(RatingDimension.clone, 3);
      expect(controller.state.draft.cloneVoiceNotEvaluated, isFalse);
      controller.suggestion('😀' * 300);
      expect(controller.state.canSubmit, isTrue);
      controller.suggestion('😀' * 301);
      expect(controller.state.canSubmit, isFalse);
      await controller.submit();
      expect(repo.keys, isEmpty);
    },
  );
  test(
    'restored stable key survives failure/retry; edit starts a new operation',
    () async {
      store.saved = const SavedRatingDraft(
        completeRating,
        submissionKey: 'stable-before-restart',
      );
      repo.fail = true;
      await controller.load();
      controller.open();
      await controller.submit();
      await controller.submit();
      expect(repo.keys, ['stable-before-restart', 'stable-before-restart']);
      controller.suggestion('补充建议');
      await controller.submit();
      expect(repo.keys.last, 'synthetic-1');
      repo.fail = false;
      await controller.submit();
      expect(repo.keys.last, 'synthetic-1');
      expect(controller.state.readOnly, isTrue);
      expect(controller.grantedPoints, 7);
      expect(refreshed, 1);
      expect(store.saved, isNull);
      controller.open();
      controller.rate(RatingDimension.call, 1);
      await controller.submit();
      expect(controller.state.draft.aiCallPerformance, 3);
      expect(repo.keys, hasLength(4));
    },
  );
  test(
    'storage failure prevents POST; busy state blocks close/edit/duplicate',
    () async {
      store.saved = const SavedRatingDraft(completeRating);
      await controller.load();
      controller.open();
      store.failSave = true;
      await controller.submit();
      expect(repo.keys, isEmpty);
      expect(controller.state.error, isNotEmpty);
      store.failSave = false;
      repo.gate = Completer<TaskRatingSubmission>();
      final saving = controller.submit();
      await Future<void>.delayed(Duration.zero);
      controller.close();
      controller.suggestion('not accepted');
      await controller.submit();
      expect(controller.state.sheetOpen, isTrue);
      expect(controller.state.draft.suggestion, '');
      expect(repo.keys, hasLength(1));
      repo.gate!.complete(
        const TaskRatingSubmission(version: 1, draft: completeRating),
      );
      await saving;
      expect(controller.grantedPoints, isNull);
      expect(refreshed, 1);
    },
  );
  test(
    'server submission wins over stale draft; cleanup failure never repeats POST',
    () async {
      store.saved = const SavedRatingDraft(completeRating);
      store.failClear = true;
      await controller.load();
      controller.open();
      await controller.submit();
      expect(controller.state.success, isTrue);
      expect(controller.state.error, isEmpty);
      controller.close();
      await controller.submit();
      expect(repo.keys, hasLength(1));
      repo.result = ratingEligibility(
        submission: const TaskRatingSubmission(
          version: 2,
          draft: TaskRatingDraft(
            taskUnderstanding: 1,
            aiCallPerformance: 1,
            taskCompletion: 1,
          ),
        ),
      );
      await controller.load();
      expect(controller.state.draft.taskUnderstanding, 1);
      expect(controller.state.readOnly, isTrue);
    },
  );
  test(
    'disposed pending submit cannot update state or refresh another account',
    () async {
      store.saved = const SavedRatingDraft(completeRating);
      repo.gate = Completer<TaskRatingSubmission>();
      await controller.load();
      controller.open();
      final saving = controller.submit();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      repo.gate!.complete(
        const TaskRatingSubmission(
          version: 1,
          draft: completeRating,
          rewardGranted: true,
        ),
      );
      await saving;
      expect(refreshed, 0);
    },
  );
}

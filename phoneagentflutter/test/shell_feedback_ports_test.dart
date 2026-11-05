import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import '../tool/previews/shell_feedback_ports.dart';
import '../tool/previews/shell_receipt_seeds.dart';

void main() {
  const single = ShellReceiptSeeds.singleTarget;
  const batch = ShellReceiptSeeds.batchTarget;
  const draft = TaskRatingDraft(
    taskUnderstanding: 4,
    aiCallPerformance: 4,
    taskCompletion: 4,
    cloneVoicePerformance: 4,
    suggestion: '合成建议',
  );

  test(
    'targets isolate ratings, eligibility, drafts and submissions',
    () async {
      final ports = ShellFeedbackPorts();
      final eligible = await ports.eligibility(single, clientVersion: 'test');
      final ineligible = await ports.eligibility(batch, clientVersion: 'test');
      expect(eligible.eligible, isTrue);
      expect(ineligible.eligible, isFalse);
      await ports.rate(single, CallRating.good);
      await ports.rate(batch, CallRating.bad);
      expect((await ports.load(single)).rating, CallRating.good);
      expect((await ports.load(batch)).rating, CallRating.bad);
      await ports.save(
        eligible,
        const SavedRatingDraft(draft, submissionKey: 'k'),
      );
      expect(await ports.read(ineligible), isNull);
      await ports.clear(ineligible);
      expect((await ports.read(eligible))!.submissionKey, 'k');
      await expectLater(
        ports.submit(ineligible, draft, idempotencyKey: 'no'),
        throwsStateError,
      );
      await expectLater(
        ports.submit(eligible, draft, idempotencyKey: 'k'),
        throwsStateError,
      );
      expect((await ports.read(eligible))!.draft.suggestion, '合成建议');
      final result = await ports.submit(eligible, draft, idempotencyKey: 'k');
      expect(
        await ports.submit(eligible, draft, idempotencyKey: 'k'),
        same(result),
      );
      expect(ports.submitKeys, ['k', 'k', 'k']);
      expect(
        (await ports.eligibility(single, clientVersion: 'test')).readOnly,
        isTrue,
      );
      expect(
        (await ports.eligibility(batch, clientVersion: 'test')).readOnly,
        isFalse,
      );
    },
  );

  test(
    'unknown IDs and disposed ports cannot return or write sample data',
    () async {
      final ports = ShellFeedbackPorts();
      const unknown = FeedbackTarget(FeedbackTargetKind.call, 'unknown');
      await expectLater(ports.load(unknown), throwsStateError);
      await expectLater(ports.rate(unknown, CallRating.good), throwsStateError);
      final eligible = await ports.eligibility(single, clientVersion: 'test');
      ports.close();
      await expectLater(ports.load(single), throwsStateError);
      await expectLater(ports.read(eligible), throwsStateError);
      await expectLater(
        ports.save(eligible, const SavedRatingDraft(draft)),
        throwsStateError,
      );
      await expectLater(
        ports.submit(eligible, draft, idempotencyKey: 'closed'),
        throwsStateError,
      );
      expect((await ShellFeedbackPorts().load(single)).rating, isNull);
    },
  );
}

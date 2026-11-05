import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/native_task_rating_entry.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/task_rating_sheet.dart';
import 'package:phone_agent/features/feedback/presentation/pages/call_evaluation_route.dart';
import 'package:phone_agent/features/feedback/presentation/pages/task_rating_route.dart';
import '../../support/rating_fakes.dart';

import '../../support/task_rating_result_refresh_fakes.dart';

void main() {
  for (final kind in FeedbackTargetKind.values) {
    testWidgets(
      'RATING-01 shared live $kind result refreshes its original target',
      (t) async {
        final target = FeedbackTarget(kind, 'live-anchor');
        ConversationMessage result(String detail) => ConversationMessage(
          id: 'live-result',
          role: MessageRole.assistant,
          text: '',
          receipt: kind == FeedbackTargetKind.call
              ? CallReceipt(
                  attemptId: 'live-attempt',
                  callId: target.id,
                  status: 'COMPLETED',
                  detail: detail,
                )
              : null,
          batchReceipt: kind == FeedbackTargetKind.batch
              ? BatchReceipt.fromJson({
                  'batchId': target.id,
                  'status': 'COMPLETED',
                  'headline': detail,
                }, fallbackId: 'fallback')
              : null,
        );
        final message = ValueNotifier(result('初始结果'));
        addTearDown(message.dispose);
        final ratings = RefreshRatingRepository()
          ..result = TaskRatingEligibility(target: target, eligible: false);
        await t.pumpWidget(
          ratingRefreshScope(
            ratings,
            ValueListenableBuilder<ConversationMessage>(
              valueListenable: message,
              builder: (_, value, __) => CallEvaluationRoute.forReceipt(value)!,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(NativeTaskRatingEntry), findsNothing);
        ratings.result = TaskRatingEligibility(
          target: target,
          eligible: true,
          id: 'live-eligibility',
          taskId: 'live-task',
          taskType: kind == FeedbackTargetKind.call ? 'SINGLE' : 'BATCH',
        );
        message.value = result('终态补全');
        await t.pumpAndSettle();
        expect(find.text('去评分'), findsOneWidget);
        expect(ratings.reads, 2);
        message.value = result('终态补全');
        await t.pumpAndSettle();
        expect(ratings.reads, 2);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'RATING-02 result refresh waits for rating sheet and preserves edited draft',
    (t) async {
      final detail = RatingRefreshDetail();
      final ratings = RefreshRatingRepository();
      final container = await mountRatingRefreshDetail(t, detail, ratings);
      await t.tap(find.text('去评分'));
      await t.pumpAndSettle();
      final controller = container.read(
        taskRatingControllerProvider(ratingTarget).notifier,
      );
      controller.suggestion('保留用户草稿');
      await t.pumpAndSettle();
      detail.publish('补全但不覆盖正在编辑');
      await t.pumpAndSettle();
      expect(ratings.reads, 1);
      expect(
        container
            .read(taskRatingControllerProvider(ratingTarget))
            .draft
            .suggestion,
        '保留用户草稿',
      );
      t.widget<TaskRatingSheet>(find.byType(TaskRatingSheet)).onClose();
      await t.pumpAndSettle();
      expect(ratings.reads, 2);
      expect(
        container
            .read(taskRatingControllerProvider(ratingTarget))
            .draft
            .suggestion,
        '保留用户草稿',
      );
      expect(find.byType(NativeTaskRatingEntry), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'RATING-02 duplicate result revisions share one eligibility refresh',
    (t) async {
      final message = ValueNotifier(ratingRefreshResult('初始结果'));
      addTearDown(message.dispose);
      final ratings = RefreshRatingRepository()
        ..result = ratingEligibility(eligible: false);
      await t.pumpWidget(
        ratingRefreshScope(
          ratings,
          ValueListenableBuilder<ConversationMessage>(
            valueListenable: message,
            builder: (_, value, __) => Column(
              children: [
                CallEvaluationRoute.forReceipt(value)!,
                CallEvaluationRoute.forReceipt(value)!,
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      ratings.result = ratingEligibility();
      message.value = ratingRefreshResult('终态补全');
      await t.pumpAndSettle();
      expect(find.byType(NativeTaskRatingEntry), findsOneWidget);
      expect(
        ratings.reads,
        2,
        reason: 'duplicate result updates must share one eligibility refresh',
      );
    },
  );

  testWidgets(
    'RATING-02 old eligibility cannot replace completed result revision',
    (t) async {
      final old = Completer<TaskRatingEligibility>();
      final detail = RatingRefreshDetail();
      final ratings = RefreshRatingRepository()..pending.add(old);
      final container = await mountRatingRefreshDetail(t, detail, ratings);
      expect(find.byType(NativeTaskRatingEntry), findsNothing);
      detail.publish('终态补全');
      await t.pumpAndSettle();
      expect(find.text('去评分'), findsOneWidget);
      old.complete(ratingEligibility(eligible: false));
      await t.pumpAndSettle();
      expect(
        container.read(taskRatingControllerProvider(ratingTarget)).visible,
        isTrue,
      );
      expect(find.text('去评分'), findsOneWidget);
      expect(ratings.reads, 2);
    },
  );

  testWidgets(
    'RATING-03 submitted result stays read only after result completion',
    (t) async {
      final detail = RatingRefreshDetail();
      final ratings = RefreshRatingRepository()
        ..result = ratingEligibility(
          submission: const TaskRatingSubmission(
            version: 1,
            draft: completeRating,
          ),
        );
      final container = await mountRatingRefreshDetail(t, detail, ratings);
      expect(find.text('查看'), findsOneWidget);
      ratings
        ..result = ratingEligibility()
        ..failEligibility = true;
      detail.publish('迟到结果字段');
      await t.pumpAndSettle();
      final state = container.read(taskRatingControllerProvider(ratingTarget));
      expect(state.readOnly, isTrue);
      expect(state.canEdit, isFalse);
      expect(state.draft.taskCompletion, 5);
      expect(find.text('查看'), findsOneWidget);
      expect(ratings.reads, 1);
    },
  );

  testWidgets(
    'RATING-03 running batch cannot claim whole batch rating from finished item',
    (t) async {
      final detail = RatingRefreshDetail();
      final ratings = RefreshRatingRepository();
      await mountRatingRefreshDetail(t, detail, ratings);
      final reads = ratings.reads;
      detail.publishResults([
        ConversationMessage(
          id: 'batch-result',
          role: MessageRole.assistant,
          text: '',
          batchReceipt: BatchReceipt.fromJson({
            'batchId': 'batch',
            'status': 'RUNNING',
            'totalCount': 2,
            'items': [
              {'itemId': 'one', 'callId': 'one', 'status': 'COMPLETED'},
              {'itemId': 'two', 'callId': 'two', 'status': 'CALLING'},
            ],
          }, fallbackId: 'batch'),
        ),
      ]);
      await t.pumpAndSettle();
      expect(find.byType(NativeTaskRatingEntry), findsNothing);
      expect(ratings.reads, reads);
      expect(find.text('Agent 结果说明'), findsOneWidget);
    },
  );

  testWidgets(
    'RATING-02 duplicate live receipts hand off one owner and retry eligibility',
    (t) async {
      final receipts = ValueNotifier<List<int>>([1, 2]);
      addTearDown(receipts.dispose);
      final ratings = RefreshRatingRepository()
        ..result = ratingEligibility(eligible: false);
      await t.pumpWidget(
        ratingRefreshScope(
          ratings,
          ValueListenableBuilder<List<int>>(
            valueListenable: receipts,
            builder: (_, ids, __) => Column(
              children: [
                for (final id in ids)
                  KeyedSubtree(
                    key: ValueKey(id),
                    child: CallEvaluationRoute(target: ratingTarget),
                  ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(NativeTaskRatingEntry), findsNothing);
      ratings.result = ratingEligibility();
      receipts.value = [2];
      await t.pumpAndSettle();
      expect(find.text('去评分'), findsOneWidget);
      expect(ratings.reads, 2);
      receipts.value = [2, 3];
      await t.pumpAndSettle();
      expect(find.byType(NativeTaskRatingEntry), findsOneWidget);
      expect(ratings.reads, 2);
    },
  );

  testWidgets('RATING-02 account replacement ignores old account eligibility', (
    t,
  ) async {
    final epoch = StateProvider<int>((ref) => 1);
    final old = Completer<TaskRatingEligibility>();
    final ratings = RefreshRatingRepository()
      ..pending.add(old)
      ..result = ratingEligibility(eligible: false);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          taskRatingRepositoryProvider.overrideWithValue(ratings),
          taskRatingDraftStoreProvider.overrideWith((ref) {
            ref.watch(loginEpochProvider);
            return FakeRatingDraftStore();
          }),
          taskRatingClientVersionProvider.overrideWith((ref) async => '1.0.52'),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TaskRatingRoute(target: ratingTarget)),
        ),
      ),
    );
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(
      t.element(find.byType(TaskRatingRoute)),
    );
    final previous = container.read(
      taskRatingControllerProvider(ratingTarget).notifier,
    );
    container.read(epoch.notifier).state = 2;
    await t.pumpAndSettle();
    expect(
      container.read(taskRatingControllerProvider(ratingTarget).notifier),
      isNot(same(previous)),
    );
    old.complete(ratingEligibility());
    await t.pumpAndSettle();
    expect(find.byType(NativeTaskRatingEntry), findsNothing);
    expect(
      container.read(taskRatingControllerProvider(ratingTarget)).visible,
      isFalse,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('RATING-02 switching target ignores old target response', (
    t,
  ) async {
    const other = FeedbackTarget(FeedbackTargetKind.call, 'other-call');
    final target = ValueNotifier(ratingTarget);
    addTearDown(target.dispose);
    final old = Completer<TaskRatingEligibility>();
    final ratings = RefreshRatingRepository()
      ..pending.add(old)
      ..result = const TaskRatingEligibility(target: other, eligible: false);
    await t.pumpWidget(
      ratingRefreshScope(
        ratings,
        ValueListenableBuilder<FeedbackTarget>(
          valueListenable: target,
          builder: (_, value, __) => TaskRatingRoute(target: value),
        ),
      ),
    );
    await t.pumpAndSettle();
    target.value = other;
    await t.pumpAndSettle();
    old.complete(ratingEligibility());
    await t.pumpAndSettle();
    expect(find.byType(NativeTaskRatingEntry), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('RATING-01/02 detail result completion recovers '
        '${fails ? 'failed' : 'ineligible'} initial eligibility in place', (
      t,
    ) async {
      final detail = RatingRefreshDetail();
      final ratings = RefreshRatingRepository()
        ..result = ratingEligibility(eligible: false)
        ..failEligibility = fails;
      final container = await mountRatingRefreshDetail(t, detail, ratings);
      final controller = container.read(
        taskRatingControllerProvider(ratingTarget).notifier,
      );
      expect(find.byType(NativeTaskRatingEntry), findsNothing);
      expect(find.text('Agent 结果说明'), findsOneWidget);
      ratings
        ..result = ratingEligibility()
        ..failEligibility = false;
      detail.publish('结果已补全');
      await t.pumpAndSettle();
      expect(
        container.read(taskRatingControllerProvider(ratingTarget).notifier),
        same(controller),
      );
      expect(find.byType(NativeTaskRatingEntry), findsOneWidget);
      expect(find.text('去评分'), findsOneWidget);
      expect(
        t.getTopLeft(find.byType(NativeTaskRatingEntry)).dy,
        lessThan(t.getTopLeft(find.text('Agent 结果说明')).dy),
      );
      final reads = ratings.reads;
      detail.publish('结果已补全');
      await t.pumpAndSettle();
      expect(
        ratings.reads,
        reads,
        reason: 'equal result rebuild is not a polling source',
      );
      expect(find.byType(NativeTaskRatingEntry), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}

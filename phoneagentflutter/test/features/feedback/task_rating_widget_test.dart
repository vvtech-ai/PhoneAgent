import 'dart:async';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import 'package:phone_agent/features/feedback/presentation/pages/task_rating_route.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/task_rating_sheet.dart';
import '../../support/rating_fakes.dart';

void main() {
  testWidgets(
    'conditional route opens, saves draft, submits once, shows server reward and read-only result',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeRatingRepository(), store = FakeRatingDraftStore();
      var refreshes = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRatingControllerProvider(ratingTarget).overrideWith((ref) {
              final controller = TaskRatingController(
                target: ratingTarget,
                repository: repo,
                drafts: store,
                clientVersion: '1.0.0',
                onSubmitted: () async {
                  refreshes++;
                },
              );
              controller.load();
              return controller;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TaskRatingRoute(target: ratingTarget),
                  TaskRatingRoute(target: ratingTarget),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('去评分'), findsOneWidget);
      await tester.tap(find.text('去评分'));
      await tester.pumpAndSettle();
      expect(find.text('评价本次任务'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交评价'))
            .onPressed,
        isNull,
      );
      for (final dimension in [
        RatingDimension.understanding,
        RatingDimension.call,
        RatingDimension.completion,
      ]) {
        final button = find.byKey(ValueKey('rating-${dimension.name}-4'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }
      final field = find.byType(TextFormField);
      await tester.ensureVisible(field);
      await tester.enterText(field, '合成建议');
      await tester.pump();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(TaskRatingSheet), findsNothing);
      await tester.tap(find.text('去评分'));
      await tester.pumpAndSettle();
      expect(find.text('合成建议'), findsOneWidget);
      await tester.tap(find.text('提交评价'));
      await tester.pumpAndSettle();
      expect(find.text('评价提交成功'), findsOneWidget);
      expect(find.textContaining('已获得7积分'), findsWidgets);
      expect(repo.keys, hasLength(1));
      expect(refreshes, 1);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看'));
      await tester.pumpAndSettle();
      expect(find.text('查看评分'), findsOneWidget);
      expect(find.text('提交评价'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('查看'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('rating backdrop cannot close while save is pending', (
    tester,
  ) async {
    final repo = FakeRatingRepository()
      ..gate = Completer<TaskRatingSubmission>();
    final store = FakeRatingDraftStore()
      ..saved = const SavedRatingDraft(
        completeRating,
        submissionKey: 'synthetic-key',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRatingControllerProvider(ratingTarget).overrideWith((ref) {
            final controller = TaskRatingController(
              target: ratingTarget,
              repository: repo,
              drafts: store,
              clientVersion: '1.0.0',
            );
            controller.load();
            return controller;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TaskRatingRoute(target: ratingTarget)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('去评分'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交评价'));
    await tester.pump();
    await tester.tapAt(const Offset(20, 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TaskRatingSheet), findsOneWidget);
    expect(repo.keys, hasLength(1));
    repo.gate!.complete(
      const TaskRatingSubmission(
        version: 1,
        draft: completeRating,
        rewardGranted: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskRatingSheet), findsNothing);
    expect(find.text('评价提交成功'), findsOneWidget);
    expect(repo.keys, hasLength(1));
  });
  testWidgets(
    'small portrait large text plus keyboard stays scrollable, clone opt-out present',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: Scaffold(
              body: TaskRatingSheet(
                state: TaskRatingState(
                  eligibility: ratingEligibility(clone: true),
                ),
                onClose: () {},
                onRate: (_, _) {},
                onSkipClone: (_) {},
                onSuggestion: (_) {},
                onSubmit: () {},
                onRetryDraft: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('未试听 / 不评价'), 160);
      await tester.scrollUntilVisible(find.byType(TextFormField), 160);
      expect(tester.takeException(), isNull);
    },
  );
}

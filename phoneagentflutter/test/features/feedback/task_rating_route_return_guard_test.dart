import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import 'package:phone_agent/features/feedback/presentation/pages/task_rating_route.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/native_task_rating_success.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/native_task_rating_entry.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/task_rating_sheet.dart';
import '../../support/rating_fakes.dart';

Future<FakeRatingRepository> mountRating(
  WidgetTester tester,
  TargetPlatform platform, {
  bool pending = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = FakeRatingRepository();
  if (pending) {
    repository.gate = Completer<TaskRatingSubmission>();
    addTearDown(() {
      if (!repository.gate!.isCompleted) {
        repository.gate!.complete(
          const TaskRatingSubmission(
            version: 1,
            draft: completeRating,
            rewardGranted: true,
          ),
        );
      }
    });
  }
  final drafts = FakeRatingDraftStore()
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
            repository: repository,
            drafts: drafts,
            clientVersion: '1.0.0',
          );
          controller.load();
          return controller;
        }),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('基础页面'),
                FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: Column(
                          children: [
                            Text('来源会话'),
                            TaskRatingRoute(target: ratingTarget),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('打开回执'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开回执'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('去评分'));
  await tester.pumpAndSettle();
  return repository;
}

void sourceStayed(WidgetTester tester) {
  expect(find.text('来源会话'), findsOneWidget);
  expect(find.text('基础页面'), findsNothing);
  expect(tester.takeException(), isNull);
}

TaskRatingSheet ratingSheet(WidgetTester tester) =>
    tester.widget<TaskRatingSheet>(find.byType(TaskRatingSheet));

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('repeat rating close only consumes sheet $platform', (
      tester,
    ) async {
      await mountRating(tester, platform);
      final close = ratingSheet(tester).onClose;
      close();
      close();
      await tester.pumpAndSettle();
      expect(find.byType(TaskRatingSheet), findsNothing);
      sourceStayed(tester);
    });
    testWidgets('old pre-save close cannot escape submission $platform', (
      tester,
    ) async {
      final repository = await mountRating(tester, platform, pending: true);
      final sheet = ratingSheet(tester);
      sheet.onSubmit();
      sheet.onClose();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TaskRatingSheet), findsOneWidget);
      expect(ratingSheet(tester).state.saving, isTrue);
      expect(repository.keys, hasLength(1));
      sourceStayed(tester);
      repository.gate!.complete(
        const TaskRatingSubmission(
          version: 1,
          draft: completeRating,
          rewardGranted: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NativeTaskRatingSuccess), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      sourceStayed(tester);
    });
    testWidgets('old sheet callbacks cannot dismiss success $platform', (
      tester,
    ) async {
      final repository = await mountRating(tester, platform);
      final old = ratingSheet(tester);
      old.onSubmit();
      await tester.pumpAndSettle();
      expect(find.byType(NativeTaskRatingSuccess), findsOneWidget);
      expect(old.onClose, returnsNormally);
      old.onSubmit();
      await tester.pumpAndSettle();
      expect(find.byType(NativeTaskRatingSuccess), findsOneWidget);
      expect(repository.keys, hasLength(1));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      sourceStayed(tester);
    });
    testWidgets('repeat success dismissal preserves conversation $platform', (
      tester,
    ) async {
      await mountRating(tester, platform);
      ratingSheet(tester).onSubmit();
      await tester.pumpAndSettle();
      final dismiss = tester
          .widget<NativeTaskRatingSuccess>(find.byType(NativeTaskRatingSuccess))
          .onDismiss;
      dismiss();
      dismiss();
      await tester.pumpAndSettle();
      expect(find.byType(NativeTaskRatingSuccess), findsNothing);
      sourceStayed(tester);
    });
    testWidgets('old entry cannot open rating behind success $platform', (
      tester,
    ) async {
      await mountRating(tester, platform);
      final oldOpen = tester
          .widget<NativeTaskRatingEntry>(find.byType(NativeTaskRatingEntry))
          .onOpen;
      ratingSheet(tester).onSubmit();
      await tester.pumpAndSettle();
      expect(find.byType(NativeTaskRatingSuccess), findsOneWidget);
      oldOpen();
      await tester.pumpAndSettle();
      expect(find.byType(TaskRatingSheet), findsNothing);
      expect(find.byType(NativeTaskRatingSuccess), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      sourceStayed(tester);
    });
    testWidgets('old close cannot dismiss newly opened rating $platform', (
      tester,
    ) async {
      await mountRating(tester, platform);
      final oldClose = ratingSheet(tester).onClose;
      oldClose();
      await tester.pumpAndSettle();
      await tester.tap(find.text('去评分'));
      await tester.pumpAndSettle();
      expect(oldClose, returnsNormally);
      expect(find.byType(TaskRatingSheet), findsOneWidget);
      ratingSheet(tester).onClose();
      await tester.pumpAndSettle();
      sourceStayed(tester);
    });
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import 'package:phone_agent/features/feedback/presentation/pages/task_rating_route.dart';
import '../../support/rating_fakes.dart';

class UnavailableRatingStore extends FakeRatingDraftStore {
  bool failRead = true;
  var reads = 0, writes = 0;
  Completer<SavedRatingDraft?>? gate;
  @override
  Future<SavedRatingDraft?> read(TaskRatingEligibility eligibility) async {
    reads++;
    if (gate != null) return gate!.future;
    if (failRead) throw StateError('synthetic read failure');
    return super.read(eligibility);
  }

  @override
  Future<void> save(
    TaskRatingEligibility eligibility,
    SavedRatingDraft draft,
  ) async {
    writes++;
    await super.save(eligibility, draft);
  }
}

void main() {
  TaskRatingController create(
    FakeRatingRepository repo,
    UnavailableRatingStore store,
  ) {
    final controller = TaskRatingController(
      target: ratingTarget,
      repository: repo,
      drafts: store,
      clientVersion: '1.0.0',
    );
    addTearDown(() {
      if (controller.mounted) controller.dispose();
    });
    return controller;
  }

  test('failed draft read cannot silently overwrite previous draft', () async {
    final repo = FakeRatingRepository();
    final original = SavedRatingDraft(
      completeRating.edit(text: '保留原建议'),
      submissionKey: 'synthetic-original-key',
    );
    final store = UnavailableRatingStore()..saved = original;
    final controller = TaskRatingController(
      target: ratingTarget,
      repository: repo,
      drafts: store,
      clientVersion: '1.0.0',
    );
    addTearDown(controller.dispose);
    await controller.load();
    controller.open();
    expect(controller.state.error, isNotEmpty);
    for (final dimension in RatingDimension.values) {
      controller.rate(dimension, 5);
    }
    controller.skipClone(true);
    controller.suggestion('不应保存的空表单编辑');
    await controller.submit();
    expect(store.writes, 0);
    expect(store.saved, same(original));
    expect(repo.keys, isEmpty);
    expect(controller.state.canSubmit, isFalse);
    controller.close();
    controller.open();
    expect(controller.state.error, isNotEmpty);
  });

  test(
    'retry restores original content and key without duplicate reads',
    () async {
      final repo = FakeRatingRepository()..fail = true;
      final original = SavedRatingDraft(
        completeRating.edit(text: ' 原建议\n😀 '),
        submissionKey: 'synthetic-restored-key',
      );
      final store = UnavailableRatingStore()..saved = original;
      final controller = create(repo, store);
      await controller.load();
      controller.open();
      await controller.retryDraft();
      expect(controller.state.draftReadFailed, isTrue);
      store.gate = Completer<SavedRatingDraft?>();
      final retry = controller.retryDraft();
      await controller.retryDraft();
      await controller.load();
      controller.suggestion('ignored');
      await controller.submit();
      expect(store.reads, 3);
      expect(store.writes, 0);
      expect(controller.state.loading, isTrue);
      store.gate!.complete(original);
      await retry;
      expect(controller.state.sheetOpen, isTrue);
      expect(controller.state.draft.suggestion, original.draft.suggestion);
      expect(controller.state.draft.taskUnderstanding, 4);
      expect(controller.state.draft.cloneVoiceNotEvaluated, isTrue);
      expect(controller.state.canSubmit, isTrue);
      expect(controller.state.error, isEmpty);
      expect(repo.keys, isEmpty);
      await controller.submit();
      await controller.submit();
      expect(repo.keys, ['synthetic-restored-key', 'synthetic-restored-key']);
    },
  );

  test(
    'confirmed missing draft is editable; reload blocks stale edits',
    () async {
      final repo = FakeRatingRepository();
      final store = UnavailableRatingStore()..failRead = false;
      final controller = create(repo, store);
      await controller.load();
      expect(controller.state.canEdit, isTrue);
      expect(controller.state.draft.suggestion, isEmpty);
      store.gate = Completer<SavedRatingDraft?>();
      final reload = controller.load();
      await Future<void>.delayed(Duration.zero);
      controller.open();
      controller.suggestion('ignored while loading');
      expect(store.writes, 0);
      store.gate!.complete(const SavedRatingDraft(completeRating));
      await reload;
      expect(controller.state.canEdit, isTrue);
      expect(controller.state.draft.taskUnderstanding, 4);
    },
  );

  test('server submitted result bypasses unavailable draft store', () async {
    final repo = FakeRatingRepository()
      ..result = ratingEligibility(
        submission: const TaskRatingSubmission(
          version: 1,
          draft: completeRating,
        ),
      );
    final store = UnavailableRatingStore()..failClear = true;
    final controller = create(repo, store);
    await controller.load();
    controller.open();
    await controller.retryDraft();
    expect(controller.state.readOnly, isTrue);
    expect(controller.state.draft.aiCallPerformance, 3);
    expect(controller.state.error, isEmpty);
    expect(store.reads, 0);
    expect(store.writes, 0);
    expect(repo.keys, isEmpty);
  });

  test('late retry after dispose does not publish or save', () async {
    final repo = FakeRatingRepository();
    final store = UnavailableRatingStore();
    final controller = create(repo, store);
    await controller.load();
    store.gate = Completer<SavedRatingDraft?>();
    final retry = controller.retryDraft();
    controller.dispose();
    store.gate!.complete(const SavedRatingDraft(completeRating));
    await retry;
    expect(store.writes, 0);
    expect(repo.keys, isEmpty);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('formal $platform route retries without blank editable form', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeRatingRepository();
      final store = UnavailableRatingStore();
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
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const Scaffold(body: TaskRatingRoute(target: ratingTarget)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('去评分'));
      await tester.pumpAndSettle();
      expect(find.text('草稿读取失败，请重试后再编辑'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交评价'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('关闭评分'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('去评分'));
      await tester.pumpAndSettle();
      expect(find.text('草稿读取失败，请重试后再编辑'), findsOneWidget);
      store.gate = Completer<SavedRatingDraft?>();
      await tester.tap(find.text('重新读取草稿'));
      await tester.pumpAndSettle();
      expect(find.text('正在读取草稿…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '重新读取草稿'))
            .onPressed,
        isNull,
      );
      store.gate!.complete(
        SavedRatingDraft(completeRating.edit(text: '恢复原建议')),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField);
      await tester.ensureVisible(field);
      expect(find.text('恢复原建议'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交评价'))
            .onPressed,
        isNotNull,
      );
      expect(store.reads, 2);
      expect(store.writes, 0);
      expect(repo.keys, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import 'package:phone_agent/features/feedback/presentation/pages/task_rating_route.dart';
import '../../support/rating_fakes.dart';

class _Repository extends FakeRatingRepository {
  final versions = <String>[];
  @override
  Future<TaskRatingEligibility> eligibility(
    FeedbackTarget target, {
    required String clientVersion,
  }) async {
    versions.add(clientVersion);
    return TaskRatingEligibility(
      target: target,
      eligible: clientVersion == '1.0.51',
      id: 'synthetic-eligibility',
      taskType: target.anchorType,
      taskId: target.id,
    );
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final kind in FeedbackTargetKind.values) {
      testWidgets(
        '$platform $kind uses installed version and displays eligible rating',
        (t) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final version = Completer<Map<String, Object?>>();
          const channel = MethodChannel('com.vvtech.phone_agent/app_info');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(channel, (_) => version.future);
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          final repository = _Repository();
          final target = FeedbackTarget(kind, 'synthetic');
          await t.pumpWidget(
            ProviderScope(
              overrides: [
                taskRatingRepositoryProvider.overrideWithValue(repository),
                taskRatingDraftStoreProvider.overrideWithValue(
                  FakeRatingDraftStore(),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: TaskRatingRoute(target: target)),
              ),
            ),
          );
          await t.pump();
          expect(repository.versions, isEmpty);
          version.complete({
            'packageName': 'com.synthetic.dev',
            'versionName': '1.0.51',
            'versionCode': 45,
          });
          await t.pumpAndSettle();
          expect(repository.versions, ['1.0.51']);
          expect(find.text('去评分'), findsOneWidget);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
  test('late version after disposal does not query the old task', () async {
    final gate = Completer<String>(), repository = _Repository();
    final controller = TaskRatingController(
      target: ratingTarget,
      repository: repository,
      drafts: FakeRatingDraftStore(),
      clientVersion: gate.future,
    );
    final load = controller.load();
    controller.dispose();
    gate.complete('1.0.51');
    await load;
    expect(repository.versions, isEmpty);
  });
  test(
    'version failure never falls back to a false version or eligibility',
    () async {
      final repository = _Repository();
      final controller = TaskRatingController(
        target: ratingTarget,
        repository: repository,
        drafts: FakeRatingDraftStore(),
        clientVersion: Future<String>.error(
          StateError('synthetic metadata error'),
        ),
      );
      TaskRatingState? observed;
      controller.addListener(
        (value) => observed = value,
        fireImmediately: true,
      );
      await controller.load();
      expect(repository.versions, isEmpty);
      expect(observed!.visible, isFalse);
      controller.dispose();
    },
  );
}

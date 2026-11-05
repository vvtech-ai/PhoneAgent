import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/feedback/data/api_task_rating_repository.dart';
import '../features/feedback/data/device_legacy_rating_draft.dart';
import '../features/feedback/data/secure_task_rating_draft_store.dart';
import '../features/feedback/domain/call_evaluation.dart';
import '../features/feedback/domain/task_rating.dart';
import '../features/feedback/domain/task_rating_draft_store.dart';
import '../features/feedback/presentation/controller/task_rating_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';
import 'points_providers.dart';
import 'home_card_preference_providers.dart';

// Use native installed metadata on both platforms, including debug suffixes.
final taskRatingClientVersionProvider = homeInstalledVersionProvider;
final taskRatingRepositoryProvider = Provider.autoDispose<TaskRatingRepository>(
  (ref) => ApiTaskRatingRepository(ref.watch(accountApiProvider)),
);
final taskRatingDraftStoreProvider = Provider<TaskRatingDraftStore>((ref) {
  ref.watch(loginEpochProvider);
  final config = ref.watch(appConfigProvider);
  final account = ref.watch(currentAccountIdProvider);
  final legacy = DeviceLegacyRatingDraft.eligible(config)
      ? DeviceLegacyRatingDraft(config: config, accountId: account)
      : null;
  final store = SecureTaskRatingDraftStore(
    config,
    account,
    legacyRead: legacy?.read,
  );
  ref.onDispose(store.close);
  return store;
});
final taskRatingControllerProvider = StateNotifierProvider.autoDispose
    .family<TaskRatingController, TaskRatingState, FeedbackTarget>((
      ref,
      target,
    ) {
      final controller = TaskRatingController(
        target: target,
        repository: ref.watch(taskRatingRepositoryProvider),
        drafts: ref.watch(taskRatingDraftStoreProvider),
        clientVersion: ref.watch(taskRatingClientVersionProvider.future),
        onSubmitted: () =>
            ref.read(pointsWalletControllerProvider.notifier).refresh(),
      );
      controller.load();
      return controller;
    });

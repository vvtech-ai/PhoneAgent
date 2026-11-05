import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/task_notifications/data/secure_home_notification_read_store.dart';
import '../features/task_notifications/domain/home_notification.dart';
import '../features/task_notifications/presentation/controller/home_notification_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';

final homeNotificationReadStoreProvider =
    Provider.autoDispose<HomeNotificationReadStore?>((ref) {
      ref.watch(loginEpochProvider);
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final config = ref.watch(appConfigProvider);
      if (owner == null || !config.isConfigured) return null;
      var disposed = false;
      ref.onDispose(() => disposed = true);
      return SecureHomeNotificationReadStore(
        config,
        owner.accountId,
        isCurrent: () => !disposed && owner.sameLogin(session.credentials),
      );
    });

final homeNotificationControllerProvider =
    StateNotifierProvider.autoDispose<
      HomeNotificationController,
      HomeNotificationState
    >((ref) {
      ref.watch(loginEpochProvider);
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final store = ref.watch(homeNotificationReadStoreProvider);
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final controller = HomeNotificationController(
        store ?? MemoryHomeNotificationReadStore(),
        isCurrent: () =>
            !disposed &&
            (owner == null
                ? session.credentials == null
                : owner.sameLogin(session.credentials)),
      );
      if (store != null && owner != null) {
        // Reuse the task owner's cached source rows, not a second network service.
        ref.watch(taskControllerProvider.notifier);
        ref.listen(
          taskControllerProvider,
          (_, next) => controller.replaceRecords(next.notificationRecords),
        );
        controller.replaceRecords(
          ref.read(taskControllerProvider).notificationRecords,
        );
      }
      controller.load();
      return controller;
    });

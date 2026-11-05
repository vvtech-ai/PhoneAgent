import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/home_notification_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/features/task_notifications/data/secure_home_notification_read_store.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';

LoginOutcome login(String owner) => LoginOutcome(
  phone: '13800000000',
  accountId: owner,
  accessToken: 'synthetic',
  inviteRequired: false,
);

Future<void> settle(ProviderContainer container) async {
  for (var i = 0; i < 5; i++) {
    await container.pump();
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'unconfigured or signed out never initializes a task API or read store',
    () async {
      final session = SessionController(_SessionStore());
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith((_) => session),
          taskRepositoryProvider.overrideWith(
            (_) => throw StateError('task API must stay lazy'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        homeNotificationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await settle(container);
      expect(container.read(homeNotificationReadStoreProvider), isNull);
      expect(
        container.read(homeNotificationControllerProvider).pending,
        isEmpty,
      );
      await session.accept(login('synthetic-a'));
      await settle(container);
      expect(container.read(homeNotificationReadStoreProvider), isNull);
      expect(
        container.read(homeNotificationControllerProvider).pending,
        isEmpty,
      );
    },
  );

  test(
    'owner switch isolates late read and token refresh keeps current controller',
    () async {
      final session = SessionController(_SessionStore());
      await session.accept(login('synthetic-a'));
      final oldStore = _ReadStore()
        ..gate = Completer()
        ..entries = {
          'legacy_task:history': DateTime.now().millisecondsSinceEpoch,
        };
      final stores = <String, _ReadStore>{'synthetic-a': oldStore};
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith((_) => session),
          homeNotificationReadStoreProvider.overrideWith((ref) {
            ref.watch(loginEpochProvider);
            final owner = ref
                .read(sessionControllerProvider.notifier)
                .credentials;
            return owner == null
                ? null
                : stores.putIfAbsent(owner.accountId, _ReadStore.new);
          }),
          taskControllerProvider.overrideWith((ref) {
            ref.watch(loginEpochProvider);
            final controller = TaskController(_Tasks());
            controller.refresh();
            return controller;
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        homeNotificationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await settle(container);
      expect(container.read(homeNotificationControllerProvider).ready, isFalse);
      await session.accept(login('synthetic-b'));
      await settle(container);
      expect(
        container.read(homeNotificationControllerProvider).pending,
        hasLength(1),
      );
      oldStore.gate!.complete();
      await settle(container);
      expect(
        container.read(homeNotificationControllerProvider).pending,
        hasLength(1),
      );
      final current = container.read(
        homeNotificationControllerProvider.notifier,
      );
      await current.markAllPendingRead();
      expect(
        container.read(homeNotificationControllerProvider).pending,
        isEmpty,
      );
      expect(stores['synthetic-b']!.entries.keys, {'legacy_task:history'});
      await session.replaceToken(session.credentials!, 'synthetic-refreshed');
      await settle(container);
      expect(
        container.read(homeNotificationControllerProvider.notifier),
        same(current),
      );
      await session.accept(login('synthetic-a'));
      await settle(container);
      expect(
        container.read(homeNotificationControllerProvider).pending,
        isEmpty,
      );
    },
  );
}

class _SessionStore implements SessionStore {
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async => value = session;
  @override
  Future<void> clear() async => value = null;
}

class _ReadStore extends MemoryHomeNotificationReadStore {
  Completer<void>? gate;
  @override
  Future<Map<String, int>> load() async {
    await gate?.future;
    return super.load();
  }
}

class _Tasks implements TaskRepository {
  @override
  Future<List<TaskRecord>> load(TaskSource source) async =>
      source == TaskSource.legacyTasks
      ? const [
          TaskRecord(
            id: 'task:history',
            taskId: 'history',
            kind: TaskRecordKind.legacyTask,
            title: '合成已完成任务',
            rawStatus: 'COMPLETED',
            status: TaskStatus.completed,
          ),
        ]
      : [];
}

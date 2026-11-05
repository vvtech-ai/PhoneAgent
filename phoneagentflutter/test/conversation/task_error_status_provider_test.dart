import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/secure_task_error_status_store.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';
import 'package:phone_agent/features/tasks/data/task_record_mapper.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import '../support/synthetic_account_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/',
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('formal reconnect refreshes once without a second failed POST', () async {
    final events = _NetworkEvents();
    final server = SyntheticAccountApi()..status = 503;
    final tasks = _Tasks();
    final store = _SessionStore();
    final container = ProviderContainer(
      overrides: [
        networkAvailabilityEventsProvider.overrideWithValue(events),
        appConfigProvider.overrideWithValue(config),
        sessionStoreProvider.overrideWithValue(store),
        accountApiProvider.overrideWithValue(server.api),
        taskRepositoryProvider.overrideWithValue(tasks),
      ],
    );
    addTearDown(events.values.close);
    addTearDown(server.api.close);
    addTearDown(container.dispose);
    final session = container.read(sessionControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    final lease = container.listen(taskControllerProvider, (_, __) {});
    final controller = container.read(taskControllerProvider.notifier);
    await controller.refresh();
    final sync = container.read(taskErrorStatusSyncProvider);
    await sync.record('s', TaskErrorStatusReason.exited);
    final initialPosts = server.requests.length;
    final initialReads = tasks.reads;
    final recovery = container.read(taskErrorNetworkRecoveryProvider);
    Future<void> emit(
      NetworkAvailability value, {
      bool awaitSync = false,
    }) async {
      final completed = awaitSync ? recovery.completed.first : null;
      events.values.add(value);
      if (completed != null) {
        await completed.timeout(const Duration(seconds: 5));
      }
      // Drain in-memory API, storage and provider microtasks; no timers/network.
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    await emit(NetworkAvailability.available, awaitSync: true);
    expect(server.requests.length, initialPosts + 1);
    expect(tasks.reads, initialReads + TaskSource.values.length);
    expect(sync.hasPending, isTrue);
    await emit(NetworkAvailability.available);
    expect(server.requests.length, initialPosts + 1);
    expect(tasks.reads, initialReads + TaskSource.values.length);

    // The page may disappear while the account's status queue keeps listening.
    lease.close();
    await container.pump();
    final pageReleasedReads = tasks.reads;
    await emit(NetworkAvailability.unavailable);
    server.status = 200;
    server.data = {'sessionId': 's', 'status': 'COMPLETED'};
    await emit(NetworkAvailability.available, awaitSync: true);
    expect(server.requests.length, initialPosts + 2);
    expect(tasks.reads, pageReleasedReads);
    expect(sync.hasPending, isFalse);

    server.status = 503;
    await sync.record('s', TaskErrorStatusReason.exited);
    final beforeLogout = server.requests.length;
    store.value = null;
    await session.restore();
    await container.pump();
    await emit(NetworkAvailability.unavailable);
    await emit(NetworkAvailability.available);
    expect(server.requests.length, beforeLogout);
    expect(events.values.hasListener, isFalse);
  });
  test(
    'formal account queue survives page release but stops on login replacement',
    () async {
      final server = SyntheticAccountApi()..status = 503;
      final store = _SessionStore();
      final container = ProviderContainer(
        overrides: [
          networkAvailabilityEventsProvider.overrideWithValue(
            const NoNetworkAvailabilityEvents(),
          ),
          appConfigProvider.overrideWithValue(config),
          sessionStoreProvider.overrideWithValue(store),
          accountApiProvider.overrideWithValue(server.api),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(server.api.close);
      final session = container.read(sessionControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      final lease = container.listen(taskErrorStatusSyncProvider, (_, __) {});
      final sync = container.read(taskErrorStatusSyncProvider);
      await sync.record('s', TaskErrorStatusReason.exited);
      lease.close();
      await container.pump();
      expect(
        identical(container.read(taskErrorStatusSyncProvider), sync),
        isTrue,
      );
      expect(
        (await SecureTaskErrorStatusStore(config, 'a').read()).single.sessionId,
        's',
      );
      final before = server.requests.length;
      store.value = const AuthSession(
        accountId: 'b',
        phone: '13800000000',
        accessToken: 'synthetic-b',
      );
      await session.restore();
      await container.pump();
      await sync.record('old-late', TaskErrorStatusReason.exited);
      expect(server.requests.length, before);
      expect(
        identical(container.read(taskErrorStatusSyncProvider), sync),
        isFalse,
      );
      expect(await SecureTaskErrorStatusStore(config, 'b').read(), isEmpty);
      expect(
        (await SecureTaskErrorStatusStore(config, 'a').read()).single.sessionId,
        's',
      );
    },
  );
  test(
    'formal task provider observes pending errors without extra list requests',
    () async {
      final server = SyntheticAccountApi()..status = 503;
      final tasks = _Tasks();
      final container = ProviderContainer(
        overrides: [
          networkAvailabilityEventsProvider.overrideWithValue(
            const NoNetworkAvailabilityEvents(),
          ),
          appConfigProvider.overrideWithValue(config),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
          accountApiProvider.overrideWithValue(server.api),
          taskRepositoryProvider.overrideWithValue(tasks),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(server.api.close);
      container.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      final lease = container.listen(taskControllerProvider, (_, __) {});
      addTearDown(lease.close);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      final initialReads = tasks.reads;
      await container
          .read(taskErrorStatusSyncProvider)
          .record('s', TaskErrorStatusReason.exited);
      await container.pump();
      expect(
        container.read(taskControllerProvider).catalog.records.single.status,
        TaskStatus.executionError,
      );
      expect(tasks.reads, initialReads);
      expect(server.requests.single.headers['X-Account-Id'], 'a');
    },
  );
}

class _SessionStore implements SessionStore {
  AuthSession? value = const AuthSession(
    accountId: 'a',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _NetworkEvents implements NetworkAvailabilityEvents {
  final values = StreamController<NetworkAvailability>.broadcast();
  @override
  Stream<NetworkAvailability> watch() => values.stream;
}

class _Tasks implements TaskRepository {
  int reads = 0;
  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    reads++;
    return source == TaskSource.conversations
        ? const TaskRecordMapper().decode([
            {'sessionId': 's', 'status': 'RUNNING', 'title': 'MOCK'},
          ], source)
        : [];
  }
}

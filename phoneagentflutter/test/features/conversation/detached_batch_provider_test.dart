import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_event_stream.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

void main() {
  test(
    'detached completion invalidates the formal three-source task list exactly once',
    () async {
      final gateway = _Gateway(), tasks = _Tasks();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          agentGatewayProvider.overrideWithValue(gateway),
          taskRepositoryProvider.overrideWithValue(tasks),
          taskErrorStatusSyncProvider.overrideWith((ref) {
            final sync = PreviewTaskErrorStatusPorts().createSync();
            ref.onDispose(sync.close);
            return sync;
          }),
        ],
      );
      addTearDown(container.dispose);
      final keep = container.listen(taskControllerProvider, (_, __) {});
      addTearDown(keep.close);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(tasks.reads, TaskSource.values.length);
      final stream = ConversationEventStream(gateway);
      stream.start(
        const AgentCommand(
          sessionId: 's',
          userId: 'synthetic',
          commandId: 'c',
          idempotencyKey: 'k',
          traceId: 't',
        ),
        isCurrent: () => true,
        accept: (_) async {},
        onError: (_) {},
        onDone: () {},
      );
      container.read(detachedBatchStreamsProvider).retain(stream);
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(tasks.reads, TaskSource.values.length * 2);
      stream.cancel();
      await container.pump();
      expect(tasks.reads, TaskSource.values.length * 2);
    },
  );
  test(
    'formal account registry survives route listeners then releases on login epoch replacement',
    () async {
      final epoch = StateProvider((ref) => 1);
      final gateway = _Gateway();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          agentGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final keep = container.listen(detachedBatchStreamsProvider, (_, __) {});
      final registry = container.read(detachedBatchStreamsProvider);
      final stream = ConversationEventStream(gateway);
      stream.start(
        const AgentCommand(
          sessionId: 's',
          userId: 'synthetic',
          commandId: 'c',
          idempotencyKey: 'k',
          traceId: 't',
        ),
        isCurrent: () => true,
        accept: (_) async {},
        onError: (_) {},
        onDone: () {},
      );
      registry.retain(stream);
      keep.close();
      await container.pump();
      expect(registry.hasActive, isTrue);
      expect(gateway.cancels, 0);
      container.read(epoch.notifier).state++;
      await container.pump();
      expect(registry.count, 0);
      expect(gateway.cancels, 1);
      expect(
        identical(container.read(detachedBatchStreamsProvider), registry),
        isFalse,
      );
    },
  );
}

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  int cancels = 0;
  @override
  AgentRun start(AgentCommand command) =>
      AgentRun(events.stream, () => cancels++);
}

class _Tasks implements TaskRepository {
  int reads = 0;
  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    reads++;
    return [];
  }
}

import '../../domain/recovery/task_error_status_command.dart';
import '../../domain/recovery/task_error_status_sync.dart';

/// Explicit MOCK boundary for the workbench/tests. No HTTP, disk or credentials.
class PreviewTaskErrorStatusPorts
    implements TaskErrorStatusStore, TaskErrorStatusGateway {
  final commands = <String, TaskErrorStatusCommand>{};
  final sent = <TaskErrorStatusCommand>[];
  final statuses = <String, String>{};
  bool offline = false;

  TaskErrorStatusSync createSync({bool Function()? isCurrent}) =>
      TaskErrorStatusSync(
        store: this,
        gateway: this,
        isCurrent: isCurrent ?? (() => true),
      );

  @override
  Future<List<TaskErrorStatusCommand>> read() async => commands.values.toList();
  @override
  Future<void> put(TaskErrorStatusCommand command) async {
    commands[command.sessionId] = command;
  }

  @override
  Future<void> removeIfCurrent(TaskErrorStatusCommand command) async {
    if (commands[command.sessionId]?.commandId == command.commandId) {
      commands.remove(command.sessionId);
    }
  }

  @override
  Future<String> send(TaskErrorStatusCommand command) async {
    sent.add(command);
    if (offline) throw StateError('MOCK offline');
    if (statuses[command.sessionId] == 'COMPLETED') return 'COMPLETED';
    return statuses[command.sessionId] =
        command.reason == TaskErrorStatusReason.exited
        ? 'EXECUTION_ERROR'
        : 'RUNNING';
  }
}

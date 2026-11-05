import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_admission_providers.dart';
import 'package:phone_agent/app/call_monitor_providers.dart';
import 'package:phone_agent/app/call_session_providers.dart';
import 'package:phone_agent/app/confirmation_billing_providers.dart';
import 'shell_billing_store.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/data/preview_call_monitor.dart';
import 'package:phone_agent/features/calls/domain/call_admission_service.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

final shellCallPortsProvider = Provider<ShellCallPorts>((ref) {
  ref.watch(loginEpochProvider);
  final ports = ShellCallPorts();
  ref.onDispose(ports.close);
  return ports;
});

List<Override> shellCallOverrides() => [
  confirmationBillingStoreProvider.overrideWith((ref) {
    ref.watch(loginEpochProvider);
    ref.keepAlive();
    return ShellBillingStore();
  }),
  callSessionRepositoryProvider.overrideWith(
    (ref) => ref.watch(shellCallPortsProvider),
  ),
  callAdmissionProvider.overrideWith(
    (ref, id) => ref.watch(shellCallPortsProvider).admission(id),
  ),
  callMonitorFactoryProvider.overrideWith(
    (ref) => ref.watch(shellCallPortsProvider).monitor.create,
  ),
];

/// MOCK server only; the App still owns launch, observation, UI and cleanup.
class ShellCallPorts implements CallSessionRepository {
  final _admissions = <String, PreviewCallFlow>{};
  final _flows = <String, PreviewCallFlow>{};
  final _runs = <AgentRun>[];
  final monitor = PreviewCallMonitor();
  bool _closed = false;

  PreviewCallFlow? flow(String id) => _flows[id];
  bool contains(String id) => _flows.containsKey(id);
  CallAdmissionService admission(String id) {
    _check();
    return _admissions
        .putIfAbsent(
          id,
          () => PreviewCallFlow(CallFlowScenario.single, narrateResults: true),
        )
        .admission;
  }

  AgentRun? start(AgentCommand command) {
    _check();
    final existing = _flows[command.sessionId];
    if (existing == null &&
        (!const {'演练单路通话', 'ui-single-call'}.contains(command.message) ||
            command.actionId != null)) {
      return null;
    }
    if (existing != null && command.actionId != 'confirm_call') return null;
    admission(command.sessionId);
    final selected = existing ?? _admissions[command.sessionId]!;
    final delegate = selected.start(command);
    var cancelled = false;
    late final AgentRun run;
    Stream<AgentEvent> events() async* {
      try {
        await for (final event in delegate.events) {
          if (_closed || cancelled) return;
          _flows[command.sessionId] = selected;
          yield event;
        }
      } finally {
        _runs.remove(run);
      }
    }

    run = AgentRun(events(), () {
      cancelled = true;
      delegate.cancel();
    });
    _runs.add(run);
    return run;
  }

  List<TaskRecord> get tasks => [
    for (final entry in _flows.entries)
      TaskRecord(
        id: 'conversation:${entry.key}',
        sessionId: entry.key,
        kind: TaskRecordKind.conversation,
        title: 'MOCK · 演练单路通话',
        status: entry.value.outcomeReady
            ? TaskStatus.completed
            : TaskStatus.running,
        rawStatus: entry.value.outcomeReady ? 'COMPLETED' : 'RUNNING',
      ),
  ];

  Future<RestoredConversation> restore(String id) {
    _check();
    final selected = _flows[id];
    if (selected == null) throw StateError('Unknown MOCK call session');
    return selected.restore(id);
  }

  PreviewCallFlow _target(CallSessionTarget target) {
    _check();
    final selected = _flows[target.taskId];
    if (selected == null ||
        target.callId.isNotEmpty && target.callId != 'mock-call') {
      throw StateError('Unknown MOCK call target');
    }
    return selected;
  }

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async =>
      _target(target).status(target);
  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async =>
      _target(target).hangUp(target);
  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) async =>
      _target(target).monitorTicket(target);

  void _check() {
    if (_closed) throw StateError('MOCK call scope closed');
  }

  void close() {
    _closed = true;
    for (final run in [..._runs]) {
      run.cancel();
    }
    _runs.clear();
    monitor.dispose();
  }
}

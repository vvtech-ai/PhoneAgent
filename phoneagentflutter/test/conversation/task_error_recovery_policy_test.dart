import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_recovery_policy.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';

void main() {
  test('normal exit and non-error restoration do not interrupt', () {
    final policy = TaskErrorRecoveryPolicy();
    for (final status in ['', 'RUNNING', 'COMPLETED', 'CLOSED', 'FAILED']) {
      policy.restore(status);
      expect(policy.exitReason, isNull);
    }
  });
  test(
    'restored execution/network error remains pending until confirmation',
    () {
      final policy = TaskErrorRecoveryPolicy();
      for (final status in [
        'EXECUTION_ERROR',
        ' network_error ',
        'NETWORK',
        'NETWORK_FAILURE',
        'TOOL_ERROR',
      ]) {
        policy.restore(status);
        expect(policy.exitReason, TaskErrorStatusReason.exited);
      }
    },
  );
  test('ordinary failure marks exit, active call failure does not', () {
    final policy = TaskErrorRecoveryPolicy();
    policy.failed(hasCallContext: true);
    expect(policy.exitReason, isNull);
    policy.failed(hasCallContext: false);
    expect(policy.exitReason, TaskErrorStatusReason.exited);
    policy.failed(hasCallContext: true);
    expect(policy.exitReason, TaskErrorStatusReason.exited);
  });
  test('all eight v65 live business responses confirm exactly once', () {
    for (final type in [
      'TEXT_REPLY',
      'ASK_USER',
      'SHOW_OPTIONS',
      'REQUEST_PERMISSION',
      'IMPORT_DOCUMENT_REQUEST',
      'LOOKUP_CONTACT_REQUEST',
      'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST',
      'MAKE_CALL_REQUEST',
    ]) {
      final policy = TaskErrorRecoveryPolicy()..failed(hasCallContext: false);
      final event = AgentEvent(AgentEventKind.signal, payload: {'type': type});
      expect(
        policy.accept(event),
        TaskErrorStatusReason.recovered,
        reason: type,
      );
      expect(policy.accept(event), isNull);
      expect(policy.exitReason, isNull);
    }
  });
  test('terminal result clears error without promoting running', () {
    for (final type in ['CALL_RESULT', 'BATCH_CALL_RESULT']) {
      final policy = TaskErrorRecoveryPolicy()..restore('EXECUTION_ERROR');
      expect(
        policy.accept(
          AgentEvent(AgentEventKind.finalResponse, payload: {'type': type}),
        ),
        isNull,
      );
      expect(policy.exitReason, isNull);
    }
  });
  test('transport progress and untyped final are not business recovery', () {
    final policy = TaskErrorRecoveryPolicy()..restore('NETWORK_ERROR');
    for (final kind in AgentEventKind.values.where(
      (k) => k != AgentEventKind.signal && k != AgentEventKind.finalResponse,
    )) {
      expect(
        policy.accept(AgentEvent(kind, payload: {'type': 'TEXT_REPLY'})),
        isNull,
      );
    }
    expect(
      policy.accept(const AgentEvent(AgentEventKind.finalResponse)),
      isNull,
    );
    expect(policy.exitReason, TaskErrorStatusReason.exited);
  });
  test(
    'reason and path identities are closed to arbitrary interrupt commands',
    () {
      final command = TaskErrorStatusCommand(
        'session-1',
        TaskErrorStatusReason.exited,
        'cmd_1',
      );
      expect(
        TaskErrorStatusCommand.fromJson(command.toJson()).reason,
        command.reason,
      );
      for (final bad in ['', '../x', 'a/b', 'a?x', 'a%2Fb', 'a\n', 'x' * 257]) {
        expect(
          () => TaskErrorStatusCommand(bad, command.reason, 'cmd'),
          throwsFormatException,
        );
      }
      expect(
        () => TaskErrorStatusCommand.fromJson({
          ...command.toJson(),
          'reason': 'reset_task_flow',
        }),
        throwsFormatException,
      );
    },
  );
}

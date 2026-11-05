import '../agent_protocol.dart';
import 'task_error_status_command.dart';

/// Only owns unresolved execution failure; UI/voice/transport state stays with
/// its existing owner. Callers must apply their stream-generation/owner guard.
class TaskErrorRecoveryPolicy {
  bool _unresolved = false;
  bool get unresolved => _unresolved;
  TaskErrorStatusReason? get exitReason =>
      _unresolved ? TaskErrorStatusReason.exited : null;

  void restore(String status) {
    _unresolved = const {
      'NETWORK_ERROR',
      'NETWORK',
      'NETWORK_FAILURE',
      'EXECUTION_ERROR',
      'TOOL_ERROR',
    }.contains(status.trim().toUpperCase());
  }

  void failed({required bool hasCallContext}) {
    if (!hasCallContext) _unresolved = true;
  }

  TaskErrorStatusReason? accept(AgentEvent event) {
    if (!_unresolved ||
        (event.kind != AgentEventKind.signal &&
            event.kind != AgentEventKind.finalResponse)) {
      return null;
    }
    final type = event.payload['type'];
    if (type == 'CALL_RESULT' || type == 'BATCH_CALL_RESULT') {
      _unresolved = false;
      return null;
    }
    if (!_recoveryTypes.contains(type)) return null;
    _unresolved = false;
    return TaskErrorStatusReason.recovered;
  }

  static const _recoveryTypes = {
    'TEXT_REPLY',
    'ASK_USER',
    'SHOW_OPTIONS',
    'REQUEST_PERMISSION',
    'IMPORT_DOCUMENT_REQUEST',
    'LOOKUP_CONTACT_REQUEST',
    'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST',
    'MAKE_CALL_REQUEST',
  };
}

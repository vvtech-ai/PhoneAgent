import '../agent_failure.dart';
import '../agent_protocol.dart';
import '../history/conversation_history.dart';
import '../history/ledger_event.dart';
import 'manual_voice_transcript.dart';

enum RecoveredTurnState { notAccepted, accepted, terminated, committed }

class RecoveredTurnPlan {
  const RecoveredTurnPlan({
    required this.text,
    required this.originalCommand,
    required this.restored,
    required this.serverState,
    this.shouldSubmit = true,
  });
  final String text, originalCommand;
  final RestoredConversation restored;
  LedgerSnapshot get ledger => restored.ledger!;
  final RecoveredTurnState serverState;
  final bool shouldSubmit;
  bool get originalCommitted => serverState == RecoveredTurnState.committed;
  String? get supersedes => originalCommitted ? null : originalCommand;
}

/// One page-owned user turn. ASR events and call actions are not retry payloads.
class ConversationTurnRecovery {
  AgentCommand? _active, _pending;
  String get baseText => _pending?.message?.trim() ?? '';
  String? get commandId => _pending?.commandId;
  bool get pending => baseText.isNotEmpty;

  void started(AgentCommand command) {
    clear();
    if (command.inputKind == null &&
        command.actionId == null &&
        command.message?.trim().isNotEmpty == true) {
      _active = command;
    }
  }

  void failed(Object? failure, {required bool ordinaryTurn}) {
    final network =
        failure == AgentTransportFailure.network ||
        (failure is AgentFailure && failure.isNetworkFailure);
    _pending = ordinaryTurn && network ? _active : null;
    _active = null;
  }

  void completed(String command) {
    if (_active?.commandId == command) clear();
  }

  void clear() {
    _active = null;
    _pending = null;
  }

  Future<RecoveredTurnPlan> plan(
    String candidate,
    ConversationHistoryRepository history, {
    int minimumHead = 0,
  }) async {
    final original = _pending;
    if (original == null) throw StateError('No recoverable turn');
    final restored = await history.restore(original.sessionId);
    final ledger = restored.ledger;
    if (!identical(original, _pending) ||
        restored.detail.sessionId != original.sessionId ||
        ledger == null ||
        ledger.sessionId != original.sessionId ||
        ledger.head < minimumHead ||
        ledger.projection.projectedThrough < ledger.head ||
        ledger.events.length != ledger.head) {
      throw StateError('Recovery history unavailable');
    }
    final ordered = ledger.events.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (var index = 0; index < ordered.length; index++) {
      if (ordered[index].sequence != index + 1 ||
          ordered[index].sessionId != original.sessionId ||
          (ordered[index].commandId == original.commandId &&
              ordered[index].schemaVersion != 1)) {
        throw StateError('Recovery history incomplete');
      }
    }
    final serverState = resolve(ordered, original.commandId);
    final merged = ManualVoiceTranscript.merge(original.message!, candidate);
    final committed = serverState == RecoveredTurnState.committed;
    return RecoveredTurnPlan(
      text: committed ? candidate.trim() : merged,
      originalCommand: original.commandId,
      restored: restored,
      serverState: serverState,
      shouldSubmit: !committed || merged != original.message!.trim(),
    );
  }

  static RecoveredTurnState resolve(
    Iterable<LedgerEvent> events,
    String command,
  ) {
    final matching = events.where((e) => e.commandId == command).toList();
    final cancellations = matching.where(
      (e) =>
          e.type == 'RUN_CANCELLED' &&
          e.payload['stage'] == 'recovery_revision',
    );
    final cutoff = cancellations.fold<int?>(
      null,
      (first, e) => first == null || e.sequence < first ? e.sequence : first,
    );
    if (matching.any(
      (e) =>
          e.type == 'ASSISTANT_TURN_COMMITTED' &&
          (cutoff == null || e.sequence < cutoff),
    )) {
      return RecoveredTurnState.committed;
    }
    if (matching.any(
      (e) => e.type == 'RUN_CANCELLED' || e.type == 'RUN_FAILED',
    )) {
      return RecoveredTurnState.terminated;
    }
    return matching.any((e) => e.type == 'USER_TURN_ACCEPTED')
        ? RecoveredTurnState.accepted
        : RecoveredTurnState.notAccepted;
  }
}

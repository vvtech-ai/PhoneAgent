import '../agent_protocol.dart';
import '../conversation_messages.dart';
import '../history/ledger_event.dart';
import '../receipts/call_receipt_projector.dart';
import '../receipts/batch_receipt_projector.dart';

/// Joins accepted live facts / read-only reconciliation with the applied UI.
/// No network, audio, history restore, or task state ownership.
class CommittedReplyNarration {
  String _session = '';
  _Terminal? _terminal;
  LedgerEvent? _pending;
  final _narrated = <String>{}, _consumed = <String>{};
  List<LedgerEvent> _facts = const [];
  Set<String> _visible = const {};

  /// Identity only: lets TTS diagnostics observe a visible result even after
  /// narration was cancelled and this join's session was cleared.
  ({String eventId, int sequence})? visibleResult(
    String sessionId,
    Iterable<LedgerEvent> facts,
    Iterable<ConversationMessage> messages,
  ) {
    if (sessionId.isEmpty) return null;
    final visible = {
      for (final message in messages)
        if (!message.transient &&
            message.role == MessageRole.assistant &&
            message.text.isNotEmpty)
          message.id,
    };
    final result = facts
        .where(
          (fact) =>
              _isReply(fact, sessionId) &&
              !_narrated.contains(fact.eventId) &&
              visible.contains('ledger:${fact.eventId}'),
        )
        .fold<LedgerEvent?>(
          null,
          (latest, fact) =>
              latest == null || fact.sequence > latest.sequence ? fact : latest,
        );
    return result == null
        ? null
        : (eventId: result.eventId, sequence: result.sequence);
  }

  void begin(String sessionId) {
    clear();
    _session = sessionId;
  }

  void clear() {
    _session = '';
    _terminal = null;
    _pending = null;
    _facts = const [];
    _visible = const {};
  }

  void committed(LedgerEvent fact) {
    if (_reply(fact) && !_narrated.contains(fact.eventId)) _pending = fact;
  }

  void terminal(AgentEvent event, {String commandId = ''}) {
    if (_session.isEmpty ||
        event.sessionId.isNotEmpty && event.sessionId != _session ||
        !const {
          AgentEventKind.signal,
          AgentEventKind.finalResponse,
        }.contains(event.kind)) {
      return;
    }
    final type = _text(event.payload, 'type');
    if (type != 'CALL_RESULT' && type != 'BATCH_CALL_RESULT') return;
    final call = ConversationMessages.object(event.payload['callResult']);
    final metadata = ConversationMessages.object(call['metadata']);
    final batch = ConversationMessages.object(event.payload['batchCallResult']);
    final attempt = _text(metadata, 'callAttemptId');
    final callId = _text(metadata, 'callId');
    final batchId = _text(batch, 'batchId');
    final wireCommand = _text(event.payload, 'commandId');
    final command = wireCommand.isEmpty ? commandId : wireCommand;
    final identity =
        [attempt, callId, batchId].where((s) => s.isNotEmpty).firstOrNull ??
        '$command|$type|${call['status']}|${batch['status']}|${event.text}';
    _set(
      _Terminal('$_session|$type|$identity', type, attempt, callId, batchId),
    );
  }

  void deferred(String callId) {
    if (_session.isEmpty || callId.trim().isEmpty) return;
    callId = callId.trim();
    _set(
      _Terminal('$_session|CALL_RESULT|$callId', 'CALL_RESULT', '', callId, ''),
    );
  }

  void deferredBatch(String batchId) {
    if (_session.isEmpty || batchId.isEmpty) return;
    _set(
      _Terminal(
        '$_session|BATCH_CALL_RESULT|$batchId',
        'BATCH_CALL_RESULT',
        '',
        '',
        batchId,
      ),
    );
  }

  void _set(_Terminal marker) {
    if (!_consumed.contains(marker.key)) _terminal = marker;
  }

  void project(
    Iterable<LedgerEvent> facts,
    Iterable<ConversationMessage> messages,
  ) {
    _facts = facts.where((e) => e.sessionId == _session).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    _visible = {
      for (final m in messages)
        if (!m.transient &&
            m.role == MessageRole.assistant &&
            m.text.isNotEmpty)
          m.id,
    };
  }

  String? take() => takeWithMetadata()?.text;

  ({String text, String eventId, int sequence})? takeWithMetadata() {
    final marker = _terminal;
    if (marker == null) return null;
    var reply = _pending;
    final sequence = _terminalSequence(marker);
    if (sequence != null) {
      reply =
          _facts
              .where(
                (e) =>
                    _reply(e) &&
                    e.sequence >= sequence &&
                    _reason(e) == marker.reason &&
                    !_narrated.contains(e.eventId) &&
                    _visible.contains('ledger:${e.eventId}'),
              )
              .lastOrNull ??
          reply;
    }
    if (reply == null ||
        !_visible.contains('ledger:${reply.eventId}') ||
        _reason(reply) != marker.reason ||
        _narrated.contains(reply.eventId)) {
      return null;
    }
    _pending = null;
    _terminal = null;
    _remember(_narrated, reply.eventId);
    _remember(_consumed, marker.key);
    return (
      text: _text(reply.payload, 'text'),
      eventId: reply.eventId,
      sequence: reply.sequence,
    );
  }

  int? _terminalSequence(_Terminal marker) {
    final sequences = <int>[];
    if (marker.type == 'CALL_RESULT') {
      for (final projection in CallReceiptProjector.project(_facts)) {
        final receipt = projection.receipt;
        if (!receipt.isRunning &&
            receipt.status.isNotEmpty &&
            (marker.attempt.isEmpty || marker.attempt == receipt.attemptId) &&
            (marker.call.isEmpty || marker.call == receipt.callId)) {
          sequences.add(projection.anchor.sequence);
        }
      }
    } else {
      for (final projection in BatchReceiptProjector.project(_facts)) {
        if (!projection.receipt.isRunning &&
            (marker.batch.isEmpty || marker.batch == projection.receipt.id)) {
          sequences.add(projection.anchor.sequence);
        }
      }
    }
    return sequences.isEmpty ? null : (sequences..sort()).last;
  }

  bool _reply(LedgerEvent e) => _isReply(e, _session);
  static bool _isReply(LedgerEvent e, String sessionId) =>
      e.sessionId == sessionId &&
      e.schemaVersion == 1 &&
      e.type == 'ASSISTANT_TURN_COMMITTED' &&
      const {'call_result', 'batch_call_result'}.contains(_reason(e)) &&
      _text(e.payload, 'text').isNotEmpty;
  static String _reason(LedgerEvent e) {
    final reason = _text(e.payload, 'finishReason').toLowerCase();
    if (reason == 'tool_terminal' &&
        BatchReceiptProjector.payload(e.payload).isNotEmpty) {
      return 'batch_call_result';
    }
    return reason;
  }

  static String _text(Map<String, Object?> map, String key) =>
      ConversationMessages.text(map, key).trim();
  static void _remember(Set<String> values, String value) {
    values.add(value);
    while (values.length > 128) {
      values.remove(values.first);
    }
  }
}

class _Terminal {
  const _Terminal(this.key, this.type, this.attempt, this.call, this.batch);
  final String key, type, attempt, call, batch;
  String get reason =>
      type == 'BATCH_CALL_RESULT' ? 'batch_call_result' : 'call_result';
}

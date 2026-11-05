import 'dart:async';
import '../../domain/agent_protocol.dart';
import '../../domain/receipts/batch_progress_tracker.dart';

/// Owns the subscription only; the conversation owns event ordering and facts.
class ConversationEventStream {
  ConversationEventStream(this.gateway);
  final AgentGateway gateway;
  AgentRun? _run;
  StreamSubscription<void>? _subscription;
  _Delivery? _delivery;
  Object? _token;
  void Function()? _onDetachedEnd;
  bool detachedBatchPending = false;

  /// Drops every UI callback while preserving this already-authorized stream.
  bool detach(void Function() onEnd) {
    if (_run == null) return false;
    _delivery = null;
    _onDetachedEnd = onEnd;
    detachedBatchPending = true;
    return true;
  }

  void start(
    AgentCommand command, {
    required bool Function() isCurrent,
    required Future<void> Function(AgentEvent) accept,
    required void Function(Object) onError,
    required void Function() onDone,
  }) {
    cancel();
    final token = Object();
    _token = token;
    _delivery = _Delivery(isCurrent, accept, onError, onDone);
    try {
      final run = gateway.start(command);
      _run = run;
      _subscription = run.events
          .asyncMap<void>((event) async {
            if (_token != token) return;
            if (event.sessionId.isNotEmpty &&
                event.sessionId != command.sessionId) {
              throw AgentTransportFailure.malformed;
            }
            final delivery = _delivery;
            if (delivery == null) {
              if (BatchProgressTracker.isFinal(event) ||
                  event.kind == AgentEventKind.error) {
                detachedBatchPending = false;
              }
              if (event.kind == AgentEventKind.done ||
                  event.kind == AgentEventKind.error) {
                cancel();
              }
            } else if (delivery.isCurrent()) {
              await delivery.accept(event);
            }
          })
          .listen(
            (_) {},
            onError: (Object error, StackTrace stack) {
              if (_token != token) return;
              final delivery = _delivery;
              if (delivery == null) {
                cancel();
              } else if (delivery.isCurrent()) {
                delivery.onError(error);
              }
            },
            onDone: () {
              if (_token != token) return;
              final delivery = _delivery;
              if (delivery == null) {
                cancel();
              } else {
                _run = null;
                if (delivery.isCurrent()) delivery.onDone();
              }
            },
          );
    } catch (error) {
      if (isCurrent()) onError(error);
    }
  }

  void cancel() {
    _token = null;
    _delivery = null;
    _run?.cancel();
    _run = null;
    _subscription?.cancel();
    _subscription = null;
    detachedBatchPending = false;
    final onEnd = _onDetachedEnd;
    _onDetachedEnd = null;
    onEnd?.call();
  }
}

class _Delivery {
  const _Delivery(this.isCurrent, this.accept, this.onError, this.onDone);
  final bool Function() isCurrent;
  final Future<void> Function(AgentEvent) accept;
  final void Function(Object) onError;
  final void Function() onDone;
}

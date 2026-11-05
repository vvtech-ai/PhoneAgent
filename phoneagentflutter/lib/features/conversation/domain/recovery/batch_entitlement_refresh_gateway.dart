import 'dart:async';
import '../agent_failure.dart';
import '../agent_protocol.dart';

/// Invalidates displayed rights after a denial; never retries task commands.
class BatchEntitlementRefreshGateway implements AgentGateway {
  BatchEntitlementRefreshGateway(
    this.delegate, {
    required this.refresh,
    required this.isCurrent,
  });
  final AgentGateway delegate;
  final void Function() refresh;
  final bool Function() isCurrent;
  bool _closed = false;

  static const _codes = {
    'BATCH_CONTACT_LIMIT',
    'BATCH_CONCURRENCY_LIMIT',
    'BATCH_ENTITLEMENT_LIMIT',
  };

  @override
  AgentRun start(AgentCommand command) {
    final run = delegate.start(command);
    var active = true, refreshed = false;
    void observe(Object? code) {
      if (_closed || !active || refreshed || !_codes.contains(code)) return;
      try {
        if (!isCurrent()) return;
        refreshed = true;
        refresh();
      } catch (_) {
        // A failed UI refresh must not replace the original task response.
      }
    }

    return AgentRun(
      run.events.transform(
        StreamTransformer<AgentEvent, AgentEvent>.fromHandlers(
          handleData: (event, sink) {
            observe(event.payload['errorCode'] ?? event.payload['code']);
            sink.add(event);
          },
          handleError: (Object error, StackTrace stack, sink) {
            if (error is AgentFailure) observe(error.errorCode);
            sink.addError(error, stack);
          },
        ),
      ),
      () {
        active = false;
        run.cancel();
      },
    );
  }

  void close() => _closed = true;
}

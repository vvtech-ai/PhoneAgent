import '../../domain/receipts/batch_progress_tracker.dart';
import 'conversation_state.dart';

/// Rechecks a transient batch card when its conversation returns to foreground.
class ConversationForegroundBatchRecovery {
  ConversationForegroundBatchRecovery({
    required this.current,
    required this.generation,
    required this.read,
    required this.write,
    required this.batch,
    required this.resumeBatch,
    required this.synchronize,
    required this.acceptedStop,
    this.onCompleted,
  });

  final bool Function() current;
  final int Function() generation;
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final BatchProgressTracker batch;
  final bool Function(String) resumeBatch;
  final Future<bool> Function() synchronize;
  final bool Function() acceptedStop;
  final void Function()? onCompleted;
  Future<void>? _ledgerSync;

  Future<void> resume() async {
    if (!current()) return;
    if (batch.active) {
      resumeBatch(batch.batchId);
      return;
    }
    final snapshot = read();
    if (snapshot.phase != ConversationPhase.ready) return;
    final pending = snapshot.messages
        .where(
          (message) =>
              message.transient &&
              message.id.endsWith(':batch-progress') &&
              message.batchReceipt != null,
        )
        .firstOrNull;
    if (pending == null) return;
    final inFlight = _ledgerSync;
    if (inFlight != null) return inFlight;
    final run = generation();
    final sync = _resumeTransientBatch(
      run,
      pending.commandId ?? '',
      pending.batchReceipt!.explicitId,
    );
    _ledgerSync = sync;
    try {
      await sync;
    } finally {
      if (identical(_ledgerSync, sync)) _ledgerSync = null;
    }
  }

  Future<void> _resumeTransientBatch(
    int run,
    String command,
    String batchId,
  ) async {
    try {
      await synchronize();
    } catch (_) {
      return;
    }
    if (!current() ||
        generation() != run ||
        read().phase != ConversationPhase.ready) {
      return;
    }
    final settled = read().messages.any(
      (message) =>
          !message.transient &&
          message.batchReceipt != null &&
          (acceptedStop()
              ? message.batchReceipt!.stopSettled
              : !message.batchReceipt!.isRunning) &&
          (batchId.isNotEmpty
              ? message.batchReceipt?.explicitId == batchId
              : command.isNotEmpty && message.commandId == command),
    );
    if (!settled) return;
    final previous = read();
    write(
      previous.copy(
        activity: '',
        transientStatus: '',
        notice: previous.notice == batchUnconfirmedNotice ? '' : null,
      ),
    );
    onCompleted?.call();
  }
}

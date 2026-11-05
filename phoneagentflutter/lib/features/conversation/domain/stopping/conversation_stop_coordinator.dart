import 'conversation_stop.dart';

/// Stop operations only; final task status still comes from the existing ledger.
class ConversationStopCoordinator {
  ConversationStopCoordinator({
    required this.repository,
    required this.sessionId,
    required this.current,
    required this.accepted,
    required this.synchronize,
    required this.notice,
    required this.changed,
    this.batchAccepted,
    this.submitBatchStop,
    this.activeBatch,
    this.canStopBatch,
  });
  final ConversationStopRepository repository;
  final String sessionId;
  final bool Function() current;
  final void Function() accepted;
  final Future<bool> Function() synchronize;
  final void Function(String) notice;
  final void Function() changed;
  final void Function(String)? batchAccepted;
  final Future<BatchStopResult> Function(
    String batchId,
    Future<BatchStopResult> Function() request,
  )?
  submitBatchStop;
  final String? Function()? activeBatch;
  final bool Function(String)? canStopBatch;
  bool busy = false;
  bool _accepted = false;
  String? retryBatchId;
  bool get awaitingSettlement => _accepted && retryBatchId == null;
  int _revision = 0;
  void restoreBatchStop(
    String batchId, {
    required bool retryable,
    bool pending = false,
  }) {
    _revision++;
    busy = pending;
    _accepted = true;
    retryBatchId = retryable ? batchId : null;
  }

  void invalidate() {
    _revision++;
    busy = false;
    _accepted = false;
    retryBatchId = null;
  }

  Future<void> stop(
    String command,
    Future<bool> Function(String) confirmBatch,
  ) async {
    if (busy || !current() || command.isEmpty) return;
    busy = true;
    changed();
    final revision = ++_revision;
    bool valid() => current() && revision == _revision;
    try {
      String? stoppedBatch;
      final live = activeBatch?.call();
      final retry = retryBatchId ?? live;
      if (!_accepted || retryBatchId != null) {
        if (retry != null && canStopBatch?.call(retry) == false) return;
        final result = retry == null
            ? await repository.stop(sessionId, command)
            : TurnStopResult(TurnStopStatus.batchConfirmationRequired, retry);
        if (!valid()) return;
        if (result.status == TurnStopStatus.batchConfirmationRequired) {
          if (!await confirmBatch(result.batchId!) || !valid()) return;
          if (live != null && activeBatch?.call() != result.batchId) return;
          if (canStopBatch?.call(result.batchId!) == false) return;
          final batchId = result.batchId!;
          Future<BatchStopResult> request() =>
              repository.stopBatch(sessionId, batchId);
          final batch =
              await (submitBatchStop?.call(batchId, request) ?? request());
          if (!valid()) return;
          stoppedBatch = batch.batchId;
          retryBatchId = batch.failedCalls > 0 ? batch.batchId : null;
          if (batch.failedCalls > 0) {
            notice('仍有${batch.failedCalls}项停止失败，点击重试');
          }
        }
        _accepted = true;
        accepted();
        if (stoppedBatch != null) batchAccepted?.call(stoppedBatch);
      }
      for (var attempt = 0; attempt < 10 && valid(); attempt++) {
        if (await synchronize() || !valid()) return;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (valid()) {
        notice(retryBatchId == null ? '停止处理中，点击同步' : '仍有停止失败项，点击重试');
      }
    } catch (_) {
      if (valid()) notice('停止任务失败，点击重试');
    } finally {
      if (valid()) {
        busy = false;
        changed();
      }
    }
  }
}

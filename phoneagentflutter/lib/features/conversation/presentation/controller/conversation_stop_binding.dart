import 'dart:async';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../domain/receipts/batch_progress_tracker.dart';
import '../../domain/receipts/batch_receipt.dart';
import '../../domain/stopping/conversation_stop.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/stopping/batch_progress.dart';
import '../../domain/stopping/batch_progress_recovery.dart';
import '../../domain/receipts/batch_receipt_projector.dart';
import '../../domain/stopping/conversation_stop_coordinator.dart';
import 'conversation_message_store.dart';
import 'conversation_foreground_batch_recovery.dart';
import 'conversation_state.dart';
import 'detached_batch_streams.dart';

class ConversationStopBinding {
  ConversationStopBinding({
    required ConversationStopRepository? repository,
    this.accountId = '',
    this.detachedBatches,
    required this.sessionId,
    required this.current,
    required this.read,
    required void Function(ConversationState) write,
    required ConversationMessageStore messages,
    required this.batch,
    required this.cancelPreparing,
    required void Function() cancelReplies,
    required Future<void>? Function() interruptSpeech,
    required Future<bool> Function() synchronize,
    int Function()? generation,
    this.onBatchRecovery,
    this.onBatchCompleted,
    this.diagnostics,
  }) {
    _foreground = ConversationForegroundBatchRecovery(
      current: current,
      generation: generation ?? () => 0,
      read: read,
      write: write,
      batch: batch,
      resumeBatch: resumeBatch,
      synchronize: synchronize,
      onCompleted: onBatchCompleted,
      acceptedStop: () => _accepted,
    );
    bool hasSettled() {
      final command = _command;
      if (command.isEmpty) return false;
      bool receiptSettled(BatchReceipt receipt) =>
          _accepted ? receipt.stopSettled : !receipt.isRunning;
      if (_batchId != null || batch.active) {
        return read().messages.any(
              (message) =>
                  message.batchReceipt != null &&
                  receiptSettled(message.batchReceipt!) &&
                  (_batchId != null
                      ? message.batchReceipt?.explicitId == _batchId
                      : message.commandId == command),
            ) ||
            BatchReceiptProjector.project(messages.facts.values).any(
              (p) =>
                  receiptSettled(p.receipt) &&
                  (_batchId != null
                      ? p.receipt.explicitId == _batchId
                      : p.anchor.commandId == command),
            );
      }
      return messages.facts.values.any(
        (event) =>
            event.commandId == command &&
            {
              'RUN_CANCELLED',
              'RUN_FAILED',
              'ASSISTANT_TURN_COMMITTED',
            }.contains(event.type),
      );
    }

    _hasSettled = hasSettled;
    BatchReceipt? visibleBatchResult(String id) => read().messages
        .where((message) => message.batchReceipt?.explicitId == id)
        .map((message) => message.batchReceipt!)
        .where((receipt) => !receipt.isRunning)
        .firstOrNull;

    bool visibleSnapshotResult() {
      final snapshot = _lastSnapshot;
      if (snapshot == null ||
          snapshot.resultSequence <= 0 ||
          snapshot.committedResult?['batchId'] != snapshot.batchId) {
        return false;
      }
      final receipt = visibleBatchResult(snapshot.batchId);
      _record(
        DiagnosticBatchResultStage.visibleResult,
        snapshot.batchId,
        snapshot: snapshot,
        receipt: receipt,
      );
      return receipt != null && (!_accepted || receipt.stopSettled);
    }

    Future<bool> settled() async {
      var synchronized = false;
      var historyFailed = false;
      try {
        synchronized = await synchronize();
      } catch (_) {
        historyFailed = true;
      }
      if (!current()) return false;
      final id = _batchId ?? batch.batchId;
      final settledInHistory = synchronized && hasSettled();
      _record(
        DiagnosticBatchResultStage.historyRead,
        id,
        receipt: settledInHistory ? visibleBatchResult(id) : null,
        result: historyFailed ? DiagnosticResult.failed : null,
      );
      if (settledInHistory) {
        if (_batchId != null || batch.active) {
          _record(
            DiagnosticBatchResultStage.visibleResult,
            id,
            receipt: visibleBatchResult(id),
          );
        }
        return true;
      }
      return visibleSnapshotResult();
    }

    void completed() {
      if (!current()) return;
      _feedback = false;
      _flow?.invalidate();
      _stopObservationCancel?.call();
      _stopObservationCancel = null;
      final completedBatchId = _batchId ?? batch.batchId;
      if (completedBatchId.isNotEmpty) {
        detachedBatches?.clearAcceptedStop(
          accountId,
          sessionId,
          completedBatchId,
        );
      }
      final wasActiveBatch = batch.active;
      if (wasActiveBatch) batch.finish(_command, batchId: _batchId ?? '');
      final previous = read();
      write(
        previous.copy(
          phase: ConversationPhase.ready,
          activity: '',
          transientStatus: '',
          notice: previous.notice == batchUnconfirmedNotice ? '' : null,
        ),
      );
      final snapshot = _lastSnapshot;
      if (snapshot != null && snapshot.resultSequence > 0) {
        _record(
          DiagnosticBatchResultStage.visibleResult,
          snapshot.batchId,
          snapshot: snapshot,
          receipt: visibleBatchResult(snapshot.batchId),
        );
      }
      if (wasActiveBatch) onBatchCompleted?.call();
    }

    _completed = completed;
    _clearStatus = () {
      if (current()) write(read().copy(transientStatus: ''));
    };

    _hasProgress = repository is BatchProgressRepository;
    _recovery = BatchProgressRecovery(
      repository: repository is BatchProgressRepository
          ? repository as BatchProgressRepository
          : null,
      sessionId: sessionId,
      current: current,
      synchronize: settled,
      apply: (snapshot) {
        if (!batch.active ||
            (batch.batchId.isNotEmpty && batch.batchId != snapshot.batchId) ||
            (_batchId != null && _batchId != snapshot.batchId)) {
          return;
        }
        _lastSnapshot = snapshot;
        _record(
          DiagnosticBatchResultStage.progressRead,
          snapshot.batchId,
          snapshot: snapshot,
        );
        for (final event in snapshot.events) {
          batch.accept(event, _command);
        }
        batch.progressRead();
        messages.batch(_command, batch.snapshot());
        if (snapshot.resultSequence > 0) {
          final result = snapshot.committedResult;
          if (result != null && result['batchId'] == snapshot.batchId) {
            final receipt = BatchReceipt.fromJson(
              result,
              fallbackId: snapshot.batchId,
            );
            if (!receipt.isRunning) {
              messages.finish({
                'batchCallResult': result,
                'resultSequence': snapshot.resultSequence,
              }, _command);
            }
          }
        }
        final projected = messages.project(read());
        write(
          projected.activity == '外呼请求失败，正在核对拨号状态，请稍后刷新'
              ? projected.copy(activity: '')
              : projected,
        );
        if (snapshot.resultSequence > 0) {
          final visible = read().messages
              .where(
                (message) =>
                    message.batchReceipt?.explicitId == snapshot.batchId,
              )
              .map((message) => message.batchReceipt!)
              .firstOrNull;
          final receipt = visible?.isRunning == false ? visible : null;
          _record(
            DiagnosticBatchResultStage.visibleResult,
            snapshot.batchId,
            snapshot: snapshot,
            receipt: receipt,
          );
        }
      },
      completed: completed,
      readFailed: (id) => _record(
        DiagnosticBatchResultStage.progressRead,
        id,
        result: DiagnosticResult.failed,
      ),
      exhausted: (id) {
        if (!current() ||
            !batch.active ||
            (batch.batchId.isNotEmpty && batch.batchId != id)) {
          return;
        }
        messages.batch(_command, batch.snapshot(unconfirmed: true));
        batch.stopObserving();
        write(
          messages
              .project(read())
              .copy(
                phase: ConversationPhase.ready,
                activity: '',
                notice: batchUnconfirmedNotice,
              ),
        );
        _record(
          DiagnosticBatchResultStage.visibleResult,
          id,
          result: DiagnosticResult.failed,
        );
      },
    );
    if (repository == null) return;
    _flow = ConversationStopCoordinator(
      repository: repository,
      sessionId: sessionId,
      current: current,
      activeBatch: () =>
          batch.active && batch.batchId.isNotEmpty ? batch.batchId : null,
      canStopBatch: (id) =>
          !batch.completed(id) &&
          !batch.awaitingAggregate &&
          (batch.batchId.isEmpty || batch.batchId == id) &&
          (_batchId == null || _batchId == id),
      notice: (text) {
        _feedback = true;
        if (current()) write(read().copy(transientStatus: text));
      },
      changed: () {
        if (_flow?.busy == true) _feedback = false;
        if (current()) {
          write(
            read().copy(
              transientStatus: _flow?.busy == true
                  ? (_accepted ? '正在同步停止结果…' : '正在停止任务…')
                  : !_accepted && !_feedback
                  ? ''
                  : null,
            ),
          );
        }
      },
      accepted: () {
        _accepted = true;
        cancelPreparing();
        cancelReplies();
        unawaited(interruptSpeech());
        messages.finishTools();
        write(
          read().copy(
            phase: ConversationPhase.sending,
            activity: '',
            transientStatus: _flow?.retryBatchId == null
                ? '正在同步停止结果…'
                : read().transientStatus,
          ),
        );
      },
      batchAccepted: (id) {
        _batchId = id;
        onBatchRecovery?.call(id);
        _recovery?.start(id);
      },
      submitBatchStop: detachedBatches == null
          ? null
          : (id, request) =>
                detachedBatches!.trackStop(accountId, sessionId, id, request),
      synchronize: () async {
        final done = await settled();
        if (done && current()) {
          _recovery?.stop();
          completed();
        }
        return done;
      },
    );
    _restore = (restored) {
      final projected = BatchReceiptProjector.project(messages.facts.values);
      for (final result in projected) {
        if (result.receipt.stopSettled &&
            result.receipt.explicitId.isNotEmpty) {
          detachedBatches?.clearAcceptedStop(
            accountId,
            sessionId,
            result.receipt.explicitId,
          );
        }
      }
      final id = restored.detail.activeBatchId.trim();
      final observation = id.isEmpty
          ? null
          : detachedBatches?.stopObservation(accountId, sessionId, id);
      if (!current() ||
          id.isEmpty ||
          projected.any(
            (p) =>
                p.receipt.explicitId == id &&
                (observation == null
                    ? !p.receipt.isRunning
                    : p.receipt.stopSettled),
          )) {
        return;
      }
      invalidate();
      _command = restored.detail.activeCommandId.trim();
      if (_command.isEmpty) _command = 'restored-batch:$id';
      _batchId = id;
      if (observation == null) {
        _flow!.retryBatchId = id;
      } else {
        _accepted = true;
        _flow!.restoreBatchStop(
          id,
          retryable: (observation.failedCalls ?? 0) > 0,
          pending: observation.pending,
        );
      }
      batch.accept(
        AgentEvent(AgentEventKind.status, payload: {'batchId': id}),
        _command,
      );
      write(
        read().copy(
          phase: ConversationPhase.sending,
          activity: observation == null ? '正在执行多路外呼，完成后会汇总结果' : '',
          transientStatus: observation == null
              ? ''
              : observation.pending
              ? '正在停止任务…'
              : observation.failedCalls! > 0
              ? '仍有${observation.failedCalls}项停止失败，点击重试'
              : '正在同步停止结果…',
        ),
      );
      _recovery?.start(id);
      if (observation?.pending == true) {
        _stopObservationCancel = detachedBatches?.observeStop(
          accountId,
          sessionId,
          id,
          (updated) {
            if (!current() || _batchId != id || updated?.pending == true) {
              return;
            }
            if (_hasSettled?.call() == true) {
              reconcile();
              return;
            }
            _stopObservationCancel?.call();
            _stopObservationCancel = null;
            if (updated == null) {
              _accepted = false;
              _flow!.invalidate();
              _flow!.retryBatchId = id;
              _feedback = true;
              write(
                read().copy(
                  phase: ConversationPhase.sending,
                  transientStatus: '停止任务失败，点击重试',
                ),
              );
              return;
            }
            _accepted = true;
            final failedCalls = updated.failedCalls!;
            _flow!.restoreBatchStop(id, retryable: failedCalls > 0);
            _feedback = failedCalls > 0;
            write(
              read().copy(
                phase: ConversationPhase.sending,
                transientStatus: failedCalls > 0
                    ? '仍有$failedCalls项停止失败，点击重试'
                    : '正在同步停止结果…',
              ),
            );
          },
        );
      }
    };
  }
  final bool Function() current;
  late final ConversationForegroundBatchRecovery _foreground;
  final String accountId;
  final DetachedBatchStreams? detachedBatches;
  final String sessionId;
  final ConversationState Function() read;
  final BatchProgressTracker batch;
  final void Function() cancelPreparing;
  void Function(RestoredConversation)? _restore;
  void restored(RestoredConversation value) => _restore?.call(value);
  ConversationStopCoordinator? _flow;
  String _command = '';
  String? _batchId;
  bool _accepted = false;
  bool _feedback = false;
  void Function()? _stopObservationCancel;
  bool Function()? _hasSettled;
  void Function()? _completed, _clearStatus;
  void reconcile() {
    if (!current() ||
        read().transientStatus.isEmpty && !busy ||
        _hasSettled?.call() != true) {
      return;
    }
    _accepted = true;
    _flow?.invalidate();
    _recovery?.stop();
    _completed?.call();
  }

  bool get suppressInteractions => _accepted;
  void serverCancelled() {
    _accepted = true;
    cancelPreparing();
  }

  BatchProgressRecovery? _recovery;
  BatchProgressSnapshot? _lastSnapshot;
  bool _hasProgress = false;
  final void Function(String)? onBatchRecovery;
  final void Function()? onBatchCompleted;
  final DiagnosticSink? diagnostics;
  void _record(
    DiagnosticBatchResultStage stage,
    String batchId, {
    BatchProgressSnapshot? snapshot,
    BatchReceipt? receipt,
    DiagnosticResult? result,
  }) {
    if (diagnostics == null || batchId.isEmpty) return;
    final pageWaiting =
        stage == DiagnosticBatchResultStage.visibleResult &&
        (read().phase == ConversationPhase.sending ||
            read().phase == ConversationPhase.restoring);
    emitDiagnostic(
      diagnostics,
      DiagnosticEvent(
        operation: DiagnosticOperation.batchResultSync,
        result:
            result ??
            (stage == DiagnosticBatchResultStage.visibleResult
                ? receipt == null
                      ? DiagnosticResult.failed
                      : pageWaiting
                      ? DiagnosticResult.received
                      : DiagnosticResult.succeeded
                : snapshot != null || receipt == null
                ? DiagnosticResult.received
                : DiagnosticResult.succeeded),
        sessionId: sessionId,
        batchResult: DiagnosticBatchResultDetails(
          stage: stage,
          batchId: batchId,
          hasResult: stage == DiagnosticBatchResultStage.visibleResult
              ? receipt != null
              : snapshot?.hasResult ?? receipt != null,
          resultSequence:
              snapshot?.resultSequence ??
              (_lastSnapshot?.batchId == batchId
                  ? _lastSnapshot?.resultSequence
                  : null) ??
              0,
          execution: DiagnosticBatchResultDetails.executionFromWire(
            snapshot?.executionStatus ?? receipt?.executionStatus,
          ),
          completedCount: receipt?.completedCount ?? 0,
          totalCount: receipt?.totalCount ?? 0,
          pageWaiting: stage == DiagnosticBatchResultStage.visibleResult
              ? pageWaiting
              : null,
        ),
      ),
    );
  }

  // Finishing one readback window does not finish an accepted stop operation.
  bool get busy =>
      _flow?.busy == true ||
      (_flow?.awaitingSettlement == true && _hasSettled?.call() != true);
  bool get available =>
      _flow != null &&
      current() &&
      (((read().phase == ConversationPhase.sending ||
                  read().phase == ConversationPhase.ready && batch.active) &&
              !batch.awaitingAggregate) ||
          busy ||
          _flow?.awaitingSettlement == true ||
          _flow?.retryBatchId != null);
  void started(String command) {
    invalidate();
    _command = command;
  }

  bool recoverBatch(String id) {
    if (!current() || !batch.active || _recovery == null) return false;
    if (batch.batchId.isNotEmpty && batch.batchId != id) return false;
    if (!batch.uncertain && !_hasProgress) return false;
    _batchId = id.isEmpty ? null : id;
    if (id.isNotEmpty) onBatchRecovery?.call(id);
    _recovery!.refresh(id);
    return true;
  }

  bool resumeBatch(String id) {
    if (!current() ||
        !batch.active ||
        _recovery == null ||
        batch.batchId != id ||
        (_batchId != null && _batchId != id)) {
      return false;
    }
    _recovery!.refresh(id);
    return true;
  }

  Future<void> resumeAfterInterruption() => _foreground.resume();

  void invalidate() {
    _stopObservationCancel?.call();
    _stopObservationCancel = null;
    _flow?.invalidate();
    _recovery?.stop();
    _lastSnapshot = null;
    _accepted = false;
    _feedback = false;
    _clearStatus?.call();
    _batchId = null;
  }

  Future<void> stop(Future<bool> Function(String) confirmBatch) async {
    if (batch.active && batch.batchId.isNotEmpty) _batchId ??= batch.batchId;
    await _flow?.stop(_command, confirmBatch);
  }
}

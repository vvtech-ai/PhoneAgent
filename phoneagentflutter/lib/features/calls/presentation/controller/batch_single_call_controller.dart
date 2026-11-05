import 'dart:async';
import '../../domain/batch_call_session_repository.dart';
import '../../domain/call_session.dart';
import '../../data/batch_stop_call_session_repository.dart';
import '../../../conversation/domain/agent_protocol.dart';
import '../../../conversation/domain/receipts/batch_progress_order.dart';
import 'call_session_controller.dart';
import 'call_session_state.dart';

/// Presentation only; batch execution, retry and result ownership stay unchanged.
class BatchSingleCallController {
  BatchSingleCallController({
    required this.sessionId,
    required this.repositories,
    required this.changed,
    this.stopBatch,
  });
  final String sessionId;
  final BatchCallSessionRepositoryFactory repositories;
  final void Function() changed;
  final Future<bool> Function(String)? stopBatch;
  final _order = BatchProgressOrder();
  final _finished = <String>{}, _multiple = <String>{};
  String _batch = '', _attempt = '', _command = '';
  CallSessionController? _call;
  void Function()? _remove;
  Timer? _clock;
  final _elapsed = Stopwatch();
  bool _closed = false;
  bool _stopping = false, _stopAccepted = false;
  bool _closingObserved = false;
  CallSessionState? get call => _call?.snapshot;
  int get seconds => _elapsed.elapsed.inSeconds;
  bool get showCall {
    final value = call;
    return value != null &&
        !_closingObserved &&
        value.target.callId.isNotEmpty &&
        value.launchProven &&
        !value.dismissRequested &&
        !value.ending &&
        !value.progress.closureObserved &&
        value.snapshot?.primaryClosed != true &&
        value.snapshot?.dialFailureObserved != true &&
        value.snapshot?.isTerminal != true;
  }

  void accept(AgentEvent event, String command) {
    if (_closed || event.sessionId != sessionId) return;
    final data = event.payload;
    if (event.kind != AgentEventKind.status) return;
    final batch = data['batchId'], attempt = data['callAttemptId'];
    if (batch is! String || batch.isEmpty || _finished.contains(batch)) return;
    final nextExecution = _batch.isNotEmpty && _batch != batch;
    if (nextExecution) {
      if (!_finished.contains(_batch) ||
          command.isEmpty ||
          command == _command) {
        return;
      }
    } else if (_command.isNotEmpty && command != _command) {
      return;
    }
    if (data['total'] is int && (data['total'] as int) > 1) {
      _multiple.add(batch);
      if (_batch == batch) _release();
      return;
    }
    if (_multiple.contains(batch) ||
        data['total'] != 1 ||
        data['itemIndex'] != 1 ||
        attempt is! String ||
        attempt.isEmpty) {
      return;
    }
    if (nextExecution) _resetExecution();
    if ((_stopping || _stopAccepted) && attempt != _attempt) return;
    if (!_order.accept(1, data)) return;
    _command = command;
    _batch = batch;
    final newAttempt = _attempt != attempt;
    final closing = _closingProgress(data);
    final gateChanged =
        _closingObserved !=
        (newAttempt ? closing : _closingObserved || closing);
    _closingObserved = newAttempt ? closing : _closingObserved || closing;
    if (_attempt != attempt) {
      _release();
      _attempt = attempt;
      final repository = repositories.forBatch(sessionId, batch, attempt);
      final observer = CallSessionController(
        conversationId: sessionId,
        target: CallSessionTarget(taskId: batch, attemptId: attempt),
        repository: stopBatch == null
            ? repository
            : BatchStopCallSessionRepository(
                repository,
                () => _stopOriginalBatch(batch, attempt),
              ),
      );
      _call = observer;
      _remove = observer.addListener((value) {
        if (_closed || _call != observer) return;
        if (value.connected && !_elapsed.isRunning) _elapsed.start();
        if (value.ending ||
            value.progress.closureObserved ||
            value.snapshot?.isTerminal == true) {
          _elapsed.stop();
        }
        changed();
      }, fireImmediately: false);
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_elapsed.isRunning) changed();
      });
      observer.start();
    }
    // No readiness is inferred from batch progress, IDs or admission events.
    _call?.acceptProgress(
      attempt,
      '',
      outcomePush: false,
      progress: {
        if (data['primaryClosed'] is bool)
          'primaryClosed': data['primaryClosed'],
        if (data['dialFailureObserved'] is bool)
          'dialFailureObserved': data['dialFailureObserved'],
        'status': data['primaryClosed'] == true
            ? 'ENDING'
            : BatchProgressOrder.status(data),
      },
    );
    if (gateChanged) changed();
  }

  // Current-command progress is filtered by the conversation owner. A tool-start
  // hint is neither required nor sufficient to replace an execution's identity.
  void _resetExecution() {
    _release();
    _batch = '';
    _attempt = '';
    _command = '';
    _order.clear();
    _stopping = false;
    _stopAccepted = false;
    _closingObserved = false;
  }

  // The shared call observer cannot consume progress until its callId resolves.
  // Keep presentation closure proof per attempt so a late ready pull cannot reopen it.
  static bool _closingProgress(Map<String, Object?> data) =>
      data['primaryClosed'] == true ||
      data['dialFailureObserved'] == true ||
      data['userCancelRequested'] == true ||
      const {
        'ENDING',
        'CANCELLING',
        'STOP_ACCEPTED',
        'PRIMARY_CLOSED_FORK_OBSERVING',
        'PHYSICAL_CLOSED',
        'RESULT_PENDING',
        'ENDED',
        'FAILED',
        'SUCCESS',
        'UNCLEAR',
        'USER_CANCELLED',
      }.contains(BatchProgressOrder.status(data).toUpperCase());

  Future<bool> hangUp() async {
    if (_closed || _stopping || _call == null) return false;
    final observer = _call;
    _stopping = true;
    try {
      final accepted = await observer!.hangUp();
      if (!_closed && _call == observer && accepted) _stopAccepted = true;
      return accepted;
    } finally {
      if (_call == observer) _stopping = false;
    }
  }

  Future<bool> _stopOriginalBatch(String batch, String attempt) async {
    final accepted = await stopBatch!(batch);
    if (!_closed && _batch == batch && _attempt == attempt && accepted) {
      // Acceptance is authoritative even if the following physical read fails.
      _stopAccepted = true;
      _closingObserved = true;
      changed();
    }
    return accepted;
  }

  void finish(String batchId) {
    if (!_finished.add(batchId)) return;
    if (_batch == batchId) {
      _release();
      changed();
    }
  }

  void _release() {
    _remove?.call();
    _remove = null;
    _call?.dispose();
    _call = null;
    _clock?.cancel();
    _clock = null;
    _elapsed
      ..stop()
      ..reset();
  }

  void dispose() {
    _closed = true;
    _release();
  }
}

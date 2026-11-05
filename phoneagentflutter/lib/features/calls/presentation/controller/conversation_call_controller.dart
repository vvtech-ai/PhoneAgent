import '../../../conversation/domain/receipts/call_receipt.dart';
import '../../../conversation/domain/receipts/call_receipt_projector.dart';
import '../../../conversation/domain/receipts/call_receipt_status.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../domain/call_admission_service.dart';
import '../../domain/points_admission_rejection.dart';
import '../../domain/call_launch_coordinator.dart';
import '../../domain/call_launch_request.dart';
import '../../domain/call_session.dart';
import '../../domain/batch_call_session_repository.dart';
import 'batch_single_call_controller.dart';
import '../../../conversation/domain/agent_protocol.dart';
import '../../../conversation/domain/agent_failure.dart';
import '../../../conversation/domain/conversation_messages.dart';
import '../../../conversation/domain/history/call_request_history.dart';
import '../../../conversation/domain/history/conversation_history.dart';
import 'call_session_controller.dart';
import 'call_session_state.dart';
import 'conversation_call_diagnostics.dart';

class ConversationCallState {
  const ConversationCallState({
    this.launch = const CallLaunchState(CallLaunchPhase.idle),
    this.call,
    this.showCall = false,
    this.seconds = 0,
  });
  final CallLaunchState launch;
  final CallSessionState? call;
  final bool showCall;
  final int seconds;
}

/// One conversation's execution lifecycle; no Widget, navigation or audio IO.
class ConversationCallController extends StateNotifier<ConversationCallState> {
  ConversationCallController({
    required CallAdmissionService admission,
    required CallSessionRepository sessions,
    required Future<void> Function(CallLaunchRequest) submit,
    required this.onBlocked,
    required this.syncOutcome,
    this.syncUnregisteredOutcome,
    this.onPhysicalEnded,
    this.onResultConfirmed,
    this.onOutcomeUnconfirmed,
    this.diagnostics,
    Stopwatch? elapsed,
    String sessionId = '',
    Future<bool> Function(String)? stopBatch,
  }) : _admission = admission,
       _sessions = sessions,
       _elapsed = elapsed ?? Stopwatch(),
       super(const ConversationCallState()) {
    _launch = CallLaunchCoordinator(
      admission: admission,
      submit: submit,
      onState: _applyLaunch,
    );
    if (sessions is BatchCallSessionRepositoryFactory && sessionId.isNotEmpty) {
      _batchCall = BatchSingleCallController(
        sessionId: sessionId,
        repositories: sessions as BatchCallSessionRepositoryFactory,
        changed: () {
          if (!mounted || _closed) return;
          // Notify the host without handing batch outcomes to the single-call owner.
          state = ConversationCallState(
            launch: state.launch,
            call: state.call,
            showCall: state.showCall,
            seconds: state.seconds,
          );
        },
        stopBatch: stopBatch,
      );
    }
  }
  final CallSessionRepository _sessions;
  final CallAdmissionService _admission;
  final _balanceRejections = <String>{};
  final void Function(CallLaunchState) onBlocked;
  final Future<bool> Function(String callId, bool Function() observationCurrent)
  syncOutcome;
  final Future<void> Function(bool Function() observationCurrent)?
  syncUnregisteredOutcome;
  final void Function()? onPhysicalEnded;
  final void Function()? onResultConfirmed;
  final void Function()? onOutcomeUnconfirmed;
  final DiagnosticSink? diagnostics;
  late final CallLaunchCoordinator _launch;
  final List<CallLaunchRequest> _requests = [];
  final Set<String> _knownCallIds = {};
  final List<(String, CallSessionTarget)> _retiredOutcomes = [];
  CallSessionController? _call;
  void Function()? _remove;
  Timer? _clock, _outcomeTimer, _unregisteredDeadline, _registeredDeadline;
  final Stopwatch _elapsed;
  BatchSingleCallController? _batchCall;
  bool _hasConnected = false;
  int _observation = 0;
  bool _closed = false;
  int _outcomeReads = 0;
  int _confirmedObservation = -1;
  bool _receiptTimedOut = false;
  bool _resultNotified = false;
  bool _unregisteredRecovery = false;
  bool _physicalClosureObserved = false;
  Future<bool>? _outcomeRead;
  Future<void>? _retiredRead;
  int _outcomeReadObservation = -1;
  String _outcomeReadId = '';
  int _registeredSyncObservation = -1;
  String? _confirmationCommandId;
  ConversationCallState get snapshot {
    final batch = _batchCall;
    if (_call == null && batch?.call != null) {
      return ConversationCallState(
        launch: state.launch,
        call: batch!.call,
        showCall: batch.showCall,
        seconds: batch.seconds,
      );
    }
    return state;
  }

  void acceptBatchProgress(AgentEvent event, String commandId) {
    if (!_closed && _call == null) _batchCall?.accept(event, commandId);
  }

  Future<void> acceptPointsRejection(
    AgentEvent event, {
    String? commandId,
    void Function()? onSettled,
  }) async {
    if (_closed || !PointsAdmissionRejection.matches(event)) return;
    final command =
        commandId ?? event.payload['commandId'] ?? _confirmationCommandId;
    if (!_balanceRejections.add('$command|${event.payload['type']}')) return;
    try {
      await _admission.refreshBalance();
      if (!_closed && mounted) onSettled?.call();
    } catch (_) {
      // The business rejection remains valid if the read fails or login ends.
    }
  }

  CallLaunchRequest? activeRequest;
  String? get callRequestBlockReason {
    if (_closed) return '当前会话已关闭，未创建拨号确认。';
    final call = _call;
    if (call == null ||
        (_receiptTimedOut &&
            _physicalClosureObserved &&
            call.snapshot.target.callId.isNotEmpty)) {
      return null;
    }
    return _receiptTimedOut
        ? '上次外呼是否已执行尚未确认，请先核对原任务结果；暂不能确认新的拨号。'
        : '当前通话仍在进行或结果待核，请先完成原通话；未创建新的拨号确认。';
  }

  bool get awaitingOutcome =>
      !_receiptTimedOut &&
      (state.call?.progress.closureObserved == true ||
          state.call?.ending == true ||
          state.call?.phase == CallSessionPhase.awaitingOutcome);

  void restoreHistory(RestoredConversation restored) {
    if (_closed) return;
    final requests = CallRequestHistory.project(
      restored.detail.sessionId,
      restored.ledger?.events ?? const [],
    );
    remember(requests);
    final receipts = CallReceiptProjector.project(
      restored.ledger?.events ?? const [],
    );
    _knownCallIds.addAll(
      receipts.map((r) => r.receipt.callId).where((id) => id.isNotEmpty),
    );
    _knownCallIds.addAll(
      receipts.map((r) => r.receipt.attemptId).where((id) => id.isNotEmpty),
    );
    final latest = receipts.lastOrNull?.receipt;
    if (_call == null &&
        requests.isNotEmpty &&
        latest != null &&
        (latest.callId.isNotEmpty || latest.attemptId.isNotEmpty) &&
        (latest.metadata['agentOutcome'] ?? '').isEmpty &&
        latest.status.trim().toUpperCase() != 'EXECUTION_ERROR' &&
        !const {'CALL_REJECTED', 'CALL_CANCELLED'}.contains(latest.status)) {
      _observe(
        requests.last,
        restoredTarget: CallSessionTarget(
          taskId: restored.detail.sessionId,
          callId: latest.callId.isEmpty ? latest.attemptId : latest.callId,
          attemptId: latest.attemptId,
        ),
      );
    }
    final pending = restored.pendingTool;
    final id =
        const {
          'makeCall',
          'makeBatchCalls',
        }.contains(pending?.payload['toolName'])
        ? pending?.payload['toolCallId']
        : null;
    _launch.restoreContext(
      requests.where((r) => r.toolId == id).lastOrNull,
      priorRequests: requests,
    );
  }

  void remember(Iterable<CallLaunchRequest> requests) {
    if (_closed) return;
    for (final request in requests) {
      if (!_requests.any((r) => r.identity == request.identity)) {
        _requests.add(request);
      }
    }
  }

  void receive({
    required String sessionId,
    required String commandId,
    required String toolId,
    required Map<String, Object?> spec,
  }) {
    // A new tool can be presented only after the old physical call closed and
    // its bounded result read ended. Presenting never submits or redials.
    if (callRequestBlockReason != null) return;
    final previous = _requests
        .where((r) => r.sessionId == sessionId && r.toolId == toolId)
        .firstOrNull;
    final request = CallLaunchRequest(
      sessionId: sessionId,
      toolId: toolId,
      commandId: commandId,
      ordinal: previous?.ordinal ?? _requests.length + 1,
      spec: spec,
    );
    if (!request.isValid) return;
    final prior = List<CallLaunchRequest>.of(_requests);
    remember([request]);
    _launch.present(request, priorRequests: prior);
  }

  bool confirm(String text) => !_closed && _launch.confirmCurrent(text);
  String get confirmationText => _launch.confirmationText;
  bool get cardPresented => _launch.currentCardPresented;
  void reportPresented(String identity, String signature) =>
      _launch.reportPresented(identity, signature);
  void pausePreparation() {
    final pending = state.launch;
    if (!{
      CallLaunchPhase.waiting,
      CallLaunchPhase.checking,
    }.contains(pending.phase)) {
      return;
    }
    final visible = cardPresented;
    _launch.restoreContext(
      pending.request,
      priorRequests: pending.priorRequests,
    );
    if (visible && pending.request != null) {
      _launch.reportPresented(
        pending.request!.identity,
        pending.request!.specSignature,
      );
    }
  }

  void _applyLaunch(CallLaunchState launch) {
    if (!mounted || _closed) return;
    state = ConversationCallState(
      launch: launch,
      call: state.call,
      showCall: state.showCall,
      seconds: state.seconds,
    );
    if (launch.phase == CallLaunchPhase.submitting &&
        !launch.request!.confirmation.isBatch) {
      _observe(launch.request!);
    } else if (launch.phase == CallLaunchPhase.blocked ||
        launch.phase == CallLaunchPhase.failed) {
      onBlocked(launch);
    }
  }

  void _observe(
    CallLaunchRequest request, {
    CallSessionTarget? restoredTarget,
  }) {
    final previous = _call;
    final previousRequest = activeRequest;
    if (previous != null &&
        previousRequest != null &&
        _receiptTimedOut &&
        _physicalClosureObserved &&
        previous.snapshot.target.callId.isNotEmpty) {
      _retiredOutcomes.add((
        previousRequest.sessionId,
        previous.snapshot.target,
      ));
    }
    dismissCall();
    if (_closed) return;
    activeRequest = request;
    final call = CallSessionController(
      conversationId: request.sessionId,
      target: restoredTarget ?? CallSessionTarget(taskId: request.sessionId),
      excludedCallIds: Set.of(_knownCallIds)..remove(restoredTarget?.callId),
      repository: _sessions,
      onTerminal: (snapshot) {
        _physicalClosureObserved = true;
        onPhysicalEnded?.call();
        final callId = snapshot.callId.isEmpty
            ? _call?.snapshot.target.callId ?? ''
            : snapshot.callId;
        unawaited(_sync(callId, _observation, waitForOutcome: true));
      },
    );
    _call = call;
    state = ConversationCallState(
      launch: state.launch,
      call: call.state,
      showCall: false,
    );
    _remove = call.addListener((value) {
      if (!mounted || _closed || _call != call) return;
      final closureBegan =
          state.call?.progress.closureObserved != true &&
          value.progress.closureObserved;
      if (value.snapshot?.isTerminal == true ||
          value.progress.closureObserved) {
        _physicalClosureObserved = true;
      }
      if (_unregisteredRecovery && value.target.callId.isNotEmpty) {
        _unregisteredRecovery = false;
        _outcomeTimer?.cancel();
        _unregisteredDeadline?.cancel();
        _outcomeReads = 0;
        _receiptTimedOut = false;
      }
      final wasWaiting = awaitingOutcome;
      if (!_hasConnected && value.connected) {
        _hasConnected = true;
        _elapsed
          ..reset()
          ..start();
      }
      if (value.snapshot?.isTerminal == true ||
          value.progress.closureObserved ||
          value.ending) {
        _elapsed.stop();
      }
      state = ConversationCallState(
        launch: state.launch,
        call: value,
        showCall:
            value.target.callId.isNotEmpty &&
            value.launchProven &&
            !value.dismissRequested &&
            !value.ending &&
            !value.progress.closureObserved &&
            value.snapshot?.isTerminal != true,
        seconds: _hasConnected ? _elapsed.elapsed.inSeconds : 0,
      );
      if (!wasWaiting &&
          awaitingOutcome &&
          value.snapshot?.isTerminal != true) {
        onPhysicalEnded?.call();
      }
      if (closureBegan && value.snapshot?.isTerminal != true) {
        unawaited(_sync(value.target.callId, _observation));
      }
    }, fireImmediately: false);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_closed && _elapsed.isRunning) {
        state = ConversationCallState(
          launch: state.launch,
          call: state.call,
          showCall: state.showCall,
          seconds: _elapsed.elapsed.inSeconds,
        );
      }
    });
    call.start();
  }

  Future<void> _sync(
    String callId,
    int observation, {
    bool waitForOutcome = true,
  }) async {
    if (_closed ||
        !mounted ||
        observation != _observation ||
        callId.isEmpty ||
        _receiptTimedOut ||
        _registeredSyncObservation == observation) {
      return;
    }
    final request = activeRequest;
    final call = _call;
    if (request == null || call == null) return;
    _registeredSyncObservation = observation;
    try {
      if (waitForOutcome && _registeredDeadline == null) {
        _registeredDeadline = Timer(
          const Duration(minutes: 5),
          () => _finishRegisteredRecovery(
            observation,
            request,
            call,
            callId,
            'unconfirmed_deadline_exhausted',
          ),
        );
      }
      final sessionId = request.sessionId;
      final taskId = call.snapshot.target.taskId;
      final attempt = call.snapshot.target.attemptId;
      final resultId = attempt.isEmpty ? callId : attempt;
      final found = await _readOutcome(
        resultId,
        observation,
        sessionId: sessionId,
        taskId: taskId,
      );
      if (_closed || !mounted || observation != _observation) return;
      if (found || !waitForOutcome) {
        _call?.markAgentOutcomeReceived(callId);
        _notifyResultConfirmed();
        dismissCall();
      } else {
        if (_receiptTimedOut) return;
        _outcomeTimer?.cancel();
        if (++_outcomeReads >= 32) {
          _finishRegisteredRecovery(
            observation,
            request,
            call,
            callId,
            'unconfirmed_sync_window_exhausted',
          );
          return;
        }
        _outcomeTimer = Timer(
          const Duration(milliseconds: 1500),
          () => unawaited(_sync(callId, observation)),
        );
      }
    } finally {
      if (_registeredSyncObservation == observation) {
        _registeredSyncObservation = -1;
      }
    }
  }

  void _finishRegisteredRecovery(
    int observation,
    CallLaunchRequest request,
    CallSessionController call,
    String callId,
    String reason,
  ) {
    if (_closed ||
        !mounted ||
        observation != _observation ||
        _receiptTimedOut ||
        activeRequest != request ||
        _call != call ||
        call.snapshot.target.callId != callId) {
      return;
    }
    _receiptTimedOut = true;
    _outcomeTimer?.cancel();
    _registeredDeadline?.cancel();
    _clock?.cancel();
    _elapsed.stop();
    call.close();
    state = ConversationCallState(launch: state.launch, call: state.call);
    onOutcomeUnconfirmed?.call();
    traceConversationCallResult(
      'CALL_RESULT_SYNC',
      reason,
      sessionId: request.sessionId,
      taskId: call.snapshot.target.taskId,
      callAttemptId: call.snapshot.target.attemptId.isEmpty
          ? callId
          : call.snapshot.target.attemptId,
    );
  }

  Future<void> _syncUnregistered(int observation) async {
    if (_closed ||
        !mounted ||
        observation != _observation ||
        !_unregisteredRecovery ||
        _receiptTimedOut ||
        activeRequest == null ||
        _call == null ||
        _call!.snapshot.target.callId.isNotEmpty) {
      return;
    }
    final request = activeRequest!;
    await _readOutcome(
      '',
      observation,
      sessionId: request.sessionId,
      taskId: _call!.snapshot.target.taskId,
    );
    if (_closed ||
        !mounted ||
        observation != _observation ||
        !_unregisteredRecovery ||
        _receiptTimedOut ||
        _call?.snapshot.target.callId.isNotEmpty == true) {
      return;
    }
    if (++_outcomeReads >= 32) {
      _finishUnregisteredRecovery(
        observation,
        request,
        'unconfirmed_sync_window_exhausted',
      );
      return;
    }
    _outcomeTimer?.cancel();
    _outcomeTimer = Timer(
      const Duration(milliseconds: 1500),
      () => unawaited(_syncUnregistered(observation)),
    );
  }

  void _finishUnregisteredRecovery(
    int observation,
    CallLaunchRequest request,
    String reason,
  ) {
    if (_closed ||
        !mounted ||
        observation != _observation ||
        !_unregisteredRecovery ||
        _receiptTimedOut ||
        activeRequest != request ||
        _call == null ||
        _call!.snapshot.target.callId.isNotEmpty) {
      return;
    }
    _receiptTimedOut = true;
    _outcomeTimer?.cancel();
    _unregisteredDeadline?.cancel();
    _clock?.cancel();
    _elapsed.stop();
    _call!.close();
    onOutcomeUnconfirmed?.call();
    traceConversationCallResult(
      'CALL_RESULT_SYNC',
      reason,
      sessionId: request.sessionId,
      taskId: request.sessionId,
      callAttemptId: '',
    );
  }

  /// Recheck a physically ended call once when the page or network returns.
  /// The bounded timer is left alone, including after it has been exhausted.
  Future<void> refreshTerminalOutcome() async {
    await Future.wait([_refreshRetiredOutcomes(), _refreshCurrentOutcome()]);
  }

  Future<void> _refreshCurrentOutcome() async {
    if (_closed || !mounted || activeRequest == null || _call == null) return;
    final call = _call!;
    final snapshot = call.snapshot;
    final target = snapshot.target;
    final resultId = target.attemptId.isEmpty
        ? target.callId
        : target.attemptId;
    if (resultId.isEmpty) {
      if (!_unregisteredRecovery) return;
      final observation = _observation;
      final request = activeRequest!;
      final olderReadInFlight =
          _outcomeRead != null &&
          _outcomeReadObservation == observation &&
          _outcomeReadId.isEmpty;
      final found = await _readOutcome(
        '',
        observation,
        sessionId: request.sessionId,
        taskId: target.taskId,
      );
      if (!found &&
          olderReadInFlight &&
          !_closed &&
          mounted &&
          observation == _observation &&
          activeRequest == request) {
        await _readOutcome(
          '',
          observation,
          sessionId: request.sessionId,
          taskId: target.taskId,
        );
      }
      return;
    }
    if (!_receiptTimedOut &&
        snapshot.snapshot?.isTerminal != true &&
        !snapshot.progress.closureObserved) {
      return;
    }
    final observation = _observation;
    final request = activeRequest;
    final olderReadInFlight =
        _outcomeRead != null &&
        _outcomeReadObservation == observation &&
        _outcomeReadId == resultId;
    var found = await _readOutcome(
      resultId,
      observation,
      sessionId: request!.sessionId,
      taskId: target.taskId,
    );
    bool valid() =>
        !_closed &&
        mounted &&
        observation == _observation &&
        activeRequest == request &&
        _call == call;
    if (!valid()) return;
    if (!found && olderReadInFlight) {
      found = await _readOutcome(
        resultId,
        observation,
        sessionId: request.sessionId,
        taskId: target.taskId,
      );
    }
    if (!found || !valid()) return;
    call.markAgentOutcomeReceived(target.callId);
    _notifyResultConfirmed();
    dismissCall();
  }

  Future<void> _refreshRetiredOutcomes() {
    final inFlight = _retiredRead;
    if (inFlight != null) return inFlight;
    late final Future<void> read;
    read = _readRetiredOutcomes().whenComplete(() {
      if (identical(_retiredRead, read)) _retiredRead = null;
    });
    _retiredRead = read;
    return read;
  }

  Future<void> _readRetiredOutcomes() async {
    for (final prior in List.of(_retiredOutcomes)) {
      if (_closed || !mounted || !_retiredOutcomes.contains(prior)) return;
      final (sessionId, target) = prior;
      final resultId = target.attemptId.isEmpty
          ? target.callId
          : target.attemptId;
      try {
        final found = await syncOutcome(
          resultId,
          () => !_closed && mounted && _retiredOutcomes.contains(prior),
        );
        if (found && !_closed && mounted) _retiredOutcomes.remove(prior);
        traceConversationCallResult(
          'CALL_RESULT_SYNC',
          found ? 'retired_confirmed' : 'retired_pending',
          sessionId: sessionId,
          taskId: target.taskId,
          callAttemptId: resultId,
        );
      } catch (_) {
        traceConversationCallResult(
          'CALL_RESULT_SYNC',
          'retired_read_failed',
          sessionId: sessionId,
          taskId: target.taskId,
          callAttemptId: resultId,
        );
        emitDiagnostic(
          diagnostics,
          DiagnosticEvent(
            operation: DiagnosticOperation.taskResultRead,
            result: DiagnosticResult.failed,
            failureKind: DiagnosticFailureKind.other,
            sessionId: sessionId,
          ),
        );
      }
    }
  }

  Future<bool> _readOutcome(
    String resultId,
    int observation, {
    required String sessionId,
    required String taskId,
  }) {
    final inFlight = _outcomeRead;
    if (inFlight != null &&
        _outcomeReadObservation == observation &&
        _outcomeReadId == resultId) {
      return inFlight;
    }
    late final Future<bool> read;
    read =
        _performOutcomeRead(
          resultId,
          observation: observation,
          sessionId: sessionId,
          taskId: taskId,
        ).whenComplete(() {
          if (identical(_outcomeRead, read)) _outcomeRead = null;
        });
    _outcomeRead = read;
    _outcomeReadObservation = observation;
    _outcomeReadId = resultId;
    return read;
  }

  Future<bool> _performOutcomeRead(
    String resultId, {
    required int observation,
    required String sessionId,
    required String taskId,
  }) async {
    try {
      final bool found;
      if (resultId.isEmpty) {
        if (syncUnregisteredOutcome == null) return false;
        await syncUnregisteredOutcome!(
          () =>
              !_closed &&
              mounted &&
              observation == _observation &&
              _unregisteredRecovery &&
              activeRequest != null &&
              _call?.snapshot.target.callId.isEmpty == true,
        );
        found = _confirmedObservation == observation;
      } else {
        final request = activeRequest;
        final call = _call;
        final callId = call?.snapshot.target.callId;
        found = await syncOutcome(
          resultId,
          () =>
              !_closed &&
              mounted &&
              observation == _observation &&
              activeRequest == request &&
              _call == call &&
              callId != null &&
              callId.isNotEmpty &&
              call?.snapshot.target.callId == callId,
        );
      }
      traceConversationCallResult(
        'CALL_RESULT_SYNC',
        found
            ? 'confirmed_try_${_outcomeReads + 1}'
            : 'pending_try_${_outcomeReads + 1}',
        sessionId: sessionId,
        taskId: taskId,
        callAttemptId: resultId,
      );
      return found;
    } catch (error) {
      final kind = error is TimeoutException
          ? DiagnosticFailureKind.timeout
          : error is FormatException
          ? DiagnosticFailureKind.format
          : error is StateError
          ? DiagnosticFailureKind.state
          : DiagnosticFailureKind.other;
      traceConversationCallResult(
        'CALL_RESULT_SYNC',
        'failed_${kind.name}',
        sessionId: sessionId,
        taskId: taskId,
        callAttemptId: resultId,
      );
      emitDiagnostic(
        diagnostics,
        DiagnosticEvent(
          operation: DiagnosticOperation.taskResultRead,
          result: DiagnosticResult.failed,
          failureKind: kind,
          sessionId: sessionId,
        ),
      );
      return false;
    }
  }

  Future<bool> hangUp() async => _call != null
      ? await _call!.hangUp()
      : await _batchCall?.hangUp() ?? false;

  bool acceptProgress(AgentEvent event, {String? commandId}) {
    acceptBatchProgress(event, commandId ?? '');
    final request = activeRequest;
    if (_closed ||
        _call == null ||
        request == null ||
        event.sessionId != request.sessionId) {
      return false;
    }
    final wireCommand = event.payload['commandId'];
    final command = wireCommand is String && wireCommand.isNotEmpty
        ? wireCommand
        : commandId;
    if (command != null &&
        command.isNotEmpty &&
        _confirmationCommandId != null &&
        command != _confirmationCommandId) {
      return false;
    }
    if (event.eventName == 'call_started') {
      final id = event.payload['callId'] ?? event.payload['callAttemptId'];
      if (id is String) {
        _call!.bindStarted(
          id,
          attemptId: event.payload['callAttemptId'] is String
              ? event.payload['callAttemptId'] as String
              : '',
        );
      }
    }
    if (event.eventName == 'call_finished') {
      final call = _call!;
      final target = call.snapshot.target;
      final result = event.payload['callResult'];
      final metadata = result is Map ? result['metadata'] : null;
      String id(Object? value) => value is String ? value.trim() : '';
      String firstId(Iterable<Object?> values) {
        for (final value in values) {
          if (id(value).isNotEmpty) return id(value);
        }
        return '';
      }

      final attempt = firstId([
        event.payload['callAttemptId'],
        if (result is Map) result['callAttemptId'],
        if (metadata is Map) metadata['callAttemptId'],
      ]);
      final resultCallId = firstId([
        event.payload['callId'],
        if (result is Map) result['callId'],
        if (metadata is Map) metadata['callId'],
      ]);
      final commandMatches =
          _confirmationCommandId != null && command == _confirmationCommandId;
      if (target.callId.isEmpty) {
        // No locally bound line can be inferred from this event. Only the
        // submitted command may start a read of its durable result.
        if (!commandMatches || result is! Map) return false;
        _beginUnregisteredRecovery();
      } else {
        if (resultCallId.isNotEmpty && resultCallId != target.callId ||
            target.attemptId.isNotEmpty &&
                attempt.isNotEmpty &&
                attempt != target.attemptId) {
          return false;
        }
        final knownAttempt = target.attemptId.isEmpty
            ? target.callId
            : target.attemptId;
        final idMatches =
            resultCallId == target.callId ||
            attempt.isNotEmpty && attempt == knownAttempt;
        if (!idMatches && !(commandMatches && result is Map)) return false;
        unawaited(call.refresh());
        unawaited(_sync(target.callId, _observation));
      }
      return true;
    }
    final attempt = event.payload['callAttemptId'];
    if (attempt is! String) return false;
    if (event.eventName == 'call_outcome_preview') {
      return _call!.acceptPreview(attempt, event.payload);
    }
    final call = _call!;
    final accepted = call.acceptProgress(
      attempt,
      event.text,
      outcomePush: event.payload['outcomePush'] == true,
      segmentIndex: event.payload['segmentIndex'] is int
          ? event.payload['segmentIndex'] as int
          : null,
      captionFinal: event.payload['captionFinal'] == true,
      progress: event.payload,
    );
    return accepted;
  }

  void releaseTerminalObservation() {
    if (_call?.snapshot.snapshot?.isTerminal == true) dismissCall();
  }

  void bindConfirmationCommand(String id) {
    _confirmationCommandId = id;
  }

  bool _hasTrustedResult(CallReceipt receipt) {
    if (CallReceiptStatus.isPhysicalOutcomePending(receipt)) return false;
    if (CallReceiptStatus.hasSemanticOutcome(receipt)) {
      return true;
    }
    final status = receipt.status.trim().toUpperCase();
    return const {'FAILED', 'UNCLEAR', 'EXECUTION_ERROR'}.contains(status);
  }

  /// Physical call status and result code alone cannot close result observation.
  void acceptReceipts(Iterable<ConversationMessage> messages) {
    for (final message in messages) {
      final batch = message.batchReceipt;
      if (batch != null && batch.stopSettled && batch.explicitId.isNotEmpty) {
        _batchCall?.finish(batch.explicitId);
      }
    }
    if (_closed) return;
    final items = messages.toList();
    _knownCallIds.addAll(
      items.map((m) => m.receipt?.callId ?? '').where((id) => id.isNotEmpty),
    );
    if (_call == null) return;
    final target = _call!.snapshot.target;
    final callId = target.callId;
    final terminal = messages.any((message) {
      final receipt = message.receipt;
      if (receipt == null ||
          receipt.status.isEmpty ||
          receipt.isRunning ||
          !_hasTrustedResult(receipt)) {
        return false;
      }
      if (message.transient) {
        return _confirmationCommandId != null &&
            message.commandId == _confirmationCommandId &&
            (callId.isEmpty ||
                receipt.callId.isEmpty ||
                receipt.callId == callId);
      }
      final executionError =
          receipt.status.trim().toUpperCase() == 'EXECUTION_ERROR';
      final matchesCall =
          callId.isNotEmpty &&
          (receipt.callId == callId ||
              receipt.callId.isEmpty &&
                  receipt.attemptId ==
                      (target.attemptId.isEmpty ? callId : target.attemptId));
      final projectedUnidentifiedAttempt =
          receipt.attemptId.startsWith('unidentified:') &&
          message.id == 'ledger:call:${receipt.attemptId}';
      final matchesCommandWithoutCallId =
          callId.isEmpty &&
          _confirmationCommandId != null &&
          (receipt.metadata['committedCallResult'] == 'true' &&
                  receipt.metadata['committedCallResultCommandId'] ==
                      _confirmationCommandId ||
              message.commandId == _confirmationCommandId &&
                  receipt.callId.isEmpty &&
                  (receipt.attemptId.isEmpty || projectedUnidentifiedAttempt) &&
                  executionError);
      return matchesCall || matchesCommandWithoutCallId;
    });
    if (!terminal) return;
    _call!.markAgentOutcomeReceived(callId);
    _notifyResultConfirmed();
    if (state.launch.request?.identity == activeRequest?.identity) {
      cancelPending();
    }
    dismissCall();
  }

  void _notifyResultConfirmed() {
    if (_resultNotified) return;
    _resultNotified = true;
    _confirmedObservation = _observation;
    onResultConfirmed?.call();
  }

  /// A known rejection can close an unregistered launch. Once a concrete call
  /// is observed, its status remains authoritative even if the command fails.
  void confirmationFailed(Object failure) {
    if (_closed || _call == null || _call!.snapshot.target.callId.isNotEmpty) {
      return;
    }
    if (failure == AgentTransportFailure.rejected ||
        failure == AgentTransportFailure.unavailable ||
        failure == AgentTransportFailure.sessionChanged ||
        failure is AgentFailure && !failure.isNetworkFailure) {
      dismissCall();
    } else {
      _beginUnregisteredRecovery();
    }
  }

  void _beginUnregisteredRecovery() {
    if (_unregisteredRecovery ||
        syncUnregisteredOutcome == null ||
        activeRequest == null ||
        _call == null ||
        _call!.snapshot.target.callId.isNotEmpty) {
      return;
    }
    _unregisteredRecovery = true;
    final observation = _observation;
    final request = activeRequest!;
    _unregisteredDeadline = Timer(
      const Duration(minutes: 5),
      () => _finishUnregisteredRecovery(
        observation,
        request,
        'unconfirmed_deadline_exhausted',
      ),
    );
    scheduleMicrotask(() => unawaited(_syncUnregistered(observation)));
  }

  bool interceptSubmission(void Function() onAllowed) =>
      !_closed && _launch.interceptSubmission(onAllowed);

  /// Called on new user input or history restoration, never confirms history.
  void cancelPending() => _launch.cancelPending();

  /// Releases local observation without sending a remote hangup.
  void dismissCall() {
    final callId = _call?.snapshot.target.callId ?? '';
    if (callId.isNotEmpty) _knownCallIds.add(callId);
    activeRequest = null;
    _confirmationCommandId = null;
    _observation++;
    _outcomeTimer?.cancel();
    _unregisteredDeadline?.cancel();
    _registeredDeadline?.cancel();
    _registeredDeadline = null;
    _clock?.cancel();
    _elapsed
      ..stop()
      ..reset();
    _hasConnected = false;
    _outcomeReads = 0;
    _receiptTimedOut = false;
    _resultNotified = false;
    _unregisteredRecovery = false;
    _physicalClosureObserved = false;
    _remove?.call();
    _remove = null;
    _call?.dispose();
    _call = null;
    if (mounted && !_closed) {
      state = ConversationCallState(launch: state.launch);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _batchCall?.dispose();
    _launch.close();
    dismissCall();
    _retiredOutcomes.clear();
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

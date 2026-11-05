import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/diagnostics/diagnostic_journal.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/call_session.dart';
import 'call_session_state.dart';

/// Observes ONE call lifecycle. Creating/confirming a call belongs to the
/// conversation coordinator; merely constructing or closing this never dials.
class CallSessionController extends StateNotifier<CallSessionState> {
  CallSessionController({
    required this.conversationId,
    required CallSessionTarget target,
    required CallSessionRepository repository,
    void Function(CallSessionSnapshot)? onTerminal,
    this.excludedCallIds = const {},
  }) : _repository = repository,
       _onTerminal = onTerminal,
       super(CallSessionState(target: target));
  final String conversationId;
  final Set<String> excludedCallIds;
  final CallSessionRepository _repository;
  CallSessionState get snapshot => state;
  final void Function(CallSessionSnapshot)? _onTerminal;
  Timer? _timer;
  Timer? _pushExpiry;
  bool _healthyPush = false;
  int _generation = 0;
  bool _active = false, _queryBusy = false, _terminalNotified = false;
  bool _hasAgentOutcome = false;
  int _endingReads = 0;
  final _pendingCaptions = <(String, int, String)>[];
  DateTime? _latestTimestamp;
  String? _lastStatusKey;
  static const pollingInterval = Duration(milliseconds: 500);
  bool acceptProgress(
    String attemptId,
    String text, {
    required bool outcomePush,
    int? segmentIndex,
    bool captionFinal = false,
    Map<String, Object?> progress = const {},
  }) {
    if (!mounted ||
        (!_active && !captionFinal) ||
        state.phase == CallSessionPhase.closed ||
        attemptId.isEmpty ||
        (state.target.callId.isNotEmpty &&
            attemptId !=
                (state.target.attemptId.isEmpty
                    ? state.target.callId
                    : state.target.attemptId)) ||
        (state.snapshot?.isTerminal == true && !captionFinal)) {
      return false;
    }
    if (state.target.callId.isEmpty) {
      if (captionFinal && segmentIndex != null && segmentIndex > 0) {
        if (_pendingCaptions.length >= 64) _pendingCaptions.removeAt(0);
        _pendingCaptions.add((attemptId, segmentIndex, text));
      }
      return false;
    }
    final phase =
        '${progress['callState'] ?? progress['status'] ?? progress['batchStatus'] ?? ''}';
    final wasProven = state.launchProven;
    if (progress.isNotEmpty) {
      final next = state.progress.observe(
        phase,
        failed: progress['dialFailureObserved'] == true,
        closed: progress['primaryClosed'] == true,
      );
      state = state.copy(
        progress: next,
        launchReady: state.launchReady || progress['launchReady'] == true,
      );
    }
    if (captionFinal && segmentIndex != null) {
      state = state.copy(
        transcript: state.transcript.live(attemptId, segmentIndex, text),
      );
    } else if (text.isNotEmpty) {
      state = state.copy(progressText: text);
    }
    // Readiness pushes are the earliest authority. Pull once so the server
    // snapshot catches up without delaying the visible call surface.
    if (!wasProven && state.launchProven) unawaited(refresh());
    if (outcomePush) {
      final wasHealthy = _healthyPush;
      _healthyPush = true;
      _pushExpiry?.cancel();
      _pushExpiry = Timer(const Duration(seconds: 45), () {
        _healthyPush = false;
        _schedule();
      });
      if (!wasHealthy) _schedule();
    }
    return true;
  }

  bool acceptPreview(String attempt, Map<String, Object?> data) {
    final target = state.target;
    if (!mounted ||
        _hasAgentOutcome ||
        target.callId.isEmpty ||
        attempt !=
            (target.attemptId.isEmpty ? target.callId : target.attemptId)) {
      return false;
    }
    final next = state.progress.withPreview(data);
    if (identical(next, state.progress)) return false;
    state = state.copy(progress: next);
    return true;
  }

  bool _current(int generation) =>
      mounted &&
      generation == _generation &&
      state.phase != CallSessionPhase.closed;

  bool start() {
    if (!mounted || state.phase != CallSessionPhase.idle) return false;
    if (!state.target.isValid) {
      state = state.copy(issue: CallSessionIssue.invalidResponse);
      return false;
    }
    _active = true;
    state = state.copy(phase: CallSessionPhase.observing);
    unawaited(refresh());
    return true;
  }

  Future<void> refresh() async {
    if (!mounted || !_active || _queryBusy || state.hangingUp) return;
    _timer?.cancel();
    _queryBusy = true;
    final generation = _generation;
    final target = state.target;
    try {
      final snapshot = await _repository.status(target);
      if (_current(generation)) {
        _apply(snapshot);
        if (state.ending && !snapshot.isTerminal && ++_endingReads >= 32) {
          state = state.copy(progressText: '挂断待核实，请稍后刷新确认。');
        }
      }
    } catch (error) {
      if (_current(generation)) {
        if (!_rejectSession(error)) {
          state = state.copy(
            issue: error == ApiFailure.invalidResponse
                ? CallSessionIssue.invalidResponse
                : CallSessionIssue.refreshFailed,
          );
          _trace('CALL_POLLING_FAILED', 'status_refresh_failure');
        }
      }
    } finally {
      _queryBusy = false;
      _schedule();
    }
  }

  void _schedule() {
    if (!mounted || !_active || _queryBusy || state.hangingUp) return;
    _timer?.cancel();
    _timer = Timer(
      state.ending
          ? Duration(milliseconds: _endingReads >= 32 ? 10000 : 1500)
          : _healthyPush
          ? const Duration(seconds: 10)
          : pollingInterval,
      () => unawaited(refresh()),
    );
  }

  bool bindStarted(String callId, {String attemptId = ''}) {
    if (!mounted ||
        !_active ||
        callId.isEmpty ||
        excludedCallIds.contains(callId) ||
        (state.target.callId.isNotEmpty && state.target.callId != callId)) {
      return false;
    }
    state = state.copy(
      target: CallSessionTarget(
        taskId: state.target.taskId,
        callId: callId,
        attemptId: attemptId,
      ),
    );
    _drainCaptions();
    unawaited(refresh());
    return true;
  }

  void _drainCaptions() {
    final pending = List.of(_pendingCaptions);
    _pendingCaptions.clear();
    for (final item in pending) {
      acceptProgress(
        item.$1,
        item.$3,
        outcomePush: false,
        segmentIndex: item.$2,
        captionFinal: true,
      );
    }
  }

  bool _apply(CallSessionSnapshot snapshot, {bool fromHangup = false}) {
    if (excludedCallIds.contains(snapshot.callId)) {
      _trace('CALL_STATUS_IGNORED', 'prior_attempt');
      return false;
    }
    if (!snapshot.belongsTo(state.target)) {
      state = state.copy(issue: CallSessionIssue.invalidResponse);
      _trace('CALL_STATUS_IGNORED', 'target_mismatch');
      return false;
    }
    if (snapshot.isNotFound && state.target.callId.isEmpty && !fromHangup) {
      _trace('CALL_STATUS_IGNORED', 'not_found_without_active_call');
      return false;
    }
    if ((state.ending || fromHangup) && snapshot.isNotFound) {
      _trace('CALL_STATUS_IGNORED', 'hangup_not_found_is_not_proof');
      return false;
    }
    if (state.ending &&
        !snapshot.isTerminal &&
        !const {'ENDING', 'CANCELLING'}.contains(snapshot.normalizedState)) {
      return false;
    }
    final timestamp = snapshot.timestamp;
    if ((timestamp != null &&
            _latestTimestamp != null &&
            timestamp.isBefore(_latestTimestamp!)) ||
        (state.snapshot?.isTerminal == true && !snapshot.isTerminal)) {
      _trace('CALL_STATUS_IGNORED', 'stale_response');
      return false;
    }
    if (timestamp != null) _latestTimestamp = timestamp;
    final awaiting = snapshot.needsAgentOutcome(
      conversationId,
      hasAgentOutcome: _hasAgentOutcome,
    );
    state = state.copy(
      target: state.target.resolve(snapshot),
      snapshot: snapshot,
      launchReady: state.launchReady || snapshot.launchReady,
      transcript: state.transcript.merge(snapshot.dialogueDetail),
      progress: state.progress.observe(
        snapshot.callState,
        failed: snapshot.dialFailureObserved,
        closed: snapshot.primaryClosed,
      ),
      ending:
          !snapshot.isTerminal &&
          (state.ending ||
              (const {
                    'ENDING',
                    'CANCELLING',
                  }.contains(snapshot.normalizedState) &&
                  !snapshot.dialFailureObserved &&
                  !snapshot.primaryClosed)),
      phase: !snapshot.isTerminal
          ? CallSessionPhase.observing
          : awaiting
          ? CallSessionPhase.awaitingOutcome
          : CallSessionPhase.ended,
      issue:
          state.issue == CallSessionIssue.hangupFailed && !snapshot.isTerminal
          ? CallSessionIssue.hangupFailed
          : CallSessionIssue.none,
    );
    if (!snapshot.isTerminal) _drainCaptions();
    final statusKey =
        '${snapshot.callId}|${snapshot.callState}|${snapshot.handoffMode}|${snapshot.resultCode}';
    if (_lastStatusKey != statusKey) {
      _lastStatusKey = statusKey;
      _trace(
        'CALL_STATUS_APPLIED',
        snapshot.isTerminal ? 'terminal' : 'observing',
      );
    } else {
      _trace('CALL_STATUS_REPEATED', 'observing');
    }
    if (snapshot.isTerminal) {
      _stopPolling();
      if (!_terminalNotified) {
        _terminalNotified = true;
        // Side effects cannot turn an accepted terminal into a polling failure.
        try {
          _onTerminal?.call(snapshot);
        } catch (_) {
          _trace('CALL_TERMINAL_CALLBACK_FAILED', 'consumer_failure');
        }
      }
    }
    return true;
  }

  Future<bool> hangUp() async {
    if (!mounted || !state.canHangUp) return false;
    _timer?.cancel();
    final generation = ++_generation;
    final target = state.target;
    state = state.copy(hangingUp: true, issue: CallSessionIssue.none);
    _trace('CALL_HANGUP_REQUESTED', 'explicit_user_action');
    try {
      final response = await _hangupOrReadback(target, generation);
      if (!_current(generation)) return false;
      if (!_apply(response, fromHangup: true)) {
        state = state.copy(issue: CallSessionIssue.hangupFailed);
        return false;
      }
      if (!_current(generation)) return false;
      if (response.isTerminal) _stopPolling();
      state = state.copy(
        hangingUp: false,
        ending: !response.isTerminal,
        dismissRequested: response.isTerminal,
      );
      _trace('CALL_HANGUP_CONFIRMED', 'server_response');
      return true;
    } catch (error) {
      if (_current(generation) && !_rejectSession(error)) {
        state = state.copy(issue: CallSessionIssue.hangupFailed);
        _trace('CALL_HANGUP_FAILED', 'request_failed_no_retry');
      }
      return false;
    } finally {
      if (_current(generation)) state = state.copy(hangingUp: false);
      _schedule();
    }
  }

  Future<CallSessionSnapshot> _hangupOrReadback(
    CallSessionTarget target,
    int generation,
  ) async {
    try {
      final response = await _repository.hangUp(target);
      if (response.isNotFound) throw ApiFailure.invalidResponse;
      return response;
    } catch (failure) {
      if (failure == ApiFailure.sessionChanged ||
          failure == ApiFailure.signedOut ||
          !_current(generation) ||
          target.callId.isEmpty) {
        rethrow;
      }
      CallSessionSnapshot? readback;
      try {
        readback = await _repository.status(target);
      } catch (error) {
        if (error == ApiFailure.signedOut ||
            error == ApiFailure.sessionChanged) {
          rethrow;
        }
        /* Unknown acceptance. */
      }
      if (!_current(generation) ||
          readback == null ||
          !readback.belongsTo(target) ||
          readback.callId != target.callId ||
          !const {
            'ENDING',
            'CANCELLING',
            'ENDED',
            'FAILED',
          }.contains(readback.normalizedState)) {
        rethrow;
      }
      return readback;
    }
  }

  bool markAgentOutcomeReceived(String callId) {
    if (!mounted ||
        state.phase == CallSessionPhase.closed ||
        callId.trim().isEmpty ||
        callId.trim() != state.target.callId) {
      return false;
    }
    _hasAgentOutcome = true;
    if (state.phase == CallSessionPhase.awaitingOutcome) {
      state = state.copy(phase: CallSessionPhase.ended);
    }
    return true;
  }

  bool _rejectSession(Object error) {
    if (error != ApiFailure.signedOut && error != ApiFailure.sessionChanged) {
      return false;
    }
    close();
    if (mounted) state = state.copy(issue: CallSessionIssue.sessionChanged);
    return true;
  }

  void _stopPolling() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _pushExpiry?.cancel();
    _pushExpiry = null;
    _healthyPush = false;
  }

  void close() {
    if (!mounted || state.phase == CallSessionPhase.closed) return;
    _trace('CALL_OBSERVATION_CLOSED', 'local_only_no_hangup');
    ++_generation;
    _stopPolling();
    state = CallSessionState(
      target: state.target,
      phase: CallSessionPhase.closed,
    );
  }

  void _trace(String event, String reason) {
    if (!mounted) return;
    assert(() {
      final level = switch (event) {
        'CALL_STATUS_REPEATED' => DiagnosticLogLevel.debug,
        'CALL_STATUS_IGNORED'
            when const {
              'not_found_without_active_call',
              'prior_attempt',
              'stale_response',
            }.contains(reason) =>
          DiagnosticLogLevel.debug,
        'CALL_STATUS_IGNORED' => DiagnosticLogLevel.warn,
        _ when event.endsWith('_FAILED') => DiagnosticLogLevel.error,
        _ => DiagnosticLogLevel.info,
      };
      if (level.index < configuredDiagnosticLogLevel.index) return true;
      String id(String value) => value
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
          .substring(0, value.length.clamp(0, 128));
      // No phone, transcript, response body, credential or exception text.
      // ignore: avoid_print
      print(
        '$event sessionId=${id(conversationId)} taskId=${id(state.target.taskId)} '
        'callId=${id(state.target.callId)} reason=$reason',
      );
      return true;
    }());
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

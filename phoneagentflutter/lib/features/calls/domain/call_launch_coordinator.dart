import 'dart:async';
import 'call_admission.dart';
import 'call_admission_service.dart';
import 'call_launch_request.dart';

enum CallLaunchPhase {
  idle,
  restored,
  awaitingConfirmation,
  waiting,
  checking,
  blocked,
  submitting,
  submitted,
  uncertain,
  failed,
  closed,
}

class CallLaunchState {
  const CallLaunchState(
    this.phase, {
    this.request,
    this.decision,
    this.noticeSaveFailed = false,
    this.priorRequests = const [],
  });
  final CallLaunchPhase phase;
  final CallLaunchRequest? request;
  final CallAdmissionDecision? decision;
  final bool noticeSaveFailed;
  final List<CallLaunchRequest> priorRequests;
}

/// Live-only coordinator. Restore must call cancelPending, never schedule.
/// The submit port hands off once to the command stream; it must not retry.
class CallLaunchCoordinator {
  CallLaunchCoordinator({
    required this.admission,
    required this.submit,
    required this.onState,
  });
  final CallAdmissionService admission;
  final Future<void> Function(CallLaunchRequest) submit;
  final void Function(CallLaunchState) onState;
  CallLaunchState state = const CallLaunchState(CallLaunchPhase.idle);
  final Set<String> _observed = {}, _submitted = {};
  final Set<String> _presented = {};
  String confirmationText = '';
  String? _visibleAlias;
  bool get currentCardPresented =>
      state.request != null &&
      _visibleAlias ==
          '${state.request!.identity}\u0000${state.request!.specSignature}';

  void reportPresented(String identity, String signature) {
    final request = state.request;
    if (!_closed &&
        request?.identity == identity &&
        request?.specSignature == signature) {
      _visibleAlias = '$identity\u0000$signature';
    }
  }

  Timer? _timer;
  int _generation = 0;
  bool _closed = false;

  /// Presentation records context only. It cannot start admission or a timer.
  bool present(
    CallLaunchRequest request, {
    Iterable<CallLaunchRequest> priorRequests = const [],
  }) {
    if (_closed ||
        !request.isValid ||
        _observed.contains(request.identity) ||
        _submitted.contains(request.identity) ||
        !_presented.add(request.identity)) {
      return false;
    }
    cancelPending();
    _emit(
      CallLaunchState(
        CallLaunchPhase.awaitingConfirmation,
        request: request,
        priorRequests: List.unmodifiable(priorRequests),
      ),
    );
    return true;
  }

  bool confirmCurrent(String text) {
    final pending = state;
    if (_closed ||
        !currentCardPresented ||
        text.trim().isEmpty ||
        pending.request == null ||
        !{
          CallLaunchPhase.awaitingConfirmation,
          CallLaunchPhase.restored,
          CallLaunchPhase.blocked,
          CallLaunchPhase.failed,
        }.contains(pending.phase)) {
      return false;
    }
    if (_submitted.contains(pending.request!.identity)) return false;
    _observed.remove(pending.request!.identity);
    final visible = _visibleAlias;
    final scheduled = schedule(
      pending.request!,
      priorRequests: pending.priorRequests,
      confirmationText: text.trim(),
    );
    if (scheduled) _visibleAlias = visible;
    return scheduled;
  }

  /// Restored facts are context, never a timer, admission check or execution.
  void restoreContext(
    CallLaunchRequest? request, {
    Iterable<CallLaunchRequest> priorRequests = const [],
  }) {
    cancelPending();
    if (_closed || request == null || !request.isValid) return;
    _emit(
      CallLaunchState(
        CallLaunchPhase.restored,
        request: request,
        priorRequests: List.unmodifiable(priorRequests),
      ),
    );
  }

  /// v65 intercepts another user turn against the still-blocked confirmation.
  /// This never confirms a call: once admitted it forwards the original input.
  bool interceptSubmission(void Function() onAllowed) {
    final previous = state;
    if (_closed ||
        !const {
          CallLaunchPhase.blocked,
          CallLaunchPhase.restored,
        }.contains(previous.phase)) {
      return false;
    }
    cancelPending();
    final generation = _generation;
    _emit(CallLaunchState(CallLaunchPhase.checking, request: previous.request));
    unawaited(_refreshSubmission(previous, generation, onAllowed));
    return true;
  }

  Future<void> _refreshSubmission(
    CallLaunchState previous,
    int generation,
    void Function() onAllowed,
  ) async {
    final request = previous.request!;
    bool current() => _current(generation);
    try {
      final decision = await admission.evaluate(
        request,
        priorRequests: previous.priorRequests,
        isCurrent: current,
        onlyRepeated: true,
      );
      if (decision == null || !current()) return;
      if (decision.kind == CallAdmissionKind.allow) {
        _emit(const CallLaunchState(CallLaunchPhase.idle));
        if (current()) onAllowed();
      } else {
        _emit(
          CallLaunchState(
            CallLaunchPhase.blocked,
            request: request,
            decision: decision,
          ),
        );
      }
    } catch (_) {
      if (current()) {
        _emit(CallLaunchState(CallLaunchPhase.failed, request: request));
      }
    }
  }

  bool schedule(
    CallLaunchRequest request, {
    Iterable<CallLaunchRequest> priorRequests = const [],
    String confirmationText = '',
  }) {
    if (_closed ||
        !request.isValid ||
        _observed.contains(request.identity) ||
        _submitted.contains(request.identity)) {
      return false;
    }
    cancelPending();
    this.confirmationText = confirmationText;
    _observed.add(request.identity);
    final generation = _generation;
    final prior = List<CallLaunchRequest>.unmodifiable(priorRequests);
    _emit(CallLaunchState(CallLaunchPhase.waiting, request: request));
    if (!_current(generation)) return false;
    _timer = Timer(const Duration(milliseconds: 1500), () {
      _timer = null;
      unawaited(_execute(request, prior, generation));
    });
    return true;
  }

  Future<void> _execute(
    CallLaunchRequest request,
    List<CallLaunchRequest> prior,
    int generation,
  ) async {
    bool current() => _current(generation);
    if (!current()) return;
    _emit(CallLaunchState(CallLaunchPhase.checking, request: request));
    try {
      final decision = await admission.evaluate(
        request,
        priorRequests: prior,
        isCurrent: current,
      );
      if (decision == null || !current()) return;
      if (decision.kind != CallAdmissionKind.allow) {
        _emit(
          CallLaunchState(
            CallLaunchPhase.blocked,
            request: request,
            decision: decision,
          ),
        );
        if (!current()) return;
        final saved = await admission.record(
          request,
          isCurrent: current,
          commitNotice: decision.kind == CallAdmissionKind.firstInsufficient,
        );
        if (current() && (!saved || decision.persistenceFailed)) {
          _emit(
            CallLaunchState(
              CallLaunchPhase.blocked,
              request: request,
              decision: decision,
              noticeSaveFailed: true,
            ),
          );
        }
        return;
      }
      // Mark before invoking any callback; reentrant listeners cannot replay it.
      _submitted.add(request.identity);
      _emit(
        CallLaunchState(
          CallLaunchPhase.submitting,
          request: request,
          decision: decision,
        ),
      );
      if (!current()) return;
      if (!admission.modelReady) {
        _submitted.remove(request.identity);
        admission.ensureModelAvailable();
      }
      try {
        await submit(request);
        if (current()) {
          _emit(CallLaunchState(CallLaunchPhase.submitted, request: request));
        }
      } catch (_) {
        // The remote side may already have accepted: observe, never resubmit.
        if (current()) {
          _emit(CallLaunchState(CallLaunchPhase.uncertain, request: request));
        }
      }
    } catch (_) {
      if (current()) {
        _emit(CallLaunchState(CallLaunchPhase.failed, request: request));
      }
    }
  }

  bool _current(int generation) => !_closed && _generation == generation;
  void _emit(CallLaunchState next) {
    if (_closed) return;
    state = next;
    onState(next);
  }

  /// New input / restore / page exit. Does not hang up or cancel remote work.
  void cancelPending() {
    if (_closed) return;
    _generation++;
    _visibleAlias = null;
    _timer?.cancel();
    _timer = null;
    _emit(const CallLaunchState(CallLaunchPhase.idle));
  }

  void close() {
    if (_closed) return;
    cancelPending();
    _closed = true;
    state = const CallLaunchState(CallLaunchPhase.closed);
  }
}

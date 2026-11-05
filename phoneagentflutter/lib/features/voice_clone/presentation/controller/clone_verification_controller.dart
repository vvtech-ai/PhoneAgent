import '../../domain/clone_request_failure.dart';
import '../../../../core/diagnostics/clone_diagnostics.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/clone_sdk_diagnosis.dart';
import '../../domain/clone_verification.dart';
import '../../domain/clone_verification_admission.dart';

enum VerificationPhase {
  idle,
  preparing,
  initializing,
  collecting,
  checking,
  passed,
  rejected,
  cancelled,
  needsSync,
  failed,
}

enum VerificationIssue {
  none,
  preparation,
  initialization,
  capture,
  request,
  pollLimit,
  conflict,
  rejected,
  expired,
  needRetry,
  risk,
  readAloud,
}

/// No identity, SDK meta/certifyId, reason text or signed material in UI state.
class CloneVerificationState {
  const CloneVerificationState({
    this.phase = VerificationPhase.idle,
    this.issue = VerificationIssue.none,
    this.script = '',
    this.observationFailed = false,
    this.failure,
    this.admissionFailure,
  });
  final VerificationPhase phase;
  final VerificationIssue issue;
  final String script;
  final bool observationFailed;
  final CloneRequestFailure? failure;
  final CloneVerificationAdmissionFailure? admissionFailure;
  String get failureMessage =>
      admissionFailure?.message ??
      failure?.message ??
      switch (issue) {
        VerificationIssue.preparation => '认证准备失败，请稍后重新认证。',
        VerificationIssue.initialization => '认证初始化失败，请稍后重新认证。',
        VerificationIssue.capture => '人脸与声音采集未完成，请返回重新认证。',
        VerificationIssue.expired => '认证已过期，请返回重新认证。',
        VerificationIssue.needRetry => '本次认证需要重试，请返回重新认证。',
        VerificationIssue.risk => '认证未通过，请使用本人身份重新认证。',
        VerificationIssue.readAloud => '跟读认证未通过，请按提示完整朗读后重新认证。',
        VerificationIssue.conflict => '认证结果异常，请返回重新认证。',
        _ =>
          phase == VerificationPhase.cancelled
              ? '认证已取消，可返回重新认证。'
              : '认证未通过或未完成，可返回重新认证。',
      };
  bool get busy => const {
    VerificationPhase.preparing,
    VerificationPhase.initializing,
    VerificationPhase.collecting,
    VerificationPhase.checking,
  }.contains(phase);
}

/// One explicitly consented initialization per instance. The caller owns the
/// replacement confirmation gate. Generation/payment are separate downstream work.
class CloneVerificationController
    extends StateNotifier<CloneVerificationState> {
  CloneVerificationController({
    required this.repository,
    required this.capture,
    required this.isCurrent,
    this.diagnostics,
    this.maxPolls = 60,
    this.interval = const Duration(seconds: 1),
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed,
       super(const CloneVerificationState()) {
    if (maxPolls < 1 || interval.isNegative) {
      throw ArgumentError('Invalid verification polling');
    }
  }
  final CloneDiagnostics? diagnostics;
  final CloneVerificationRepository repository;
  final IdentityCapturePort capture;
  final bool Function() isCurrent;
  final int maxPolls;
  final Duration interval;
  final Future<void> Function(Duration) _delay;
  bool _started = false, _queryAllowed = false, _reported = false;
  String? _attemptId;
  VerificationObservation? _observation;
  Future<void>? _release;
  String? get verifiedAttemptId =>
      _current && state.phase == VerificationPhase.passed ? _attemptId : null;
  bool get _current => mounted && isCurrent();

  Future<void> start(VerificationIdentity identity) async {
    if (!_current || _started) return;
    _started = true;
    _set(VerificationPhase.preparing);
    String metaInfo;
    try {
      metaInfo = await capture.prepare();
    } catch (_) {
      await _abort();
      if (_current) {
        _set(VerificationPhase.failed, issue: VerificationIssue.preparation);
      }
      return;
    }
    if (!_current) {
      await _abort();
      return;
    }
    _set(VerificationPhase.initializing);
    VerificationAttempt attempt;
    try {
      attempt = await repository.initialize(identity, metaInfo);
    } catch (error) {
      // Unknown init outcome must never automatically create another attempt.
      await _abort();
      if (_current) {
        _set(
          VerificationPhase.failed,
          issue: VerificationIssue.initialization,
          failure: error is CloneRequestFailure ? error : null,
          admissionFailure: error is CloneVerificationAdmissionFailure
              ? error
              : null,
        );
      }
      return;
    }
    if (!_current) {
      await _abort();
      return;
    }
    _attemptId = attempt.id;
    _set(VerificationPhase.collecting, script: attempt.script);
    try {
      _observation = await _collect(attempt.certifyId);
    } catch (_) {
      if (_current) {
        _set(VerificationPhase.failed, issue: VerificationIssue.capture);
      }
      return;
    }
    if (!_current) {
      _observation = null;
      return;
    }
    final code = _observation!.sdkCode;
    _queryAllowed = CloneSdkDiagnosis.requiresServerQuery(code);
    if (!_queryAllowed) {
      _set(
        code == 1003 ? VerificationPhase.cancelled : VerificationPhase.rejected,
        issue: code == 1003
            ? VerificationIssue.none
            : VerificationIssue.capture,
      );
      _reportOnce();
      return;
    }
    await _poll();
    _reportOnce();
  }

  Future<VerificationObservation> _collect(String certifyId) async {
    final watch = Stopwatch()..start();
    final result = await capture.capture(certifyId);
    watch.stop();
    return CloneSdkDiagnosis.observation(result, watch.elapsed);
  }

  /// Recovery only reads the original attempt. It cannot open SDK, initialize,
  /// complete, activate or create a candidate.
  Future<void> synchronize() async {
    if (!_current ||
        !_queryAllowed ||
        state.phase != VerificationPhase.needsSync) {
      return;
    }
    await _poll();
    _reportOnce();
  }

  Future<void> _poll() async {
    _set(VerificationPhase.checking);
    for (var count = 0; count < maxPolls && _current; count++) {
      diagnostics?.event(
        DiagnosticCloneStage.verificationRead,
        DiagnosticResult.started,
        pollCount: count + 1,
      );
      VerificationSnapshot snapshot;
      try {
        snapshot = await repository.read(_attemptId!);
      } catch (_) {
        if (_current) {
          _set(VerificationPhase.needsSync, issue: VerificationIssue.request);
        }
        return;
      }
      if (!_current) return;
      if (snapshot.attemptId != _attemptId) {
        _queryAllowed = false;
        _set(VerificationPhase.failed, issue: VerificationIssue.conflict);
        return;
      }
      switch (snapshot.status) {
        case VerificationStatus.pass:
          _set(VerificationPhase.passed);
          return;
        case VerificationStatus.cancelled:
          _set(VerificationPhase.cancelled);
          return;
        case VerificationStatus.fail:
        case VerificationStatus.expired:
        case VerificationStatus.needRetry:
          _set(
            VerificationPhase.rejected,
            issue: switch (snapshot.status) {
              VerificationStatus.expired => VerificationIssue.expired,
              VerificationStatus.needRetry => VerificationIssue.needRetry,
              _ => switch (snapshot.providerSubCode) {
                '205' => VerificationIssue.risk,
                '220' => VerificationIssue.readAloud,
                _ => VerificationIssue.rejected,
              },
            },
          );
          return;
        case VerificationStatus.initiated:
        case VerificationStatus.processing:
          if (count + 1 < maxPolls) await _delay(interval);
      }
    }
    if (_current) {
      _set(VerificationPhase.needsSync, issue: VerificationIssue.pollLimit);
    }
  }

  void _reportOnce() {
    if (!_current || _reported || _observation == null || _attemptId == null) {
      return;
    }
    _reported = true;
    final observation = _observation!;
    _observation = null;
    // Best-effort telemetry cannot hold up a passed verification or retry writes.
    unawaited(_report(_attemptId!, observation));
  }

  Future<void> _report(
    String attempt,
    VerificationObservation observation,
  ) async {
    try {
      await repository.observe(attempt, observation);
    } catch (_) {
      if (_current) {
        state = CloneVerificationState(
          phase: state.phase,
          issue: state.issue,
          script: state.script,
          observationFailed: true,
          failure: state.failure,
          admissionFailure: state.admissionFailure,
        );
      }
    }
  }

  void _set(
    VerificationPhase phase, {
    VerificationIssue issue = VerificationIssue.none,
    String? script,
    CloneRequestFailure? failure,
    CloneVerificationAdmissionFailure? admissionFailure,
  }) {
    diagnostics?.event(
      DiagnosticCloneStage.verificationState,
      DiagnosticResult.received,
      state: phase.name,
      issue: issue.name,
    );
    state = CloneVerificationState(
      phase: phase,
      issue: issue,
      script: script ?? state.script,
      observationFailed: state.observationFailed,
      failure: failure,
      admissionFailure: admissionFailure,
    );
  }

  @override
  void dispose() {
    _attemptId = null;
    _observation = null;
    _queryAllowed = false;
    unawaited(_abort());
    super.dispose();
  }

  Future<void> _abort() => _release ??= _releaseCapture();

  Future<void> _releaseCapture() async {
    try {
      await capture.abort();
    } catch (_) {
      /* Never surface native SDK details. */
    }
  }
}

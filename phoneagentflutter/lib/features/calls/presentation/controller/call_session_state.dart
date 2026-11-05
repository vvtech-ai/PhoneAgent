import '../../domain/call_session.dart';
import '../../domain/call_transcript.dart';
import '../../domain/call_progress.dart';

enum CallSessionPhase { idle, observing, awaitingOutcome, ended, closed }

enum CallSessionIssue {
  none,
  refreshFailed,
  invalidResponse,
  sessionChanged,
  hangupFailed,
}

class CallSessionState {
  CallSessionState({
    required this.target,
    this.phase = CallSessionPhase.idle,
    this.snapshot,
    CallTranscript? transcript,
    this.hangingUp = false,
    this.ending = false,
    this.dismissRequested = false,
    this.issue = CallSessionIssue.none,
    this.progressText = '',
    this.progress = const CallProgress(),
    this.launchReady = false,
  }) : transcript = transcript ?? CallTranscript();
  final CallSessionTarget target;
  final CallSessionPhase phase;
  final CallSessionSnapshot? snapshot;
  final CallTranscript transcript;
  final bool hangingUp, dismissRequested, ending;
  final CallSessionIssue issue;
  final String progressText;
  final CallProgress progress;

  /// Sticky proof that Phone and Netty are ready and START_CALL was persisted.
  /// Readiness can arrive from either the status poll or the SSE push.
  final bool launchReady;
  bool get launchProven => launchReady;
  bool get connected =>
      progress.connectedObserved || snapshot?.normalizedState == 'CONNECTED';
  bool get canHangUp =>
      phase == CallSessionPhase.observing &&
      !hangingUp &&
      !ending &&
      !dismissRequested &&
      !progress.closureObserved &&
      target.isValid;

  CallSessionState copy({
    CallSessionTarget? target,
    CallSessionPhase? phase,
    CallSessionSnapshot? snapshot,
    CallTranscript? transcript,
    bool? hangingUp,
    bool? ending,
    bool? dismissRequested,
    CallSessionIssue? issue,
    String? progressText,
    CallProgress? progress,
    bool? launchReady,
  }) => CallSessionState(
    target: target ?? this.target,
    phase: phase ?? this.phase,
    snapshot: snapshot ?? this.snapshot,
    transcript: transcript ?? this.transcript,
    hangingUp: hangingUp ?? this.hangingUp,
    ending: ending ?? this.ending,
    dismissRequested: dismissRequested ?? this.dismissRequested,
    issue: issue ?? this.issue,
    progressText: progressText ?? this.progressText,
    progress: progress ?? this.progress,
    launchReady: launchReady ?? this.launchReady,
  );
}

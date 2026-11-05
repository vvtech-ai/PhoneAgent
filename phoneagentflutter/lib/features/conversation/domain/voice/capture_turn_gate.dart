import 'voice_gateway_event.dart';

enum CapturePhase {
  idle,
  awaitingReady,
  capturing,
  awaitingFinal,
  ended,
  cancelled,
}

/// Bind this to the actual connection/capture context, never to arrival time.
final class CaptureTurn {
  CaptureTurn._(this.generation);
  final int generation;
}

/// Synchronous event admission only. Does not open sockets, own the microphone,
/// merge ASR segments, or decide when to submit a conversation command.
final class CaptureTurnGate {
  CaptureTurn? _current;
  int _generation = 0;
  CapturePhase _phase = CapturePhase.idle;

  CapturePhase get phase => _phase;

  CaptureTurn begin() {
    _current = CaptureTurn._(++_generation);
    _phase = CapturePhase.awaitingReady;
    return _current!;
  }

  bool ready(CaptureTurn turn) {
    if (!_owns(turn) || _phase != CapturePhase.awaitingReady) return false;
    _phase = CapturePhase.capturing;
    return true;
  }

  bool allowsPcm(CaptureTurn turn) =>
      _owns(turn) && _phase == CapturePhase.capturing;

  /// Returns true exactly when an active capture needs to be stopped.
  bool release(CaptureTurn turn) {
    if (!_owns(turn)) return false;
    if (_phase == CapturePhase.awaitingReady) {
      _phase = CapturePhase.ended;
      return false;
    }
    if (_phase != CapturePhase.capturing) return false;
    _phase = CapturePhase.awaitingFinal;
    return true;
  }

  bool accept(CaptureTurn turn, VoiceTranscript event) {
    if (!_owns(turn) || event.text.trim().isEmpty) return false;
    if (_phase == CapturePhase.capturing) return true;
    if (_phase == CapturePhase.awaitingFinal && event.isFinal) {
      _phase = CapturePhase.ended;
      return true;
    }
    return false;
  }

  /// Call after exit, cancellation, failure, or an audio interruption.
  bool cancel(CaptureTurn turn) {
    if (!_owns(turn) || _phase == CapturePhase.cancelled) return false;
    _phase = CapturePhase.cancelled;
    return true;
  }

  /// The lifecycle owner applies the existing idle-close policy, not a new
  /// product timeout invented by this admission layer.
  bool expire(CaptureTurn turn) {
    if (!_owns(turn) || _phase != CapturePhase.awaitingFinal) return false;
    _phase = CapturePhase.ended;
    return true;
  }

  bool _owns(CaptureTurn turn) => identical(_current, turn);
}

import 'dart:async';
import '../diagnostics/diagnostic_audio_details.dart';
import '../diagnostics/diagnostic_event.dart';
import 'audio_focus_diagnostics.dart';
import 'audio_resource_coordinator.dart';

/// Serializes actual shutdown, not just ownership labels. No hardware is used.
class AudioPlaybackFocus {
  AudioPlaybackFocus({
    this.stopTimeout = const Duration(seconds: 5),
    this.diagnostics,
  });
  final Duration stopTimeout;
  final DiagnosticSink? Function()? diagnostics;
  AudioFocusTrace? _leaseTrace;
  final _resources = AudioResourceCoordinator();
  Future<void> _tail = Future.value();
  Future<void> Function(AudioLease)? _stop;
  Future<void>? _stopping;
  AudioLease? _stoppingLease;
  bool _interruptible = true;
  int _request = 0;
  AudioLease? get active => _resources.active;
  bool owns(AudioLease lease) => _resources.owns(lease);

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<AudioLease> acquire({
    required String owner,
    required Future<void> Function(AudioLease) stop,
    required bool Function() isCurrent,
    bool interruptible = true,
  }) {
    if (owner.trim().isEmpty) throw ArgumentError('Audio owner required');
    final request = ++_request;
    final trace = AudioFocusTrace(owner, request, diagnostics);
    final watch = Stopwatch()..start();
    var cancelled = false;
    DiagnosticAudioOwner? blockedBy;
    trace.emit(DiagnosticAudioStage.acquire, DiagnosticResult.started);
    void check() {
      if (request != _request || !isCurrent()) {
        cancelled = true;
        throw StateError('Audio request superseded');
      }
    }

    return _serial(() async {
      try {
        check();
        if (active != null && !_interruptible) {
          blockedBy = _leaseTrace?.owner;
          throw StateError('Exclusive audio is in use');
        }
        await _stopActive();
        check();
        final lease = _resources.acquire(owner);
        if (lease == null) throw StateError('Audio has not stopped');
        _stop = stop;
        _interruptible = interruptible;
        _leaseTrace = trace..lease = lease.generation;
        trace.emit(
          DiagnosticAudioStage.acquire,
          DiagnosticResult.succeeded,
          elapsedMs: watch.elapsedMilliseconds,
        );
        return lease;
      } catch (error) {
        trace.emit(
          DiagnosticAudioStage.acquire,
          cancelled ? DiagnosticResult.cancelled : DiagnosticResult.failed,
          elapsedMs: watch.elapsedMilliseconds,
          error: error,
          blockedBy: blockedBy,
        );
        rethrow;
      }
    });
  }

  /// Caller must await native shutdown/pause before releasing.
  bool release(AudioLease lease) {
    if (!_resources.release(lease)) return false;
    _stop = null;
    final trace = _leaseTrace;
    _leaseTrace = null;
    trace?.emit(DiagnosticAudioStage.release, DiagnosticResult.succeeded);
    return true;
  }

  Future<void> _stopActive() async {
    final lease = active;
    if (lease == null) return;
    final trace = _leaseTrace;
    final stop = _stop;
    if (stop == null) throw StateError('Audio owner has no shutdown hook');
    if (!identical(_stoppingLease, lease)) {
      _stoppingLease = lease;
      _stopping = _performStop(lease, stop, trace);
    }
    // A timeout does not prove the device stopped. Keep the lease and reuse
    // the same pending shutdown on retry, never start a second shutdown.
    final watch = Stopwatch()..start();
    await _stopping!.timeout(
      stopTimeout,
      onTimeout: () {
        final error = TimeoutException(
          'Audio stop wait timed out',
          stopTimeout,
        );
        trace?.emit(
          DiagnosticAudioStage.stopWait,
          DiagnosticResult.failed,
          elapsedMs: watch.elapsedMilliseconds,
          error: error,
        );
        throw error;
      },
    );
  }

  Future<void> _performStop(
    AudioLease lease,
    Future<void> Function(AudioLease) stop,
    AudioFocusTrace? trace,
  ) async {
    final watch = Stopwatch()..start();
    trace?.emit(DiagnosticAudioStage.stop, DiagnosticResult.started);
    try {
      await Future.sync(() => stop(lease));
      trace?.emit(
        DiagnosticAudioStage.stop,
        DiagnosticResult.succeeded,
        elapsedMs: watch.elapsedMilliseconds,
      );
      release(lease);
    } catch (error) {
      trace?.emit(
        DiagnosticAudioStage.stop,
        DiagnosticResult.failed,
        elapsedMs: watch.elapsedMilliseconds,
        error: error,
      );
      rethrow;
    } finally {
      if (identical(_stoppingLease, lease)) {
        _stoppingLease = null;
        _stopping = null;
      }
    }
  }

  /// Account/host shutdown invalidates pending starts and stops protected media.
  Future<void> stopAll() {
    ++_request;
    return _serial(_stopActive);
  }
}

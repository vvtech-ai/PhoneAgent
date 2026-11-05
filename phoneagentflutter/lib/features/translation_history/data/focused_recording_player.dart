import 'dart:async';
import '../../../../core/audio/audio_playback_focus.dart';
import '../../../../core/audio/audio_resource_coordinator.dart';
import '../domain/recording_audio.dart';

/// Shared focus at the actual playback boundary, never on download/preload.
class FocusedRecordingPlayer implements RecordingAudioPlayer {
  FocusedRecordingPlayer(this.delegate, this.focus, {required this.isCurrent}) {
    _subscription = delegate.events.listen(
      _event,
      onError: (Object _) {
        _event(const RecordingPlaybackEvent(failed: true));
      },
    );
  }
  final RecordingAudioPlayer delegate;
  final AudioPlaybackFocus focus;
  final bool Function() isCurrent;
  final _events = StreamController<RecordingPlaybackEvent>.broadcast();
  late final StreamSubscription<RecordingPlaybackEvent> _subscription;
  final _settling = <AudioLease>{};
  Future<void> _tail = Future.value();
  AudioLease? _lease;
  int _intent = 0;
  bool _closed = false;
  @override
  Stream<RecordingPlaybackEvent> get events => _events.stream;
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  bool _current(int intent) => !_closed && isCurrent() && intent == _intent;
  void _release(AudioLease? lease) {
    if (lease == null) return;
    focus.release(lease);
    if (identical(_lease, lease)) _lease = null;
  }

  void _event(RecordingPlaybackEvent event) {
    if (_closed) return;
    _events.add(event);
    final lease = _lease;
    if (lease == null ||
        !(event.completed || event.failed || event.paused) ||
        !_settling.add(lease)) {
      return;
    }
    unawaited(
      _serial(() async {
        try {
          if (!focus.owns(lease)) return;
          if (event.failed) {
            await delegate.stop();
          } else {
            await delegate.pause();
          }
          _release(lease);
        } finally {
          _settling.remove(lease);
        }
      }).catchError((Object _) {}),
    ); // Uncertain stop keeps the lease.
  }

  @override
  Future<int?> prepare(RecordingAudioAsset asset) => _serial(() async {
    if (_closed || !isCurrent()) throw StateError('Recording owner closed');
    return delegate.prepare(asset);
  });
  Future<void> _interrupt(AudioLease lease) => _serial(() async {
    if (!focus.owns(lease)) return;
    if (_closed) {
      await delegate.close();
    } else {
      await delegate.pause();
    }
    _release(lease);
    if (!_closed) _events.add(const RecordingPlaybackEvent(paused: true));
  });
  Future<void> _begin({required bool resume}) async {
    final intent = ++_intent;
    if (!_current(intent)) return;
    // Claim outside the local command queue: stopping an old lease may itself
    // need that queue. Waiting inside it would deadlock same-player replay.
    final lease = await focus.acquire(
      owner: 'recording',
      stop: _interrupt,
      isCurrent: () => _current(intent),
    );
    _lease = lease;
    await _serial(() async {
      if (!_current(intent) || !focus.owns(lease)) {
        _release(lease);
        return;
      }
      if (resume) {
        await delegate.resume();
      } else {
        await delegate.play();
      }
    });
  }

  @override
  Future<void> play() => _begin(resume: false);
  @override
  Future<void> resume() => _begin(resume: true);
  @override
  Future<void> pause() {
    ++_intent;
    return _serial(() async {
      await delegate.pause();
      _release(_lease);
    });
  }

  @override
  Future<void> stop() {
    ++_intent;
    return _serial(() async {
      if (_closed) {
        await delegate.close();
      } else {
        await delegate.stop();
      }
      _release(_lease);
    });
  }

  @override
  Future<void> close() {
    _closed = true;
    ++_intent;
    return _serial(() async {
      await delegate.close();
      _release(_lease);
      await _subscription.cancel();
      if (!_events.isClosed) await _events.close();
    });
  }
}

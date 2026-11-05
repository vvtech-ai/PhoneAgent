import 'dart:typed_data';
import '../../../../core/audio/audio_playback_focus.dart';
import '../../../../core/audio/audio_resource_coordinator.dart';
import '../domain/clone_preview_player.dart';

class FocusedClonePreviewPlayer implements ClonePreviewPlayer {
  FocusedClonePreviewPlayer(
    this.delegate,
    this.focus, {
    required this.isCurrent,
    this.owner = 'clone-preview',
  });
  final ClonePreviewPlayer delegate;
  final AudioPlaybackFocus focus;
  final String owner;
  final bool Function() isCurrent;
  AudioLease? _lease;
  bool _closed = false;
  int _intent = 0;
  bool _current(int intent) => !_closed && isCurrent() && intent == _intent;
  void _release(AudioLease? lease) {
    if (lease == null) return;
    focus.release(lease);
    if (identical(_lease, lease)) _lease = null;
  }

  Future<void> _interrupt(AudioLease lease) async {
    if (!focus.owns(lease)) return;
    await delegate.stop();
    _release(lease);
  }

  @override
  Future<void> play(Uint8List wav) async {
    final intent = ++_intent;
    if (!_current(intent)) return;
    final lease = await focus.acquire(
      owner: owner,
      stop: _interrupt,
      isCurrent: () => _current(intent),
    );
    _lease = lease;
    if (!_current(intent) || !focus.owns(lease)) {
      _release(lease);
      return;
    }
    try {
      // The delegate completes only after actual playback and native cleanup.
      await delegate.play(wav);
      _release(lease);
    } catch (_) {
      // A failed disposal cannot be treated as a free device. The delegate
      // retains its failed native handle so explicit stop can retry cleanup.
      try {
        await delegate.stop();
        _release(lease);
      } catch (_) {
        /* Retain. */
      }
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    ++_intent;
    final lease = _lease;
    await delegate.stop();
    _release(lease);
  }

  @override
  Future<void> close() async {
    _closed = true;
    ++_intent;
    final lease = _lease;
    await delegate.close();
    _release(lease);
  }
}

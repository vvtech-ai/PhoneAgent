import '../../../core/audio/audio_playback_focus.dart';
import '../../../core/audio/audio_resource_coordinator.dart';
import '../domain/call_monitor_media.dart';
import '../domain/call_session.dart';

/// The lease includes muted periods and is released only after native cleanup.
class FocusedCallMonitorMedia
    implements CallMonitorMedia, CallMonitorAudioReadiness {
  FocusedCallMonitorMedia({
    required this.delegate,
    required this.focus,
    required this.isCurrent,
    required this.onInterrupted,
  });
  final CallMonitorMedia delegate;
  final AudioPlaybackFocus focus;
  final bool Function() isCurrent;
  final void Function() onInterrupted;
  AudioLease? _lease;
  bool _closed = false;
  @override
  Stream<void> get disconnected => delegate.disconnected;
  @override
  Future<bool> get audioStarted => delegate is CallMonitorAudioReadiness
      ? (delegate as CallMonitorAudioReadiness).audioStarted
      : Future.value(true);
  void _check() {
    if (_closed || !isCurrent()) throw const CallMonitorFailure('cancelled');
  }

  @override
  Future<void> start(CallMonitorTicket ticket, String initialRoute) async {
    _check();
    try {
      _lease = await focus.acquire(
        owner: 'call-monitor',
        isCurrent: () => !_closed && isCurrent(),
        stop: (_) {
          onInterrupted();
          return close();
        },
      );
      _check();
      await delegate.start(ticket, initialRoute);
      _check();
    } catch (_) {
      await close();
      rethrow;
    }
  }

  @override
  Future<void> setPlaybackEnabled(bool enabled) {
    _check();
    return delegate.setPlaybackEnabled(enabled);
  }

  @override
  Future<CallMonitorRoute> route({String? select}) {
    _check();
    return delegate.route(select: select);
  }

  @override
  Future<void> close() async {
    _closed = true;
    await delegate.close();
    final lease = _lease;
    if (lease != null) {
      focus.release(lease);
      _lease = null;
    }
  }
}

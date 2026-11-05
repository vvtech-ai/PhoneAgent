import 'dart:async';
import 'dart:typed_data';
import '../../../../core/audio/audio_playback_focus.dart';
import '../../../../core/audio/audio_resource_coordinator.dart';
import '../../../conversation/domain/tools/conversation_permission.dart';
import '../../domain/translation_dial_preflight.dart';
import '../../domain/translation_pcm_bridge.dart';
import '../../domain/translation_realtime_event.dart';

/// Admission happens before financial/SIP work; hardware starts after connect.
class FocusedDomesticPcmBridge
    implements
        TranslationPcmBridge,
        TranslationPcmDrain,
        TranslationPcmPreparation {
  FocusedDomesticPcmBridge({
    required this.delegate,
    required this.permissions,
    required this.focus,
    required this.isCurrent,
    required this.onInterrupted,
    this.onStatistics,
  });
  final TranslationPcmBridge delegate;
  final ConversationPermissionSource permissions;
  final AudioPlaybackFocus focus;
  final bool Function() isCurrent;
  final Future<void> Function() onInterrupted;
  final void Function(Map<String, int>)? onStatistics;
  Timer? _statisticsTimer;
  Future<void>? _sampling;
  Future<void> _sample() =>
      _sampling ??= _sampleOnce().whenComplete(() => _sampling = null);
  Future<void> _sampleOnce() async {
    final bridge = delegate;
    if (bridge is! TranslationPcmStatistics || onStatistics == null) return;
    try {
      final stats = await (bridge as TranslationPcmStatistics)
          .playbackStatistics()
          .timeout(const Duration(seconds: 1));
      if (stats.isNotEmpty) onStatistics?.call(stats);
    } catch (_) {
      /* Diagnostics must not alter playback ownership. */
    }
  }

  AudioLease? _lease;
  Future<void>? _preparation, _cleanup;
  final _cancelled = Completer<void>();
  bool _closed = false;
  bool get _current => !_closed && isCurrent();

  Future<void> prepare() => _preparation ??= Future.any<void>([
    _prepare(),
    _cancelled.future.then(
      (_) => throw StateError('Audio preparation cancelled'),
    ),
  ]);
  Future<void> _prepare() async {
    final bridge = delegate;
    if (bridge is TranslationPcmQueue) {
      (bridge as TranslationPcmQueue).enableQueuedPlayback();
    }
    await ensureTranslationMicrophone(permissions, () => _current);
    final lease = await focus.acquire(
      owner: 'translation-sip',
      isCurrent: () => _current,
      interruptible: false,
      stop: (_) async {
        try {
          await onInterrupted();
        } finally {
          await close();
        }
      },
    );
    _lease = lease;
    if (!_current) {
      await close();
      if (focus.owns(lease)) focus.release(lease);
      throw StateError('Audio preparation cancelled');
    }
  }

  void _guard() {
    final lease = _lease;
    if (!_current || lease == null || !focus.owns(lease)) {
      throw StateError('Domestic audio unavailable');
    }
  }

  @override
  Future<void> prepareCallAudio() async {
    _guard();
    final bridge = delegate;
    if (bridge is! TranslationPcmPreparation) {
      throw StateError('Call audio preparation unavailable');
    }
    await (bridge as TranslationPcmPreparation).prepareCallAudio();
    _guard();
  }

  @override
  Future<void> start() async {
    _guard();
    await delegate.start();
    _guard();
    _statisticsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_current) unawaited(_sample());
    });
  }

  @override
  Future<Uint8List?> read() async {
    _guard();
    final frame = await delegate.read();
    _guard();
    return frame;
  }

  @override
  Future<void> play(TranslationAudio audio) async {
    _guard();
    await delegate.play(audio);
    _guard();
  }

  @override
  Future<void> drain() async {
    _guard();
    final bridge = delegate;
    if (bridge is TranslationPcmDrain) {
      await (bridge as TranslationPcmDrain).drain();
    }
    _guard();
    unawaited(_sample());
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    _guard();
    await delegate.setSpeaker(enabled);
    _guard();
  }

  @override
  Future<void> close() {
    _closed = true;
    _statisticsTimer?.cancel();
    if (!_cancelled.isCompleted) _cancelled.complete();
    return _cleanup ??= _close();
  }

  Future<void> _close() async {
    // Failure retains the lease: a label change cannot prove hardware stopped.
    await _sample();
    await delegate.close();
    final lease = _lease;
    if (lease != null) focus.release(lease);
  }
}

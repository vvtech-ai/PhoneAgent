import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'pcm_output.dart';
import 'playback_ledger.dart';

enum PcmPlaybackPhase { accepting, draining, drained, cancelled, failed }

/// Owns bounded bytes and uses native consumption acknowledgements for ledger.
class PcmPlaybackQueue {
  PcmPlaybackQueue({
    required this.output,
    required this.sampleRateHz,
    this.capacityBytes = 16 * 1024 * 1024,
    this.onChanged,
  }) : ledger = PlaybackLedger(capacityBytes: capacityBytes) {
    if (sampleRateHz < 8000 || sampleRateHz > 48000 || capacityBytes.isOdd) {
      throw ArgumentError('Invalid PCM output configuration');
    }
    _turn = ledger.begin();
  }
  final PcmOutput output;
  final int sampleRateHz, capacityBytes;
  final void Function()? onChanged;
  final PlaybackLedger ledger;
  late final PlaybackTurn _turn;
  final _queue = Queue<(Uint8List, PlaybackChunk)>();
  final _finished = Completer<PcmPlaybackPhase>();
  Future<PcmPlaybackPhase> get finished => _finished.future;
  PcmPlaybackPhase phase = PcmPlaybackPhase.accepting;
  String error = '';
  int _inflight = 0;
  bool _opening = false, _started = false, _closed = false;
  Future<void>? _cleanup;
  int get queuedBytes => ledger.queuedBytes;
  int get nativeBytes => _inflight;

  void add(Uint8List bytes) {
    if (_closed || phase != PcmPlaybackPhase.accepting) {
      throw const PcmOutputFailure('output_closed');
    }
    if (bytes.isEmpty) return;
    if (bytes.length.isOdd || bytes.length > ledger.availableBytes) {
      throw const PcmOutputFailure('output_capacity');
    }
    // 200 ms chunks, <=2 seconds submitted to the native queue at a time.
    final size = min((sampleRateHz * 2 ~/ 5) ~/ 2 * 2, capacityBytes);
    for (var offset = 0; offset < bytes.length; offset += size) {
      final end = min(offset + size, bytes.length);
      final chunk = ledger.enqueue(_turn, end - offset).chunk!;
      _queue.add((Uint8List.fromList(bytes.sublist(offset, end)), chunk));
    }
    onChanged?.call();
    if (!_opening && !_started) {
      _opening = true;
      unawaited(_open());
    } else {
      _pump();
    }
  }

  Future<void> _open() async {
    try {
      await output.start(sampleRateHz);
      if (_closed) return;
      _started = true;
      _pump();
    } catch (_) {
      if (!_closed) unawaited(fail('output_start_failed'));
    } finally {
      _opening = false;
    }
  }

  void _pump() {
    if (_closed || !_started) return;
    while (_queue.isNotEmpty &&
        _inflight + _queue.first.$1.length <= sampleRateHz * 4) {
      final (bytes, receipt) = _queue.removeFirst();
      _inflight += bytes.length;
      unawaited(
        Future.sync(() => output.play(bytes)).then(
          (_) {
            if (_closed) return;
            _inflight -= bytes.length;
            ledger.consumed(_turn, receipt);
            onChanged?.call();
            _pump();
            _drain();
          },
          onError: (Object _, StackTrace __) {
            if (!_closed) unawaited(fail('output_play_failed'));
          },
        ),
      );
    }
  }

  void complete() {
    if (_closed || phase != PcmPlaybackPhase.accepting) return;
    ledger.complete(_turn);
    phase = PcmPlaybackPhase.draining;
    onChanged?.call();
    _drain();
  }

  void _drain() {
    if (!_closed && ledger.phase == PlaybackPhase.drained) {
      unawaited(_finish(PcmPlaybackPhase.drained));
    }
  }

  Future<void> fail(String reason) {
    if (_closed) return Future.value();
    error = reason;
    return _finish(PcmPlaybackPhase.failed);
  }

  Future<void> stop() => _closed
      ? (_cleanup ??= _shutdown(phase))
      : _finish(PcmPlaybackPhase.cancelled);

  Future<void> _finish(PcmPlaybackPhase target) {
    _closed = true;
    _queue.clear();
    if (target != PcmPlaybackPhase.drained) ledger.cancel(_turn);
    // Natural completion remains draining until hardware release succeeds.
    if (target != PcmPlaybackPhase.drained) phase = target;
    onChanged?.call();
    return _cleanup ??= _shutdown(target);
  }

  Future<void> _shutdown(PcmPlaybackPhase target) async {
    try {
      await output.stop();
      _inflight = 0;
      phase = target;
    } catch (_) {
      phase = PcmPlaybackPhase.failed;
      error = 'output_stop_failed';
      _cleanup = null; // Explicit stop may retry; the lease remains occupied.
    }
    if (!_finished.isCompleted) _finished.complete(phase);
    onChanged?.call();
  }
}

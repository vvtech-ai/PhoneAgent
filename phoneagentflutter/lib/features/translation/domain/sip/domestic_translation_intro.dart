import 'dart:async';
import 'dart:typed_data';
import 'sip_lease.dart';
import 'translation_intro_audio.dart';
import 'translation_intro_gate.dart';

class DomesticTranslationIntro {
  DomesticTranslationIntro({
    required this.source,
    required this.callerLanguage,
    required this.peerLanguage,
    required this.responseBoundarySupported,
    required this.playLocal,
    this.drainLocal,
    this.bufferedLocal = false,
    required this.playRemote,
    this.queueRemote,
    required this.sendTrigger,
    required this.isCurrent,
    this.responseTimeout = const Duration(seconds: 5),
    int Function()? elapsedMs,
    Future<void> Function(Duration)? delay,
  }) : _elapsedMs = elapsedMs ?? (Stopwatch()..start()).readMilliseconds,
       _delay = delay ?? Future<void>.delayed;
  final TranslationIntroAudioSource source;
  final Future<void> Function()? drainLocal;
  final bool bufferedLocal;
  final String callerLanguage, peerLanguage;
  final bool responseBoundarySupported;
  final Future<void> Function(Uint8List) playLocal, playRemote;
  final Future<void> Function(List<Uint8List>)? queueRemote;
  final void Function(Uint8List) sendTrigger;
  final bool Function() isCurrent;
  final Duration responseTimeout;
  final int Function() _elapsedMs;
  final Future<void> Function(Duration) _delay;
  final gate = TranslationIntroGate();
  final _cancelled = Completer<void>(), _responseDone = Completer<void>();
  bool _closed = false, _injected = false;
  Future<void>? _startWork;
  bool get suppressLiveInput => gate.suppressLiveInput;
  bool get suppressModelOutput => gate.suppressModelOutput(_elapsedMs());

  Future<void> start() {
    if (_closed) {
      throw const SipLeaseFailure('INTRO_CANCELLED');
    }
    if (_startWork != null) {
      return _startWork!;
    }
    // Gate is synchronous so no live frame can slip through asset loading.
    gate.enter(responseBoundary: responseBoundarySupported);
    return _startWork = _run();
  }

  void triggerResponseDone() {
    if (!_injected || _closed || !responseBoundarySupported) {
      return;
    }
    gate.responseDone();
    if (!_responseDone.isCompleted) {
      _responseDone.complete();
    }
  }

  Future<void> _run() async {
    try {
      final frames = await Future.any<List<List<Uint8List>>?>([
        Future.wait([
          source.load(callerLanguage),
          source.load(peerLanguage),
          source.trigger(),
        ]),
        _cancelled.future.then((_) => null),
      ]);
      _check();
      if (frames == null ||
          frames.any(
            (part) => part.isEmpty || part.any((frame) => frame.length != 640),
          )) {
        throw const SipLeaseFailure('INTRO_AUDIO_UNAVAILABLE');
      }
      final caller = frames[0], peer = frames[1], trigger = frames[2];
      final remote = <Uint8List>[
        for (var i = 0; i < 10; i++) Uint8List(640),
        ...peer,
        for (var i = peer.length; i < caller.length; i++) Uint8List(640),
      ];
      // Attach error handlers to every concurrent side before any can fail.
      await Future.wait<void>([
        bufferedLocal ? _enqueueLocal(caller) : _play(caller, playLocal),
        queueRemote == null
            ? _play(remote, playRemote)
            : Future.any<void>([queueRemote!(remote), _cancelled.future]),
        _play([...trigger, for (var i = 0; i < 30; i++) Uint8List(640)], (
          frame,
        ) async {
          _injected = true;
          sendTrigger(frame);
        }),
      ], eagerError: true);
      _check();
      final drain = drainLocal;
      if (drain != null) {
        await Future.any<void>([drain(), _cancelled.future]);
        _check();
      }
      gate.playbackFinished(_elapsedMs());
      if (responseBoundarySupported) {
        await Future.any<void>([
          _responseDone.future,
          _cancelled.future,
        ]).timeout(responseTimeout);
        _check();
      }
    } on TimeoutException {
      _abort();
      throw const SipLeaseFailure('INTRO_TRIGGER_RESPONSE_TIMEOUT');
    } catch (_) {
      if (!_closed) {
        _abort();
      }
      rethrow;
    }
  }

  Future<void> _enqueueLocal(List<Uint8List> frames) async {
    // Submit 200ms chunks continuously; native admission supplies backpressure.
    for (var start = 0; start < frames.length; start += 10) {
      _check();
      final end = (start + 10).clamp(0, frames.length);
      final chunk = Uint8List((end - start) * 640);
      for (var i = start; i < end; i++) {
        chunk.setRange((i - start) * 640, (i - start + 1) * 640, frames[i]);
      }
      await Future.any<void>([playLocal(chunk), _cancelled.future]);
      _check();
    }
  }

  Future<void> _play(
    List<Uint8List> frames,
    Future<void> Function(Uint8List) output,
  ) async {
    var scheduled = _elapsedMs();
    for (final frame in frames) {
      _check();
      await Future.any<void>([output(frame), _cancelled.future]);
      _check();
      final now = _elapsedMs();
      scheduled = now - scheduled > 20 ? now + 20 : scheduled + 20;
      final wait = scheduled - now;
      if (wait > 0) {
        await Future.any<void>([
          _delay(Duration(milliseconds: wait)),
          _cancelled.future,
        ]);
      }
    }
  }

  void _check() {
    if (_closed || !isCurrent()) {
      throw const SipLeaseFailure('INTRO_CANCELLED');
    }
  }

  void _abort() {
    gate.failClosed();
    _closed = true;
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _cancelled.complete();
    gate.cancel();
  }
}

extension on Stopwatch {
  int readMilliseconds() => elapsedMilliseconds;
}

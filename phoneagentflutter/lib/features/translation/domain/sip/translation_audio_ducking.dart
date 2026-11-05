/// Native response-aware ducking. Time is monotonic milliseconds from owner.
enum TranslationDuckingState { original, attack, active, hold, release }

class TranslationAudioDucking {
  TranslationAudioDucking({required this.responseBoundarySupported});
  final bool responseBoundarySupported;
  TranslationDuckingState state = TranslationDuckingState.original;
  int _started = 0;
  int? _gap, _done;
  double progress(int now, int duration) =>
      ((now - _started) / duration).clamp(0, 1);

  void translated(int now) {
    _done = null;
    switch (state) {
      case TranslationDuckingState.original:
      case TranslationDuckingState.release:
        _transition(TranslationDuckingState.attack, now);
      case TranslationDuckingState.hold:
        _transition(TranslationDuckingState.active, now);
      case TranslationDuckingState.attack:
      case TranslationDuckingState.active:
        break;
    }
    _gap = null;
  }

  void responseDone(int now) {
    if (state != TranslationDuckingState.original) {
      _done = now;
    }
  }

  TranslationDuckingState next(int now, {required bool queued}) {
    switch (state) {
      case TranslationDuckingState.original:
        break;
      case TranslationDuckingState.attack:
        if (now - _started >= 40) {
          _transition(TranslationDuckingState.active, now);
          if (!queued) {
            _startGap(now);
          }
        }
      case TranslationDuckingState.active:
        if (!queued) {
          _startGap(now);
        }
      case TranslationDuckingState.hold:
        if (queued) {
          _transition(TranslationDuckingState.active, now);
          _gap = null;
        } else {
          final elapsed = now - (_gap ?? now);
          final release = _done == null
              ? elapsed >= (responseBoundarySupported ? 1500 : 700)
              : now - ((_gap ?? now) > _done! ? _gap! : _done!) >= 200;
          if (release) {
            _transition(TranslationDuckingState.release, now);
          }
        }
      case TranslationDuckingState.release:
        if (now - _started >= 350) {
          _transition(TranslationDuckingState.original, now);
          _done = null;
        }
    }
    return state;
  }

  void _startGap(int now) {
    _gap = now;
    _transition(TranslationDuckingState.hold, now);
  }

  void _transition(TranslationDuckingState value, int now) {
    state = value;
    _started = now;
  }
}

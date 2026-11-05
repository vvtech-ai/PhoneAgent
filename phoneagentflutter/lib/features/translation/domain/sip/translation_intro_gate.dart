/// Suppression boundaries follow native intro behavior; owner supplies time.
class TranslationIntroGate {
  bool _live = false, _pending = false, _expected = false;
  int _until = 0;
  bool get suppressLiveInput => _live;
  bool suppressModelOutput(int now) => _live || _pending || now < _until;
  void enter({required bool responseBoundary}) {
    _live = true;
    _expected = _pending = responseBoundary;
    _until = 0;
  }

  void playbackFinished(int now) {
    _live = false;
    if (!_expected) {
      _until = now + 800;
    }
  }

  void responseDone() {
    if (_expected) {
      _pending = false;
      _until = 0;
    }
  }

  void failClosed() {
    _live = _pending = _expected = true;
  }

  void cancel() {
    _live = _pending = _expected = false;
    _until = 0;
  }
}

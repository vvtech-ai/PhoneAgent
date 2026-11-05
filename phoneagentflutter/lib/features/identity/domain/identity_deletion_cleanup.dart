/// One deletion's local work; successful steps never repeat on explicit retry.
class IdentityDeletionCleanup {
  IdentityDeletionCleanup({
    required Future<void> Function() markSkipped,
    required Future<void> Function() clearRecording,
  }) : _steps = [markSkipped, clearRecording];
  final List<Future<void> Function()> _steps;
  final _done = <int>{};
  Future<void>? _running;

  Future<void> run() {
    final running = _running;
    if (running != null) return running;
    final next = _run();
    _running = next;
    return next;
  }

  Future<void> _run() async {
    try {
      await Future.wait([
        for (var index = 0; index < _steps.length; index++)
          if (!_done.contains(index)) _step(index),
      ]);
    } finally {
      _running = null;
    }
  }

  Future<void> _step(int index) async {
    await _steps[index]();
    _done.add(index);
  }
}

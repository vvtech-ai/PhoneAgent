/// Latest-request-wins ownership shared by ordinary receipt recordings.
/// TTS, translation and clone integration is a separate host-level concern.
class RecordingPlaybackArbiter {
  Object? _owner;
  Future<void> Function()? _interrupt;
  Future<void> Function()? _failedInterrupt;
  int _generation = 0;
  Future<void> _stopping = Future<void>.value();

  Future<int> claim(Object owner, Future<void> Function() interrupt) async {
    if (identical(_owner, owner)) {
      final generation = _generation;
      await _stopping;
      return generation;
    }
    final previous = _interrupt;
    final generation = ++_generation;
    _owner = owner;
    _interrupt = interrupt;
    try {
      await _queueStop(previous);
    } catch (_) {
      if (isCurrent(owner, generation)) release(owner);
      rethrow; // Do not play another source if stopping the previous one failed.
    }
    return generation;
  }

  bool isCurrent(Object owner, int generation) =>
      identical(_owner, owner) && _generation == generation;

  void release(Object owner) {
    if (!identical(_owner, owner)) return;
    ++_generation;
    _owner = null;
    _interrupt = null;
  }

  Future<void> stop() async {
    final previous = _interrupt;
    ++_generation;
    _owner = null;
    _interrupt = null;
    await _queueStop(previous);
  }

  Future<void> _queueStop(Future<void> Function()? previous) {
    final result = _stopping.then((_) async {
      final failed = _failedInterrupt;
      if (failed != null) {
        await failed();
        _failedInterrupt = null;
      }
      if (previous != null && !identical(previous, failed)) {
        try {
          await previous();
        } catch (_) {
          _failedInterrupt = previous;
          rethrow;
        }
      }
    });
    // Keep the queue usable, while returning the actual failure to this caller.
    _stopping = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}

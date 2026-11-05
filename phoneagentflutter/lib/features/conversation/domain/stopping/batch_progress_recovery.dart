import 'dart:async';
import 'batch_progress.dart';

/// Read-only recovery; original stream and ledger remain authoritative.
class BatchProgressRecovery {
  BatchProgressRecovery({
    required this.repository,
    required this.sessionId,
    required this.current,
    required this.apply,
    required this.synchronize,
    required this.completed,
    this.readFailed,
    this.exhausted,
  });
  final BatchProgressRepository? repository;
  final String sessionId;
  final bool Function() current;
  final void Function(BatchProgressSnapshot) apply;
  final Future<bool> Function() synchronize;
  final void Function() completed;
  final void Function(String batchId)? readFailed;
  final void Function(String batchId)? exhausted;
  Timer? _timer, _deadline;
  int _revision = 0, _attempts = 0;
  int _highestResultSequence = 0;
  String? _batchId;
  int? _readingRevision;
  bool _refreshQueued = false, _deadlineReached = false;
  void stop() {
    ++_revision;
    _timer?.cancel();
    _deadline?.cancel();
    _timer = null;
    _deadline = null;
    _deadlineReached = false;
    _batchId = null;
    _readingRevision = null;
    _refreshQueued = false;
    _highestResultSequence = 0;
  }

  void start(String batchId) {
    stop();
    _batchId = batchId;
    _attempts = 0;
    final revision = _revision;
    _deadline = Timer(const Duration(minutes: 5), () {
      if (revision != _revision) return;
      _deadline = null;
      _deadlineReached = true;
      _timer?.cancel();
      _timer = null;
      _refreshQueued = false;
      if (current()) exhausted?.call(batchId);
    });
    unawaited(_read(batchId, _revision));
  }

  void refresh(String batchId) {
    if (!current()) return;
    if (_batchId != batchId) {
      start(batchId);
      return;
    }
    if (_deadlineReached) return;
    if (_readingRevision == _revision) {
      _refreshQueued = true;
      return;
    }
    _timer?.cancel();
    _timer = null;
    unawaited(_read(batchId, _revision));
  }

  Future<void> _read(String id, int revision) async {
    bool valid() => revision == _revision && current();
    if (!valid()) return;
    _readingRevision = revision;
    try {
      try {
        if (id.isNotEmpty && repository != null) {
          final snapshot = await repository!.progress(sessionId, id);
          if (!valid()) return;
          if (snapshot.batchId == id &&
              snapshot.resultSequence >= _highestResultSequence) {
            if (snapshot.resultSequence > _highestResultSequence) {
              _highestResultSequence = snapshot.resultSequence;
            }
            apply(snapshot);
          }
        }
      } catch (_) {
        readFailed?.call(id);
        /* Older services may lack progress; ledger is still read. */
      }
      if (!valid()) return;
      try {
        if (await synchronize()) {
          if (valid()) {
            stop();
            completed();
          }
          return;
        }
      } catch (_) {
        /* Preserve results and retry reads only. */
      }
      if (!valid()) return;
      // External refreshes must not shorten the five-minute recovery window.
      if (_deadlineReached) return;
      // The first 12 unresolved reads schedule five seconds; later reads ten.
      _timer = Timer(Duration(seconds: ++_attempts <= 12 ? 5 : 10), () {
        _timer = null;
        unawaited(_read(id, revision));
      });
    } finally {
      if (revision == _revision && _readingRevision == revision) {
        _readingRevision = null;
        if (_refreshQueued && !_deadlineReached && current()) {
          _refreshQueued = false;
          _timer?.cancel();
          _timer = null;
          unawaited(_read(id, revision));
        }
      }
    }
  }
}

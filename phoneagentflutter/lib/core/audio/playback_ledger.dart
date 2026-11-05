enum PlaybackPhase { idle, accepting, draining, drained, cancelled }

enum EnqueueStatus { accepted, backpressure, inactive }

final class PlaybackTurn {
  PlaybackTurn._(this.generation);
  final int generation;
}

/// A single-use receipt. A native adapter acknowledges this only after the
/// whole chunk has played, not when it has merely been scheduled or copied.
final class PlaybackChunk {
  PlaybackChunk._(this.byteCount);
  final int byteCount;
}

final class EnqueueResult {
  const EnqueueResult._(this.status, [this.chunk]);
  final EnqueueStatus status;
  final PlaybackChunk? chunk;
}

/// Bounded admission/accounting, not an audio queue or a device player.
/// The adapter owns the bytes and must await capacity or fail explicitly.
final class PlaybackLedger {
  PlaybackLedger({required this.capacityBytes}) {
    if (capacityBytes <= 0) throw ArgumentError('Positive capacity required');
  }

  final int capacityBytes;
  final Set<PlaybackChunk> _pending = Set.identity();
  PlaybackTurn? _current;
  int _generation = 0;
  int _queuedBytes = 0;
  PlaybackPhase _phase = PlaybackPhase.idle;

  PlaybackPhase get phase => _phase;
  int get queuedBytes => _queuedBytes;
  int get availableBytes => capacityBytes - _queuedBytes;

  PlaybackTurn begin() {
    if (_phase == PlaybackPhase.accepting || _phase == PlaybackPhase.draining) {
      throw StateError('Cancel and stop the old player before a new turn');
    }
    _pending.clear();
    _queuedBytes = 0;
    _phase = PlaybackPhase.accepting;
    return _current = PlaybackTurn._(++_generation);
  }

  EnqueueResult enqueue(PlaybackTurn turn, int byteCount) {
    if (!_owns(turn) || _phase != PlaybackPhase.accepting) {
      return const EnqueueResult._(EnqueueStatus.inactive);
    }
    if (byteCount <= 0 || byteCount > capacityBytes) {
      // An oversize chunk can never fit: the adapter must split it first.
      throw ArgumentError('Chunk size must be positive and fit capacity');
    }
    if (byteCount > availableBytes) {
      return const EnqueueResult._(EnqueueStatus.backpressure);
    }
    final chunk = PlaybackChunk._(byteCount);
    _pending.add(chunk);
    _queuedBytes += byteCount;
    return EnqueueResult._(EnqueueStatus.accepted, chunk);
  }

  bool complete(PlaybackTurn turn) {
    if (!_owns(turn) || _phase != PlaybackPhase.accepting) return false;
    _phase = _queuedBytes == 0 ? PlaybackPhase.drained : PlaybackPhase.draining;
    return true;
  }

  bool consumed(PlaybackTurn turn, PlaybackChunk chunk) {
    if (!_owns(turn) || !_pending.remove(chunk)) return false;
    _queuedBytes -= chunk.byteCount;
    if (_phase == PlaybackPhase.draining && _queuedBytes == 0) {
      _phase = PlaybackPhase.drained;
    }
    return true;
  }

  bool cancel(PlaybackTurn turn) {
    if (!_owns(turn) ||
        (_phase != PlaybackPhase.accepting &&
            _phase != PlaybackPhase.draining)) {
      return false;
    }
    _pending.clear();
    _queuedBytes = 0;
    _phase = PlaybackPhase.cancelled;
    return true;
  }

  bool _owns(PlaybackTurn turn) => identical(_current, turn);
}

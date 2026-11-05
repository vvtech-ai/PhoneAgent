final class AudioLease {
  AudioLease._(this.owner, this.generation);
  final String owner;
  final int generation;
}

/// Admission policy, not a platform AudioSession. The application composition
/// root must share one instance across capture, playback and call media.
final class AudioResourceCoordinator {
  AudioLease? _active;
  int _generation = 0;

  AudioLease? get active => _active;

  /// No implicit preemption or re-entrant ownership, even for the same owner.
  AudioLease? acquire(String owner) {
    if (owner.trim().isEmpty) throw ArgumentError('Audio owner required');
    if (_active != null) return null;
    return _active = AudioLease._(owner, ++_generation);
  }

  bool owns(AudioLease lease) => identical(_active, lease);

  /// Caller must first await actual adapter shutdown. Releasing admission alone
  /// does not stop hardware; early release would allow two native audio owners.
  bool release(AudioLease lease) {
    if (!owns(lease)) return false;
    _active = null;
    return true;
  }
}

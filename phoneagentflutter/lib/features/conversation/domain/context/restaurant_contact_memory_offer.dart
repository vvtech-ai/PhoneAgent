abstract interface class RestaurantMemoryAskedStore {
  Future<bool> read();
  Future<void> markAsked();
}

/// Records an offer, never a contact or memory entry. Owned by one login.
class RestaurantContactMemoryOffer {
  RestaurantContactMemoryOffer(this.store, this.isCurrent);
  final RestaurantMemoryAskedStore store;
  final bool Function() isCurrent;
  static const questionId = 'restaurantContactMemoryConsent';
  bool? _asked;
  Future<bool>? _reading, _saving;
  bool _closed = false;
  bool get _current => !_closed && isCurrent();

  Future<bool> _read() async {
    if (_asked != null) return _asked!;
    final pending = _reading ??= store.read();
    try {
      final value = await pending;
      if (_current) _asked ??= value;
      return _asked ?? value;
    } finally {
      if (identical(_reading, pending)) _reading = null;
    }
  }

  Future<Map<String, Object?>> context() async {
    if (!_current) return const {};
    try {
      await _saving;
      final asked = await _read();
      await _saving;
      return _current
          ? {'restaurantContactMemoryAsked': _asked ?? asked}
          : const {};
    } catch (_) {
      // Do not fabricate a successful read or block the user's current task.
      return const {};
    }
  }

  Future<bool> shown(bool Function() isVisible) {
    if (!_current || !isVisible()) return Future.value(false);
    return _saving ??= _save(isVisible).whenComplete(() => _saving = null);
  }

  Future<bool> _save(bool Function() isVisible) async {
    try {
      if (await _read()) return true;
      if (!_current || !isVisible()) return false;
      await store.markAsked();
      if (!_current) return false;
      _asked = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  void close() => _closed = true;
}

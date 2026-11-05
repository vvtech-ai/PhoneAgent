import 'dart:async';

/// Holds only a live permission continuation across transient system UI focus.
class ConversationPermissionResume {
  ConversationPermissionResume(this.abandon);
  final void Function() abandon;
  bool _foreground = true;
  int _epoch = 0;
  int get generation => _epoch;
  bool _abandoned = false;
  Object? _pending;
  Completer<void>? _resumed;

  void inactive() {
    _foreground = false;
    _resumed ??= Completer<void>();
  }

  void resume() {
    _foreground = true;
    _abandoned = false;
    _resumed?.complete();
    _resumed = null;
  }

  void background({bool preflightPending = false}) {
    final cancelled = !_abandoned && (_pending != null || preflightPending);
    _pending = null;
    ++_epoch;
    _foreground = false;
    _resumed?.complete();
    _resumed = null;
    if (cancelled) {
      _abandoned = true;
      abandon();
    }
  }

  Future<T?> run<T>(
    Future<T?> Function(bool Function()) resolve,
    bool Function() current,
  ) async {
    if (!_foreground || !current()) return null;
    final epoch = _epoch;
    final token = Object();
    _pending = token;
    bool valid() => epoch == _epoch && current();
    try {
      final result = await resolve(valid);
      if (!valid() || result == null) return null;
      if (!_foreground) await _resumed?.future;
      return valid() && _foreground ? result : null;
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
  }
}

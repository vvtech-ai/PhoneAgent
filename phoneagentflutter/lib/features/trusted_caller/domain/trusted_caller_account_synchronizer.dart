import 'dart:async';
import 'trusted_caller.dart';
import 'trusted_caller_account.dart';

/// Serial app-lifetime delivery; stale success never confirms a newer account.
class TrustedCallerAccountSynchronizer {
  TrustedCallerAccountSynchronizer(this.port);
  final TrustedCallerAccountPort port;
  TrustedCallerOwner? _owner;
  String _environment = '';
  int _revision = 0;
  bool _closed = false, _confirmed = false;
  Future<void> _tail = Future.value();
  Future<bool>? _pending;

  bool _matches(TrustedCallerOwner? owner, String environment) =>
      !_closed &&
      environment == _environment &&
      (owner == null ? _owner == null : _owner?.matches(owner) == true);

  Future<bool> select(TrustedCallerOwner? owner, String environment) {
    if (_closed) return Future.value(false);
    if (_matches(owner, environment)) return ensure(owner, environment);
    _owner = owner;
    _environment = environment;
    _revision++;
    _confirmed = false;
    _pending = null;
    return _schedule();
  }

  Future<bool> ensure(TrustedCallerOwner? owner, String environment) {
    if (!_matches(owner, environment)) return Future.value(false);
    if (_confirmed) return Future.value(true);
    return _pending ?? _schedule();
  }

  Future<bool> _schedule() {
    final revision = _revision;
    final owner = _owner;
    final environment = _environment;
    final completion = Completer<bool>();
    final future = completion.future;
    _pending = future;
    final operation = _tail.then((_) async {
      if (_closed || revision != _revision) return false;
      final success = await port.updateAccount(owner, environment);
      if (_closed || revision != _revision) return false;
      _confirmed = success;
      return success;
    });
    _tail = operation.then<void>((_) {}, onError: (Object _) {});
    operation.then(
      completion.complete,
      onError: (Object error, StackTrace stack) {
        if (_closed || revision != _revision) {
          completion.complete(false);
        } else {
          completion.completeError(error, stack);
        }
      },
    );
    // This listener also handles automatic delivery errors until an entry retries.
    future.then<void>(
      (_) {
        if (identical(_pending, future)) _pending = null;
      },
      onError: (Object _) {
        if (identical(_pending, future)) _pending = null;
      },
    );
    return future;
  }

  void close() {
    _closed = true;
    _revision++;
  }
}

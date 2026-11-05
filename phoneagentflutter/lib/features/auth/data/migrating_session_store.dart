import 'dart:async';
import '../domain/auth_gateway.dart';
import '../domain/auth_session.dart';
import '../domain/legacy_session_source.dart';

/// Serializes migration and ordinary writes, including logout during restore.
/// Old files are retained; only the new source-consumed barrier is changed.
class MigratingSessionStore implements SessionStore {
  MigratingSessionStore(this.destination, this.source, {required this.scope});
  final SessionStore destination;
  final LegacySessionSource source;
  final String scope;
  // Provider recreation must not create a second writer for the same key.
  // Completed tails are removed; this map never stores credentials or results.
  static final Map<String, Future<void>> _tails = {};

  Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _tails[scope] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tails[scope] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[scope], tail)) _tails.remove(scope);
      }),
    );
    return result;
  }

  @override
  Future<AuthSession?> read() => _serial(() async {
    final existing = await destination.read();
    if (existing != null) {
      if (!existing.valid) throw AuthFailure.invalidResponse;
      await source.consume();
      return existing;
    }
    final legacy = await source.read();
    if (legacy == null) return null;
    if (!legacy.valid) throw AuthFailure.invalidResponse;
    await destination.write(legacy);
    await source.consume();
    return legacy;
  });

  @override
  Future<void> write(AuthSession session) => _serial(() async {
    if (!session.valid) throw AuthFailure.invalidResponse;
    await source.consume();
    await destination.write(session);
  });

  @override
  Future<void> clear() => _serial(() async {
    await source.consume();
    await destination.clear();
  });
}

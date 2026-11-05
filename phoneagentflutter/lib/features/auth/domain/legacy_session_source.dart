import 'auth_session.dart';

/// Local same-package upgrade source, never a network authentication provider.
abstract interface class LegacySessionSource {
  Future<AuthSession?> read();

  /// Durable one-way barrier. Must succeed before accepting logout/new login.
  Future<void> consume();
}

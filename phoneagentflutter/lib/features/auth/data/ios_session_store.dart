import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/ios_installation.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_session.dart';
import 'secure_session_store.dart';

/// Token and private account metadata are separately stored and bound together.
class IosSessionStore implements SessionStore {
  IosSessionStore(
    AppConfig config, {
    this.local = const AppLocalStorage(),
    this.credentials = IosInstallation.credentials,
    Future<void> Function()? initialize,
  }) : scope = SecureSessionStore.keyFor(
         config,
       ).substring('phoneagent.auth.v1.'.length),
       initialize = initialize ?? IosInstallation.current.ensure;
  final FlutterSecureStorage local, credentials;
  final Future<void> Function() initialize;
  final String scope;
  String get metadataKey => 'phoneagent.session.v1.$scope';
  String get tokenKey => '${IosInstallation.tokenPrefix}$scope';
  static final _tails = <String, Future<void>>{};

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = (_tails[scope] ?? Future<void>.value()).then((_) async {
      await initialize();
      return action();
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tails[scope] = tail;
    return result.whenComplete(() {
      if (identical(_tails[scope], tail)) _tails.remove(scope);
    });
  }

  @override
  Future<AuthSession?> read() => _serial(() async {
    final raw = await local.read(key: metadataKey);
    if (raw == null) {
      await credentials.delete(key: tokenKey);
      return null;
    }
    final token = await credentials.read(key: tokenKey);
    if (token == null) {
      await local.delete(key: metadataKey);
      return null;
    }
    final data = jsonDecode(raw), secret = jsonDecode(token);
    if (data is! Map ||
        secret is! Map ||
        data['version'] != 1 ||
        secret['version'] != 1 ||
        data['binding'] is! String ||
        data['binding'] != secret['binding']) {
      throw AuthFailure.storage;
    }
    final session = AuthSession(
      accountId: data['accountId'] as String,
      phone: data['phone'] as String,
      displayName: data['displayName'] as String,
      accessToken: secret['accessToken'] as String,
    );
    if (!session.valid) throw AuthFailure.invalidResponse;
    return session;
  });

  @override
  Future<void> write(AuthSession session) => _serial(() async {
    if (!session.valid) throw AuthFailure.invalidResponse;
    // Invalidate the old credential before any metadata update.
    await credentials.delete(key: tokenKey);
    final random = Random.secure();
    final binding = base64Url.encode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    await local.write(
      key: metadataKey,
      value: jsonEncode({
        'version': 1,
        'binding': binding,
        'accountId': session.accountId,
        'phone': session.phone,
        'displayName': session.displayName,
      }),
    );
    await credentials.write(
      key: tokenKey,
      value: jsonEncode({
        'version': 1,
        'binding': binding,
        'accessToken': session.accessToken,
      }),
    );
  });

  @override
  Future<void> clear() => _serial(() async {
    await credentials.delete(key: tokenKey);
    await local.delete(key: metadataKey);
  });
}

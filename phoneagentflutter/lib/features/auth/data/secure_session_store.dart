import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_session.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore(AppConfig config, {FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          ),
      _key = keyFor(config);
  final FlutterSecureStorage _storage;
  final String _key;

  static String keyFor(AppConfig config) {
    if (!config.isConfigured) throw AuthFailure.unavailable;
    final uri = config.apiBaseUri!;
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    final scope = '${config.environment!.name}|${uri.replace(path: path)}';
    return 'phoneagent.auth.v1.${base64Url.encode(utf8.encode(scope))}';
  }

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> || data['version'] != 1) {
      throw AuthFailure.invalidResponse;
    }
    String field(String key) {
      final value = data[key];
      if (value is! String) throw AuthFailure.invalidResponse;
      return value;
    }

    final session = AuthSession(
      accountId: field('accountId'),
      phone: field('phone'),
      accessToken: field('accessToken'),
      displayName: field('displayName'),
    );
    if (!session.valid) throw AuthFailure.invalidResponse;
    return session;
  }

  @override
  Future<void> write(AuthSession session) async {
    if (!session.valid) throw AuthFailure.invalidResponse;
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'version': 1,
        'accountId': session.accountId,
        'phone': session.phone,
        'accessToken': session.accessToken,
        'displayName': session.displayName,
      }),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// No configured environment means no storage access and no authenticated user.
class UnconfiguredSessionStore implements SessionStore {
  const UnconfiguredSessionStore();
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> write(AuthSession session) async =>
      throw AuthFailure.unavailable;
  @override
  Future<void> clear() async {}
}

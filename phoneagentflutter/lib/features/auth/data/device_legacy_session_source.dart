import 'package:flutter/services.dart';
import '../../../core/config/app_config.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_session.dart';
import '../domain/legacy_session_source.dart';

class DeviceLegacySessionSource implements LegacySessionSource {
  const DeviceLegacySessionSource();
  static const channel = MethodChannel('com.vvtech.phone_agent/legacy_session');

  /// v65 prod is unambiguously this endpoint. Old .dev was a local flavor,
  /// whereas old remote dev was .test; never infer source scope from a suffix.
  static bool eligible(AppConfig config) {
    final uri = config.apiBaseUri;
    return config.isConfigured &&
        config.environment == AppEnvironment.prod &&
        uri?.scheme == 'https' &&
        uri?.host == 'chaken.ai' &&
        uri?.port == 443 &&
        const {'/aiassistant-api', '/aiassistant-api/'}.contains(uri?.path);
  }

  @override
  Future<AuthSession?> read() async {
    final data = await channel.invokeMapMethod<String, Object?>('read');
    if (data == null) return null;
    if (data['version'] != 1 ||
        data['phone'] is! String ||
        data['accessToken'] is! String) {
      throw AuthFailure.invalidResponse;
    }
    var phone = (data['phone']! as String)
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '');
    if (phone.startsWith('+86')) {
      phone = phone.substring(3);
    } else if (phone.startsWith('86')) {
      phone = phone.substring(2);
    }
    final token = (data['accessToken']! as String).trim();
    // A hint or token-less old login is not a reusable authenticated session.
    if (phone.isEmpty || token.isEmpty) return null;
    final session = AuthSession(
      accountId: 'phone-$phone',
      phone: phone,
      accessToken: token,
    );
    if (!session.valid) throw AuthFailure.invalidResponse;
    return session;
  }

  @override
  Future<void> consume() async {
    if (await channel.invokeMethod<bool>('consume') != true) {
      throw AuthFailure.storage;
    }
  }
}

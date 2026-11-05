import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../service_routes.dart';
import 'c1_credentials.dart';

/// Native OTA compatibility only; deployment credentials never enter logs.
abstract final class OtaV2RequestSigner {
  static bool applies(Uri uri, ApiService service) =>
      service == ApiService.sdk && uri.path.endsWith('/api/ota/check');

  static Map<String, Object?> headers(
    Uri uri,
    String method,
    List<int> body,
    C1Credentials credentials,
  ) {
    final hash = sha256.convert(body).toString();
    final canonical = [
      'v2',
      method.toUpperCase(),
      uri.path,
      uri.query,
      credentials.apiKey,
      hash,
    ].join('\n');
    final signature = Hmac(
      sha256,
      utf8.encode(credentials.secret),
    ).convert(utf8.encode(canonical)).toString();
    return {
      'X-Sign-Version': 'v2',
      'X-App-Key': credentials.apiKey,
      'X-Body-SHA256': hash,
      'X-Sign-Alg': 'HMAC-SHA256',
      'X-Signature': signature,
    };
  }
}

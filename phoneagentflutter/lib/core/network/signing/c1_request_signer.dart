import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sm3.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'c1_signed_url.dart';

/// Byte-exact C1 signing. Credentials and diagnostic context come from a port.
abstract final class C1RequestSigner {
  static String digest(List<int> bytes) =>
      _hex(SM3Digest().process(Uint8List.fromList(bytes)));

  static String sign({
    required String method,
    required Uri uri,
    required String requestId,
    required int timestamp,
    required String deviceId,
    required String apiKey,
    required String secret,
    required String clientContext,
    required String accessToken,
    required List<int> body,
  }) {
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    if (!uuid.hasMatch(requestId) ||
        !uuid.hasMatch(deviceId) ||
        !RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(apiKey) ||
        secret.isEmpty ||
        accessToken.length > 4096 ||
        !RegExp(r'^[0-9]{13}$').hasMatch('$timestamp') ||
        !RegExp(r'^[A-Za-z0-9_-]{1,1366}$').hasMatch(clientContext)) {
      throw const FormatException('Invalid C1 input');
    }
    final context = base64Url.decode(base64Url.normalize(clientContext));
    if (context.length > 1024 ||
        base64Url.encode(context).replaceAll('=', '') != clientContext) {
      throw const FormatException('Invalid C1 context');
    }
    final canonical = [
      method.toUpperCase(),
      C1SignedUrl.path(uri.path),
      C1SignedUrl.query(uri.query),
      requestId,
      '$timestamp',
      deviceId,
      apiKey,
      'HMAC-SM3',
      '1',
      digest(utf8.encode(accessToken)),
      digest(context),
      digest(body),
    ].join('\n');
    final mac = HMac(SM3Digest(), 64)
      ..init(KeyParameter(Uint8List.fromList(utf8.encode(secret))));
    return _hex(mac.process(Uint8List.fromList(utf8.encode(canonical))));
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

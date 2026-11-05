import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:pointycastle/digests/sm3.dart';
import '../service_routes.dart';
import 'c1_credentials.dart';
import 'c1_request_signer.dart';
import 'ota_v2_request_signer.dart';

/// One signing path for JSON, SSE, binary GET and multipart. Never logs input.
class C1Transport {
  C1Transport(
    this.credentials, {
    String Function()? requestId,
    int Function()? now,
  }) : _requestId = requestId ?? newDeviceId,
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);
  final C1CredentialSource credentials;
  final String Function() _requestId;
  final int Function() _now;

  static String newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<(Object?, Map<String, Object?>)> prepare(
    Uri uri, {
    required ApiService service,
    required String method,
    required String token,
    Object? body,
  }) async {
    final credential = await credentials.read(service);
    final Object? data = body is FormData
        ? body.clone()
        : body == null
        ? null
        : body is String
        ? body
        : jsonEncode(body);
    final bytes = body is FormData
        ? await _multipart(body)
        : utf8.encode(data as String? ?? '');
    if (OtaV2RequestSigner.applies(uri, service)) {
      if (body is FormData) throw const FormatException('OTA requires JSON');
      return (data, OtaV2RequestSigner.headers(uri, method, bytes, credential));
    }
    final requestId = _requestId(), timestamp = _now();
    final sign = C1RequestSigner.sign(
      method: method,
      uri: uri,
      requestId: requestId,
      timestamp: timestamp,
      deviceId: credential.deviceId,
      apiKey: credential.apiKey,
      secret: credential.secret,
      clientContext: credential.clientContext,
      accessToken: token,
      body: bytes,
    );
    return (
      data,
      {
        'X-Api-Key': credential.apiKey,
        'X-Udid': credential.deviceId,
        'X-Reqid': requestId,
        'X-Timestamp': '$timestamp',
        'X-Sign-Alg': 'HMAC-SM3',
        'X-Api-Version': '1',
        'X-Client-Context': credential.clientContext,
        'X-Sign': sign,
      },
    );
  }

  Future<Map<String, Object?>> upgrade(Uri uri, String token) async =>
      (await prepare(
        uri,
        service: ApiService.agent,
        method: 'GET',
        token: token,
      )).$2;

  Future<List<int>> _multipart(FormData body) async {
    if (body.fields.length + body.files.length > 16) {
      throw const FormatException('Too many C1 parts');
    }
    String encoded(String value) =>
        base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    final entries = <String>[];
    for (final field in body.fields) {
      final bytes = utf8.encode(field.value);
      entries.add(
        '${encoded(field.key)}:::${bytes.length}:${C1RequestSigner.digest(bytes)}',
      );
    }
    for (final file in body.files) {
      final digest = SM3Digest();
      var size = 0;
      await for (final chunk in file.value.clone().finalize()) {
        size += chunk.length;
        digest.update(chunk, 0, chunk.length);
      }
      final output = Uint8List(digest.digestSize);
      digest.doFinal(output, 0);
      final hash = output
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      entries.add(
        '${encoded(file.key)}:${encoded(file.value.filename ?? '')}:'
        '${file.value.contentType.toString().toLowerCase()}:$size:$hash',
      );
    }
    entries.sort();
    return utf8.encode('MULTIPART-SM3-V1\n${entries.join('\n')}');
  }
}

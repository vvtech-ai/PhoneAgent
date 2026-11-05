import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Versioned authenticated envelope. Scope + filename are authenticated but not
/// stored; moving ciphertext to another account or filename fails verification.
class DiagnosticArchiveCipher {
  static const maxStoredBytes = 5 * 1024 * 1024;
  static const maxPlainBytes = ((maxStoredBytes - 3) ~/ 4) * 3 - 29;

  static Future<String> encrypt(
    String text,
    List<int> key,
    String binding,
  ) async {
    final bytes = utf8.encode(text);
    if (bytes.length > maxPlainBytes) {
      throw StateError('Diagnostic file too large');
    }
    final cipher = AesGcm.with256bits();
    final box = await cipher.encrypt(
      bytes,
      secretKey: SecretKey(key),
      nonce: cipher.newNonce(),
      aad: utf8.encode('phoneagent-diagnostics-v1|$binding'),
    );
    return 'v1.${base64Encode([1, ...box.nonce, ...box.mac.bytes, ...box.cipherText])}';
  }

  static Future<String> decrypt(
    String text,
    List<int> key,
    String binding,
  ) async {
    if (!text.startsWith('v1.') || text.length > maxStoredBytes) {
      throw const FormatException('Diagnostic envelope');
    }
    final bytes = base64Decode(text.substring(3));
    if (bytes.length < 29 || bytes.first != 1) {
      throw const FormatException('Diagnostic envelope');
    }
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(
        bytes.sublist(29),
        nonce: bytes.sublist(1, 13),
        mac: Mac(bytes.sublist(13, 29)),
      ),
      secretKey: SecretKey(key),
      aad: utf8.encode('phoneagent-diagnostics-v1|$binding'),
    );
    return utf8.decode(plain);
  }
}

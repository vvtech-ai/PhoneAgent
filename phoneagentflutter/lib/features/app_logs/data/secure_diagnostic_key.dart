import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureDiagnosticKey {
  SecureDiagnosticKey(
    String scope, {
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key =
           'phoneagent.diagnostics.key.v1.${sha256.convert(utf8.encode(scope))}',
       _storage = storage;
  final String key;
  final FlutterSecureStorage _storage;

  // Caller holds the scope directory transaction during creation and write.
  Future<List<int>> load({required bool allowCreate}) async {
    final value = await _storage.read(key: key);
    if (value != null) {
      final bytes = base64Decode(value);
      if (bytes.length != 32) throw const FormatException('Diagnostic key');
      return bytes;
    }
    if (!allowCreate) throw StateError('Diagnostic key unavailable');
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(key: key, value: base64Encode(bytes));
    return bytes;
  }
}

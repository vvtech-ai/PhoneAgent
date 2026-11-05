import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../../core/diagnostics/diagnostic_journal.dart';

class SecureDiagnosticStore implements DiagnosticStore {
  SecureDiagnosticStore(
    String scope, {
    FlutterSecureStorage storage = const AppLocalStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key = 'phoneagent.diagnostics.v1.${sha256.convert(utf8.encode(scope))}',
       _storage = storage;
  final String key;
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

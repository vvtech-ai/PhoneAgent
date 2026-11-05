import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../domain/task_pinned_visibility.dart';

class SecureTaskPinnedPreferences implements TaskPinnedPreferenceRepository {
  SecureTaskPinnedPreferences(
    List<String> scope, {
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : scopeKey =
           'tasks.pinned.${sha256.convert(utf8.encode(jsonEncode(scope)))}';
  @override
  final String scopeKey;
  final FlutterSecureStorage storage;
  @override
  Future<bool> read() async {
    final raw = await storage.read(key: scopeKey);
    if (raw == null) return false;
    if (raw != 'true' && raw != 'false') {
      throw const FormatException('Invalid pinned preference');
    }
    return raw == 'true';
  }

  @override
  Future<void> save(bool collapsed) =>
      storage.write(key: scopeKey, value: '$collapsed');
}

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/home_notification.dart';

/// Current owner only. Old unscoped native read sets are never imported.
class SecureHomeNotificationReadStore implements HomeNotificationReadStore {
  SecureHomeNotificationReadStore(
    AppConfig config,
    String accountId, {
    FlutterSecureStorage? storage,
    bool Function()? isCurrent,
  }) : key = keyFor(config, accountId),
       _isCurrent = isCurrent ?? (() => true),
       _storage =
           storage ??
           const AppLocalStorage(
             preference: true,
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
           );
  final String key;
  final FlutterSecureStorage _storage;
  final bool Function() _isCurrent;

  static String keyFor(AppConfig config, String accountId) {
    if (!config.isConfigured || accountId.trim().isEmpty) {
      throw StateError('Missing notification owner');
    }
    final base = config.apiBaseUri!;
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    final owner = jsonEncode([
      config.environment!.name,
      base.replace(path: path).toString(),
      accountId.trim(),
    ]);
    return 'phoneagent.home-notification.v1.${sha256.convert(utf8.encode(owner))}';
  }

  void _check() {
    if (!_isCurrent()) throw StateError('Notification owner changed');
  }

  @override
  Future<Map<String, int>> load() =>
      PreferenceOperationQueue.run(key, () async {
        _check();
        final raw = await _storage.read(key: key);
        _check();
        if (raw == null) return {};
        try {
          if (utf8.encode(raw).length > 1024 * 1024) {
            throw const FormatException();
          }
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic> ||
              decoded['schema'] != 1 ||
              decoded['entries'] is! Map<String, dynamic>) {
            throw const FormatException();
          }
          final entries = <String, int>{};
          for (final entry
              in (decoded['entries'] as Map<String, dynamic>).entries) {
            if (entry.key.isEmpty ||
                entry.value is! int ||
                (entry.value as int) < 0) {
              throw const FormatException();
            }
            entries[entry.key] = entry.value as int;
          }
          return Map.unmodifiable(entries);
        } catch (_) {
          throw const FormatException('Invalid notification read store');
        }
      });

  @override
  Future<void> save(Map<String, int> readAtMillis) {
    final snapshot = Map<String, int>.unmodifiable(readAtMillis);
    return PreferenceOperationQueue.run(key, () async {
      _check();
      final raw = jsonEncode({'schema': 1, 'entries': snapshot});
      if (utf8.encode(raw).length > 1024 * 1024) {
        throw const FormatException('Notification read store too large');
      }
      await _storage.write(key: key, value: raw);
      _check();
    });
  }
}

class MemoryHomeNotificationReadStore implements HomeNotificationReadStore {
  Map<String, int> entries = {};
  @override
  Future<Map<String, int>> load() async => Map.of(entries);
  @override
  Future<void> save(Map<String, int> readAtMillis) async =>
      entries = Map.of(readAtMillis);
}

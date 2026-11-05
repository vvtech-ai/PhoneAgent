import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../../../../core/storage/preference_operation_queue.dart';

/// Device preference, not an account identity or overseas translation setting.
class SecureVoiceLanguageStore {
  SecureVoiceLanguageStore(
    String scope, {
    this.legacyRead,
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key =
           'phoneagent.voice-language.v1.${base64Url.encode(utf8.encode(scope))}' {
    if (scope.trim().isEmpty) {
      throw ArgumentError('Missing voice preference scope');
    }
  }
  final String key;
  final FlutterSecureStorage storage;
  final Future<String?> Function()? legacyRead;

  Future<String> read() => PreferenceOperationQueue.run(key, () async {
    final raw = await storage.read(key: key);
    if (raw != null) {
      if (!const {'zh-CN', 'en-US', 'ja-JP'}.contains(raw)) {
        throw const FormatException('Invalid voice language preference');
      }
      return raw;
    }
    final old = await legacyRead?.call();
    if (old == null) return 'zh-CN';
    final language = switch (old.trim().toLowerCase()) {
      'en' || 'en-us' => 'en-US',
      'ja' || 'jp' || 'ja-jp' => 'ja-JP',
      _ => 'zh-CN',
    };
    await storage.write(key: key, value: language);
    return language;
  });
}

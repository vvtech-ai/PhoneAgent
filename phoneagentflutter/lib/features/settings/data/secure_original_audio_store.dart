import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/original_audio_settings.dart';

class SecureOriginalAudioStore implements OriginalAudioStore {
  const SecureOriginalAudioStore(
    this.scope, {
    this.legacyRead,
    FlutterSecureStorage storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : _storage = storage;
  final String scope;
  final FlutterSecureStorage _storage;
  final Future<OriginalAudioSettings?> Function()? legacyRead;
  String get key =>
      'phoneagent.original-audio.v1.${base64Url.encode(utf8.encode(scope))}';
  @override
  Future<OriginalAudioSettings> read() =>
      PreferenceOperationQueue.run(key, () async {
        final raw = await _storage.read(key: key);
        if (raw != null) return OriginalAudioSettings.fromJson(jsonDecode(raw));
        final legacy = await legacyRead?.call();
        if (legacy == null) return const OriginalAudioSettings();
        await _storage.write(key: key, value: jsonEncode(legacy.toJson()));
        return legacy;
      });

  @override
  Future<void> write(OriginalAudioSettings value) =>
      PreferenceOperationQueue.run(
        key,
        () => _storage.write(key: key, value: jsonEncode(value.toJson())),
      );
}

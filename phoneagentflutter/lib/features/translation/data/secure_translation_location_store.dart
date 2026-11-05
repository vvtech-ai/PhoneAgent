import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/translation_location.dart';

class SecureTranslationLocationStore implements TranslationLocationStore {
  const SecureTranslationLocationStore(
    this.scope, {
    this.legacyRead,
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  });
  final String scope;
  final FlutterSecureStorage storage;
  final Future<TrustedTranslationLocation?> Function()? legacyRead;
  String get key =>
      'phoneagent.location.v1.${base64Url.encode(utf8.encode(scope))}';

  @override
  Future<TrustedTranslationLocation?> read() =>
      PreferenceOperationQueue.run(key, () async {
        final raw = await storage.read(key: key);
        if (raw == null) {
          final legacy = await legacyRead?.call();
          if (legacy != null) await _write(legacy);
          return legacy;
        }
        final value = jsonDecode(raw);
        if (value is! Map ||
            value['schema'] != 1 ||
            value['countryIso'] is! String ||
            value['sampledAtMs'] is! int) {
          throw const FormatException('Invalid location cache');
        }
        return TrustedTranslationLocation(
          value['countryIso'],
          value['sampledAtMs'],
        );
      });

  @override
  Future<void> write(TrustedTranslationLocation value) =>
      PreferenceOperationQueue.run(key, () => _write(value));

  Future<void> _write(TrustedTranslationLocation value) => storage.write(
    key: key,
    value: jsonEncode({
      'schema': 1,
      'countryIso': value.countryIso,
      'sampledAtMs': value.sampledAtMs,
    }),
  );
}

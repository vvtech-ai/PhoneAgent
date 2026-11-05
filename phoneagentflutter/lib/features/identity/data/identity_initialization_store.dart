import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/preference_operation_queue.dart';

/// v65 stores this preference per installation, not per login/account.
/// Environment isolation avoids a development skip affecting production.
class IdentityInitializationStore {
  IdentityInitializationStore(
    AppConfig config, {
    FlutterSecureStorage? storage,
    Future<bool?> Function()? legacyRead,
  }) : _key = keyFor(config),
       _legacyRead = legacyRead,
       _storage =
           storage ??
           const AppLocalStorage(
             preference: true,
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
           );

  final String _key;
  final FlutterSecureStorage _storage;
  final Future<bool?> Function()? _legacyRead;
  bool _skippedInMemory = false;

  static String keyFor(AppConfig config) {
    if (!config.isConfigured) throw StateError('Environment is not configured');
    final uri = config.apiBaseUri!;
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    final scope = '${config.environment!.name}|${uri.replace(path: path)}';
    return 'phoneagent.identity.init.v1.${base64Url.encode(utf8.encode(scope))}';
  }

  Future<bool> isSkipped() async {
    if (_skippedInMemory) return true;
    return PreferenceOperationQueue.run(_key, () async {
      final saved = await _storage.read(key: _key);
      if (saved != null) return _skippedInMemory || saved == 'true';
      final legacy = await _legacyRead?.call();
      if (legacy != null) {
        await _storage.write(key: _key, value: legacy.toString());
      }
      // A pending read must not reverse this instance's new skip decision.
      return _skippedInMemory || legacy == true;
    });
  }

  Future<void> markSkipped() async {
    _skippedInMemory = true;
    await PreferenceOperationQueue.run(
      _key,
      () => _storage.write(key: _key, value: 'true'),
    );
  }
}

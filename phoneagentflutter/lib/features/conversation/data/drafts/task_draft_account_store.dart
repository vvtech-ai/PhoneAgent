import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../../../../core/storage/preference_operation_queue.dart';

/// Orders account-bound draft operations across page and repository instances.
class TaskDraftAccountStore {
  TaskDraftAccountStore(
    List<String> scope, {
    this.storage = const AppLocalStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : scope = List.unmodifiable(scope),
       _indexKey = 'task.draft.index.${_hash(scope)}',
       _resetKey = 'task.draft.reset.${_hash(scope)}';

  final List<String> scope;
  final FlutterSecureStorage storage;
  final String _indexKey, _resetKey;
  static String _hash(List<String> scope) =>
      sha256.convert(utf8.encode(jsonEncode(scope))).toString();
  static String draftKey(List<String> scope) => 'task.draft.${_hash(scope)}';

  Future<Set<String>> _keys() async {
    final raw = await storage.read(key: _indexKey);
    return raw == null
        ? <String>{}
        : (jsonDecode(raw) as List).cast<String>().toSet();
  }

  Future<void> _saveKeys(Set<String> keys) =>
      storage.write(key: _indexKey, value: jsonEncode(keys.toList()));

  Future<String?> read(String key) => PreferenceOperationQueue.run(
    _indexKey,
    () async {
      final keys = await _keys();
      // Legacy keys were not indexed. After logout they must not reappear; new
      // saves explicitly register their keys, so they remain valid on re-login.
      if (!keys.contains(key) && await storage.read(key: _resetKey) != null) {
        await storage.delete(key: key);
        return null;
      }
      final raw = await storage.read(key: key);
      if (raw != null && keys.add(key)) await _saveKeys(keys);
      return raw;
    },
  );

  Future<void> save(String key, String? raw) =>
      PreferenceOperationQueue.run(_indexKey, () async {
        final keys = await _keys();
        if (raw == null) {
          await storage.delete(key: key);
          if (keys.remove(key)) await _saveKeys(keys);
        } else {
          if (keys.add(key)) await _saveKeys(keys);
          await storage.write(key: key, value: raw);
        }
      });

  Future<void> clearTask(String sessionId) =>
      save(draftKey([...scope, sessionId]), null);

  Future<void> clearAccount() =>
      PreferenceOperationQueue.run(_indexKey, () async {
        final keys = await _keys();
        await storage.write(key: _resetKey, value: '1');
        await _saveKeys({});
        for (final key in keys) {
          await storage.delete(key: key);
        }
      });
}

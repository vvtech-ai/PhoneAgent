import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/dial_permission_store.dart';

class SecureDialPermissionStore implements DialPermissionStore {
  const SecureDialPermissionStore(
    this.scope, {
    FlutterSecureStorage storage = const AppLocalStorage(preference: true),
  }) : _storage = storage;
  final String scope;
  final FlutterSecureStorage _storage;
  String get _key =>
      'phoneagent.dial-permission.v1.${base64Url.encode(utf8.encode(scope))}';

  @override
  Future<DialPermissionFlags> read() =>
      PreferenceOperationQueue.run(_key, () async {
        final raw = await _storage.read(key: _key);
        final value = raw == null ? null : jsonDecode(raw);
        return (
          locationShown: value is Map && value['locationShown'] == true,
          locationRequested: value is Map && value['locationRequested'] == true,
          callLogRequested: value is Map && value['callLogRequested'] == true,
        );
      });

  @override
  Future<void> write(DialPermissionFlags flags) => PreferenceOperationQueue.run(
    _key,
    () => _storage.write(
      key: _key,
      value: jsonEncode({
        'locationShown': flags.locationShown,
        'locationRequested': flags.locationRequested,
        'callLogRequested': flags.callLogRequested,
      }),
    ),
  );
}

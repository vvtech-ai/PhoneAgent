import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/apple_cancellation_outbox.dart';

class SecureAppleCancellationStore implements AppleCancellationStore {
  SecureAppleCancellationStore({
    required String scope,
    required this.isCurrent,
    this.storage = const AppLocalStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key =
           'phoneagent.apple-cancel-pending.v1.${sha256.convert(utf8.encode(scope))}';
  final String key;
  final bool Function() isCurrent;
  final FlutterSecureStorage storage;
  void _guard() {
    if (!isCurrent()) throw StateError('Cancellation owner changed');
  }

  Future<T> _run<T>(Future<T> Function(Map<String, String>) action) =>
      PreferenceOperationQueue.run(key, () async {
        _guard();
        final raw = await storage.read(key: key);
        _guard();
        final Map<String, String> values;
        if (raw == null) {
          values = {};
        } else {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          if (decoded['schema'] != 1) {
            throw const FormatException('Cancellation schema');
          }
          values = Map<String, String>.from(decoded['pending'] as Map);
          if (values.entries.any((e) => e.key.isEmpty || e.value.isEmpty)) {
            throw const FormatException('Cancellation identity');
          }
        }
        return action(values);
      });
  Future<void> _write(Map<String, String> values) async {
    _guard();
    await storage.write(
      key: key,
      value: jsonEncode({'schema': 1, 'pending': values}),
    );
    _guard();
  }

  @override
  Future<Map<String, String>> read() => _run((v) async => Map.of(v));
  @override
  Future<void> remember(String no, String id) => _run((v) async {
    if (v.containsKey(no)) return;
    v[no] = id;
    await _write(v);
  });
  @override
  Future<void> remove(String no) => _run((v) async {
    if (v.remove(no) != null) await _write(v);
  });
}

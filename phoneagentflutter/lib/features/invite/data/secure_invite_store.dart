import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../domain/invite_store.dart';
import '../domain/invite.dart';

class SecureInviteStore implements InviteStore {
  SecureInviteStore(String scope, {FlutterSecureStorage? storage})
    : _prefix = 'invite.v1.${sha256.convert(utf8.encode(scope))}',
      _storage = storage ?? const AppLocalStorage();
  final String _prefix;
  final FlutterSecureStorage _storage;
  Future<void> _tail = Future.value();
  String _key(String slot) => '$_prefix.${sha256.convert(utf8.encode(slot))}';
  @override
  Future<Map<String, dynamic>> read(String slot) async {
    await _tail;
    final text = await _storage.read(key: _key(slot));
    if (text == null) return {};
    try {
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic>) throw const InviteFailure('STORAGE');
      return value;
    } on FormatException {
      throw const InviteFailure('STORAGE');
    }
  }

  @override
  Future<void> write(String slot, Map<String, dynamic> value) {
    final encoded = jsonEncode(value);
    final next = _tail.then(
      (_) => _storage.write(key: _key(slot), value: encoded),
    );
    _tail = next.catchError((Object _) {});
    return next;
  }
}

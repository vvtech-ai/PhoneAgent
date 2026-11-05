import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../domain/call_admission.dart';

class SecureCallAdmissionNoticeStore implements CallAdmissionNoticeStore {
  SecureCallAdmissionNoticeStore({
    required String environment,
    required String accountId,
    this.legacyRead,
    this.isCurrent,
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
    FlutterSecureStorage storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : _scope = [environment, accountId],
       _read = read ?? ((key) => storage.read(key: key)),
       _write =
           write ?? ((key, value) => storage.write(key: key, value: value)) {
    if (_scope.any((part) => part.trim().isEmpty)) {
      throw ArgumentError('Missing notice store owner');
    }
  }
  final List<String> _scope;
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  final Future<Set<String>> Function(String, Iterable<String>)? legacyRead;
  final bool Function()? isCurrent;

  void _guard() {
    if (isCurrent?.call() == false) throw StateError('Notice owner changed');
  }

  Iterable<String> _keys(String sessionId, Iterable<String> aliases) {
    if (sessionId.trim().isEmpty) throw ArgumentError('Missing session');
    final values = aliases.toSet();
    if (values.isEmpty || values.any((alias) => alias.trim().isEmpty)) {
      throw ArgumentError('Missing confirmation identity');
    }
    // JSON framing prevents delimiter collisions; only the digest reaches disk.
    return values.map((alias) {
      final hash = sha256.convert(
        utf8.encode(jsonEncode([..._scope, sessionId, alias])),
      );
      return 'phoneagent.call-admission.v1.$hash';
    });
  }

  @override
  Future<bool> wasNotified(String sessionId, Iterable<String> aliases) async {
    _guard();
    final values = aliases.toSet().toList();
    final keys = _keys(sessionId, values).toList();
    final missing = <String>[];
    for (var index = 0; index < keys.length; index++) {
      final raw = await _read(keys[index]);
      _guard();
      if (raw == '1') return true;
      // Preserve existing interpretation of present non-1 values; never let
      // an old marker replace any present new value.
      if (raw == null) missing.add(values[index]);
    }
    if (missing.isEmpty || legacyRead == null) return false;
    final found = await legacyRead!(sessionId, missing);
    _guard();
    if (found.any((alias) => !missing.contains(alias))) {
      throw const FormatException('Foreign legacy marker');
    }
    if (found.isEmpty) return false;
    await markNotified(sessionId, found);
    return true;
  }

  @override
  Future<void> markNotified(String sessionId, Iterable<String> aliases) async {
    // Per-alias keys avoid concurrent read/modify/write dropping other notices.
    for (final key in _keys(sessionId, aliases)) {
      _guard();
      await _write(key, '1');
      _guard();
    }
  }
}

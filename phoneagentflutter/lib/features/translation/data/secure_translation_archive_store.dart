import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../domain/translation_archive.dart';
import 'translation_archive_codec.dart';

class SecureTranslationArchiveStore implements TranslationArchiveStore {
  SecureTranslationArchiveStore({
    required String environment,
    required String apiBase,
    required this.accountId,
    required this.isCurrent,
    this.legacyRead,
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : scope = sha256
           .convert(utf8.encode(jsonEncode([environment, apiBase, accountId])))
           .toString(),
       _read = read ?? ((key) => _storage.read(key: key)),
       _write =
           write ?? ((key, value) => _storage.write(key: key, value: value)) {
    if ([environment, apiBase, accountId].any((item) => item.trim().isEmpty)) {
      throw ArgumentError('Missing archive scope');
    }
  }
  static const _storage = AppLocalStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  final String scope, accountId;
  final bool Function() isCurrent;
  final Future<List<TranslationArchiveEntry>?> Function()? legacyRead;
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  static final _tails = <String, Future<void>>{};
  String get key => 'phoneagent.translation-archive.v1.$scope';
  void _guard() {
    if (!isCurrent()) throw StateError('Archive owner changed');
  }

  @override
  Future<List<TranslationArchiveEntry>> load() => _serial(_load);
  Future<List<TranslationArchiveEntry>> _load() async {
    _guard();
    final raw = await _read(key);
    _guard();
    if (raw != null || legacyRead == null) {
      return TranslationArchiveCodec.decode(scope, accountId, raw);
    }
    final old = await legacyRead!();
    _guard();
    if (old == null) return [];
    final migrated = TranslationArchiveCodec.encode(scope, accountId, old);
    await _write(key, migrated);
    _guard();
    return old;
  }

  @override
  Future<void> save(List<TranslationArchiveEntry> entries) => _serial(() async {
    _guard();
    // Corrupt/foreign-version data is never overwritten by an ordinary retry.
    await _load();
    final raw = TranslationArchiveCodec.encode(scope, accountId, entries);
    _guard();
    await _write(key, raw);
    _guard();
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = (_tails[key] ?? Future<void>.value()).then((_) {
      _guard();
      return action();
    });
    late final Future<void> tail;
    tail = next
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() {
          if (identical(_tails[key], tail)) _tails.remove(key);
        });
    _tails[key] = tail;
    return next;
  }
}

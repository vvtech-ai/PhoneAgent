import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../domain/app_call_record_repository.dart';
import '../domain/dial_recent_call.dart';
import 'app_call_record_codec.dart';

class SecureAppCallRecordRepository implements AppCallRecordRepository {
  SecureAppCallRecordRepository({
    required String environment,
    required String apiBase,
    required String accountId,
    required this.isCurrent,
    this.readLegacy,
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : scope = _scope(environment, apiBase, accountId),
       _read = read ?? ((key) => _storage.read(key: key)),
       _write =
           write ?? ((key, value) => _storage.write(key: key, value: value));
  static const _storage = AppLocalStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  final String scope;
  final bool Function() isCurrent;
  final Future<List<DialRecentCall>> Function()? readLegacy;
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  static final _tails = <String, Future<void>>{};
  final _changes = StreamController<void>.broadcast();
  bool _closed = false;
  String get key => 'phoneagent.app-call-records.v1.$scope';
  static String _scope(String environment, String api, String account) {
    if ([environment, api, account].any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Missing call record owner');
    }
    return sha256
        .convert(utf8.encode(jsonEncode([environment, api, account])))
        .toString();
  }

  void _guard() {
    if (_closed || !isCurrent()) throw const AppCallRecordFailure('closed');
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = (_tails[key] ?? Future<void>.value()).then((_) async {
      _guard();
      try {
        return await action();
      } on AppCallRecordFailure {
        rethrow;
      } catch (_) {
        throw const AppCallRecordFailure('storage');
      }
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

  Future<List<DialRecentCall>> _load() async {
    final raw = await _read(key);
    _guard();
    if (raw == null && readLegacy != null) {
      final imported = await readLegacy!();
      _guard();
      // An empty v1 envelope also marks migration complete. Never delete it
      // during clear: otherwise the untouched legacy source could reappear.
      await _save(imported);
      return List.unmodifiable(imported);
    }
    return AppCallRecordCodec.decode(scope, raw);
  }

  Future<void> _save(List<DialRecentCall> records) async {
    final raw = AppCallRecordCodec.encode(scope, records);
    _guard();
    await _write(key, raw);
    _guard();
    _changes.add(null);
  }

  @override
  Future<List<DialRecentCall>> load() => _serial(_load);
  @override
  Future<void> append(DialRecentCall record) => _serial(() async {
    AppCallRecordCodec.encode(scope, [record]);
    final current = await _load();
    if (current.any(
      (item) => item.id == record.id && item.kind == record.kind,
    )) {
      return;
    }
    await _save([record, ...current]);
  });
  @override
  Future<void> clear() => _serial(() async {
    // Do not overwrite corrupt or unknown-schema data under an ordinary action.
    await _load();
    await _save(const []);
  });
  @override
  Stream<void> get changes => _changes.stream;
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_changes.close());
  }
}

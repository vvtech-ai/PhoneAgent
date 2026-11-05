import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../domain/app_update.dart';
import '../domain/startup_update.dart';

/// Device update policy, not account profile. URLs/headers are never stored.
class SecureStartupUpdateStore implements StartupUpdateStore {
  const SecureStartupUpdateStore(
    this.scope, {
    FlutterSecureStorage storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;
  final String scope;
  final FlutterSecureStorage _storage;
  static final _tails = <String, Future<void>>{};
  Future<T> _serial<T>(InstalledApp app, Future<T> Function() operation) async {
    final key = _key(app);
    final previous = _tails[key] ?? Future<void>.value();
    final done = Completer<void>();
    _tails[key] = done.future;
    try {
      await previous;
      return await operation();
    } finally {
      done.complete();
      if (identical(_tails[key], done.future)) _tails.remove(key);
    }
  }

  String _key(InstalledApp app) =>
      'phoneagent.ota-startup.v1.${sha256.convert(utf8.encode(jsonEncode([scope, app.packageName])))}';
  @override
  Future<StartupUpdateRecord> read(InstalledApp app) => _serial(app, () async {
    final raw = await _storage.read(key: _key(app));
    if (raw == null) return const StartupUpdateRecord();
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['v'] != 1 ||
        data['force'] is! bool ||
        (data['day'] != null &&
            (data['day'] is! String ||
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(data['day'])))) {
      throw const FormatException('Invalid update policy record');
    }
    return StartupUpdateRecord(
      lastSuccessDate: data['day'],
      forceRequired: data['force'],
    );
  });
  @override
  Future<void> write(InstalledApp app, StartupUpdateRecord record) => _serial(
    app,
    () => _storage.write(
      key: _key(app),
      value: jsonEncode({
        'v': 1,
        'day': record.lastSuccessDate,
        'force': record.forceRequired,
      }),
    ),
  );
}

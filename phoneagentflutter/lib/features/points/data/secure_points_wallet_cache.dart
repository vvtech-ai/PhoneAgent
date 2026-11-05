import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../domain/points_wallet_cache.dart';
import 'points_wallet_cache_codec.dart';

class SecurePointsWalletCache implements PointsWalletCache {
  SecurePointsWalletCache({
    required String environment,
    required String apiBase,
    required String accountId,
    required this.isCurrent,
    FlutterSecureStorage storage = const AppLocalStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : _storage = storage,
       _scope = _scopeFor(environment, apiBase, accountId);
  final FlutterSecureStorage _storage;
  final String _scope;
  final bool Function() isCurrent;
  static final _tails = <String, Future<void>>{};
  String get _key => 'phoneagent.points-wallet.v1.$_scope';
  static String _scopeFor(
    String environment,
    String apiBase,
    String accountId,
  ) {
    final parts = [environment, apiBase, accountId];
    if (parts.any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Missing wallet owner');
    }
    return sha256.convert(utf8.encode(jsonEncode(parts))).toString();
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final next = (_tails[_key] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    late final Future<void> tail;
    tail = next
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() {
          if (identical(_tails[_key], tail)) _tails.remove(_key);
        });
    _tails[_key] = tail;
    return next;
  }

  @override
  Future<PointsWalletSnapshot?> read() => _serial(() async {
    if (!isCurrent()) return null;
    final raw = await _storage.read(key: _key);
    if (!isCurrent()) return null;
    return PointsWalletCacheCodec.decode(_scope, raw);
  });
  @override
  Future<void> write(PointsWalletSnapshot snapshot) => _serial(() async {
    if (!isCurrent()) return;
    final encoded = PointsWalletCacheCodec.encode(_scope, snapshot);
    if (!isCurrent()) return;
    await _storage.write(key: _key, value: encoded);
  });
}

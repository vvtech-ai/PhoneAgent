import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/service_routes.dart';
import '../../../core/network/signing/c1_transport.dart';
import '../domain/home_config.dart';
import 'home_config_mapper.dart';
import '../domain/home_defaults.dart';

abstract interface class HomeLocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureHomeLocalStore implements HomeLocalStore {
  SecureHomeLocalStore(this.namespace);
  final String namespace;
  final _storage = const AppLocalStorage(
    preference: true,
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: '$namespace.$key');
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$namespace.$key', value: value);
}

class DioHomeRepository implements HomeRepository, HomeRepositoryStatus {
  DioHomeRepository(AppConfig config, this._store, {Dio? client, this.signing})
    : _base = config.sdkApiBaseUri ?? config.apiBaseUri,
      _client = client ?? Dio() {
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.json,
    );
  }
  final Uri? _base;
  final Dio _client;
  final HomeLocalStore _store;
  final C1Transport? signing;
  @override
  bool loadFailed = false;
  bool _closed = false;
  Future<void>? _refreshing;
  Map<String, dynamic>? _cachedDocument;
  void close() {
    _closed = true;
    _client.close(force: true);
  }

  @override
  Future<HomeConfig> load() async {
    final base = _base;
    if (base == null || _closed) return builtinHome;
    final mapper = HomeConfigMapper(base);
    Map<String, dynamic>? cache;
    HomeConfig snapshot = builtinHome;
    try {
      final raw = await _store.read('published');
      if (raw != null) {
        cache = HomeConfigMapper.object(jsonDecode(raw));
        snapshot = mapper.parse(HomeConfigMapper.object(cache['data']));
      }
    } catch (_) {
      cache = null;
    }
    _cachedDocument = cache;
    unawaited(refreshPublished());
    return snapshot;
  }

  /// Refreshes the persisted snapshot; callers keep their current entry frozen.
  Future<void> refreshPublished() {
    final base = _base;
    if (_closed || base == null) return Future<void>.value();
    return _refreshing ??= _refreshPublished(
      base,
      _cachedDocument,
    ).whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshPublished(Uri base, Map<String, dynamic>? cache) async {
    loadFailed = false;
    final mapper = HomeConfigMapper(base);
    try {
      final url = base
          .replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/')
          .resolve('api/home-config/published');
      final signed = await signing?.prepare(
        url,
        service: ApiService.sdk,
        method: 'GET',
        token: '',
      );
      if (_closed) return;
      final response = await _client.getUri<Object?>(
        url,
        options: Options(
          headers: {
            ...?signed?.$2,
            if (cache?['etag'] is String) 'If-None-Match': cache!['etag'],
          },
        ),
      );
      if (_closed) return;
      if (response.statusCode == 304 && cache != null) {
        return;
      }
      if (response.statusCode != 200) {
        loadFailed = true;
        return;
      }
      final data = HomeConfigMapper.object(AccountApi.unwrap(response.data));
      mapper.parse(data);
      try {
        await _store.write(
          'published',
          jsonEncode({'data': data, 'etag': response.headers.value('etag')}),
        );
      } catch (_) {
        /* Keep the current snapshot if background cache persistence fails. */
      }
    } catch (_) {
      if (!_closed) loadFailed = true;
    }
  }

  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async {
    var index = 0;
    try {
      final raw = await _store.read('slogan');
      final saved = raw == null ? null : jsonDecode(raw);
      if (saved is Map &&
          saved['version'] == config.version &&
          saved['index'] is int) {
        index = (saved['index'] as int) % config.slogans.length;
      }
      await _store.write(
        'slogan',
        jsonEncode({
          'version': config.version,
          'index': (index + 1) % config.slogans.length,
        }),
      );
    } catch (_) {
      /* Rotation persistence is not required for entry availability. */
    }
    return config.slogans[index];
  }
}

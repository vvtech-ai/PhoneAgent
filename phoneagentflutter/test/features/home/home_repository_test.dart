import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/home/data/dio_home_repository.dart';
import 'package:phone_agent/features/home/data/home_config_mapper.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

Map<String, dynamic> fixture() => {
  'version': 'home-config-v1',
  'configId': 'synthetic',
  'configVersion': 'v1',
  'publicationStatus': 'published',
  'skillRefs': [
    {'id': 'test_skill', 'opening': '配置中的正式开场'},
  ],
  'home': {
    'slogans': [
      {
        'id': 's',
        'line1': '测试任务',
        'line2': '测试文案',
        'status': 'enabled',
        'sortOrder': 1,
      },
    ],
    'cards': [
      {
        'id': 'c',
        'title': '测试',
        'subtitle': '测试入口',
        'status': 'enabled',
        'sortOrder': 1,
        'entryAction': {'type': 'openSkill', 'skillId': 'test_skill'},
        'backgroundImage': {
          'assetId': 'a-1',
          'url': '/api/home-config/assets/a-1',
        },
      },
    ],
  },
};

class _Signing implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async => const C1Credentials(
    apiKey: 'public-fixture',
    secret: 'public-secret',
    clientContext: 'e30',
    deviceId: '33333333-3333-4333-8333-333333333333',
  );
}

class _Store implements HomeLocalStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

class _Adapter implements HttpClientAdapter {
  int status = 200;
  Map<String, dynamic>? data;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data ?? fixture()}),
      status,
      headers: {
        'etag': ['synthetic-etag'],
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('published cloud asset does not cause homepage fallback', () async {
    const cloud =
        'https://cdn.chaken.net.cn/home-config/assets/2026/09/a-1.png';
    final data = fixture();
    data['home']['cards'][0]['backgroundImage']['url'] = cloud;
    final adapter = _Adapter()..data = data;
    final store = _Store();
    final repository = DioHomeRepository(
      AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test/'),
      store,
      client: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(repository.close);
    expect((await repository.load()).builtin, true);
    await repository.refreshPublished();
    final home = await repository.load();
    expect(home.builtin, false);
    expect(home.cards.single.imageUrl, cloud);
    expect(repository.loadFailed, false);
  });
  test('published config signs SDK GET without account credentials', () async {
    final adapter = _Adapter();
    final store = _Store();
    final repository = DioHomeRepository(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api',
        sdkApiBaseUrl: 'https://example.test/aiassistant-sdk-api',
      ),
      store,
      client: Dio()..httpClientAdapter = adapter,
      signing: C1Transport(_Signing()),
    );
    expect((await repository.load()).builtin, true);
    await repository.refreshPublished();
    expect((await repository.load()).version, 'v1');
    expect(
      adapter.requests.single.uri.path,
      '/aiassistant-sdk-api/api/home-config/published',
    );
    expect(
      adapter.requests.single.headers['X-Sign'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    expect(adapter.requests.single.headers['Authorization'], isNull);
    repository.close();
  });
  final mapper = HomeConfigMapper(
    Uri.parse('https://example.test/aiassistant-api/'),
  );
  test('complete ordinary opening and asset prefix are preserved', () {
    final config = mapper.parse(fixture());
    expect(
      config.cards.single.imageUrl,
      'https://example.test/aiassistant-api/api/home-config/assets/a-1',
    );
    expect(config.cards.single.opening, '配置中的正式开场');
    expect(config.cards.single.canEnter('1.0.0'), true);
  });
  test('unknown status hidden, minimum version exact contract enforced', () {
    final data = fixture();
    final card = data['home']['cards'][0] as Map;
    card['minClientVersion'] = '65.0.0';
    expect(mapper.parse(data).cards.single.canEnter('1.0.0'), false);
    expect(mapper.parse(data).cards.single.supports('65.0.0-debug'), true);
    card['status'] = 'future';
    expect(mapper.parse(data).cards.single.status, HomeCardStatus.disabled);
  });
  test(
    'unpublished duplicate order invalid action and unsafe assets fail closed',
    () {
      final unpublished = fixture()..['publicationStatus'] = 'draft';
      expect(() => mapper.parse(unpublished), throwsFormatException);
      final duplicate = fixture();
      duplicate['home']['cards'].add(duplicate['home']['cards'][0]);
      expect(() => mapper.parse(duplicate), throwsFormatException);
      for (final url in [
        'https://user:password@other.test/a',
        'https://other.test/a#fragment',
        'http://other.test/a',
        '/api/home-config/assets/another-id',
      ]) {
        final unsafe = fixture();
        unsafe['home']['cards'][0]['backgroundImage']['url'] = url;
        expect(() => mapper.parse(unsafe), throwsFormatException);
      }
      final action = fixture();
      action['home']['cards'][0]['entryAction']['type'] = 'unknown';
      expect(() => mapper.parse(action), throwsFormatException);
    },
  );
  test(
    '200 refreshes next snapshot, 304 revalidates, failure preserves valid cache',
    () async {
      final store = _Store(), adapter = _Adapter();
      final repository = DioHomeRepository(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/aiassistant-api/',
        ),
        store,
        client: Dio()..httpClientAdapter = adapter,
      );
      expect((await repository.load()).builtin, true);
      await repository.refreshPublished();
      adapter.status = 304;
      expect((await repository.load()).version, 'v1');
      await repository.refreshPublished();
      expect(adapter.requests.last.headers['If-None-Match'], 'synthetic-etag');
      expect(adapter.requests.last.headers['Authorization'], isNull);
      adapter.status = 500;
      expect((await repository.load()).version, 'v1');
      await repository.refreshPublished();
      expect(repository.loadFailed, true);
      expect(
        jsonDecode(store.data['published']!)['data']['configVersion'],
        'v1',
      );
    },
  );
  test(
    'slogan rotates between sessions and resets on config version',
    () async {
      final repository = DioHomeRepository(
        AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
        _Store(),
      );
      const slogans = [HomeSlogan('1', '一', 'a'), HomeSlogan('2', '二', 'b')];
      const config = HomeConfig('v1', slogans, []);
      expect((await repository.nextSlogan(config)).id, '1');
      expect((await repository.nextSlogan(config)).id, '2');
      expect(
        (await repository.nextSlogan(const HomeConfig('v2', slogans, []))).id,
        '1',
      );
    },
  );
}

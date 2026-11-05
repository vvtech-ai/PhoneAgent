import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/app_update/data/api_app_update_repository.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';

void main() {
  const installed = InstalledApp('com.example.preview', '1.0.0', 1);
  late _Adapter adapter;
  late AccountApi api;
  late ApiAppUpdateRepository repository;
  setUp(() {
    adapter = _Adapter();
    api = AccountApi(
      AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test/'),
      _Session(),
      client: Dio()..httpClientAdapter = adapter,
    );
    repository = ApiAppUpdateRepository(api, accountId: 'a', channel: 'dev');
  });
  tearDown(() => api.close());
  test(
    'uses installed identity and v65 POST contract, not production constants',
    () async {
      final result = await repository.check(installed);
      expect(result.hasUpdate, true);
      expect(result.forceUpdate, true);
      expect(result.versionCode, 2);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/ota/check');
      expect(request.data, {
        'packageName': installed.packageName,
        'currentVersionName': '1.0.0',
        'currentVersionCode': 1,
        'sourceType': 0,
        'deviceId': 'a',
        'channel': 'dev',
      });
      expect(
        request.headers.keys.any((k) => k.toLowerCase() == 'authorization'),
        false,
      );
    },
  );
  group('iOS', () {
    setUp(() {
      repository = ApiAppUpdateRepository(
        api,
        accountId: 'a',
        channel: 'test',
        sourceType: 1,
      );
      adapter.data['sourceType'] = 1;
      adapter.data['iosSourceUrl'] =
          'itms-apps://apps.apple.com/app/id6813455647';
    });
    test(
      'sends platform and returns distribution link without APK data',
      () async {
        final result = await repository.check(installed);
        expect((adapter.requests.single.data as Map)['sourceType'], 1);
        expect(result.sourceType, 1);
        expect(
          result.iosSourceUrl,
          'itms-apps://apps.apple.com/app/id6813455647',
        );
        expect(result.apkUrl, isEmpty);
        expect(result.fileSize, isNull);
      },
    );
    for (final empty in [null, '', '  ']) {
      test('empty iOS URL $empty uses fixed store, never apkUrl', () async {
        adapter.data['iosSourceUrl'] = empty;
        adapter.data['apkUrl'] = 'https://other.invalid/ignored.apk';
        expect(
          (await repository.check(installed)).iosSourceUrl,
          'https://apps.apple.com/app/id6813455647',
        );
      });
    }
    test('no update never retains fallback or force flag', () async {
      adapter.data['hasUpdate'] = false;
      final result = await repository.check(installed);
      expect(result.iosSourceUrl, isEmpty);
      expect(result.forceUpdate, false);
    });
    test('rejects mismatched Android response', () async {
      adapter.data['sourceType'] = 0;
      await expectLater(
        repository.check(installed),
        throwsA(ApiFailure.invalidResponse),
      );
    });
    test(
      'malformed nonempty link fails instead of hiding it with fallback',
      () async {
        adapter.data['iosSourceUrl'] = 'file:///tmp/app.ipa';
        await expectLater(repository.check(installed), throwsFormatException);
      },
    );
  });
  test(
    'no update does not retain force flag or stale download metadata',
    () async {
      adapter.data['hasUpdate'] = false;
      final result = await repository.check(installed);
      expect(result.hasUpdate, false);
      expect(result.forceUpdate, false);
      expect(result.apkUrl, isEmpty);
    },
  );
  for (final invalid in <String, Object?>{
    'packageName': 'com.example.other',
    'hasUpdate': 'true',
    'forceUpdate': 'false',
    'versionCode': 0,
    'versionName': '',
    'apkUrl': 'file:///tmp/update.apk',
    'checksumSha256': 'invalid',
    'fileSize': -1,
    'downloadHeaders': {'X-Test': 'a\r\nb'},
  }.entries) {
    test('rejects malformed ${invalid.key} without retry', () async {
      adapter.data[invalid.key] = invalid.value;
      await expectLater(
        repository.check(installed),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(adapter.requests, hasLength(1));
    });
  }
  test('invalid installed identity never sends a request', () async {
    await expectLater(
      repository.check(const InstalledApp('', '', 0)),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(adapter.requests, isEmpty);
  });
  for (final current in [45, 2026101513]) {
    test('accepts backend update 45 with installed code $current', () async {
      adapter.data['versionCode'] = 45;
      final result = await repository.check(
        InstalledApp(installed.packageName, '1.0.52', current),
      );
      expect(result.hasUpdate, isTrue);
      expect(result.versionCode, 45);
    });
  }
}

class _Session implements AccountSession {
  @override
  AccountCredentials? get credentials =>
      const AccountCredentials('a', 'synthetic', 1);
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final data = <String, Object?>{
    'hasUpdate': true,
    'packageName': 'com.example.preview',
    'forceUpdate': true,
    'versionName': '1.1.0',
    'versionCode': 2,
    'apkUrl': 'https://example.test/update.apk',
    'fileSize': 1024,
    'releaseNotes': 'Synthetic release',
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

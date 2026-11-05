import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/config/translation_service_config.dart';
import 'package:phone_agent/features/translation/data/http_translation_catalog_repository.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';

class _Http implements HttpClientAdapter {
  Object? body = {
    'languages': [
      {'code': 'zh-CN', 'label': '中文'},
      {'code': ' en-US ', 'label': ''},
      {'code': 'ZH-cn', 'label': 'duplicate'},
      {'code': ''},
      1,
    ],
  };
  int status = 200;
  bool offline = false;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (offline) throw DioException(requestOptions: options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('catalog HTTP rejection diagnostics retain stage and status', () async {
    final events = <DiagnosticEvent>[];
    final http = _Http()..status = 503;
    final repo = HttpTranslationCatalogRepository(
      (_) => Uri.parse('https://example.test/'),
      client: Dio()..httpClientAdapter = http,
      diagnostics: events.add,
    );
    addTearDown(repo.close);
    await expectLater(
      repo.load('US'),
      throwsA(TranslationCatalogFailure.rejected),
    );
    expect(events.single.statusCode, 503);
    expect(events.single.translation!.stage, 'overseasLanguages');
    expect(events.single.translation!.code, 'CATALOG_REJECTED');
  });

  test('fixed v65 endpoints and explicit empty-region fallback', () {
    final dev = TranslationServiceConfig.forEnvironment(AppEnvironment.dev);
    final prod = TranslationServiceConfig.forEnvironment(AppEnvironment.prod);
    expect(dev.resolve('DEFAULT').host, 'translate-us-webrtc.vvtech.tech');
    expect(dev.resolve('US').host, 'translate-test-us-webrtc.vvtech.tech');
    expect(dev.resolve('JP').host, 'translate-test-jp-webrtc.vvtech.tech');
    expect(prod.resolve('DEFAULT'), dev.resolve('US'));
    expect(
      TranslationServiceConfig.forEnvironment(
        AppEnvironment.dev,
        usUrl: '',
      ).resolve('US'),
      dev.resolve('DEFAULT'),
    );
    expect(() => dev.resolve('CN'), throwsFormatException);
  });
  test('invalid endpoint never silently falls back or accepts credentials', () {
    for (final value in [
      'http://example.test',
      'https://u:p@example.test',
      'https://example.test/?key=secret',
      'https://example.test/#fragment',
      'bad',
    ]) {
      final config = TranslationServiceConfig.forEnvironment(
        AppEnvironment.dev,
        usUrl: value,
      );
      expect(() => config.resolve('US'), throwsFormatException);
    }
  });
  test(
    'raw public GET catalog, normalization and no account credentials',
    () async {
      final http = _Http();
      final repo = HttpTranslationCatalogRepository(
        (_) => Uri.parse('https://example.test/base/'),
        client: Dio()..httpClientAdapter = http,
      );
      addTearDown(repo.close);
      final catalog = await repo.load('US');
      expect(catalog.languages.map((e) => e.code), ['zh-CN', 'en-US']);
      expect(catalog.languages.last.label, 'en-US');
      final request = http.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/base/api/app-translation-calls/languages');
      expect(request.data, isNull);
      expect(
        request.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        request.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('x-account-id')),
      );
      expect(request.followRedirects, isFalse);
    },
  );
  test(
    'malformed, rejection and network failures stay explicit, no retries',
    () async {
      final http = _Http();
      final repo = HttpTranslationCatalogRepository(
        (_) => Uri.parse('https://example.test/'),
        client: Dio()..httpClientAdapter = http,
      );
      addTearDown(repo.close);
      for (final value in [
        null,
        [],
        {
          'code': 0,
          'data': {'languages': []},
        },
        {'languages': 4},
      ]) {
        http.body = value;
        await expectLater(
          repo.load('US'),
          throwsA(TranslationCatalogFailure.invalidResponse),
        );
      }
      http.status = 403;
      await expectLater(
        repo.load('US'),
        throwsA(TranslationCatalogFailure.rejected),
      );
      http.offline = true;
      await expectLater(
        repo.load('US'),
        throwsA(TranslationCatalogFailure.network),
      );
      expect(http.requests, hasLength(6));
    },
  );
  test(
    'empty valid catalog is not fabricated; close prevents further IO',
    () async {
      final http = _Http()..body = {'languages': []};
      final repo = HttpTranslationCatalogRepository(
        (_) => Uri.parse('https://example.test/'),
        client: Dio()..httpClientAdapter = http,
      );
      expect((await repo.load('US')).languages, isEmpty);
      repo.close();
      await expectLater(
        repo.load('US'),
        throwsA(TranslationCatalogFailure.unavailable),
      );
      expect(http.requests, hasLength(1));
    },
  );
}

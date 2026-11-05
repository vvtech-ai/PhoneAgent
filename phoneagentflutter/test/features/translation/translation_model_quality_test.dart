import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_quality_providers.dart';
import 'package:phone_agent/features/translation/data/http_translation_model_probe.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';

class _Http implements HttpClientAdapter {
  int status = 200;
  bool offline = false, closed = false;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    request = options;
    if (offline) throw DioException(requestOptions: options);
    return ResponseBody.fromString('not a language catalog', status);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

class _Probe implements TranslationModelProbe {
  final calls = <String>[];
  final pending = <Completer<TranslationModelSample>>[];
  @override
  Future<TranslationModelSample> sample(String region) {
    calls.add(region);
    final gate = Completer<TranslationModelSample>();
    pending.add(gate);
    return gate.future;
  }
}

void main() {
  test(
    'domestic probe uses exact public entry and no auth/body download',
    () async {
      final http = _Http()..status = 401;
      final probe = HttpTranslationModelProbe(
        (_) => Uri.parse('https://example.test/realtime'),
        catalogPath: false,
        client: Dio()..httpClientAdapter = http,
      );
      expect((await probe.sample('QWEN')).latencyMs, isNonNegative);
      expect(http.request!.path, 'https://example.test/realtime');
      expect(http.request!.headers['Range'], 'bytes=0-0');
      expect(http.request!.headers['Connection'], 'close');
      expect(http.request!.headers.containsKey('Authorization'), false);
      expect(http.request!.responseType, ResponseType.stream);
      probe.close();
    },
  );
  test('quality has v65 exact 200/500 boundaries and rejects negative', () {
    for (final pair in {
      -1: TranslationQuality.unavailable,
      0: TranslationQuality.good,
      199: TranslationQuality.good,
      200: TranslationQuality.fair,
      499: TranslationQuality.fair,
      500: TranslationQuality.high,
    }.entries) {
      expect(TranslationModelSample.reachable(pair.key).quality, pair.value);
    }
  });
  test(
    'public GET headers/timeouts and non-JSON 4xx are reachability only',
    () async {
      final http = _Http();
      final probe = HttpTranslationModelProbe(
        (_) => Uri.parse('https://example.test/'),
        client: Dio()..httpClientAdapter = http,
      );
      for (final status in [200, 302, 401, 404, 499]) {
        http.status = status;
        expect((await probe.sample('US')).latencyMs, isNonNegative);
      }
      expect(http.request!.method, 'GET');
      expect(
        http.request!.path,
        'https://example.test/api/app-translation-calls/languages',
      );
      expect(http.request!.followRedirects, false);
      expect(http.request!.connectTimeout, const Duration(milliseconds: 2500));
      expect(http.request!.headers.containsKey('Authorization'), false);
      expect(http.request!.headers.containsKey('x-user-id'), false);
      probe.close();
      expect(http.closed, true);
      expect(
        (await probe.sample('US')).quality,
        TranslationQuality.unavailable,
      );
    },
  );
  test(
    '5xx, network and invalid endpoint fail closed without thrown UI errors',
    () async {
      final http = _Http()..status = 503;
      final probe = HttpTranslationModelProbe(
        (_) => Uri.parse('https://example.test/'),
        client: Dio()..httpClientAdapter = http,
      );
      expect(
        (await probe.sample('JP')).quality,
        TranslationQuality.unavailable,
      );
      http.offline = true;
      expect(
        (await probe.sample('JP')).quality,
        TranslationQuality.unavailable,
      );
      probe.close();
      final invalid = HttpTranslationModelProbe((_) => throw FormatException());
      expect(
        (await invalid.sample('bad')).quality,
        TranslationQuality.unavailable,
      );
      invalid.close();
    },
  );
  test(
    'provider starts distinct model samples concurrently in each scoped request',
    () async {
      final probe = _Probe();
      final container = ProviderContainer(
        overrides: [translationModelProbeProvider.overrideWithValue(probe)],
      );
      final us = container.listen(
        translationModelQualityProvider('US'),
        (_, __) {},
      );
      final jp = container.listen(
        translationModelQualityProvider('JP'),
        (_, __) {},
      );
      expect(probe.calls, [
        'OPENAI',
        'GEMINI',
        'QWEN',
        'OPENAI',
        'GEMINI',
        'QWEN',
      ]);
      final usFuture = container.read(
        translationModelQualityProvider('US').future,
      );
      final jpFuture = container.read(
        translationModelQualityProvider('JP').future,
      );
      probe.pending[3].complete(TranslationModelSample.reachable(30));
      probe.pending[4].completeError(StateError('synthetic'));
      probe.pending[5].complete(TranslationModelSample.reachable(40));
      final japan = await jpFuture;
      expect(japan['OPENAI']!.latencyMs, 30);
      expect(japan['GEMINI']!.quality, TranslationQuality.unavailable);
      probe.pending[0].complete(TranslationModelSample.reachable(900));
      probe.pending[1].complete(TranslationModelSample.reachable(901));
      probe.pending[2].complete(TranslationModelSample.reachable(902));
      expect(japan['QWEN']!.latencyMs, 40);
      expect((await usFuture)['OPENAI']!.latencyMs, 900);
      expect(
        container
            .read(translationModelQualityProvider('JP'))
            .value!['OPENAI']!
            .latencyMs,
        30,
      );
      us.close();
      jp.close();
      container.dispose();
    },
  );
}

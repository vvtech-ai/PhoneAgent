import 'package:dio/dio.dart';
import '../domain/translation_model_quality.dart';

/// Reachability sample only, not language validation or model readiness.
class HttpTranslationModelProbe implements TranslationModelProbe {
  HttpTranslationModelProbe(
    this.endpoint, {
    Dio? client,
    this.catalogPath = true,
  }) : _client = client ?? Dio() {
    _client.options = BaseOptions(
      connectTimeout: const Duration(milliseconds: 2500),
      receiveTimeout: const Duration(milliseconds: 2500),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.stream,
      headers: {
        'Accept': '*/*',
        'Cache-Control': 'no-cache',
        'Connection': 'close',
        'Range': 'bytes=0-0',
      },
    );
  }
  final Uri Function(String region) endpoint;
  final bool catalogPath;
  final Dio _client;
  bool _closed = false;

  @override
  Future<TranslationModelSample> sample(String region) async {
    if (_closed) return const TranslationModelSample.unavailable();
    final watch = Stopwatch()..start();
    try {
      final response = await _client.getUri<ResponseBody>(
        catalogPath
            ? endpoint(region).resolve('api/app-translation-calls/languages')
            : endpoint(region),
      );
      final latencyMs = watch.elapsedMilliseconds;
      final status = response.statusCode ?? 0;
      // Measure response headers as the native probes do; discard the body.
      await response.data?.stream.listen((_) {}).cancel();
      if (!_closed && status >= 100 && status < 500) {
        return TranslationModelSample.reachable(latencyMs);
      }
    } catch (_) {
      // Intentionally do not surface raw URLs/headers or retry in a loop.
    } finally {
      watch.stop();
    }
    return const TranslationModelSample.unavailable();
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

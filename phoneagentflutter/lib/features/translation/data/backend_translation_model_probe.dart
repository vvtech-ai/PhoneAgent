import 'package:dio/dio.dart';
import '../domain/translation_model_quality.dart';

/// Model diagnostics are independent for each provider and never create calls.
class BackendTranslationModelProbe implements TranslationModelProbe {
  BackendTranslationModelProbe(this.endpoint, {Dio? client})
    : _client = client ?? Dio() {
    _client.options.connectTimeout = const Duration(seconds: 8);
  }
  final Future<Uri> Function() endpoint;
  final Dio _client;
  bool _closed = false;
  @override
  Future<TranslationModelSample> sample(String model) async {
    final provider = switch (model) {
      'OPENAI' => 'openai',
      'GEMINI' => 'google-gemini-live-translate',
      'QWEN' => 'qwen3.5-livetranslate-flash-realtime',
      _ => '',
    };
    if (_closed || provider.isEmpty) {
      return const TranslationModelSample.unavailable();
    }
    try {
      final base = await endpoint();
      if (_closed) return const TranslationModelSample.unavailable();
      final response = await _client.postUri<Object?>(
        base.resolve('api/diagnostics/model-latencies'),
        data: {
          'providers': [provider],
          'timeoutMs': 3500,
        },
        options: Options(
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
      if (_closed || response.statusCode != 200 || response.data is! Map) {
        return const TranslationModelSample.unavailable();
      }
      final rows = (response.data as Map)['models'];
      if (rows is! List) return const TranslationModelSample.unavailable();
      final matches = rows
          .whereType<Map>()
          .where((r) => r['provider'] == provider)
          .toList();
      if (matches.length != 1) {
        return const TranslationModelSample.unavailable();
      }
      final row = matches.single, latency = matches.single['latencyMs'];
      if (!const {'available', 'degraded'}.contains(row['state']) ||
          latency is! num ||
          !latency.isFinite ||
          latency < 0) {
        return const TranslationModelSample.unavailable();
      }
      return TranslationModelSample.reachable(latency.toInt());
    } catch (_) {
      return const TranslationModelSample.unavailable();
    }
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

import 'dart:async';
import 'dart:convert';
import '../domain/translation_model_quality.dart';
import '../domain/sip/domestic_model_socket.dart';
import 'api_translation_runtime.dart';
import 'sip/io_domestic_model_socket.dart';

/// Authenticated model handshake, without microphone, SIP or audio upload.
class RuntimeTranslationModelProbe implements TranslationModelProbe {
  RuntimeTranslationModelProbe(
    this.runtime,
    this.countryIso, {
    Future<DomesticModelSocket> Function(Uri, Map<String, String>)? connect,
  }) : _connect = connect ?? _open;
  final Future<DomesticModelSocket> Function(Uri, Map<String, String>) _connect;
  static Future<DomesticModelSocket> _open(
    Uri uri,
    Map<String, String> headers,
  ) => connectDomesticModelSocket(
    uri,
    headers,
    timeout: const Duration(seconds: 8),
  );
  final _sockets = <DomesticModelSocket>{};
  bool _closed = false;
  void close() {
    _closed = true;
    for (final socket in _sockets.toList()) {
      unawaited(socket.close().catchError((Object _) {}));
    }
    _sockets.clear();
  }

  final ApiTranslationRuntime runtime;
  final String countryIso;
  @override
  Future<TranslationModelSample> sample(String provider) async {
    DomesticModelSocket? socket;
    final watch = Stopwatch();
    try {
      final config = await runtime.loadSelectedFor(countryIso, provider);
      if (_closed || config == null) {
        return const TranslationModelSample.unavailable();
      }
      final uri = config.provider == 'QWEN'
          ? config.uri.replace(
              queryParameters: {
                ...config.uri.queryParameters,
                'model': config.model,
              },
            )
          : config.uri;
      watch.start();
      socket = await _connect(uri, config.headers);
      _sockets.add(socket);
      if (_closed) return const TranslationModelSample.unavailable();
      if (config.provider == 'QWEN') {
        await socket.messages
            .firstWhere((message) {
              if (message is! String) return false;
              final value = jsonDecode(message);
              return value is Map && value['type'] == 'session.created';
            })
            .timeout(const Duration(seconds: 8));
      }
      return _closed
          ? const TranslationModelSample.unavailable()
          : TranslationModelSample.reachable(watch.elapsedMilliseconds);
    } catch (_) {
      return const TranslationModelSample.unavailable();
    } finally {
      _sockets.remove(socket);
      try {
        await socket?.close();
      } catch (_) {
        /* Best-effort probe release. */
      }
    }
  }
}

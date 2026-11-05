import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

Dio createStreamClient() => Dio()..httpClientAdapter = FetchStreamAdapter();

/// Fetch exposes the response at headers and streams bytes without XHR buffering.
/// Used for JSON Agent requests and protected binary GET. Multipart uploads
/// continue to use the ordinary client; binary GET requires redirect:error.
class FetchStreamAdapter implements HttpClientAdapter {
  final _active = <web.AbortController>{};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) throw StateError('Stream client is closed');
    final abort = web.AbortController();
    _active.add(abort);
    var released = false;
    void release() {
      if (released) return;
      released = true;
      _active.remove(abort);
      abort.abort();
    }

    cancelFuture?.then((_) => release());
    try {
      final bytes = BytesBuilder(copy: false);
      if (requestStream != null) {
        await for (final chunk in requestStream) {
          bytes.add(chunk);
        }
      }
      final headers = web.Headers();
      options.headers.forEach((name, value) {
        if (name.toLowerCase() != 'content-length') {
          headers.set(name, value is Iterable ? value.join(', ') : '$value');
        }
      });
      var pending = web.window
          .fetch(
            options.uri.toString().toJS,
            web.RequestInit(
              method: options.method,
              headers: headers,
              body: requestStream == null ? null : bytes.takeBytes().toJS,
              signal: abort.signal,
              credentials: 'omit',
              redirect: options.followRedirects ? 'follow' : 'error',
              cache: 'no-store',
            ),
          )
          .toDart;
      final timeout = options.connectTimeout;
      if (timeout != null && timeout > Duration.zero) {
        pending = pending.timeout(
          timeout,
          onTimeout: () {
            release();
            throw DioException.connectionTimeout(
              requestOptions: options,
              timeout: timeout,
            );
          },
        );
      }
      final response = await pending;
      final responseHeaders = <String, List<String>>{};
      for (final name in ['content-type', 'content-length']) {
        final value = response.headers.get(name);
        if (value != null) responseHeaders[name] = [value];
      }
      final body = response.body;
      if (body == null) {
        release();
        return ResponseBody.fromBytes(
          [],
          response.status,
          headers: responseHeaders,
        );
      }
      final reader = body.getReader() as web.ReadableStreamDefaultReader;
      late StreamController<Uint8List> output;
      var cancelled = false;
      Future<void> pump() async {
        try {
          while (!cancelled) {
            var read = reader.read().toDart;
            final idle = options.receiveTimeout;
            if (idle != null && idle > Duration.zero) {
              read = read.timeout(
                idle,
                onTimeout: () {
                  release();
                  throw DioException.receiveTimeout(
                    requestOptions: options,
                    timeout: idle,
                  );
                },
              );
            }
            final chunk = await read;
            if (cancelled || chunk.done) break;
            output.add((chunk.value as JSUint8Array).toDart);
          }
        } catch (error, stack) {
          if (!cancelled) output.addError(error, stack);
        } finally {
          release();
          reader.releaseLock();
          await output.close();
        }
      }

      output = StreamController<Uint8List>(
        onListen: pump,
        onCancel: () {
          cancelled = true;
          release();
        },
      );
      return ResponseBody(
        output.stream,
        response.status,
        headers: responseHeaders,
        statusMessage: response.statusText,
      );
    } catch (_) {
      release();
      rethrow;
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    if (force) {
      for (final abort in _active.toList()) {
        abort.abort();
      }
      _active.clear();
    }
  }
}

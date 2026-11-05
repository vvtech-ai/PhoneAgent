@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;
import 'package:phone_agent/core/network/stream_client_web.dart';

@JS('window.fetch')
external JSFunction get _fetch;
@JS('window.fetch')
external set _fetch(JSFunction value);

void main() {
  late JSFunction original;
  late FetchStreamAdapter adapter;
  setUp(() {
    original = _fetch;
    adapter = FetchStreamAdapter();
  });
  tearDown(() {
    adapter.close(force: true);
    _fetch = original;
  });

  test(
    'POST delivers bytes before EOF and cancellation aborts fetch',
    () async {
      final created = Completer<web.ReadableStreamDefaultController>();
      final aborted = Completer<void>();
      final stream = web.ReadableStream(
        {
              'start': ((web.ReadableStreamDefaultController value) {
                created.complete(value);
              }).toJS,
            }.jsify()
            as JSObject,
      );
      final controller = await created.future;
      _fetch = ((JSAny url, web.RequestInit options) {
        expect(options.method, 'POST');
        expect(options.credentials, 'omit');
        expect(options.redirect, 'error');
        options.signal!.addEventListener(
          'abort',
          ((web.Event event) {
            if (!aborted.isCompleted) {
              aborted.complete();
              controller.close();
            }
          }).toJS,
        );
        return Future.value(
          web.Response(
            stream,
            web.ResponseInit(
              status: 200,
              headers: web.Headers(
                {'content-type': 'text/event-stream'}.jsify() as JSObject,
              ),
            ),
          ),
        ).toJS;
      }).toJS;
      final cancel = Completer<void>();
      final response = await adapter.fetch(
        RequestOptions(
          path: 'https://synthetic.invalid/stream',
          method: 'POST',
          followRedirects: false,
        ),
        Stream.value(Uint8List.fromList(utf8.encode('{}'))),
        cancel.future,
      );
      expect(response.headers['content-type'], ['text/event-stream']);
      final first = Completer<String>();
      final subscription = response.stream.listen((bytes) {
        if (!first.isCompleted) first.complete(utf8.decode(bytes));
      });
      controller.enqueue(Uint8List.fromList(utf8.encode('data: 首段\n\n')).toJS);
      expect(
        await first.future.timeout(const Duration(seconds: 2)),
        'data: 首段\n\n',
      );
      expect(aborted.isCompleted, isFalse);
      cancel.complete();
      await aborted.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();
    },
  );

  test('header timeout aborts outstanding fetch', () async {
    final aborted = Completer<void>();
    _fetch = ((JSAny url, web.RequestInit options) {
      options.signal!.addEventListener(
        'abort',
        ((web.Event event) {
          aborted.complete();
        }).toJS,
      );
      return Completer<web.Response>().future.toJS;
    }).toJS;
    await expectLater(
      adapter.fetch(
        RequestOptions(
          path: 'https://synthetic.invalid/stall',
          connectTimeout: const Duration(milliseconds: 30),
        ),
        null,
        null,
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionTimeout,
        ),
      ),
    );
    expect(aborted.isCompleted, isTrue);
  });
}

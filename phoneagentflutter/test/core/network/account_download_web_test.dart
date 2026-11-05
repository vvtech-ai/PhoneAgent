@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';

@JS('window.fetch')
external JSFunction get _fetch;
@JS('window.fetch')
external set _fetch(JSFunction value);

void main() {
  late JSFunction original;
  late AccountApi api;
  setUp(() {
    original = _fetch;
    // No injected client: verifies the production Web binary client selection.
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://synthetic.invalid/prefix/',
      ),
      _Session(),
    );
  });
  tearDown(() {
    api.close();
    _fetch = original;
  });
  test(
    'certified recording query remains same-origin encoded and no-redirect',
    () async {
      _fetch = ((JSAny url, web.RequestInit options) {
        final parsed = Uri.parse((url as JSString).toDart);
        expect(parsed.host, 'synthetic.invalid');
        expect(
          parsed.path,
          '/prefix/api/account/settings/voice-clone/verification/attempt/certified-recording',
        );
        expect(parsed.queryParameters, {'grant': 'synthetic+opaque/grant'});
        expect(options.redirect, 'error');
        expect(options.credentials, 'omit');
        expect(
          (options.headers as web.Headers).get('Authorization'),
          'Bearer synthetic-token',
        );
        return Future.value(
          web.Response(
            Uint8List.fromList([1, 2]).toJS,
            web.ResponseInit(
              status: 200,
              headers: web.Headers(
                {'content-type': 'audio/wav'}.jsify() as JSObject,
              ),
            ),
          ),
        ).toJS;
      }).toJS;
      expect(
        await api.download(
          'api/account/settings/voice-clone/verification/attempt/certified-recording',
          maxBytes: 2,
          mediaTypes: {'audio/wav'},
          query: {'grant': 'synthetic+opaque/grant'},
        ),
        [1, 2],
      );
    },
  );
  test(
    'protected GET uses fetch with redirect error, no cookies and binary bytes',
    () async {
      _fetch = ((JSAny url, web.RequestInit options) {
        expect(
          (url as JSString).toDart,
          'https://synthetic.invalid/prefix/api/agent/conversations/session/attachments/ocr-id/content',
        );
        expect(options.method, 'GET');
        expect(options.redirect, 'error');
        expect(options.credentials, 'omit');
        final headers = options.headers as web.Headers;
        expect(headers.get('Authorization'), 'Bearer synthetic-token');
        expect(headers.get('X-Account-Id'), 'synthetic-account');
        return Future.value(
          web.Response(
            Uint8List.fromList([1, 2, 3]).toJS,
            web.ResponseInit(
              status: 200,
              headers: web.Headers(
                {'content-type': 'image/png', 'content-length': '3'}.jsify()
                    as JSObject,
              ),
            ),
          ),
        ).toJS;
      }).toJS;
      expect(
        await api.download(
          'api/agent/conversations/session/attachments/ocr-id/content',
          maxBytes: 3,
          mediaTypes: {'image/png'},
        ),
        [1, 2, 3],
      );
    },
  );
  test('oversized browser response aborts fetch before stalled EOF', () async {
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
              {'content-type': 'image/png'}.jsify() as JSObject,
            ),
          ),
        ),
      ).toJS;
    }).toJS;
    final result = expectLater(
      api.download(
        'api/agent/conversations/session/attachments/ocr-id/content',
        maxBytes: 8,
        mediaTypes: {'image/png'},
      ),
      throwsA(ApiFailure.invalidResponse),
    );
    controller.enqueue(Uint8List(80 * 1024).toJS);
    await result.timeout(const Duration(seconds: 2));
    await aborted.future.timeout(const Duration(seconds: 2));
  });
}

class _Session implements AccountSession {
  @override
  AccountCredentials? get credentials =>
      const AccountCredentials('synthetic-account', 'synthetic-token', 1);
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

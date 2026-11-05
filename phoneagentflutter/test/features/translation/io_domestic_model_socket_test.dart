import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/io_domestic_model_socket.dart';

void main() {
  test('redirect response is refused and HTTP owner closed', () async {
    final client = _Client();
    await expectLater(
      connectDomesticModelSocket(Uri.parse('wss://example.test/realtime'), {
        'Authorization': 'synthetic',
      }, clientFactory: () => client),
      throwsA(anything),
    );
    expect(client.uri, Uri.parse('https://example.test/realtime'));
    expect(client.request.followRedirects, false);
    expect(client.request.headers.values['Authorization'], 'synthetic');
    expect(client.closed, true);
    expect(client.request.closed, true);
  });
  test(
    'rejects handshake header override before opening HTTP client',
    () async {
      var created = false;
      await expectLater(
        connectDomesticModelSocket(
          Uri.parse('wss://example.test'),
          {'Host': 'other.test'},
          clientFactory: () {
            created = true;
            return _Client();
          },
        ),
        throwsA(anything),
      );
      expect(created, false);
    },
  );
  test(
    'timeout closes client and late request never sends credentials',
    () async {
      final client = _Client()..pending = Completer<HttpClientRequest>();
      await expectLater(
        connectDomesticModelSocket(
          Uri.parse('wss://example.test'),
          {'Authorization': 'synthetic'},
          timeout: const Duration(milliseconds: 5),
          clientFactory: () => client,
        ),
        throwsA(anything),
      );
      expect(client.closed, true);
      client.pending!.complete(client.request);
      await Future<void>.delayed(Duration.zero);
      expect(client.request.headers.values, isEmpty);
      expect(client.request.closed, false);
    },
  );
}

class _Client implements HttpClient {
  final _Request request = _Request();
  Completer<HttpClientRequest>? pending;
  Uri? uri;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri value) async {
    uri = value;
    return pending == null ? request : pending!.future;
  }

  @override
  void close({bool force = false}) {
    closed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  @override
  final _Headers headers = _Headers();
  @override
  bool followRedirects = true;
  bool closed = false;
  @override
  Future<HttpClientResponse> close() async {
    closed = true;
    return _Response();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  String? value(String name) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response implements HttpClientResponse {
  @override
  int get statusCode => 302;
  @override
  final _Headers headers = _Headers();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

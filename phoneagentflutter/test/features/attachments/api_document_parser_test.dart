import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/attachments/data/api_document_parser.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'token',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String body = '';
  Object? data = {
    'status': 'OK',
    'fileName': 'sample.docx',
    'content': 'synthetic',
    'charCount': 9,
    'truncated': false,
  };
  int status = 200;
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (stream != null) {
      body = utf8.decode(await stream.expand((b) => b).toList());
    }
    if (gate != null) await gate!.future;
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
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
  late _Session session;
  late _Adapter adapter;
  late ApiDocumentParser parser;
  final bytes = Uint8List.fromList(utf8.encode('synthetic bytes'));
  final file = SelectedDocument(
    name: 'sample.docx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    size: 15,
    read: () async => bytes,
  );
  setUp(() {
    session = _Session();
    adapter = _Adapter();
    parser = ApiDocumentParser(
      AccountApi(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/aiassistant-api',
        ),
        session,
        client: Dio()..httpClientAdapter = adapter,
      ),
    );
  });
  test(
    'multipart file wire contract, account prefix, and parsed fields',
    () async {
      final result = await parser.parse(file, bytes);
      final request = adapter.requests.single;
      expect(request.uri.path, '/aiassistant-api/api/documents/parse');
      expect(request.method, 'POST');
      expect(request.contentType, startsWith('multipart/form-data; boundary='));
      expect(request.headers['X-Account-Id'], 'synthetic');
      expect(request.headers['Authorization'], isNull);
      expect(adapter.body, contains('name="file"; filename="sample.docx"'));
      expect(adapter.body, contains(file.mimeType));
      expect(adapter.body, contains('synthetic bytes'));
      expect(result.content, 'synthetic');
      expect(result.charCount, 9);
    },
  );
  test('parse failure is business result without retry', () async {
    adapter.data = {'status': 'FAILED', 'message': '文件解析失败'};
    final result = await parser.parse(file, bytes);
    expect(result.status, 'FAILED');
    expect(result.message, '文件解析失败');
    expect(adapter.requests, hasLength(1));
  });
  test(
    'Agent parser accepts markdown without widening proactive parser',
    () async {
      final markdown = SelectedDocument(
        name: 'sample.md',
        mimeType: 'text/markdown',
        size: bytes.length,
        read: () async => bytes,
      );
      await expectLater(parser.parse(markdown, bytes), throwsFormatException);
      expect(adapter.requests, isEmpty);
      final agent = ApiDocumentParser(parser.api, agentRequest: true);
      await agent.parse(markdown, bytes);
      expect(
        adapter.requests.single.uri.path,
        '/aiassistant-api/api/documents/parse',
      );
      expect(adapter.body, contains('filename="sample.md"'));
    },
  );
  test('malformed fields rejected', () async {
    for (final value in [
      null,
      {},
      {'status': ''},
      {'status': 'OK', 'content': 1},
      {'status': 'OK', 'charCount': -1},
      {'status': 'OK', 'truncated': 'false'},
    ]) {
      adapter.data = value;
      await expectLater(
        parser.parse(file, bytes),
        throwsA(ApiFailure.invalidResponse),
      );
    }
  });
  test('HTTP error never replays multipart POST', () async {
    adapter.status = 500;
    await expectLater(parser.parse(file, bytes), throwsA(ApiFailure.rejected));
    expect(adapter.requests, hasLength(1));
  });
  test('account switch drops late upload response', () async {
    adapter.gate = Completer();
    final pending = expectLater(
      parser.parse(file, bytes),
      throwsA(ApiFailure.sessionChanged),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    session.credentials = const AccountCredentials('another', 'other', 2);
    adapter.gate!.complete();
    await pending;
    expect(adapter.requests, hasLength(1));
  });
  test('oversized actual bytes rejected before HTTP', () async {
    await expectLater(
      parser.parse(file, Uint8List(documentMaxBytes + 1)),
      throwsFormatException,
    );
    expect(adapter.requests, isEmpty);
  });
}

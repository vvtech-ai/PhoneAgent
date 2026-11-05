import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';

void main() {
  late DiagnosticJournal journal;
  late ZipLogRepository repository;
  late _Session session;
  late _Adapter adapter;
  late AccountApi api;
  final diagnostics = <DiagnosticEvent>[];
  setUp(() {
    journal = DiagnosticJournal(_Store());
    repository = ZipLogRepository(journal, uploadBundle: (_) async {});
    session = _Session();
    adapter = _Adapter();
    diagnostics.clear();
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
      diagnostics: diagnostics.add,
    );
  });
  tearDown(() {
    journal.close();
    api.close();
  });
  Future<AppLogBundle> bundle() async {
    journal.record(
      DiagnosticEvent(
        operation: DiagnosticOperation.agentStream,
        result: DiagnosticResult.failed,
        sessionId: 'e5701dfe-85dc-41af-a212-048974fe2512',
        traceId: 'phone +8618811111111 token secret',
      ),
    );
    return repository.prepare();
  }

  void reply(AppLogBundle value) {
    adapter.response = {
      'id': 1,
      'accountId': 'synthetic-account',
      'originalFileName': value.fileName,
      'fileSize': value.bytes.length,
      'checksumSha256': sha256.convert(value.bytes).toString(),
    };
  }

  test(
    'actual ZIP contains one jsonl and only whitelisted event data',
    () async {
      final value = await bundle();
      final archive = ZipDecoder().decodeBytes(value.bytes, verify: true);
      expect(archive.files.map((f) => f.name), ['diagnostics.jsonl']);
      final text = utf8.decode(archive.files.single.content as List<int>);
      expect(text, contains('e5701dfe'));
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('+8618811111111')));
      final data = jsonDecode(text) as Map<String, dynamic>;
      expect(data.keys.toSet(), {
        'operation',
        'result',
        'time',
        'statusCode',
        'elapsedMs',
        'sessionId',
      });
      expect(data['operation'], 'agentStream');
    },
  );
  test(
    'multipart uses account and bearer, correct checksum response',
    () async {
      final value = await bundle();
      reply(value);
      await ApiLogUploader(
        api,
        'synthetic-account',
        'Flutter test',
      ).upload(value);
      final request = adapter.requests.single;
      final data = request.data as FormData;
      expect(request.uri.path, '/aiassistant-api/api/logs/upload');
      expect(request.method, 'POST');
      expect(request.headers['X-Account-Id'], 'synthetic-account');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(Map.fromEntries(data.fields), {
        'accountId': 'synthetic-account',
        'deviceInfo': 'Flutter test',
      });
      expect(data.files.single.key, 'file');
      expect(data.files.single.value.contentType.toString(), 'application/zip');
      expect(diagnostics.single.result, DiagnosticResult.succeeded);
      expect(
        jsonEncode(diagnostics.single.toJson()),
        isNot(contains('synthetic-account')),
      );
    },
  );
  test('wrong checksum or wrong owner is rejected before cleanup', () async {
    final value = await bundle();
    reply(value);
    adapter.response['checksumSha256'] = 'invalid';
    await expectLater(
      ApiLogUploader(api, 'synthetic-account', 'test').upload(value),
      throwsA(ApiFailure.invalidResponse),
    );
    reply(value);
    adapter.response['accountId'] = 'other';
    await expectLater(
      ApiLogUploader(api, 'synthetic-account', 'test').upload(value),
      throwsA(ApiFailure.invalidResponse),
    );
    expect((await journal.snapshot()).events, isNotEmpty);
  });
  test('failed HTTP never auto-replays and retains journal', () async {
    final value = await bundle();
    adapter.status = 500;
    await expectLater(
      ApiLogUploader(api, 'synthetic-account', 'test').upload(value),
      throwsA(ApiFailure.rejected),
    );
    expect(adapter.requests.length, 1);
    expect((await journal.snapshot()).events.length, 1);
    expect(diagnostics.single.result, DiagnosticResult.failed);
  });
  test('account switch prevents sending old bundle', () async {
    final value = await bundle();
    session.value = const AccountCredentials('new', 'new-token', 2);
    await expectLater(
      ApiLogUploader(api, 'synthetic-account', 'test').upload(value),
      throwsA(ApiFailure.sessionChanged),
    );
    expect(adapter.requests, isEmpty);
  });
  test(
    'uploader accepts a bounded archive above old 512 KiB client ceiling',
    () async {
      final value = AppLogBundle(
        watermark: 1,
        count: 1,
        bytes: Uint8List(600 * 1024),
        fileName: 'phoneagent-diagnostics-123.zip',
      );
      reply(value);
      await ApiLogUploader(api, 'synthetic-account', 'test').upload(value);
      expect(adapter.requests, hasLength(1));
    },
  );
  test('uploader rejects above five MiB before sending or clearing', () async {
    final value = AppLogBundle(
      watermark: 1,
      count: 1,
      bytes: Uint8List(5 * 1024 * 1024 + 1),
      fileName: 'phoneagent-diagnostics-123.zip',
    );
    await expectLater(
      ApiLogUploader(api, 'synthetic-account', 'test').upload(value),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(adapter.requests, isEmpty);
  });
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }
}

class _Session implements AccountSession {
  AccountCredentials? value = const AccountCredentials(
    'synthetic-account',
    'test-token',
    1,
  );
  @override
  AccountCredentials? get credentials => value;
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, Object> response = {};
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) await requestStream.drain<void>();
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': response}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/contacts/data/api_contact_directory_repository.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';

void main() {
  late _Adapter adapter;
  late AccountApi api;
  late ApiContactDirectoryRepository repo;
  late _Session session;
  const contact = ContactRecord(
    name: '合成名字',
    phone: '+86 13800000000',
    systemDialPhone: '+86 13800000000',
  );
  setUp(() {
    adapter = _Adapter();
    session = _Session();
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/base/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
    repo = ApiContactDirectoryRepository(api, 'a');
  });
  tearDown(() => api.close());
  test('list uses current account and nullable fields', () async {
    expect((await repo.load()).single.description, isNull);
    final request = adapter.requests.single;
    expect(request.uri.path, '/base/api/assistant/contacts');
    expect(request.uri.queryParameters['userId'], 'a');
    expect(request.headers['X-Account-Id'], 'a');
    expect(request.headers['Authorization'], 'Bearer synthetic');
  });
  test(
    'remark update preserves all existing metadata and clears with null',
    () async {
      await repo.saveRemark(
        contact: contact,
        remark: '  ',
        existing: const ContactDirectoryEntry(
          phone: '13800000000',
          displayName: '',
          primaryRelation: '同事',
          speakingStyle: '正式',
        ),
      );
      expect(adapter.requests.single.data, {
        'userId': 'a',
        'phone': '13800000000',
        'displayName': '',
        'primaryRelation': '同事',
        'speakingStyle': '正式',
        'description': null,
      });
      adapter.requests.clear();
      await repo.saveRemark(contact: contact, remark: ' 新备注 ');
      expect((adapter.requests.single.data as Map)['description'], '新备注');
      expect((adapter.requests.single.data as Map)['displayName'], '合成名字');
    },
  );
  test(
    'wrong contact response and incompatible existing metadata rejected',
    () async {
      await expectLater(
        repo.saveRemark(
          contact: contact,
          remark: '',
          existing: const ContactDirectoryEntry(phone: '13800000001'),
        ),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(adapter.requests, isEmpty);
      adapter.phone = '13800000001';
      await expectLater(
        repo.saveRemark(contact: contact, remark: ''),
        throwsA(ApiFailure.invalidResponse),
      );
    },
  );
  test(
    'DELETE normalized phone with account query and rejects unsafe keys',
    () async {
      await repo.deleteRemark(contact.key);
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/base/api/assistant/contacts/13800000000');
      expect(request.uri.queryParameters, {'userId': 'a'});
      for (final key in ['', '../other', '+13800000000']) {
        await expectLater(
          repo.deleteRemark(key),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      expect(adapter.requests.length, 1);
    },
  );
  test('account switch while DELETE pending rejects response', () async {
    adapter.gate = Completer<void>();
    final pending = repo.deleteRemark(contact.key);
    final check = expectLater(pending, throwsA(ApiFailure.sessionChanged));
    await Future<void>.delayed(Duration.zero);
    session.value = const AccountCredentials('b', 'synthetic-b', 2);
    adapter.gate!.complete();
    await check;
  });
  test('account switch while GET pending rejects response', () async {
    adapter.gate = Completer<void>();
    final pending = repo.load();
    final check = expectLater(pending, throwsA(ApiFailure.sessionChanged));
    await Future<void>.delayed(Duration.zero);
    session.value = const AccountCredentials('b', 'synthetic-b', 2);
    adapter.gate!.complete();
    await check;
  });
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String phone = '13800000000';
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (gate != null) await gate!.future;
    final row = {'phone': phone, 'displayName': '合成名字'};
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data': options.method == 'GET' ? [row] : row,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Session implements AccountSession {
  AccountCredentials? value = const AccountCredentials('a', 'synthetic', 1);
  @override
  AccountCredentials? get credentials => value;
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/identity/data/api_identity_repository.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';

void main() {
  late _Adapter adapter;
  late _Session session;
  late AccountApi api;
  late ApiIdentityRepository repository;
  setUp(() {
    adapter = _Adapter();
    session = _Session();
    api = AccountApi(
      AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test/'),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
    repository = ApiIdentityRepository(api, 'a');
  });
  tearDown(() => api.close());
  test(
    'GET and DELETE use owner query; empty response profile not authenticated',
    () async {
      expect((await repository.load()).status, IdentityStatus.empty);
      await repository.delete();
      expect(adapter.requests.map((r) => r.method), ['GET', 'DELETE']);
      expect(
        adapter.requests.every((r) => r.uri.queryParameters['userId'] == 'a'),
        isTrue,
      );
      expect(
        adapter.requests.every((r) => r.headers['X-Account-Id'] == 'a'),
        isTrue,
      );
    },
  );
  test(
    'loads optional masked certificate without adding it to save payload',
    () async {
      adapter.masked = '000***********0005';
      expect((await repository.load()).certNoMasked, adapter.masked);
      await repository.save(const IdentityDraft(name: '合成姓名'), verified: true);
      expect(
        (adapter.requests.last.data as Map).containsKey('certNoMasked'),
        isFalse,
      );
      adapter.masked = null;
      expect((await repository.load()).certNoMasked, isEmpty);
    },
  );
  test(
    'POST trims retained metadata and removes companyless work identities',
    () async {
      await repository.save(
        const IdentityDraft(
          name: ' 名字 ',
          gender: '男',
          description: ' 说明 ',
          workIdentities: [
            WorkIdentity(company: ' 公司 ', department: ' 部门 '),
            WorkIdentity(position: '无公司'),
          ],
        ),
        verified: false,
      );
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      final body = request.data as Map;
      expect(body['userId'], 'a');
      expect(body['name'], '名字');
      expect(body['contactPhone'], isNull);
      expect(body['workIdentities'], [
        {'company': '公司', 'department': '部门', 'position': ''},
      ]);
    },
  );
  test('PATCH excludes name and other verified identity fields', () async {
    await repository.save(
      const IdentityDraft(
        name: '认证姓名',
        gender: '女',
        contactPhone: '13800000000',
        description: '不得覆盖',
      ),
      verified: true,
    );
    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect((request.data as Map).keys.toSet(), {
      'userId',
      'gender',
      'contactPhone',
    });
  });
  test(
    'different account response and switched account requests rejected',
    () async {
      adapter.user = 'other';
      await expectLater(repository.load(), throwsA(ApiFailure.sessionChanged));
      session.credentials = const AccountCredentials('other', 'synthetic', 2);
      await expectLater(
        repository.delete(),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(adapter.requests, hasLength(1));
    },
  );
}

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'a',
    'synthetic',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  String user = 'a';
  String? masked;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data': {'userId': user, if (masked != null) 'certNoMasked': masked},
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';

class Fixture implements AccountSession, HttpClientAdapter, C1CredentialSource {
  late final api = AccountApi(
    AppConfig.parse(
      environment: 'dev',
      apiBaseUrl: 'https://sdk.invalid/context/',
    ),
    this,
    client: Dio()..httpClientAdapter = this,
    signing: C1Transport(this),
  );
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'old',
    1,
  );
  final requests = <RequestOptions>[];
  bool denyAgain = false;
  bool rejectSignature = false;
  void Function()? duringRefresh;
  @override
  Future<C1Credentials> read(ApiService service) async => const C1Credentials(
    apiKey: 'fixture',
    secret: 'fixture',
    deviceId: '33333333-3333-4333-8333-333333333333',
    clientContext: 'e30',
  );
  @override
  Future<bool> replaceToken(AccountCredentials previous, String token) async {
    if (!previous.sameLogin(credentials)) return false;
    credentials = AccountCredentials(previous.accountId, token, previous.epoch);
    return true;
  }

  @override
  Future<void> rejectSession(AccountCredentials previous) async {}
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (request.path.endsWith('/refresh')) {
      duringRefresh?.call();
      return ResponseBody.fromString(
        jsonEncode({
          'code': 0,
          'data': {'voiceCloneAccessToken': 'new'},
        }),
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    if (request.headers['Authorization'] == 'Bearer old' || denyAgain) {
      return ResponseBody.fromString(
        jsonEncode({'code': rejectSignature ? 'AC0007' : 'UNAUTHORIZED'}),
        401,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    return ResponseBody.fromBytes(
      [2, 3],
      206,
      headers: {
        'content-type': ['audio/mp4'],
        'content-range': ['bytes 1-2/3'],
      },
    );
  }
}

void main() {
  test(
    'content Range uses SDK Bearer and fresh C1 after one refresh',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.api.close);
      final response = await fixture.api.openRecordingContent(
        'call',
        offset: 1,
        cancellation: CancelToken(),
      );
      expect(response.statusCode, 206);
      expect(await response.data!.stream.expand((x) => x).toList(), [2, 3]);
      final reads = fixture.requests
          .where((r) => r.path.endsWith('recording-content'))
          .toList();
      expect(reads.map((r) => r.headers['Authorization']), [
        'Bearer old',
        'Bearer new',
      ]);
      for (final request in reads) {
        expect(
          request.uri.path,
          '/context/api/realtime-translation-calls/call/recording-content',
        );
        expect(request.headers['X-Account-Id'], 'synthetic');
        expect(request.headers['Range'], 'bytes=1-');
        expect(request.headers['Accept-Encoding'], 'identity');
        expect(request.headers['X-Sign'], isNotEmpty);
        expect(request.followRedirects, false);
      }
      expect(
        reads.first.headers['X-Reqid'],
        isNot(reads.last.headers['X-Reqid']),
      );
      expect(
        reads.first.headers['X-Sign'],
        isNot(reads.last.headers['X-Sign']),
      );
      expect(
        fixture.requests.where((r) => r.path.endsWith('/refresh')).length,
        1,
      );
    },
  );
  test('second 401 and signature rejection do not loop', () async {
    final fixture = Fixture()..denyAgain = true;
    addTearDown(fixture.api.close);
    await expectLater(
      fixture.api.openRecordingContent('call', cancellation: CancelToken()),
      throwsA(ApiFailure.signedOut),
    );
    expect(fixture.requests.length, 3);
    final signed = Fixture()..rejectSignature = true;
    addTearDown(signed.api.close);
    await expectLater(
      signed.api.openRecordingContent('call', cancellation: CancelToken()),
      throwsA(ApiFailure.rejected),
    );
    expect(signed.requests.length, 1);
  });
  test('owner change during refresh prevents content replay', () async {
    final fixture = Fixture();
    addTearDown(fixture.api.close);
    fixture.duringRefresh = () =>
        fixture.credentials = const AccountCredentials('other', 'other', 2);
    await expectLater(
      fixture.api.openRecordingContent('call', cancellation: CancelToken()),
      throwsA(ApiFailure.sessionChanged),
    );
    expect(fixture.requests.length, 2);
  });
  test(
    'foreign and traversing identities cannot reach authenticated transport',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.api.close);
      for (final id in [
        '../other',
        'https://foreign.invalid/file',
        'a?token=x',
      ]) {
        await expectLater(
          fixture.api.openRecordingContent(id, cancellation: CancelToken()),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      expect(fixture.requests, isEmpty);
    },
  );
}

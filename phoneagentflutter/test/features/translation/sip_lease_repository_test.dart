import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/translation/data/sip/api_sip_lease_repository.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import '../../support/synthetic_account_api.dart';

class LeaseApi extends SyntheticAccountApi {
  final lease = <String, Object?>{
    'leaseId': 'synthetic-lease',
    'sipAccountId': 'synthetic-account',
    'server': 'sip.example.test',
    'port': 5060,
    'transport': 'udp',
    'username': 'synthetic-user',
    'password': 'synthetic-password',
    'callerNumber': 'synthetic-caller',
  };
  Object? released = true;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    data = request.path.endsWith('/release')
        ? {'leaseId': 'synthetic-lease', 'released': released}
        : lease;
    return super.fetch(request, stream, cancel);
  }
}

void main() {
  late LeaseApi api;
  late ApiSipLeaseRepository repository;
  final request = SipLeaseRequest(route: 'domestic', callId: 'synthetic-call');
  setUp(() {
    api = LeaseApi();
    repository = ApiSipLeaseRepository(api.api);
  });
  tearDown(() => api.api.close());
  Matcher failure(String code) =>
      isA<SipLeaseFailure>().having((value) => value.code, 'code', code);
  test(
    'native lease contract and confirmed release, credentials opaque',
    () async {
      final lease = await repository.acquire(request);
      expect(lease.transport, 'UDP');
      expect(lease.toString(), isNot(contains('synthetic-password')));
      expect(api.requests.single.data, {
        'route': 'domestic',
        'purpose': 'translation_call',
        'callId': 'synthetic-call',
      });
      expect(api.requests.single.headers['X-Account-Id'], 'a');
      await repository.release(lease.id, request.callId);
      expect(api.requests.last.path, endsWith('/synthetic-lease/release'));
      expect(api.requests.last.data, {
        'reason': 'call_session_finished',
        'callId': 'synthetic-call',
      });
    },
  );
  test('invalid allocated lease released without reacquiring', () async {
    api.lease['port'] = 0;
    await expectLater(
      repository.acquire(request),
      throwsA(failure('UNSUPPORTED_TRANSPORT')),
    );
    expect(api.requests, hasLength(2));
    expect(api.requests.last.path, endsWith('/release'));
  });
  test('unknown lease id cannot be interpolated or released', () async {
    api.lease['leaseId'] = '../synthetic-private';
    await expectLater(
      repository.acquire(request),
      throwsA(failure('INVALID_LEASE')),
    );
    expect(api.requests, hasLength(1));
  });
  test(
    'malformed credentials never reach signaling and cleanup uncertainty visible',
    () async {
      api.lease['username'] = 'user\r\nInjected: true';
      api.released = false;
      await expectLater(
        repository.acquire(request),
        throwsA(failure('INVALID_LEASE_CLEANUP_FAILED')),
      );
      expect(api.requests, hasLength(2));
    },
  );
  test(
    'release requires confirmation; account switch sends no request',
    () async {
      api.released = false;
      await expectLater(
        repository.release('synthetic-lease', request.callId),
        throwsA(failure('RELEASE_UNCONFIRMED')),
      );
      api.credentials = const AccountCredentials('b', 'synthetic-other', 2);
      await expectLater(
        repository.acquire(request),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(api.requests, hasLength(1));
    },
  );
}

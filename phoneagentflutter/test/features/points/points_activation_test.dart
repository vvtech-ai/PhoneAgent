import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/points/data/api_points_activation_repository.dart';
import 'package:phone_agent/features/points/domain/points_activation.dart';
import 'package:phone_agent/features/points/domain/points_activation_registry.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import '../../support/synthetic_account_api.dart';

const account = PointsAccount(
  totalBalance: 900,
  availableBalance: 870,
  heldBalance: 30,
  updatedAt: 'synthetic-now',
);
Map<String, Object?> response() => {
  'walletSummary': {
    'totalBalance': 900,
    'availableBalance': 870,
    'heldBalance': 30,
    'updatedAt': 'synthetic-now',
  },
  'grantEvents': [
    {'type': 'INITIAL_GRANT', 'amount': 800, 'businessDate': '2026-09-18'},
    {'type': 'DAILY_LOGIN_GRANT', 'amount': 100, 'businessDate': '2026-09-18'},
  ],
};

void main() {
  test(
    'activation uses protected empty POST and server wallet/grants',
    () async {
      final wire = SyntheticAccountApi()..data = response();
      addTearDown(wire.api.close);
      final result = await ApiPointsActivationRepository(wire.api).activate();
      final request = wire.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/points/session-activations');
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.data, isNull);
      expect(result.account.availableBalance, 870);
      expect(result.account.heldBalance, 30);
      expect(result.grants.map((e) => e.notice), [
        '初始赠送 ✦800 积分已到账',
        '今日登录赠送 ✦100 积分已到账',
      ]);
    },
  );
  test('absent grants do not synthesize daily reward', () async {
    final wire = SyntheticAccountApi()
      ..data = (response()..remove('grantEvents'));
    addTearDown(wire.api.close);
    expect(
      (await ApiPointsActivationRepository(wire.api).activate()).grants,
      isEmpty,
    );
    expect(const PointsGrant('FUTURE', 100, '').notice, isNull);
    expect(
      const PointsGrant('daily_login_grant', 7, '').notice,
      contains('✦7'),
    );
  });
  for (final bad in [
    {'walletSummary': null},
    {...response(), 'grantEvents': 'bad'},
    {
      ...response(),
      'grantEvents': [
        {'type': 'INITIAL_GRANT', 'amount': '900', 'businessDate': ''},
      ],
    },
    {
      ...response(),
      'grantEvents': [
        {'type': 'INITIAL_GRANT', 'amount': 900, 'businessDate': null},
      ],
    },
  ]) {
    test('malformed activation is rejected ${bad.hashCode}', () async {
      final wire = SyntheticAccountApi()..data = bad;
      addTearDown(wire.api.close);
      await expectLater(
        ApiPointsActivationRepository(wire.api).activate(),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(wire.requests, hasLength(1));
    });
  }
  test(
    'activation is single flight with one result, success retained per account',
    () async {
      final registry = PointsActivationRegistry();
      final gate = Completer<PointsActivation>();
      var calls = 0;
      Future<PointsActivation> activate() {
        calls++;
        return gate.future;
      }

      final first = registry.activateIfNeeded('a', activate);
      final second = registry.activateIfNeeded('a', activate);
      gate.complete(const PointsActivation(account, []));
      expect(await first, isNotNull);
      expect(await second, isNull);
      expect(await registry.activateIfNeeded('a', activate), isNull);
      expect(calls, 1);
      expect(await registry.activateIfNeeded('b', activate), isNotNull);
      expect(calls, 2);
    },
  );
  test('login mark skips activation and empty owner cannot write', () async {
    final registry = PointsActivationRegistry()..markActivated('a');
    Future<PointsActivation> unexpected() async =>
        throw StateError('must not call');
    expect(await registry.activateIfNeeded('a', unexpected), isNull);
    expect(await registry.activateIfNeeded('', unexpected), isNull);
  });
  test(
    'failed activation can retry only on next explicit invocation',
    () async {
      final registry = PointsActivationRegistry();
      var calls = 0;
      Future<PointsActivation> activate() async {
        if (++calls == 1) throw StateError('offline');
        return const PointsActivation(account, []);
      }

      await expectLater(
        registry.activateIfNeeded('a', activate),
        throwsStateError,
      );
      expect(calls, 1);
      expect(await registry.activateIfNeeded('a', activate), isNotNull);
      expect(calls, 2);
    },
  );
}

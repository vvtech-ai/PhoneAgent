import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/data/api_points_wallet_repository.dart';
import 'package:phone_agent/core/network/account_session.dart';

void main() {
  test('shared wallet sources conserve available and held totals', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/commerce/consumer-fixtures.json',
              ).readAsStringSync(),
            )
            as Map;
    final values = Map<String, Object?>.from(fixture['wallet'] as Map)
      ..addAll({'totalBalance': 175, 'updatedAt': '2026-10-12 12:00:00'});
    final wallet = ApiPointsWalletRepository.parseAccount(values);
    expect(wallet.membershipAvailableBalance, 50);
    expect(wallet.permanentAvailableBalance, 100);
    expect(
      () => ApiPointsWalletRepository.parseAccount({
        ...values,
        'permanentHeldBalance': 6,
      }),
      throwsA(ApiFailure.invalidResponse),
    );
  });
  test(
    'legacy total fields remain compatible without invented member balance',
    () {
      final wallet = ApiPointsWalletRepository.parseAccount({
        'availableBalance': 10,
        'heldBalance': 0,
        'totalBalance': 10,
        'updatedAt': '2026-10-12 12:00:00',
      });
      expect(wallet.membershipAvailableBalance, isNull);
      expect(wallet.permanentAvailableBalance, isNull);
    },
  );
}

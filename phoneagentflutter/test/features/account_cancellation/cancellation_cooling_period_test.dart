import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/account_cancellation/data/api_cancellation_gateway.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';

void main() {
  for (final entry in <int, String>{
    1: '1秒',
    30: '30秒',
    60: '60秒',
    61: '1分钟',
    300: '5分钟',
    3599: '59分钟',
    3600: '60分钟',
    3601: '1小时',
    7200: '2小时',
    86399: '23小时',
    86400: '24小时',
    86401: '1天',
    90000: '1天',
    172800: '2天',
    1296000: '15天',
  }.entries) {
    test('${entry.key} seconds displays ${entry.value}', () {
      expect(cancellationCoolingPeriod(entry.key), entry.value);
    });
  }
  test('formatter never invents a duration for non-positive values', () {
    expect(() => cancellationCoolingPeriod(0), throwsArgumentError);
    expect(() => cancellationCoolingPeriod(-1), throwsArgumentError);
  });
  test(
    'server seconds are parsed; old response leaves duration unspecified',
    () {
      final old = ApiCancellationGateway.decodeConfirmation(_confirmation());
      expect(old.coolingPeriodSeconds, isNull);
      final current = ApiCancellationGateway.decodeConfirmation({
        ..._confirmation(),
        'coolingPeriodSeconds': 300,
      });
      expect(current.coolingPeriodSeconds, 300);
      expect(current.estimatedEffectiveAt, old.estimatedEffectiveAt);
    },
  );
  for (final invalid in <Object?>[null, 0, -1, '300', 300.0, false]) {
    test('malformed cooling seconds $invalid are rejected', () {
      expect(
        () => ApiCancellationGateway.decodeConfirmation({
          ..._confirmation(),
          'coolingPeriodSeconds': invalid,
        }),
        throwsA(ApiFailure.invalidResponse),
      );
    });
  }
}

Map<String, Object?> _confirmation() => {
  'confirmationId': 'confirmation',
  'agreementVersion': '1.0',
  'estimatedEffectiveAt': '2026-10-28T09:05:00Z',
};

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_error_mapping.dart';
import 'package:phone_agent/core/network/account_session.dart';

void main() {
  void map(Map payload, {Set<String> stages = const {}}) =>
      throwAllowedAccountError(
        payload,
        409,
        codes: const {},
        dataCodes: const {'LEDGER_NOT_READY'},
        dataStages: stages,
      );

  test('nested ledger recovery and HTTP status survive integration', () {
    expect(
      () => map({
        'data': {
          'errorCode': 'LEDGER_NOT_READY',
          'retryable': true,
          'recoveryAction': 'WAIT_FOR_MIGRATION',
        },
      }),
      throwsA(
        isA<ApiCodeFailure>()
            .having((e) => e.code, 'code', 'LEDGER_NOT_READY')
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.retryable, 'retryable', true)
            .having((e) => e.recoveryAction, 'action', 'WAIT_FOR_MIGRATION'),
      ),
    );
  });

  test('allowlisted stage keeps incoming behavior with HTTP status', () {
    expect(
      () => map(
        {
          'data': {'stage': 'SYNTHETIC_STAGE', 'message': 'private detail'},
        },
        stages: {'SYNTHETIC_STAGE'},
      ),
      throwsA(
        isA<ApiCodeFailure>()
            .having((e) => e.code, 'code', 'SYNTHETIC_STAGE')
            .having((e) => e.statusCode, 'status', 409),
      ),
    );
    expect(() => map({'message': 'private detail'}), returnsNormally);
  });

  test('flat recovery ignores unknown action and nonboolean retryability', () {
    expect(
      () => map({
        'errorCode': 'LEDGER_NOT_READY',
        'retryable': 'true',
        'recoveryAction': 'private detail',
      }),
      throwsA(
        isA<ApiCodeFailure>()
            .having((e) => e.retryable, 'retryable', null)
            .having((e) => e.recoveryAction, 'action', null),
      ),
    );
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_failure.dart';
import 'package:phone_agent/features/translation/domain/translation_preparation_policy.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';

void main() {
  for (final entry in const {
    'REGISTER_503': '暂时无法接通，请稍后重试',
    'INVITE_500': '暂时无法接通，请稍后重试',
    'INVITE_486': '对方正在通话中',
    'INVITE_600': '对方正在通话中',
    'INVITE_408': '对方暂时无法接通',
    'INVITE_480': '对方暂时无法接通',
    'INVITE_404': '通话未接通，请稍后重试',
    'SIP_NETWORK_UNAVAILABLE': '网络连接异常，请检查网络后重试',
    'INVITE_TIMEOUT': '网络连接异常，请检查网络后重试',
    'CALL_CLEANUP_UNCONFIRMED': '通话未接通，请稍后重试',
    'POINTS_SETTLEMENT_UNCONFIRMED': '通话已结束，但结算结果暂不可用，请稍后查看积分流水',
    'BUSY': '对方正在通话中',
    'TEMPORARILY_UNAVAILABLE': '对方暂时无法接通',
    'SERVICE_UNAVAILABLE': '暂时无法接通，请稍后重试',
    'synthetic private remote error': '通话未接通，请稍后重试',
  }.entries) {
    test('native classification for ${entry.key}', () {
      expect(translationCallFailureMessage(entry.key), entry.value);
    });
  }
  test(
    'structured SIP code survives while untrusted exception text does not',
    () {
      expect(
        translationFailureCode(const SipLeaseFailure('INVITE_486')),
        'INVITE_486',
      );
      expect(translationFailureCode(StateError('private')), 'UNKNOWN');
    },
  );
  test(
    'overseas failure wording uses native policy for every preparation stage',
    () {
      for (final stage in [
        'overseasLanguages',
        'overseasCreate',
        'overseasMedia',
        'overseasDial',
      ]) {
        expect(
          translationPreparationMessage(stage, TimeoutException('private')),
          '网络连接异常，请检查网络后重试',
        );
        expect(
          translationPreparationMessage(
            stage,
            const TranslationBackendFailure('BUSY'),
          ),
          '对方正在通话中',
        );
        expect(
          translationPreparationMessage(
            stage,
            const TranslationBackendFailure('INVALID_RESPONSE', status: 403),
          ),
          '通话未接通，请稍后重试',
        );
      }
    },
  );
}

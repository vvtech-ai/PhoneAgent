import 'dart:async';
import 'sip/sip_lease.dart';
import 'translation_backend_session.dart';

/// Android CallFailureClassifier / CallFailureUserMessagePolicy parity.
/// Accept structured codes only; never display arbitrary server text.
String translationCallFailureMessage(String code) {
  final value = code.toUpperCase();
  if (value == 'POINTS_SETTLEMENT_UNCONFIRMED') {
    return '通话已结束，但结算结果暂不可用，请稍后查看积分流水';
  }
  final sip = RegExp(r'^(?:REGISTER|INVITE)_(\d{3})$').firstMatch(value);
  final status = sip == null ? null : int.parse(sip.group(1)!);
  if ((status != null && status >= 500 && status <= 599) ||
      value == 'SERVICE_UNAVAILABLE') {
    return '暂时无法接通，请稍后重试';
  }
  if (status == 486 || status == 600 || value == 'BUSY') {
    return '对方正在通话中';
  }
  if (status == 408 || status == 480 || value == 'TEMPORARILY_UNAVAILABLE') {
    return '对方暂时无法接通';
  }
  if (const {
    'NETWORK',
    'TIMEOUT',
    'REGISTER_TIMEOUT',
    'INVITE_TIMEOUT',
    'SIP_NETWORK_UNAVAILABLE',
    'SIP_SEND_FAILED',
    'SIP_WIRE_CLOSED',
    'SIP_CONNECTION_LOST',
  }.contains(value)) {
    return '网络连接异常，请检查网络后重试';
  }
  return '通话未接通，请稍后重试';
}

String translationFailureCode(Object error) => switch (error) {
  SipLeaseFailure() => error.code,
  TranslationBackendFailure() => error.code,
  TimeoutException() => 'NETWORK',
  _ => 'UNKNOWN',
};

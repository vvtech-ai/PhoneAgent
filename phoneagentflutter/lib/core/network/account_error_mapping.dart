import 'account_session.dart';

bool accountSignatureRejected(
  Object? value, {
  int statusCode = 0,
  Set<String> allowedStages = const {},
}) =>
    value is Map &&
    const {'AC0001', 'AC0007', 'AC0008', 'AC0009'}.contains(value['code']) &&
    !(value['code'] == 'AC0001' &&
        statusCode == 400 &&
        value['data'] is Map &&
        allowedStages.contains(value['data']['stage']));

typedef AccountErrorMessageMapper =
    String? Function(Object? code, Object? message);

String? projectAccountRequestError(
  Object? payload,
  int statusCode,
  AccountErrorMessageMapper? mapper,
  Set<String> allowedStages,
) {
  final message = projectAccountErrorMessage(payload, statusCode, mapper);
  if (message == null &&
      accountSignatureRejected(
        payload,
        statusCode: statusCode,
        allowedStages: allowedStages,
      )) {
    throw ApiFailure.rejected;
  }
  return message;
}

/// Endpoint opt-in only; success, authentication and server failures stay opaque.
String? projectAccountErrorMessage(
  Object? payload,
  int statusCode,
  AccountErrorMessageMapper? mapper,
) {
  if (mapper == null ||
      payload is! Map ||
      statusCode < 200 ||
      statusCode >= 500 ||
      statusCode == 401 ||
      statusCode == 403 ||
      const {
        0,
        '000000',
        'AC0007',
        'AC0008',
        'AC0009',
      }.contains(payload['code'])) {
    return null;
  }
  return mapper(payload['code'], payload['message']);
}

/// Exposes only caller-allowlisted codes and bounded recovery metadata.
void throwAllowedAccountError(
  Map payload,
  int statusCode, {
  required Set<String> codes,
  required Set<String> dataCodes,
  required Set<String> dataStages,
  String? projectedMessage,
}) {
  if (projectedMessage != null) {
    throw ApiCodeFailure(projectedMessage, statusCode: statusCode);
  }
  for (final code in [payload['code'], payload['message']]) {
    if (code is String && codes.contains(code)) {
      throw ApiCodeFailure(code, statusCode: statusCode);
    }
  }
  final detail = payload['data'] is Map ? payload['data'] as Map : payload;
  final stage = detail['stage'];
  if (stage is String && dataStages.contains(stage)) {
    throw ApiCodeFailure(stage, statusCode: statusCode);
  }
  final code = detail['errorCode'];
  if (code is String && dataCodes.contains(code)) {
    final action = detail['recoveryAction'];
    throw ApiCodeFailure(
      code,
      statusCode: statusCode,
      retryable: detail['retryable'] is bool
          ? detail['retryable'] as bool
          : null,
      recoveryAction:
          const {
            'NONE',
            'RETRY',
            'FULL_RESYNC',
            'WAIT_FOR_MIGRATION',
          }.contains(action)
          ? action as String
          : null,
    );
  }
}

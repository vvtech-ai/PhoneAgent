import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/account_cancellation.dart';

class ApiCancellationGateway implements CancellationGateway {
  const ApiCancellationGateway(this.api, this.recover);
  final AccountApi api;
  final Future<CancellationResult> Function(
    String queryToken,
    String operationId,
  )
  recover;
  static const path = 'api/account/cancellation';
  @override
  Future<CancellationConfirmation> confirmation() async {
    return decodeConfirmation(await _request('$path/confirmation'));
  }

  static const _businessFailures = <String, CancellationFailure>{
    '账号注销暂不可用，请稍后重试': CancellationFailure.unavailable,
    '账号注销协议尚未发布': CancellationFailure.agreementUnavailable,
    '验证码不正确': CancellationFailure.incorrectCode,
    '验证码已过期，请重新获取': CancellationFailure.codeExpired,
    '验证码已失效，请重新获取': CancellationFailure.codeExpired,
    '验证码错误次数过多，请重新获取': CancellationFailure.codeExpired,
    '验证已过期，请重新获取验证码': CancellationFailure.verificationExpired,
    '验证身份不匹配，请重新验证': CancellationFailure.verificationExpired,
    '确认已过期，请重新确认注销': CancellationFailure.confirmationExpired,
    '协议已更新，请重新确认注销': CancellationFailure.agreementChanged,
    '验证码发送太频繁，请稍后重试': CancellationFailure.rateLimited,
    '账号状态已变化，请重新登录': CancellationFailure.accountChanged,
    '请先结束进行中的通话、任务或支付，再申请注销': CancellationFailure.inFlight,
    '当前有通话正在进行，请先结束通话，再申请注销': CancellationFailure.inFlight,
    '正在确认通话结束状态，请稍后重试': CancellationFailure.callStateUnknown,
  };

  Future<Object?> _request(
    String endpoint, {
    String method = 'GET',
    Object? body,
  }) async {
    try {
      return await api.request(
        endpoint,
        method: method,
        body: body,
        exposedCodes: _businessFailures.keys.toSet(),
        exposedMessage: (code, message) => code == 'AC0001' && message is String
            ? _businessFailures[message]?.name
            : null,
      );
    } on ApiCodeFailure catch (failure) {
      // A 5xx response cannot prove rejection even if it contains familiar text.
      if (failure.statusCode >= 500) throw CancellationFailure.network;
      final known =
          _businessFailures[failure.code] ??
          CancellationFailure.values
              .where((value) => value.name == failure.code)
              .firstOrNull;
      if (known != null) throw known;
      rethrow;
    } on ApiFailure catch (failure) {
      if (failure == ApiFailure.network) throw CancellationFailure.network;
      if (failure == ApiFailure.sessionChanged ||
          failure == ApiFailure.signedOut) {
        throw CancellationFailure.accountChanged;
      }
      rethrow;
    }
  }

  static CancellationConfirmation decodeConfirmation(Object? value) {
    final dto = AccountApi.object(value);
    final seconds = dto['coolingPeriodSeconds'];
    if (dto.containsKey('coolingPeriodSeconds') &&
        (seconds is! int || seconds <= 0)) {
      throw ApiFailure.invalidResponse;
    }
    return CancellationConfirmation(
      text(dto, 'confirmationId'),
      text(dto, 'agreementVersion'),
      accountCancellationAgreementUrl,
      date(dto, 'estimatedEffectiveAt'),
      coolingPeriodSeconds: seconds as int?,
    );
  }

  @override
  Future<CancellationDelivery> send(
    CancellationConfirmation confirmation,
    String operationId,
  ) async {
    final dto = AccountApi.object(
      await _request(
        '$path/sms/send',
        method: 'POST',
        body: {
          'confirmationId': confirmation.id,
          'agreementVersion': confirmation.agreementVersion,
          'operationId': operationId,
        },
      ),
    );
    final seconds = dto['resendCooldownSeconds'];
    if (seconds is! int || seconds < 1) throw ApiFailure.invalidResponse;
    return CancellationDelivery(
      text(dto, 'challengeId'),
      text(dto, 'queryToken'),
      text(dto, 'maskedPhone'),
      seconds,
    );
  }

  @override
  Future<CancellationVerification> verify(
    CancellationDelivery delivery,
    String operationId,
    String code,
  ) async {
    final dto = AccountApi.object(
      await _request(
        '$path/sms/verify',
        method: 'POST',
        body: {
          'challengeId': delivery.challengeId,
          'queryToken': delivery.queryToken,
          'operationId': operationId,
          'code': code,
        },
      ),
    );
    return CancellationVerification(
      text(dto, 'verificationToken'),
      date(dto, 'expiresAt'),
      decodeConfirmation(dto['confirmation']),
    );
  }

  @override
  Future<CancellationResult> submit(
    CancellationDelivery delivery,
    String operationId,
    String verificationToken,
  ) async => decodeResult(
    await _request(
      '$path/applications',
      method: 'POST',
      body: {
        'challengeId': delivery.challengeId,
        'queryToken': delivery.queryToken,
        'operationId': operationId,
        'verificationToken': verificationToken,
      },
    ),
  );
  @override
  Future<CancellationResult> lookup(
    CancellationDelivery delivery,
    String operationId,
  ) => recover(delivery.queryToken, operationId);

  static CancellationResult decodeResult(Object? value) {
    final dto = AccountApi.object(value);
    final status = text(dto, 'status');
    if (!const {
      'PENDING',
      'FINALIZED',
      'REVOKED',
      'NOT_SUBMITTED',
    }.contains(status)) {
      throw ApiFailure.invalidResponse;
    }
    return CancellationResult(
      status == 'NOT_SUBMITTED' ? '' : text(dto, 'applicationId'),
      status,
      status == 'NOT_SUBMITTED' ? null : date(dto, 'effectiveAt'),
    );
  }

  static String text(Map<String, dynamic> dto, String key) {
    final value = dto[key];
    if (value is! String || value.isEmpty) throw ApiFailure.invalidResponse;
    return value;
  }

  static DateTime date(Map<String, dynamic> dto, String key) {
    final value = DateTime.tryParse(text(dto, key));
    if (value == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text(dto, key))) {
      throw ApiFailure.invalidResponse;
    }
    return value;
  }
}

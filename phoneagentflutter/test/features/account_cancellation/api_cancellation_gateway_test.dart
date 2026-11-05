import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/account_cancellation/data/api_cancellation_gateway.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  for (final address in [null, 'https://example.test/other', 'invalid']) {
    test('agreement address is fixed despite response value $address', () {
      final confirmation = ApiCancellationGateway.decodeConfirmation({
        'confirmationId': 'confirmation',
        'agreementVersion': '1.0',
        if (address != null) 'agreementUrl': address,
        'estimatedEffectiveAt': '2026-11-11T06:00:00Z',
      });
      expect(confirmation.agreementUrl, accountCancellationAgreementUrl);
      expect(confirmation.agreementVersion, '1.0');
    });
  }
  test(
    'verification and final submission use distinct requests; code is not resubmitted',
    () async {
      final transport = SyntheticAccountApi();
      addTearDown(transport.api.close);
      final gateway = ApiCancellationGateway(
        transport.api,
        (_, __) async => const CancellationResult('', 'NOT_SUBMITTED', null),
      );
      transport.data = {
        'verificationToken': 'synthetic-proof',
        'expiresAt': '2026-10-27T06:10:00Z',
        'confirmation': {
          'confirmationId': 'confirmation',
          'agreementVersion': 'v1',
          'agreementUrl': 'https://example.test/agreement',
          'estimatedEffectiveAt': '2026-11-11T06:00:00Z',
          'coolingPeriodSeconds': 300,
        },
      };
      const delivery = CancellationDelivery(
        'sms',
        'synthetic-query',
        '138****0000',
        60,
      );
      final verification = await gateway.verify(
        delivery,
        'operation',
        '123456',
      );
      expect(
        transport.requests.single.path,
        endsWith('/api/account/cancellation/sms/verify'),
      );
      expect((transport.requests.single.data as Map)['code'], '123456');
      expect(verification.confirmation.agreementVersion, 'v1');
      expect(verification.confirmation.coolingPeriodSeconds, 300);
      transport.data = {
        'applicationId': 'application',
        'status': 'PENDING',
        'effectiveAt': '2026-11-11T06:00:00Z',
      };
      await gateway.submit(delivery, 'operation', verification.token);
      expect(
        transport.requests.last.path,
        endsWith('/api/account/cancellation/applications'),
      );
      final submitted = transport.requests.last.data as Map;
      expect(submitted['verificationToken'], 'synthetic-proof');
      expect(submitted.containsKey('code'), isFalse);
      expect(submitted['operationId'], 'operation');
    },
  );
  for (final entry in <String, CancellationFailure>{
    '账号注销暂不可用，请稍后重试': CancellationFailure.unavailable,
    '账号注销协议尚未发布': CancellationFailure.agreementUnavailable,
    '验证码不正确': CancellationFailure.incorrectCode,
    '验证码已过期，请重新获取': CancellationFailure.codeExpired,
    '验证已过期，请重新获取验证码': CancellationFailure.verificationExpired,
    '协议已更新，请重新确认注销': CancellationFailure.agreementChanged,
    '请先结束进行中的通话、任务或支付，再申请注销': CancellationFailure.inFlight,
    '当前有通话正在进行，请先结束通话，再申请注销': CancellationFailure.inFlight,
    '正在确认通话结束状态，请稍后重试': CancellationFailure.callStateUnknown,
  }.entries) {
    test(
      'projects allowlisted business category ${entry.value.name}',
      () async {
        final transport = _FailureApi(
          entry.key,
          entry.value == CancellationFailure.inFlight ||
                  entry.value == CancellationFailure.callStateUnknown
              ? 403
              : 400,
        );
        addTearDown(transport.api.close);
        final gateway = ApiCancellationGateway(
          transport.api,
          (_, __) async => const CancellationResult('', 'NOT_SUBMITTED', null),
        );
        await expectLater(gateway.confirmation(), throwsA(entry.value));
      },
    );
  }
  for (final status in [400, 404, 500]) {
    test('unknown error text stays opaque at status $status', () async {
      final transport = _FailureApi(
        'private backend exception and credentials must stay hidden',
        status,
      );
      addTearDown(transport.api.close);
      final gateway = ApiCancellationGateway(
        transport.api,
        (_, __) async => const CancellationResult('', 'NOT_SUBMITTED', null),
      );
      await expectLater(
        gateway.confirmation(),
        throwsA(isNot(isA<CancellationFailure>())),
      );
    });
  }
  test('malformed verification data never grants a usable proof', () async {
    final transport = SyntheticAccountApi();
    addTearDown(transport.api.close);
    final gateway = ApiCancellationGateway(
      transport.api,
      (_, __) async => const CancellationResult('', 'NOT_SUBMITTED', null),
    );
    transport.data = {
      'verificationToken': 'synthetic-proof',
      'expiresAt': '2026-10-27T06:10:00',
      'confirmation': {},
    };
    await expectLater(
      gateway.verify(
        const CancellationDelivery('sms', 'query', '138****0000', 60),
        'operation',
        '123456',
      ),
      throwsA(ApiFailure.invalidResponse),
    );
  });
}

class _FailureApi extends SyntheticAccountApi {
  _FailureApi(this.message, this.responseStatus);
  final String message;
  final int responseStatus;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode({
        'code': responseStatus == 403 ? 'AC0003' : 'AC0001',
        'message': message,
      }),
      responseStatus,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

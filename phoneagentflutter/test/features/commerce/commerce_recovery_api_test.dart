import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'commerce_recovery_transport.dart';
import 'fake_commerce_repository.dart';

void main() {
  test('payment HTTP failures never use a null 404 fallback', () async {
    final server = CommerceRecoveryTransport();
    addTearDown(server.api.close);
    final repo = ApiCommerceRepository(server.api);
    final quote = await repo.quote('BASIC', 1);
    for (final status in [500, 502, 503, 504]) {
      server.overrideStatus = status;
      for (final action in [
        () => repo.payment('order-1'),
        () => repo.createOrder(quote, 'request-second', 'v1'),
        () => repo.closeOrder('order-1', 'close-request'),
      ]) {
        await expectLater(
          action(),
          throwsA(
            isA<CommerceFailure>()
                .having(
                  (e) => e.code,
                  'safe cause',
                  'COMMERCE_SERVICE_UNAVAILABLE',
                )
                .having((e) => e.httpStatus, 'HTTP preserved', status),
          ),
        );
      }
    }
  });
  test(
    'material cap survives original query and prevents native launch',
    () async {
      final server = CommerceRecoveryTransport()
        ..errorCode = 'COMMERCE_MATERIAL_LIMIT_REACHED'
        ..errorPath = '/payment'
        ..payment = 'PROCESSING'
        ..fulfillment = 'NOT_STARTED';
      addTearDown(server.api.close);
      final native = FakePaymentLauncher();
      final purchase = PurchaseController(
        ApiCommerceRepository(server.api),
        native,
        paymentChannel: 'ALIPAY',
      );
      addTearDown(purchase.dispose);
      await purchase.preview('BASIC', 1, agreementAccepted: true);
      await purchase.confirmPurchase('v1');
      expect(purchase.snapshot.order?.orderNo, 'order-1');
      expect(purchase.snapshot.error, '支付操作过于频繁，本订单支付重试次数已达上限，请查询原订单');
      expect(native.launches, 0);
      server
        ..payment = 'SUCCEEDED'
        ..fulfillment = 'SUCCEEDED';
      await purchase.query('order-1');
      expect(purchase.snapshot.error, isEmpty);
      expect(purchase.snapshot.order?.unresolved, isFalse);
      expect(server.creates, 1);
    },
  );
  for (final code in [
    'COMMERCE_ORDER_MINUTE_LIMITED',
    'COMMERCE_ORDER_HOUR_LIMITED',
    'COMMERCE_MATERIAL_INTERVAL_LIMITED',
    'COMMERCE_MATERIAL_LIMIT_REACHED',
    'MEMBERSHIP_PAYMENT_UNKNOWN',
    'MEMBERSHIP_STATE_CONFLICT',
  ]) {
    test('wire $code retains safe recovery without provider body', () async {
      final server = CommerceRecoveryTransport()..errorCode = code;
      addTearDown(server.api.close);
      await expectLater(
        ApiCommerceRepository(server.api).payment('order-1'),
        throwsA(
          isA<CommerceFailure>()
              .having((e) => e.code, 'code', code)
              .having(
                (e) => e.message,
                'private text',
                isNot(contains('private')),
              ),
        ),
      );
    });
  }
  for (final code in [null, 'AC0006', 'MEMBERSHIP_PAYMENT_UNKNOWN']) {
    test(
      '502 has priority over envelope $code on quote and original query',
      () async {
        final server = CommerceRecoveryTransport()
          ..quoteStatus = 502
          ..queryStatus = 502
          ..errorCode = code;
        addTearDown(server.api.close);
        final repo = ApiCommerceRepository(server.api);
        for (final action in [
          () => repo.quote('BASIC', 1),
          () => repo.order('order-1'),
        ]) {
          await expectLater(
            action(),
            throwsA(
              isA<CommerceFailure>().having(
                (e) => e.code,
                'safe cause',
                'COMMERCE_SERVICE_UNAVAILABLE',
              ),
            ),
          );
        }
      },
    );
  }
  test('network is distinct and account conflicts remain unexposed', () async {
    final server = CommerceRecoveryTransport()..networkFailure = true;
    addTearDown(server.api.close);
    final repo = ApiCommerceRepository(server.api);
    await expectLater(
      repo.quote('BASIC', 1),
      throwsA(
        isA<CommerceFailure>().having(
          (e) => e.code,
          'network',
          'COMMERCE_NETWORK_UNAVAILABLE',
        ),
      ),
    );
    server
      ..networkFailure = false
      ..errorCode = 'AC0005';
    await expectLater(repo.quote('BASIC', 1), throwsA(ApiFailure.rejected));
  });
  for (final type in ['renew', 'upgrade', 'lower_queued']) {
    test(
      'completed then quote502 recovers immediately to independent $type',
      () async {
        final server = CommerceRecoveryTransport()
          ..nextType = type
          ..firstType = switch (type) {
            'renew' => 'renew',
            'upgrade' => 'new',
            _ => 'upgrade',
          };
        final firstLevel = type == 'upgrade' ? 'BASIC' : 'PREMIUM';
        final targetLevel = type == 'lower_queued' ? 'BASIC' : 'PREMIUM';
        addTearDown(server.api.close);
        final native = FakePaymentLauncher();
        final controller = PurchaseController(
          ApiCommerceRepository(server.api),
          native,
          paymentChannel: 'ALIPAY',
        );
        addTearDown(controller.dispose);
        await controller.preview(firstLevel, 1, agreementAccepted: true);
        await controller.confirmPurchase('v1');
        expect(controller.snapshot.order?.fulfillmentState, 'SUCCEEDED');
        expect(
          controller.snapshot.order?.membershipFulfillment?.entitlementState,
          type == 'renew' ? 'QUEUED' : 'ACTIVE',
        );
        expect(controller.snapshot.order?.membershipLevel, firstLevel);
        server.quoteStatus = 502;
        await controller.preview(targetLevel, 1, agreementAccepted: true);
        expect(controller.snapshot.error, '支付服务暂不可用，请稍后重试');
        expect(server.creates, 1);
        expect(native.launches, 1);
        server.quoteStatus = 200;
        await controller.preview(targetLevel, 1, agreementAccepted: true);
        expect(controller.snapshot.quote?.purchaseType, type.toUpperCase());
        expect(controller.snapshot.quote?.productId, targetLevel);
        expect(
          controller.snapshot.quote?.membershipPreview?.targetLevel,
          targetLevel,
        );
        expect(server.creates, 1);
        await controller.confirmPurchase('v1');
        expect(server.requestIds.toSet(), hasLength(2));
        expect(server.materialOrders, ['order-1', 'order-2']);
        expect(controller.snapshot.order?.orderNo, 'order-2');
        expect(controller.snapshot.order?.membershipLevel, targetLevel);
        expect(native.launches, 2);
      },
    );
  }
}

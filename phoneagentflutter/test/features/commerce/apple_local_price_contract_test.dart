import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/commerce_payment');
  const launcher = DevicePaymentLauncher();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final displayPrice in ['US\$4.99', '¥300', 'KWD 1.234']) {
    test(
      '$displayPrice stays localized; launch requires no CNY price parameters',
      () async {
        Object? arguments;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'products') {
            return [
              {'id': 'discount-sku', 'displayPrice': displayPrice},
            ];
          }
          if (call.method == 'launch') {
            arguments = call.arguments;
            return {'nativeOutcome': 'PENDING'};
          }
          return true;
        });
        final material = CommerceDto.payment({
          'channel': 'APPLE_IAP',
          'orderNo': 'order-1',
          'expiresAt': '2099-01-01 00:00:00',
          'parameters': {
            'platformProductId': 'discount-sku',
            'appAccountToken': 'synthetic-binding',
          },
        });
        expect(
          (await launcher.products({
            'discount-sku',
          }))['discount-sku']?.displayPrice,
          displayPrice,
        );
        await launcher.launch(material);
        expect((arguments as Map)['parameters'], material.parameters);
      },
    );
  }

  for (final paymentChannel in ['APPLE_IAP', 'ALIPAY']) {
    test('$paymentChannel has no special CNY price error mapping', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          throw PlatformException(
            code: 'APPLE_PRICE_UNAVAILABLE',
            message: 'unsafe native details',
          );
        }
        return true;
      });
      final operation = launcher.launch(
        PaymentMaterial(
          channel: paymentChannel,
          orderNo: 'order-1',
          expiresAt: DateTime(2099),
          parameters: const {},
        ),
      );
      await expectLater(operation, throwsA(isA<PlatformException>()));
    });
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('local_ios_price_test');
  const bridge = DevicePaymentLauncher(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'exact decimal, currency and type cross the bridge without localized text parsing',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'available'
            ? true
            : [
                {
                  'id': 'sku',
                  'displayPrice': 'CN¥6.00',
                  'price': '6.000',
                  'currencyCode': 'CNY',
                  'productType': 'consumable',
                },
              ],
      );
      final product = (await bridge.products({'sku'}))['sku']!;
      expect(product.displayPrice, 'CN¥6.00');
      expect(product.price, '6.000');
      expect(product.currencyCode, 'CNY');
      expect(product.supports('POINTS_PACK'), true);
    },
  );
  test(
    'null or empty localized price is a query failure, not an absent SKU',
    () async {
      for (final payload in [
        null,
        [
          {'id': 'sku', 'displayPrice': ''},
        ],
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'available' ? true : payload,
        );
        await expectLater(bridge.products({'sku'}), throwsFormatException);
      }
    },
  );
  test(
    'native pre-purchase price change maps to a safe refresh failure',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'available') return true;
        throw PlatformException(
          code: 'PRICE_CHANGED',
          message: 'ignored provider data',
        );
      });
      await expectLater(
        bridge.launch(
          PaymentMaterial(
            channel: 'APPLE_IAP',
            orderNo: 'local-order',
            expiresAt: DateTime(2099),
            parameters: const {},
          ),
        ),
        throwsA(
          isA<CommerceFailure>().having(
            (e) => e.code,
            'code',
            'APPLE_PRICE_CHANGED',
          ),
        ),
      );
    },
  );
}

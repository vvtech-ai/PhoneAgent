import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/commerce_payment');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('missing native bridge keeps channel unavailable', () async {
    final launcher = DevicePaymentLauncher();
    expect(await launcher.available(), isFalse);
    expect(await launcher.products({'product-1'}), isEmpty);
  });
  test(
    'native success is only transaction material not completed order',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          return {
            'transactionId': 'transaction-1',
            'signedTransaction': 'synthetic',
            'appAccountToken': 'binding-1',
          };
        }
        return true;
      });
      final result = await DevicePaymentLauncher().launch(
        PaymentMaterial(
          channel: 'APPLE_IAP',
          orderNo: 'order-1',
          expiresAt: DateTime(2099),
          parameters: const {
            'platformProductId': 'product-1',
            'appAccountToken': 'binding-1',
          },
        ),
      );
      expect(result.transactionId, 'transaction-1');
    },
  );
  test(
    'server Alipay environment reaches native without APP_ENV inference',
    () async {
      for (final environment in ['SANDBOX', 'PRODUCTION']) {
        Object? nativeArguments;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            nativeArguments = call.arguments;
            return <String, Object?>{};
          }
          return true;
        });
        final material = CommerceDto.payment({
          'channel': 'ALIPAY',
          'orderNo': 'order-1',
          'expiresAt': '2099-01-01 00:00:00',
          'parameters': {
            'signedOrder': 'synthetic-signed-material',
            'environment': environment,
          },
        });
        final result = await DevicePaymentLauncher().launch(material);
        expect(nativeArguments, {
          'channel': 'ALIPAY',
          'orderNo': 'order-1',
          'parameters': {
            'signedOrder': 'synthetic-signed-material',
            'environment': environment,
          },
        });
        expect(result.transactionId, isNull);
      }
    },
  );
}

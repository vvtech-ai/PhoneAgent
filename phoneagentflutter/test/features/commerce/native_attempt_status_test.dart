import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/commerce_payment');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  final material = PaymentMaterial(
    channel: 'ALIPAY',
    orderNo: 'synthetic-order',
    expiresAt: DateTime(2099),
    parameters: const {'signedOrder': 'synthetic'},
  );
  test(
    'numeric attempt status crosses bridge without becoming a transaction',
    () async {
      for (final code in ['6001', '4000', '9000', '8000', '6004']) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'launch'
              ? {'nativeResultStatus': code, 'memo': 'synthetic ignored'}
              : true,
        );
        final result = await const DevicePaymentLauncher().launch(material);
        expect(result.nativeResultStatus, code);
        expect(result.transactionId, isNull);
      }
    },
  );
  test(
    'missing status is unknown and malformed status is protocol failure',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'launch' ? {} : true,
      );
      expect(
        (await const DevicePaymentLauncher().launch(
          material,
        )).nativeResultStatus,
        isNull,
      );
      for (final value in [6001, ' 6001', '6001memo', '６００１']) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'launch' ? {'nativeResultStatus': value} : true,
        );
        await expectLater(
          const DevicePaymentLauncher().launch(material),
          throwsFormatException,
        );
      }
    },
  );
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'existing Apple transactions remain discoverable when new purchases are disabled',
    () async {
      const channel = MethodChannel('apple-discovery-permission-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return switch (call.method) {
          'available' => false,
          'restore' => [
            {
              'transactionId': '123',
              'signedTransaction': 'jws',
              'appAccountToken': 'original',
            },
          ],
          _ => null,
        };
      });
      try {
        const native = DevicePaymentLauncher(
          channel: channel,
          discoverWithoutPurchasePermission: true,
        );
        expect(await native.available(), false);
        expect((await native.restore()).single.transactionId, '123');
        expect(methods, ['available', 'restore']);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );
}

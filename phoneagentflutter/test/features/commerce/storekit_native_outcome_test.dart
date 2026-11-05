import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/commerce_payment');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final material = PaymentMaterial(
    channel: 'APPLE_IAP',
    orderNo: 'synthetic-order',
    expiresAt: DateTime(2099),
    parameters: const {
      'platformProductId': 'synthetic-product',
      'appAccountToken': 'synthetic-binding',
    },
  );
  void respond(Map<String, Object?> value) {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'launch' ? value : true,
    );
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final pair in {'CANCELED': 'canceled', 'PENDING': 'pending'}.entries) {
    test('${pair.key} is an attempt outcome, not a transaction', () async {
      respond({'nativeOutcome': pair.key});
      final result = await const DevicePaymentLauncher().launch(material);
      expect(result.nativeOutcome?.name, pair.value);
      expect(result.transactionId, isNull);
      expect(result.signedTransaction, isNull);
      expect(result.nativeResultStatus, isNull);
    });
  }
  test('old bridge missing or null outcome remains unknown', () async {
    for (final value in <Map<String, Object?>>[
      {},
      {'nativeOutcome': null},
    ]) {
      respond(value);
      final result = await const DevicePaymentLauncher().launch(material);
      expect(result.nativeOutcome, isNull);
      expect(result.transactionId, isNull);
    }
  });
  test('unknown and malformed outcomes are protocol failures', () async {
    for (final value in [1, true, {}, 'SUCCESS', 'canceled', ' PENDING']) {
      respond({'nativeOutcome': value});
      await expectLater(
        const DevicePaymentLauncher().launch(material),
        throwsFormatException,
      );
    }
  });
}

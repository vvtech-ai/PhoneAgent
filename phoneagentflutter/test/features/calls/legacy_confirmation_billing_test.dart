import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/confirmation_billing.dart';
import 'package:phone_agent/features/calls/data/device_legacy_confirmation_billing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = DeviceLegacyConfirmationBilling();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final request = ConfirmationBillingRequest('s', ['tool']);
  tearDown(
    () => messenger.setMockMethodCallHandler(
      DeviceLegacyConfirmationBilling.channel,
      null,
    ),
  );
  test(
    'scoped old key precedes legacy alias key; missing scoped uses old shape',
    () async {
      var scoped = true;
      messenger.setMockMethodCallHandler(
        DeviceLegacyConfirmationBilling.channel,
        (call) async {
          final args = call.arguments as Map;
          expect(args.keys, ['keys']);
          final keys = args['keys'] as List;
          expect(
            keys.first,
            '1e0eef211fb5804eafbae5c38a3fb3267edf5d83ced77dcd9168ca061227a719',
          );
          expect(keys.length, 2);
          return {
            'version': 1,
            'snapshots': {
              keys[0]: scoped
                  ? jsonEncode({'modelTitle': 'Doubao', 'availableBalance': 5})
                  : null,
              keys[1]: jsonEncode({
                'modelTitle': 'Qwen',
                'availableBalance': 42,
              }),
            },
          };
        },
      );
      expect((await source.read('a', request))!.availableBalance, 5);
      scoped = false;
      expect((await source.read('a', request))!.availableBalance, 42);
    },
  );
  test(
    'null nonproduction source and absent old keys do not invent snapshots',
    () async {
      messenger.setMockMethodCallHandler(
        DeviceLegacyConfirmationBilling.channel,
        (_) async => null,
      );
      expect(await source.read('a', request), isNull);
      messenger.setMockMethodCallHandler(
        DeviceLegacyConfirmationBilling.channel,
        (call) async => {
          'version': 1,
          'snapshots': {
            for (final key in (call.arguments as Map)['keys'] as List)
              key: null,
          },
        },
      );
      expect(await source.read('a', request), isNull);
    },
  );
  test(
    'malformed key set, type, JSON, values and version fail instead of using defaults',
    () async {
      for (final bad in [
        true,
        'invalid-json',
        '{"availableBalance":"10"}',
        'x' * 4097,
      ]) {
        messenger.setMockMethodCallHandler(
          DeviceLegacyConfirmationBilling.channel,
          (call) async => {
            'version': 1,
            'snapshots': {
              for (final key in (call.arguments as Map)['keys'] as List)
                key: bad,
            },
          },
        );
        await expectLater(source.read('a', request), throwsFormatException);
      }
      for (final value in [
        {'version': 2},
        {
          'version': 1,
          'snapshots': {'foreign': null},
        },
      ]) {
        messenger.setMockMethodCallHandler(
          DeviceLegacyConfirmationBilling.channel,
          (_) async => value,
        );
        await expectLater(source.read('a', request), throwsFormatException);
      }
    },
  );
}

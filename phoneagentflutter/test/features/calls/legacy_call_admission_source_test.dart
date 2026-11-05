import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/device_legacy_call_admission_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const source = DeviceLegacyCallAdmissionSource();
  final channel = DeviceLegacyCallAdmissionSource.channel;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'fixed v65 NUL-separated hash, only digests cross native boundary',
    () async {
      final calls = <List<String>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'read');
        final args = call.arguments as Map;
        expect(args.keys, ['keys']);
        final keys = List<String>.from(args['keys'] as List);
        calls.add(keys);
        expect(
          keys.every((key) => RegExp(r'^[a-f0-9]{64}$').hasMatch(key)),
          true,
        );
        return {
          'version': 1,
          'markers': {for (final key in keys) key: true},
        };
      });
      expect(await source.read('a', 's', ['tool']), {'tool'});
      expect(
        calls.single.single,
        '1e0eef211fb5804eafbae5c38a3fb3267edf5d83ced77dcd9168ca061227a719',
      );
      const alias = 'task-confirmation-v1\u00001\u0000合成\u001e文本';
      expect(await source.read('a', 's', [alias, alias]), {alias});
      await source.read('b', 's', ['tool']);
      await source.read('a', 'other', ['tool']);
      expect(calls.map((items) => items.single).toSet().length, 4);
    },
  );
  test(
    'nonproduction null and false do not invent markers; exact response required',
    () async {
      Object? response;
      messenger.setMockMethodCallHandler(channel, (_) async => response);
      expect(await source.read('a', 's', ['tool']), isEmpty);
      const hash =
          '1e0eef211fb5804eafbae5c38a3fb3267edf5d83ced77dcd9168ca061227a719';
      response = {
        'version': 1,
        'markers': {hash: false},
      };
      expect(await source.read('a', 's', ['tool']), isEmpty);
      for (final bad in [
        {
          'version': 2,
          'markers': {hash: true},
        },
        {'version': 1, 'markers': {}},
        {
          'version': 1,
          'markers': {hash: 1},
        },
        {
          'version': 1,
          'markers': {hash: true, 'foreign': true},
        },
        {
          'version': 1,
          'markers': {'foreign': true},
        },
      ]) {
        response = bad;
        await expectLater(
          source.read('a', 's', ['tool']),
          throwsFormatException,
        );
      }
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await expectLater(
        source.read('a', 's', ['tool']),
        throwsA(isA<PlatformException>()),
      );
    },
  );
  test(
    'invalid scope and excessive requests fail before platform reads',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => fail('No native request'),
      );
      for (final account in ['', 'a\u0000b']) {
        await expectLater(
          source.read(account, 's', ['tool']),
          throwsArgumentError,
        );
      }
      for (final aliases in [
        <String>[],
        [''],
        List.generate(1025, (i) => '$i'),
      ]) {
        await expectLater(source.read('a', 's', aliases), throwsArgumentError);
      }
    },
  );
}

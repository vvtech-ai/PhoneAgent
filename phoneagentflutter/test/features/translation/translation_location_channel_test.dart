import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/translation_location_channel.dart';
import 'package:phone_agent/features/translation/data/secure_translation_location_store.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/location');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('web performs no system call or fabricated location', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw StateError('forbidden'),
    );
    final source = TranslationLocationChannel(channel: channel, web: true);
    expect(
      (await source.locate()).status,
      TranslationLocationStatus.unavailable,
    );
    await source.cancel();
    await expectLater(source.openSettings(), throwsUnsupportedError);
  });
  test(
    'native protocol forwards normalized validation and cancels matching id',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'locate'
            ? {'status': 'resolved', 'countryIso': 'US'}
            : null;
      });
      final source = TranslationLocationChannel(
        channel: channel,
        web: false,
        platform: TargetPlatform.iOS,
      );
      expect((await source.locate()).countryIso, 'US');
      expect(calls.map((c) => c.method), ['locate', 'cancel']);
      expect(
        calls.first.arguments['requestId'],
        calls.last.arguments['requestId'],
      );
      await source.openSettings();
      expect(calls.last.method, 'openSettings');
    },
  );
  test('unknown status or malformed success cannot become trusted', () async {
    final source = TranslationLocationChannel(
      channel: channel,
      web: false,
      platform: TargetPlatform.android,
    );
    for (final response in [
      {'status': 'ok'},
      {'status': 'resolved'},
      {'status': 'resolved', 'countryIso': 'USA'},
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'locate' ? response : null,
      );
      await expectLater(source.locate(), throwsFormatException);
    }
  });
  test(
    'cancel carries old request id even after a new generation begins',
    () async {
      final pending = <Completer<Object?>>[];
      final ids = <String>[];
      final canceled = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancel') {
          canceled.add(call.arguments['requestId']);
          return null;
        }
        ids.add(call.arguments['requestId']);
        final gate = Completer<Object?>();
        pending.add(gate);
        return gate.future;
      });
      final source = TranslationLocationChannel(
        channel: channel,
        web: false,
        platform: TargetPlatform.android,
      );
      final first = source.locate();
      await Future<void>.delayed(Duration.zero);
      await expectLater(source.locate(), throwsStateError);
      await source.cancel();
      final second = source.locate();
      await Future<void>.delayed(Duration.zero);
      pending.first.complete({'status': 'failed'});
      await first;
      expect(canceled, everyElement(ids.first));
      pending.last.complete({'status': 'resolved', 'countryIso': 'JP'});
      await second;
      expect(canceled.last, ids.last);
      expect(ids.first, isNot(ids.last));
    },
  );
  test(
    'secure cache isolates environment, persists only country/time and rejects bad schema',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const dev = SecureTranslationLocationStore(
        'dev|https://dev.example/api/',
      );
      const prod = SecureTranslationLocationStore(
        'prod|https://prod.example/api/',
      );
      await dev.write(TrustedTranslationLocation('jp', 42));
      expect((await dev.read())!.countryIso, 'JP');
      expect(await prod.read(), isNull);
      final raw = await dev.storage.read(key: dev.key);
      expect(raw, '{"schema":1,"countryIso":"JP","sampledAtMs":42}');
      await dev.storage.write(key: dev.key, value: '{"schema":2}');
      await expectLater(dev.read(), throwsFormatException);
    },
  );
}

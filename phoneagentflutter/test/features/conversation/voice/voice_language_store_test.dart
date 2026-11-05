import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/secure_voice_language_store.dart';
import '../../translation/legacy_location_storage_test.dart'
    show ControlledStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('v65 aliases normalize, persist and never reread old value', () async {
    for (final entry in {
      'EN': 'en-US',
      ' en-US ': 'en-US',
      'jp': 'ja-JP',
      'ja': 'ja-JP',
      'JA-jp': 'ja-JP',
      'unknown': 'zh-CN',
    }.entries) {
      var reads = 0;
      final store = SecureVoiceLanguageStore(
        entry.key,
        legacyRead: () async {
          reads++;
          return entry.key;
        },
      );
      expect(await store.read(), entry.value);
      expect(await store.storage.read(key: store.key), entry.value);
      expect(await store.read(), entry.value);
      expect(reads, 1);
    }
  });
  test(
    'missing default is not persisted; existing valid new value wins',
    () async {
      final store = SecureVoiceLanguageStore('prod');
      expect(await store.read(), 'zh-CN');
      expect(await store.storage.read(key: store.key), isNull);
      await store.storage.write(key: store.key, value: 'ja-JP');
      expect(
        await SecureVoiceLanguageStore(
          'prod',
          legacyRead: () async => throw StateError('must not read'),
        ).read(),
        'ja-JP',
      );
      expect(await SecureVoiceLanguageStore('dev').read(), 'zh-CN');
    },
  );
  test('new corruption or read failure never falls back', () async {
    final disk = ControlledStorage();
    final store = SecureVoiceLanguageStore(
      'prod',
      storage: disk,
      legacyRead: () async => fail('must not import'),
    );
    await disk.write(key: store.key, value: 'invalid');
    await expectLater(store.read(), throwsFormatException);
    disk.failRead = true;
    await expectLater(store.read(), throwsStateError);
  });
  test(
    'source and target failure preserve retry without publishing defaults',
    () async {
      final disk = ControlledStorage()..failWrite = true;
      var failSource = true;
      final store = SecureVoiceLanguageStore(
        'prod',
        storage: disk,
        legacyRead: () async {
          if (failSource) throw StateError('source');
          return 'en';
        },
      );
      await expectLater(store.read(), throwsStateError);
      failSource = false;
      await expectLater(store.read(), throwsStateError);
      expect(await disk.read(key: store.key), isNull);
      disk.failWrite = false;
      expect(await store.read(), 'en-US');
    },
  );
  test(
    'same-key instances serialize and different environments stay separate',
    () async {
      final gate = Completer<String?>();
      var reads = 0;
      Future<String?> old() {
        reads++;
        return gate.future;
      }

      final a = SecureVoiceLanguageStore('prod', legacyRead: old);
      final b = SecureVoiceLanguageStore('prod', legacyRead: old);
      final first = a.read(), second = b.read();
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      gate.complete('ja');
      expect(await Future.wait([first, second]), ['ja-JP', 'ja-JP']);
      expect(reads, 1);
      expect(await SecureVoiceLanguageStore('dev').read(), 'zh-CN');
    },
  );
}

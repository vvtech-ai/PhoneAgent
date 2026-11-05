import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/secure_translation_location_store.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_location_controller.dart';

class ControlledStorage extends FlutterSecureStorage {
  bool failWrite = false;
  bool failRead = false;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (failRead) throw StateError('synthetic read failure');
    return super.read(key: key);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (failWrite) throw StateError('synthetic write failure');
    return super.write(key: key, value: value);
  }
}

class NoLocationSource implements TranslationLocationSource {
  @override
  Future<TranslationLocationResult> locate() =>
      throw StateError('no GPS in migration');
  @override
  Future<void> openSettings() => throw StateError('no permission in migration');
  @override
  Future<void> cancel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final oldValue = TrustedTranslationLocation('JP', 1000);
  final newValue = TrustedTranslationLocation('US', 2000);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'imports once and reconstructed store prefers newer saved location',
    () async {
      var calls = 0;
      Future<TrustedTranslationLocation?> legacy() async {
        calls++;
        return oldValue;
      }

      final first = SecureTranslationLocationStore('test', legacyRead: legacy);
      expect((await first.read())?.sampledAtMs, 1000);
      await first.write(newValue);
      final second = SecureTranslationLocationStore('test', legacyRead: legacy);
      expect((await second.read())?.countryIso, 'US');
      expect((await second.read())?.sampledAtMs, 2000);
      expect(calls, 1);
    },
  );

  test('missing source writes no empty snapshot', () async {
    final store = SecureTranslationLocationStore(
      'test',
      legacyRead: () async => null,
    );
    expect(await store.read(), isNull);
    expect(await store.storage.read(key: store.key), isNull);
  });

  test('source error retries without poisoning operation queue', () async {
    var fail = true;
    final store = SecureTranslationLocationStore(
      'test',
      legacyRead: () async {
        if (fail) throw StateError('synthetic source error');
        return oldValue;
      },
    );
    await expectLater(store.read(), throwsStateError);
    expect(await store.storage.read(key: store.key), isNull);
    fail = false;
    expect((await store.read())?.countryIso, 'JP');
  });

  test(
    'failed import write does not publish unpersisted cache; retry works',
    () async {
      final storage = ControlledStorage()..failWrite = true;
      var calls = 0;
      final store = SecureTranslationLocationStore(
        'test',
        storage: storage,
        legacyRead: () async {
          calls++;
          return oldValue;
        },
      );
      await expectLater(store.read(), throwsStateError);
      expect(await storage.read(key: store.key), isNull);
      storage.failWrite = false;
      expect((await store.read())?.sampledAtMs, 1000);
      expect(calls, 2);
    },
  );

  test(
    'new read failure and corrupt data never fall back to old source',
    () async {
      final storage = ControlledStorage()..failRead = true;
      var calls = 0;
      final store = SecureTranslationLocationStore(
        'test',
        storage: storage,
        legacyRead: () async {
          calls++;
          return oldValue;
        },
      );
      await expectLater(store.read(), throwsStateError);
      storage.failRead = false;
      for (final raw in [
        'bad',
        '{"schema":2}',
        '{"schema":1,"countryIso":"US","sampledAtMs":0}',
      ]) {
        await storage.write(key: store.key, value: raw);
        await expectLater(store.read(), throwsFormatException);
      }
      expect(calls, 0);
    },
  );

  test('late import cannot overwrite newer cross-instance GPS write', () async {
    final started = Completer<void>(),
        gate = Completer<TrustedTranslationLocation?>();
    final first = SecureTranslationLocationStore(
      'test',
      legacyRead: () {
        started.complete();
        return gate.future;
      },
    );
    final reading = first.read();
    await started.future;
    const second = SecureTranslationLocationStore('test');
    final writing = second.write(newValue);
    gate.complete(oldValue);
    await reading;
    await writing;
    expect((await first.read())?.countryIso, 'US');
    expect((await first.read())?.sampledAtMs, 2000);
  });

  test(
    'formal controller marks imported value cached without GPS or permission',
    () async {
      final store = SecureTranslationLocationStore(
        'test',
        legacyRead: () async => oldValue,
      );
      final controller = TranslationLocationController(
        NoLocationSource(),
        store,
        now: () => 999999,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.snapshot.status, TranslationLocationStatus.resolved);
      expect(controller.snapshot.cached, isTrue);
      expect(controller.snapshot.trusted?.sampledAtMs, 1000);
      expect(controller.snapshot.trusted?.countryIso, 'JP');
    },
  );

  test(
    'cached controller error supports retry without showing successful location',
    () async {
      final storage = ControlledStorage()..failWrite = true;
      final store = SecureTranslationLocationStore(
        'test',
        storage: storage,
        legacyRead: () async => oldValue,
      );
      final controller = TranslationLocationController(
        NoLocationSource(),
        store,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.snapshot.trusted, isNull);
      expect(controller.snapshot.error, isNotEmpty);
      storage.failWrite = false;
      await controller.load();
      expect(controller.snapshot.cached, isTrue);
      expect(controller.snapshot.trusted?.sampledAtMs, 1000);
    },
  );
}

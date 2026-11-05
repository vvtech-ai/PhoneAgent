import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/identity/data/identity_initialization_store.dart';

class FailableInitializationStorage extends FlutterSecureStorage {
  bool failWrite = true;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.parse(
    environment: 'prod',
    apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
  );
  final key = IdentityInitializationStore.keyFor(config);
  const storage = FlutterSecureStorage();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final old in [true, false]) {
    test(
      'legacy $old persists before returning and imports once across instances',
      () async {
        var reads = 0;
        Future<bool?> legacy() async {
          reads++;
          return old;
        }

        final first = IdentityInitializationStore(config, legacyRead: legacy);
        final second = IdentityInitializationStore(config, legacyRead: legacy);
        expect(await Future.wait([first.isSkipped(), second.isSkipped()]), [
          old,
          old,
        ]);
        expect(await storage.read(key: key), old.toString());
        expect(reads, 1);
      },
    );
  }

  for (final saved in ['true', 'false', 'malformed', '']) {
    test('existing new value "$saved" never falls back', () async {
      FlutterSecureStorage.setMockInitialValues({key: saved});
      final store = IdentityInitializationStore(
        config,
        legacyRead: () async {
          fail('Must not read legacy when the new key exists');
        },
      );
      expect(await store.isSkipped(), saved == 'true');
      expect(await storage.read(key: key), saved);
    });
  }

  test(
    'missing legacy does not persist a default and later read can retry',
    () async {
      bool? old;
      final store = IdentityInitializationStore(
        config,
        legacyRead: () async => old,
      );
      expect(await store.isSkipped(), false);
      expect(await storage.read(key: key), isNull);
      old = true;
      expect(await store.isSkipped(), true);
      expect(await storage.read(key: key), 'true');
    },
  );

  test('source error does not poison queue or write fallback', () async {
    var failRead = true;
    final store = IdentityInitializationStore(
      config,
      legacyRead: () async {
        if (failRead) throw StateError('synthetic source failure');
        return true;
      },
    );
    await expectLater(store.isSkipped(), throwsStateError);
    expect(await storage.read(key: key), isNull);
    failRead = false;
    expect(await store.isSkipped(), true);
  });

  test(
    'failed import does not cache true, next read retries persistence',
    () async {
      final target = FailableInitializationStorage();
      var reads = 0;
      final store = IdentityInitializationStore(
        config,
        storage: target,
        legacyRead: () async {
          reads++;
          return true;
        },
      );
      await expectLater(store.isSkipped(), throwsStateError);
      await expectLater(store.isSkipped(), throwsStateError);
      expect(await storage.read(key: key), isNull);
      target.failWrite = false;
      expect(await store.isSkipped(), true);
      expect(reads, 3);
      expect(await storage.read(key: key), 'true');
    },
  );

  for (final sameInstance in [true, false]) {
    test(
      'late old false cannot overwrite skip, same instance=$sameInstance',
      () async {
        final entered = Completer<void>(), legacy = Completer<bool?>();
        final reader = IdentityInitializationStore(
          config,
          legacyRead: () {
            entered.complete();
            return legacy.future;
          },
        );
        final writer = sameInstance
            ? reader
            : IdentityInitializationStore(config);
        final read = reader.isSkipped();
        await entered.future;
        final write = writer.markSkipped();
        expect(await writer.isSkipped(), true);
        legacy.complete(false);
        expect(await read, sameInstance);
        await write;
        expect(await storage.read(key: key), 'true');
        expect(await reader.isSkipped(), true);
      },
    );
  }

  test(
    'explicit skip remains in memory after write failure and can retry',
    () async {
      final target = FailableInitializationStorage();
      final store = IdentityInitializationStore(
        config,
        storage: target,
        legacyRead: () async {
          fail('An explicit skip must not read legacy');
        },
      );
      await expectLater(store.markSkipped(), throwsStateError);
      expect(await store.isSkipped(), true);
      expect(await storage.read(key: key), isNull);
      target.failWrite = false;
      await store.markSkipped();
      expect(await IdentityInitializationStore(config).isSkipped(), true);
    },
  );
}

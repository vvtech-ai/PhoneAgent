import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/data/secure_original_audio_store.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';

class FailableStorage extends FlutterSecureStorage {
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

void exercise<T>({
  required String name,
  required T oldValue,
  required T newValue,
  required dynamic Function(Future<T?> Function()?, FlutterSecureStorage)
  create,
  required Object Function(T) encode,
}) {
  test('$name: import once, persisted new values take precedence', () async {
    FlutterSecureStorage.setMockInitialValues({});
    var reads = 0;
    Future<T?> legacy() async {
      reads++;
      return oldValue;
    }

    final store = create(legacy, const FlutterSecureStorage());
    expect(encode(await store.read() as T), encode(oldValue));
    await store.write(newValue);
    expect(
      encode(await create(legacy, const FlutterSecureStorage()).read() as T),
      encode(newValue),
    );
    expect(reads, 1);
  });
  test('$name: import cannot overwrite a newer cross-instance write', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final started = Completer<void>(), gate = Completer<T?>();
    final first = create(() {
      started.complete();
      return gate.future;
    }, const FlutterSecureStorage());
    final read = first.read() as Future<T>;
    await started.future;
    final second = create(null, const FlutterSecureStorage());
    final write = second.write(newValue) as Future<void>;
    gate.complete(oldValue);
    await read;
    await write;
    expect(encode(await first.read() as T), encode(newValue));
  });
  test(
    '$name: write failure retries without poisoning queue; corrupt new never falls back',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = FailableStorage();
      var reads = 0;
      final store = create(() async {
        reads++;
        return oldValue;
      }, storage);
      await expectLater(store.read() as Future<T>, throwsStateError);
      storage.failWrite = false;
      expect(encode(await store.read() as T), encode(oldValue));
      expect(reads, 2);
      await storage.write(key: store.key as String, value: 'bad');
      await expectLater(store.read() as Future<T>, throwsFormatException);
      expect(reads, 2);
    },
  );
  test(
    '$name: source failure retries, missing source keeps defaults without writing',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      var fail = true;
      final store = create(() async {
        if (fail) throw StateError('synthetic source');
        return null;
      }, const FlutterSecureStorage());
      await expectLater(store.read() as Future<T>, throwsStateError);
      fail = false;
      await store.read();
      expect(
        await const FlutterSecureStorage().read(key: store.key as String),
        isNull,
      );
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  exercise<OriginalAudioSettings>(
    name: 'original audio',
    oldValue: const OriginalAudioSettings(gain: 10),
    newValue: const OriginalAudioSettings(gain: 40),
    create: (read, storage) => SecureOriginalAudioStore(
      'migration-test',
      legacyRead: read,
      storage: storage,
    ),
    encode: (value) => value.toJson(),
  );
  exercise<TranslationPreferences>(
    name: 'translation',
    oldValue: const TranslationPreferences(peer: 'ja'),
    newValue: const TranslationPreferences(peer: 'fr'),
    create: (read, storage) => SecureTranslationPreferenceStore(
      'migration-test',
      legacyRead: read,
      storage: storage,
    ),
    encode: TranslationPreferenceCodec.encode,
  );
}

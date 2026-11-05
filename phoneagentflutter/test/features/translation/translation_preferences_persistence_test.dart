import 'dart:async';
import '../../support/translation_directory_fixture.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';

class MemoryTranslationStore implements TranslationPreferenceStore {
  TranslationPreferences value = const TranslationPreferences();
  bool readFails = false, writeFails = false;
  Completer<void>? readGate, writeGate;
  int reads = 0;
  final writes = <TranslationPreferences>[];
  @override
  Future<TranslationPreferences> read() async {
    reads++;
    await readGate?.future;
    if (readFails) throw StateError('synthetic read');
    return value;
  }

  @override
  Future<void> write(TranslationPreferences next) async {
    writes.add(next);
    await writeGate?.future;
    if (writeFails) throw StateError('synthetic write');
    value = next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'secure roundtrip restores all fields and separates environments',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const dev = SecureTranslationPreferenceStore('dev|https://test.invalid');
      const prod = SecureTranslationPreferenceStore(
        'prod|https://prod.invalid',
      );
      const value = TranslationPreferences(
        enabled: false,
        prompt: false,
        caller: 'de',
        peer: 'fr',
        normalCountry: 'SG',
        translationCountry: 'JP',
        provider: 'OPENAI',
        region: 'US',
      );
      await dev.write(value);
      final reopened = SecureTranslationPreferenceStore(dev.scope);
      expect(
        TranslationPreferenceCodec.encode(await reopened.read()),
        TranslationPreferenceCodec.encode(value),
      );
      expect((await prod.read()).provider, 'GEMINI');
      expect(dev.key, isNot(prod.key));
    },
  );
  test(
    'server country/language IDs survive storage; malformed choices use defaults',
    () {
      final value = TranslationPreferenceCodec.decode(
        '{"schema":1,"caller":"xx","peer":42,"provider":"QWEN",'
        '"normalCountry":"ZZ","region":"CN","enabled":"false"}',
      );
      expect(value.caller, 'xx');
      expect(value.peer, 'en');
      expect(value.country, 'CN');
      expect(value.provider, 'QWEN');
      expect(value.region, 'DEFAULT');
      expect(value.enabled, isTrue);
      for (final raw in ['bad', '[]', '{}', '{"schema":2}']) {
        expect(
          () => TranslationPreferenceCodec.decode(raw),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'read error blocks every mutation and retry restores previous value',
    () async {
      final store = MemoryTranslationStore()
        ..readFails = true
        ..value = const TranslationPreferences(peer: 'es');
      final c = TranslationSetupController(store: store);
      addTearDown(c.dispose);
      await c.load();
      c.enable(false);
      c.prompt(false);
      c.country('JP');
      c.language('de', caller: true);
      c.provider('OPENAI');
      c.region('US');
      await c.save();
      expect(store.writes, isEmpty);
      expect(c.status.ready, isFalse);
      expect(c.status.error, contains('读取'));
      store.readFails = false;
      await c.load();
      expect(c.snapshot.peer, 'es');
    },
  );
  test('single flight read and no default overwrite while loading', () async {
    final store = MemoryTranslationStore()..readGate = Completer<void>();
    final c = TranslationSetupController(store: store);
    addTearDown(c.dispose);
    final load = c.load();
    await c.load();
    c.country('JP');
    expect(store.reads, 1);
    expect(store.writes, isEmpty);
    store.readGate!.complete();
    await load;
    expect(c.status.ready, isTrue);
  });
  test(
    'serial coalesced writes persist the newest complete snapshot',
    () async {
      final store = MemoryTranslationStore()..writeGate = Completer<void>();
      final c = TranslationSetupController(store: store);
      await c.load();
      c.directory(syntheticTranslationDirectory);
      c.country('JP');
      c.language('fr', caller: false);
      c.enable(false);
      c.country('SG');
      c.enable(true);
      c.prompt(false);
      c.provider('OPENAI');
      c.region('US');
      expect(store.writes.length, 1);
      store.writeGate!.complete();
      await pumpEventQueue();
      expect(store.writes.length, 2);
      expect(c.status.saving, isFalse);
      c.dispose();
      final next = TranslationSetupController(store: store);
      addTearDown(next.dispose);
      await next.load();
      expect(next.snapshot.country, 'JP');
      expect(next.snapshot.normalCountry, 'SG');
      expect(next.snapshot.peer, 'en');
      expect(next.snapshot.provider, 'OPENAI');
      expect(next.snapshot.prompt, isFalse);
      expect(next.snapshot.region, 'US');
    },
  );
  test(
    'write failure preserves latest draft and explicit retry saves it',
    () async {
      final store = MemoryTranslationStore()..writeFails = true;
      final c = TranslationSetupController(store: store);
      addTearDown(c.dispose);
      await c.load();
      c.language('fr', caller: true);
      c.region('JP');
      await pumpEventQueue();
      expect(c.status.error, contains('尚未保存'));
      expect(c.snapshot.caller, 'fr');
      expect(store.value.caller, 'zh');
      store.writeFails = false;
      await c.save();
      expect(c.status.error, isEmpty);
      expect(store.value.region, 'JP');
    },
  );
  test('disposed pending read does not emit or write', () async {
    final store = MemoryTranslationStore()..readGate = Completer<void>();
    final c = TranslationSetupController(store: store);
    final load = c.load();
    c.dispose();
    store.readGate!.complete();
    await load;
    expect(store.writes, isEmpty);
  });
  test('disposed pending write does not queue another write', () async {
    final store = MemoryTranslationStore()..writeGate = Completer<void>();
    final c = TranslationSetupController(store: store);
    await c.load();
    c.country('JP');
    c.region('US');
    c.dispose();
    store.writeGate!.complete();
    await pumpEventQueue();
    expect(store.writes.length, 1);
  });
  test('isolated controller has no effect on persistent controller', () async {
    final store = MemoryTranslationStore();
    final live = TranslationSetupController(store: store);
    final mock = TranslationSetupController();
    addTearDown(live.dispose);
    addTearDown(mock.dispose);
    await live.load();
    mock.country('JP');
    mock.provider('OPENAI');
    await pumpEventQueue();
    expect(live.snapshot.country, 'CN');
    expect(store.writes, isEmpty);
  });
}

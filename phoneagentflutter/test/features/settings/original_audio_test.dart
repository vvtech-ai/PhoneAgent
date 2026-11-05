import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/data/secure_original_audio_store.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/settings/presentation/controller/original_audio_controller.dart';

class MemoryAudioStore implements OriginalAudioStore {
  OriginalAudioSettings value = const OriginalAudioSettings();
  bool readFails = false, writeFails = false;
  Completer<void>? gate;
  final writes = <OriginalAudioSettings>[];
  @override
  Future<OriginalAudioSettings> read() async {
    if (readFails) throw StateError('synthetic read failure');
    return value;
  }

  @override
  Future<void> write(OriginalAudioSettings next) async {
    writes.add(next);
    await gate?.future;
    if (writeFails) throw StateError('synthetic write failure');
    value = next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('v65 defaults and rounded/clamped step options', () {
    const value = OriginalAudioSettings();
    expect(value.toJson(), {
      'version': 1,
      'enabled': false,
      'gain': 50,
      'volume': 100,
    });
    expect(value.copy(gain: -10).gain, 0);
    expect(value.copy(gain: 55).gain, 50);
    expect(value.copy(gain: 25).gain, 30);
    expect(value.copy(volume: 124).volume, 100);
    expect(value.copy(volume: 34).volume, 30);
    expect(value.copy(enabled: false, gain: 20).gain, 20);
  });
  test('corrupt persisted data is not silently treated as defaults', () {
    for (final data in [
      null,
      {},
      {'version': 2},
      {'version': 1, 'enabled': 'false', 'gain': 50, 'volume': 100},
    ]) {
      expect(() => OriginalAudioSettings.fromJson(data), throwsFormatException);
    }
  });
  test('secure store roundtrip and environment isolation', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const dev = SecureOriginalAudioStore('dev'),
        prod = SecureOriginalAudioStore('prod');
    expect((await dev.read()).enabled, isFalse);
    await dev.write(
      const OriginalAudioSettings(enabled: true, gain: 20, volume: 80),
    );
    expect((await const SecureOriginalAudioStore('dev').read()).gain, 20);
    expect((await prod.read()).enabled, isFalse);
    expect(dev.key, isNot(prod.key));
  });
  test('load failure blocks default overwrite and can retry', () async {
    final store = MemoryAudioStore()..readFails = true;
    final c = OriginalAudioController(store);
    addTearDown(c.dispose);
    await c.load();
    c.change(enabled: true);
    await c.save();
    expect(store.writes, isEmpty);
    expect(c.state.error, contains('读取'));
    store.readFails = false;
    await c.load();
    expect(c.state.ready, isTrue);
  });
  test(
    'serialized last-wins writes survive navigation/controller recreation',
    () async {
      final store = MemoryAudioStore()..gate = Completer<void>();
      final c = OriginalAudioController(store);
      await c.load();
      c.change(enabled: true);
      c.change(gain: 20);
      c.change(volume: 60);
      expect(store.writes.length, 1);
      store.gate!.complete();
      await pumpEventQueue();
      expect(store.writes.length, 2);
      expect(c.state.saving, isFalse);
      c.dispose();
      final next = OriginalAudioController(store);
      addTearDown(next.dispose);
      await next.load();
      expect(next.state.value.toJson(), {
        'version': 1,
        'enabled': true,
        'gain': 20,
        'volume': 60,
      });
    },
  );
  test(
    'failed save retains latest draft and explicit retry persists',
    () async {
      final store = MemoryAudioStore()..writeFails = true;
      final c = OriginalAudioController(store);
      addTearDown(c.dispose);
      await c.load();
      c.change(enabled: true, gain: 30);
      await pumpEventQueue();
      expect(c.state.error, contains('尚未保存'));
      expect(c.state.value.gain, 30);
      expect(store.value.enabled, isFalse);
      store.writeFails = false;
      await c.save();
      expect(c.state.error, isEmpty);
      expect(store.value.gain, 30);
    },
  );
  test(
    'late write does not update disposed notifier or queue more writes',
    () async {
      final store = MemoryAudioStore()..gate = Completer<void>();
      final c = OriginalAudioController(store);
      await c.load();
      c.change(enabled: true);
      c.change(gain: 20);
      c.dispose();
      store.gate!.complete();
      await pumpEventQueue();
      expect(store.writes.length, 1);
    },
  );
}

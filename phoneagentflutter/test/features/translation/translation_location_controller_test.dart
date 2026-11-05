import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_location_controller.dart';

class Source implements TranslationLocationSource {
  int calls = 0, canceled = 0, settings = 0;
  bool settingsError = false;
  Future<TranslationLocationResult> Function() result = () async =>
      const TranslationLocationResult(
        TranslationLocationStatus.resolved,
        countryIso: 'US',
      );
  @override
  Future<TranslationLocationResult> locate() {
    calls++;
    return result();
  }

  @override
  Future<void> cancel() async {
    canceled++;
  }

  @override
  Future<void> openSettings() async {
    settings++;
    if (settingsError) throw StateError('settings');
  }
}

class Store implements TranslationLocationStore {
  TrustedTranslationLocation? value;
  bool readError = false, writeError = false;
  int writes = 0;
  Completer<TrustedTranslationLocation?>? pending;
  @override
  Future<TrustedTranslationLocation?> read() async {
    if (readError) throw StateError('read');
    return pending == null ? value : pending!.future;
  }

  @override
  Future<void> write(TrustedTranslationLocation value) async {
    writes++;
    if (writeError) throw StateError('write');
    this.value = value;
  }
}

void main() {
  late Source source;
  late Store store;
  late TranslationLocationController controller;
  setUp(() {
    source = Source();
    store = Store();
    controller = TranslationLocationController(source, store, now: () => 1000);
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test(
    'permission refresh waits for initial cache load and remains single flight',
    () async {
      store.pending = Completer<TrustedTranslationLocation?>();
      final loading = controller.load();
      final refresh = controller.refreshAfterPermission();
      expect(source.calls, 0);
      store.pending!.complete(TrustedTranslationLocation('JP', 1));
      await Future.wait([loading, refresh]);
      expect(source.calls, 1);
      expect(controller.snapshot.trusted!.countryIso, 'US');
    },
  );
  test(
    'permission refresh discarded when disposed during cache load',
    () async {
      store.pending = Completer<TrustedTranslationLocation?>();
      controller.load();
      final refresh = controller.refreshAfterPermission();
      controller.dispose();
      store.pending!.complete(null);
      await refresh;
      expect(source.calls, 0);
    },
  );
  test(
    'load is cache-only and accepts old trusted sample without invented expiry',
    () async {
      store.value = TrustedTranslationLocation(' jp ', 1);
      await controller.load();
      expect(controller.snapshot.trusted!.countryIso, 'JP');
      expect(controller.snapshot.cached, isTrue);
      expect(source.calls, 0);
    },
  );
  test(
    'empty cache remains idle; only explicit locate stores normalized country',
    () async {
      await controller.load();
      expect(controller.snapshot.status, TranslationLocationStatus.idle);
      source.result = () async => const TranslationLocationResult(
        TranslationLocationStatus.resolved,
        countryIso: ' us ',
      );
      await controller.locate();
      expect(store.value!.countryIso, 'US');
      expect(store.value!.sampledAtMs, 1000);
      expect(controller.snapshot.cached, isFalse);
    },
  );
  for (final status in [
    TranslationLocationStatus.denied,
    TranslationLocationStatus.blocked,
    TranslationLocationStatus.unavailable,
    TranslationLocationStatus.failed,
  ]) {
    test(
      '$status preserves trusted cache, no implicit retry or write',
      () async {
        store.value = TrustedTranslationLocation('CN', 42);
        await controller.load();
        source.result = () async => TranslationLocationResult(status);
        await controller.locate();
        expect(controller.snapshot.status, TranslationLocationStatus.resolved);
        expect(controller.snapshot.trusted!.countryIso, 'CN');
        expect(controller.snapshot.cached, isTrue);
        expect(source.calls, 1);
        expect(store.writes, 0);
      },
    );
  }
  test(
    'request is single flight and disposal cancels/ignores late location',
    () async {
      final pending = Completer<TranslationLocationResult>();
      source.result = () => pending.future;
      final operation = controller.locate();
      await controller.locate();
      expect(source.calls, 1);
      controller.dispose();
      pending.complete(
        const TranslationLocationResult(
          TranslationLocationStatus.resolved,
          countryIso: 'US',
        ),
      );
      await operation;
      expect(source.canceled, 1);
      expect(store.writes, 0);
    },
  );
  test(
    'cache read failure retry and late read disposal never requests system',
    () async {
      store.readError = true;
      await controller.load();
      expect(controller.snapshot.error, contains('读取位置缓存失败'));
      store.readError = false;
      store.pending = Completer();
      final operation = controller.load();
      await controller.locate();
      expect(source.calls, 0);
      controller.dispose();
      store.pending!.complete(TrustedTranslationLocation('JP', 1));
      await operation;
      expect(source.calls, 0);
    },
  );
  test(
    'save failure does not erase live sample or claim persistent success',
    () async {
      store.writeError = true;
      await controller.locate();
      expect(controller.snapshot.trusted!.countryIso, 'US');
      expect(controller.snapshot.error, contains('缓存保存失败'));
      store.writeError = false;
      await controller.locate();
      expect(controller.snapshot.error, isEmpty);
    },
  );
  test(
    'malformed country and thrown source become failure without cache overwrite',
    () async {
      store.value = TrustedTranslationLocation('SG', 1);
      await controller.load();
      source.result = () async => const TranslationLocationResult(
        TranslationLocationStatus.resolved,
        countryIso: 'USA',
      );
      await controller.locate();
      expect(controller.snapshot.status, TranslationLocationStatus.resolved);
      expect(store.value!.countryIso, 'SG');
      source.result = () async => throw StateError('system');
      await controller.locate();
      expect(controller.snapshot.status, TranslationLocationStatus.resolved);
      expect(store.writes, 0);
    },
  );
  test('settings does not auto-locate and failures are recoverable', () async {
    await controller.openSettings();
    expect(controller.snapshot.error, contains('重新检查权限'));
    expect(source.calls, 0);
    source.settingsError = true;
    await controller.openSettings();
    expect(controller.snapshot.status, TranslationLocationStatus.blocked);
    expect(controller.snapshot.error, contains('无法打开设置'));
  });
  test(
    'trusted refresh stays resolved, single flight, cancellation ignores late result',
    () async {
      store.value = TrustedTranslationLocation('CN', 42);
      await controller.load();
      final pending = Completer<TranslationLocationResult>();
      source.result = () => pending.future;
      final operation = controller.locate();
      expect(controller.snapshot.status, TranslationLocationStatus.resolved);
      expect(controller.snapshot.trusted!.countryIso, 'CN');
      expect(controller.snapshot.refreshing, isTrue);
      expect(controller.snapshot.busy, isTrue);
      await controller.locate();
      expect(source.calls, 1);
      controller.cancel();
      expect(controller.snapshot.refreshing, isFalse);
      pending.complete(
        const TranslationLocationResult(
          TranslationLocationStatus.resolved,
          countryIso: 'US',
        ),
      );
      await operation;
      expect(controller.snapshot.trusted!.countryIso, 'CN');
      expect(store.writes, 0);
    },
  );
  test(
    'first locate has no trusted admission and successful refresh updates country',
    () async {
      final pending = Completer<TranslationLocationResult>();
      source.result = () => pending.future;
      final operation = controller.locate();
      expect(controller.snapshot.status, TranslationLocationStatus.locating);
      expect(controller.snapshot.trusted, isNull);
      pending.complete(
        const TranslationLocationResult(
          TranslationLocationStatus.resolved,
          countryIso: 'CN',
        ),
      );
      await operation;
      expect(controller.snapshot.busy, isFalse);
      expect(controller.snapshot.trusted!.countryIso, 'CN');
      await controller.locate();
      expect(source.calls, 2);
    },
  );
  test('trusted country rejects invalid identifiers and timestamps', () {
    for (final iso in ['', 'USA', '1A', '中国']) {
      expect(() => TrustedTranslationLocation(iso, 1), throwsFormatException);
    }
    expect(() => TrustedTranslationLocation('US', 0), throwsFormatException);
  });
}

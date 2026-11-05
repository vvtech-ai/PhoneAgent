import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/data/secure_points_wallet_cache.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  final operations = <String>[];
  Completer<void>? writeGate, readGate;
  var failWrite = false;
  SecurePointsWalletCache store({
    String environment = 'dev',
    String api = 'https://example.test/api/',
    String account = 'synthetic-owner',
    bool Function()? current,
  }) => SecurePointsWalletCache(
    environment: environment,
    apiBase: api,
    accountId: account,
    isCurrent: current ?? () => true,
  );
  setUp(() {
    values.clear();
    operations.clear();
    writeGate = null;
    readGate = null;
    failWrite = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map,
              key = arguments['key'] as String;
          operations.add(call.method);
          if (call.method == 'read') {
            await readGate?.future;
            return values[key];
          }
          if (call.method == 'write') {
            await writeGate?.future;
            if (failWrite) throw PlatformException(code: 'synthetic');
            values[key] = arguments['value'] as String;
            return null;
          }
          throw StateError('Unexpected storage operation');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'persistent read across instances and environment/API/account isolation',
    () async {
      await store().write(pointsSnapshot());
      expect((await store().read())!.account.availableBalance, 120);
      for (final other in [
        store(environment: 'prod'),
        store(api: 'https://other.test/api/'),
        store(api: 'https://example.test/other/'),
        store(account: 'another'),
      ]) {
        expect(await other.read(), isNull);
      }
      expect(values.keys.single, startsWith('phoneagent.points-wallet.v1.'));
      expect(values.keys.single, isNot(contains('synthetic-owner')));
      expect(values.values.single, isNot(contains('synthetic-owner')));
    },
  );
  test(
    'copied blob in another owner slot is rejected by envelope scope',
    () async {
      await store().write(pointsSnapshot());
      final blob = values.values.single;
      await store(account: 'another').write(pointsSnapshot(balance: 10));
      values[values.keys.last] = blob;
      expect(await store(account: 'another').read(), isNull);
    },
  );
  test('cross instance writes serialized in submission order', () async {
    writeGate = Completer();
    final first = store().write(pointsSnapshot(balance: 100));
    final second = store().write(pointsSnapshot(balance: 200));
    await Future<void>.delayed(Duration.zero);
    expect(operations, ['write']);
    writeGate!.complete();
    await Future.wait([first, second]);
    expect((await store().read())!.account.availableBalance, 200);
  });
  test('queued old owner operations are skipped after invalidation', () async {
    var current = true;
    writeGate = Completer();
    final active = store();
    final old = store(current: () => current);
    final first = active.write(pointsSnapshot(balance: 100));
    final obsolete = old.write(pointsSnapshot(balance: 50));
    await Future<void>.delayed(Duration.zero);
    current = false;
    writeGate!.complete();
    await Future.wait([first, obsolete]);
    expect((await active.read())!.account.availableBalance, 100);
    expect(operations.where((op) => op == 'write'), hasLength(1));
  });
  test('late read after owner change is ignored', () async {
    await store().write(pointsSnapshot());
    var current = true;
    readGate = Completer();
    final read = store(current: () => current).read();
    await Future<void>.delayed(Duration.zero);
    current = false;
    readGate!.complete();
    expect(await read, isNull);
  });
  test('failed write does not poison queue or remove prior snapshot', () async {
    final cache = store();
    await cache.write(pointsSnapshot());
    failWrite = true;
    await expectLater(
      cache.write(pointsSnapshot(balance: 10)),
      throwsA(isA<PlatformException>()),
    );
    failWrite = false;
    expect((await cache.read())!.account.availableBalance, 120);
    await cache.write(pointsSnapshot(balance: 200));
    expect((await cache.read())!.account.availableBalance, 200);
  });
  test(
    'malformed persisted blob is a miss without deletion or raw content leak',
    () async {
      await store().write(pointsSnapshot());
      values[values.keys.single] = jsonEncode({'version': 1});
      expect(await store().read(), isNull);
      expect(operations, isNot(contains('delete')));
    },
  );
}

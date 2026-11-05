import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/device_identity_capture_port.dart';

const channel = MethodChannel('phone_agent/identity_capture');
Map<String, Object> result() => {
  'code': 2006,
  'reason': 'Z1030',
  'deviceModel': 'Synthetic',
  'networkType': 'WIFI',
  'networkValidated': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'prepare' => 'synthetic-meta',
        'capture' => result(),
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform defers SDK preparation and keeps same session through abort',
      () async {
        final port = DeviceIdentityCapturePort(platform: platform, web: false);
        expect(calls, isEmpty);
        final meta = await Future.wait([port.prepare(), port.prepare()]);
        expect(meta, ['synthetic-meta', 'synthetic-meta']);
        final captured = await port.capture('synthetic-certify');
        expect(captured.code, 2006);
        expect(captured.reason, 'Z1030');
        await port.abort();
        await port.abort();
        expect(calls.map((c) => c.method), ['prepare', 'capture', 'abort']);
        final sessions = calls
            .map((c) => (c.arguments as Map)['session'])
            .toSet();
        expect(sessions.length, 1);
        expect(sessions.single, matches(r'^[A-Za-z0-9_-]{1,128}$'));
        expect((calls[1].arguments as Map).keys.toSet(), {
          'session',
          'certifyId',
        });
        expect((calls[1].arguments as Map)['certifyId'], 'synthetic-certify');
      },
    );
  }
  test(
    'Web and unsupported platforms cannot quietly substitute a fake SDK',
    () async {
      for (final port in [
        DeviceIdentityCapturePort(web: true, platform: TargetPlatform.android),
        DeviceIdentityCapturePort(web: false, platform: TargetPlatform.windows),
      ]) {
        expect(port.prepare, throwsA(IdentityCaptureFailure.unavailable));
        await expectLater(
          port.capture('certify'),
          throwsA(IdentityCaptureFailure.unavailable),
        );
        await port.abort();
      }
      expect(calls, isEmpty);
    },
  );
  test(
    'unused abort never initializes SDK and closed port cannot restart',
    () async {
      final port = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.android,
      );
      await port.abort();
      expect(calls, isEmpty);
      expect(port.prepare, throwsA(IdentityCaptureFailure.cancelled));
    },
  );
  test(
    'different port instances receive distinct cancellation leases',
    () async {
      final a = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.android,
      );
      final b = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.android,
      );
      await a.prepare();
      await b.prepare();
      expect(
        (calls[0].arguments as Map)['session'],
        isNot((calls[1].arguments as Map)['session']),
      );
      await a.abort();
      await b.abort();
    },
  );
  test('capture requires prepare and nonempty bounded certifyId', () async {
    final port = DeviceIdentityCapturePort(
      web: false,
      platform: TargetPlatform.android,
    );
    await expectLater(
      port.capture('certify'),
      throwsA(IdentityCaptureFailure.unavailable),
    );
    expect(calls, isEmpty);
    await port.prepare();
    for (final id in ['', ' ', 'x' * 4097]) {
      await expectLater(
        port.capture(id),
        throwsA(IdentityCaptureFailure.unavailable),
      );
    }
    expect(calls.length, 1);
    await port.abort();
  });
  test(
    'single-use capture rejects duplicate during and after completion',
    () async {
      final pending = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'prepare'
            ? 'meta'
            : call.method == 'capture'
            ? pending.future
            : null;
      });
      final port = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.android,
      );
      await port.prepare();
      final first = port.capture('certify');
      await expectLater(
        port.capture('certify'),
        throwsA(IdentityCaptureFailure.busy),
      );
      pending.complete(result());
      await first;
      await expectLater(
        port.capture('certify'),
        throwsA(IdentityCaptureFailure.busy),
      );
      expect(calls.where((c) => c.method == 'capture').length, 1);
      await port.abort();
    },
  );
  test('abort during preparation drops meta and prevents capture', () async {
    final pending = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'prepare' ? pending.future : null;
    });
    final port = DeviceIdentityCapturePort(
      web: false,
      platform: TargetPlatform.iOS,
    );
    final preparation = port.prepare();
    final rejected = expectLater(
      preparation,
      throwsA(IdentityCaptureFailure.cancelled),
    );
    await port.abort();
    pending.complete('old-meta');
    await rejected;
    await expectLater(
      port.capture('certify'),
      throwsA(IdentityCaptureFailure.cancelled),
    );
    expect(calls.map((c) => c.method), ['prepare', 'abort']);
  });
  test('abort during capture drops a late vendor success', () async {
    final pending = Completer<Object?>();
    final entered = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepare') return 'meta';
      if (call.method == 'capture') {
        entered.complete();
        return pending.future;
      }
      return null;
    });
    final port = DeviceIdentityCapturePort(
      web: false,
      platform: TargetPlatform.iOS,
    );
    await port.prepare();
    final capture = port.capture('certify');
    final rejected = expectLater(
      capture,
      throwsA(IdentityCaptureFailure.cancelled),
    );
    await entered.future;
    await port.abort();
    pending.complete(result());
    await rejected;
  });
  test('malformed SDK result is never accepted', () async {
    for (final value in [
      null,
      {'code': '1000'},
      {...result(), 'networkValidated': 'true'},
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'prepare' ? 'meta' : value,
      );
      final port = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.android,
      );
      await port.prepare();
      await expectLater(
        port.capture('certify'),
        throwsA(IdentityCaptureFailure.invalidResponse),
      );
      await port.abort();
    }
  });
  test('native errors are mapped without leaking raw reason or meta', () async {
    for (final entry in {
      'capture_busy': IdentityCaptureFailure.busy,
      'capture_cancelled': IdentityCaptureFailure.cancelled,
      'unexpected': IdentityCaptureFailure.unavailable,
    }.entries) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(
          code: entry.key,
          message: 'private-native-details',
          details: 'private-meta',
        ),
      );
      final port = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.android,
      );
      await expectLater(port.prepare(), throwsA(entry.value));
    }
  });
  test('missing plugin fails closed instead of generating mock data', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final port = DeviceIdentityCapturePort(
      web: false,
      platform: TargetPlatform.iOS,
    );
    await expectLater(
      port.prepare(),
      throwsA(IdentityCaptureFailure.unavailable),
    );
  });
}

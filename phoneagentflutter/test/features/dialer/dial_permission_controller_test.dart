import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission_store.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_permission_port.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_permission_controller.dart';

class PermissionFixture {
  PermissionFixture({
    PreviewDialPermissionPort? port,
    DialPermissionMemory? memory,
    bool androidNativeParity = false,
  }) : port = port ?? PreviewDialPermissionPort(),
       memory = memory ?? DialPermissionMemory() {
    controller = DialPermissionController(
      port: this.port,
      androidNativeParity: androidNativeParity,
      memory: this.memory,
      setTranslation: (value) {
        enabled = value;
        toggles++;
      },
      refreshRegion: () {
        regions++;
      },
      refreshRecent: () {
        recent++;
      },
    );
    addTearDown(() {
      if (controller.mounted) controller.dispose();
    });
  }
  final PreviewDialPermissionPort port;
  final DialPermissionMemory memory;
  late final DialPermissionController controller;
  bool enabled = true;
  int toggles = 0, regions = 0, recent = 0;
}

void main() {
  test(
    'simulated location waits for saved CallLog marker before OS check',
    () async {
      final store = _DelayedMemoryStore();
      final memory = DialPermissionMemory(store: store);
      final port = PreviewDialPermissionPort();
      final controller = DialPermissionController(
        port: port,
        memory: memory,
        simulatedLocation: () => true,
        setTranslation: (_) {},
        refreshRegion: () => fail('simulation cannot request device location'),
        refreshRecent: () {},
      );
      addTearDown(controller.dispose);
      final start = controller.start(translationEnabled: true);
      await pumpEventQueue();
      expect(port.trace, isEmpty);
      store.gate.complete((
        locationShown: true,
        locationRequested: true,
        callLogRequested: true,
      ));
      await start;
      await memory.flushed;
      expect(port.trace, ['callLog:check']);
      expect(memory.locationShown, isTrue);
      expect(memory.locationRequested, isTrue);
      expect(memory.callLogRequested, isTrue);
      expect(store.writes, isEmpty);
      expect(controller.snapshot.stage, DialPermissionStage.ready);
    },
  );
  test(
    'Android initial denied is requestable; reentry never repeats explanation',
    () async {
      final memory = DialPermissionMemory();
      final port = PreviewDialPermissionPort();
      final first = PermissionFixture(
        memory: memory,
        port: port,
        androidNativeParity: true,
      );
      await first.controller.start(translationEnabled: false);
      expect(first.controller.snapshot.stage, DialPermissionStage.request);
      await first.controller.cancel();
      port.grant = DialPermissionGrant.blocked;
      final next = PermissionFixture(
        memory: memory,
        port: port,
        androidNativeParity: true,
      );
      await next.controller.start(translationEnabled: false);
      expect(next.controller.snapshot.stage, DialPermissionStage.ready);
      await next.controller.toggle(true);
      expect(next.controller.snapshot.stage, DialPermissionStage.blocked);
      await next.controller.confirm();
      expect(next.controller.snapshot.stage, DialPermissionStage.settings);
      await next.controller.resume();
      await next.controller.resume();
      expect(next.enabled, true);
      expect(next.regions, 1);
      expect(port.trace.where((e) => e == 'location:request'), isEmpty);
      expect(port.trace.where((e) => e == 'settings:open'), hasLength(1));
    },
  );
  test(
    'Android first explanation matches native even with prior OS blocking',
    () async {
      final f = PermissionFixture(
        androidNativeParity: true,
        port: PreviewDialPermissionPort()..grant = DialPermissionGrant.blocked,
      );
      await f.controller.start(translationEnabled: true);
      expect(f.controller.snapshot.stage, DialPermissionStage.request);
      await f.controller.confirm();
      expect(f.enabled, false);
      expect(f.controller.snapshot.stage, DialPermissionStage.ready);
    },
  );
  test('Android settings rejection never re-requests permission', () async {
    final port = PreviewDialPermissionPort()
      ..grant = DialPermissionGrant.blocked;
    final f = PermissionFixture(
      androidNativeParity: true,
      port: port,
      memory: DialPermissionMemory()..locationShown = true,
    );
    await f.controller.toggle(true);
    await f.controller.confirm();
    port.grant = DialPermissionGrant.blocked;
    await f.controller.resume();
    expect(f.enabled, false);
    expect(f.controller.snapshot.stage, DialPermissionStage.ready);
    expect(port.trace.where((e) => e == 'location:request'), isEmpty);
  });

  test(
    'initial location explanation waits; cancel permits Android call-log sequence',
    () async {
      final f = PermissionFixture();
      await f.controller.start(translationEnabled: true);
      expect(f.controller.snapshot.stage, DialPermissionStage.request);
      expect(f.port.trace, ['location:check']);
      await f.controller.cancel();
      expect(f.port.trace, [
        'location:check',
        'callLog:check',
        'callLog:request',
      ]);
      expect(f.enabled, isFalse);
      expect(f.recent, 1);
      expect(f.memory.locationShown, isTrue);
      expect(f.memory.locationRequested, isFalse);
      expect(f.controller.snapshot.stage, DialPermissionStage.ready);
    },
  );
  test(
    'granted entry refreshes region and requests CallLog without changing translation',
    () async {
      final f = PermissionFixture(
        port: PreviewDialPermissionPort()..grant = DialPermissionGrant.granted,
      );
      await f.controller.start(translationEnabled: false);
      expect(f.regions, 1);
      expect(f.toggles, 0);
      expect(f.port.trace, [
        'location:check',
        'callLog:check',
        'callLog:request',
      ]);
    },
  );
  test(
    'grant only enables translation when requested; all callbacks once',
    () async {
      final f = PermissionFixture(
        port: PreviewDialPermissionPort(allowLocation: true),
      );
      await f.controller.start(translationEnabled: true);
      final first = f.controller.confirm();
      await f.controller.confirm();
      await first;
      expect(f.enabled, isTrue);
      expect(f.toggles, 1);
      expect(f.regions, 1);
      expect(f.port.trace.where((e) => e == 'location:request').length, 1);
      await f.controller.start(translationEnabled: true);
      expect(f.port.trace.where((e) => e == 'callLog:request').length, 1);
    },
  );
  test(
    'denial disables translation; later blocked toggle uses settings and rechecks on resume',
    () async {
      final f = PermissionFixture();
      await f.controller.start(translationEnabled: true);
      await f.controller.confirm();
      expect(f.enabled, isFalse);
      expect(f.memory.locationRequested, isTrue);
      await f.controller.toggle(true);
      expect(f.controller.snapshot.stage, DialPermissionStage.blocked);
      await f.controller.confirm();
      expect(f.controller.snapshot.stage, DialPermissionStage.settings);
      expect(f.enabled, isFalse);
      await f.controller.resume();
      await f.controller.resume();
      expect(f.enabled, isTrue);
      expect(f.regions, 1);
      expect(f.port.trace.where((e) => e == 'callLog:request').length, 1);
    },
  );
  test(
    'return from settings without grant keeps ordinary dialing available',
    () async {
      final memory = DialPermissionMemory()
        ..locationRequested = true
        ..locationShown = true;
      final f = PermissionFixture(
        memory: memory,
        port: PreviewDialPermissionPort()..grant = DialPermissionGrant.blocked,
      );
      await f.controller.toggle(true);
      await f.controller.confirm();
      f.port.grant = DialPermissionGrant.blocked;
      await f.controller.resume();
      expect(f.enabled, isFalse);
      expect(f.controller.snapshot.stage, DialPermissionStage.ready);
    },
  );
  test(
    'initial blocked location opens settings instead of repeating the request',
    () async {
      final f = PermissionFixture(
        memory: DialPermissionMemory()..locationShown = true,
        port: PreviewDialPermissionPort()..grant = DialPermissionGrant.blocked,
      );
      await f.controller.start(translationEnabled: true);
      expect(f.controller.snapshot.stage, DialPermissionStage.blocked);
      await f.controller.confirm();
      expect(f.controller.snapshot.stage, DialPermissionStage.settings);
      expect(f.port.trace, ['location:check', 'settings:open']);
    },
  );
  test('iOS never calls system history port', () async {
    final f = PermissionFixture(
      port: PreviewDialPermissionPort(supportsCallLog: false),
    );
    await f.controller.start(translationEnabled: true);
    await f.controller.cancel();
    expect(f.port.trace, ['location:check']);
    expect(f.memory.callLogRequested, isFalse);
  });
  test(
    'reopening does not repeat explanation or CallLog request; reset only reopens location',
    () async {
      final memory = DialPermissionMemory()
        ..locationShown = true
        ..locationRequested = true
        ..callLogRequested = true;
      final f = PermissionFixture(memory: memory);
      await f.controller.start(translationEnabled: true);
      expect(f.controller.snapshot.stage, DialPermissionStage.ready);
      expect(f.port.trace, ['location:check', 'callLog:check']);
      memory.resetLocation();
      expect(memory.callLogRequested, isTrue);
      final next = PermissionFixture(memory: memory);
      await next.controller.start(translationEnabled: true);
      expect(next.controller.snapshot.stage, DialPermissionStage.request);
      await f.controller.toggle(true);
      expect(f.port.trace.length, 2);
    },
  );
  test(
    'unavailable environment does not fabricate permission or request history',
    () async {
      final f = PermissionFixture(
        port: PreviewDialPermissionPort()
          ..grant = DialPermissionGrant.unavailable,
      );
      await f.controller.start(translationEnabled: true);
      expect(f.port.trace, ['location:check']);
      expect(f.regions, 0);
      await f.controller.toggle(true);
      expect(f.enabled, isFalse);
      expect(f.controller.snapshot.message, isNotEmpty);
    },
  );
  for (final reset in [true, false]) {
    test(
      'pending result is discarded after ${reset ? 'reset' : 'dispose'}',
      () async {
        final port = _DelayedPort();
        final f = PermissionFixture(port: port);
        final pending = f.controller.start(translationEnabled: true);
        if (reset) {
          f.memory.resetLocation();
        } else {
          f.controller.dispose();
        }
        port.gate.complete(DialPermissionGrant.granted);
        await pending;
        expect(f.regions, 0);
        expect(f.toggles, 0);
        expect(f.memory.callLogRequested, isFalse);
      },
    );
  }
  test('location failures are visible and explicit retry recovers', () async {
    final port = _FailingPort();
    final f = PermissionFixture(port: port);
    await f.controller.start(translationEnabled: true);
    expect(f.controller.snapshot.stage, DialPermissionStage.failed);
    port.fail = false;
    port.allowLocation = true;
    await f.controller.retry();
    expect(f.controller.snapshot.stage, DialPermissionStage.request);
    await f.controller.confirm();
    expect(f.controller.snapshot.stage, DialPermissionStage.ready);
    expect(f.enabled, isTrue);
  });
}

class _DelayedPort extends PreviewDialPermissionPort {
  final gate = Completer<DialPermissionGrant>();
  @override
  Future<DialPermissionGrant> location({bool request = false}) => gate.future;
}

class _DelayedMemoryStore implements DialPermissionStore {
  final gate = Completer<DialPermissionFlags>();
  final writes = <DialPermissionFlags>[];
  @override
  Future<DialPermissionFlags> read() => gate.future;
  @override
  Future<void> write(DialPermissionFlags flags) async => writes.add(flags);
}

class _FailingPort extends PreviewDialPermissionPort {
  bool fail = true;
  @override
  Future<DialPermissionGrant> location({bool request = false}) async {
    if (fail) throw StateError('synthetic');
    return super.location(request: request);
  }
}

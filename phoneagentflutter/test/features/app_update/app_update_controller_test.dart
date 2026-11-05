import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/presentation/controller/app_update_controller.dart';

void main() {
  test(
    'manual only, single-flight and permits another explicit check',
    () async {
      final port = _Port();
      final controller = AppUpdateController(port, port);
      expect(port.reads, 0);
      final first = controller.check();
      await controller.check();
      expect(port.reads, 1);
      port.identity.complete(_app);
      await Future<void>.delayed(Duration.zero);
      expect(port.requests, 1);
      port.release.complete(_release);
      await first;
      expect(controller.state.release, _release);
      await controller.check();
      expect(port.requests, 2);
      controller.dispose();
    },
  );
  test('leaving during metadata read prevents HTTP', () async {
    final port = _Port();
    final controller = AppUpdateController(port, port);
    final pending = controller.check();
    controller.dispose();
    port.identity.complete(_app);
    await pending;
    expect(port.requests, 0);
  });
  test('leaving during check ignores late result', () async {
    final port = _Port()..identity.complete(_app);
    final controller = AppUpdateController(port, port);
    final pending = controller.check();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    port.release.complete(_release);
    await pending;
    expect(port.requests, 1);
  });
  test(
    'failure clears busy, never auto-retries, allows explicit retry',
    () async {
      final port = _Port()..identity.complete(_app);
      final controller = AppUpdateController(port, port);
      final pending = controller.check();
      await Future<void>.delayed(Duration.zero);
      port.release.completeError(StateError('Synthetic'));
      await pending;
      expect(controller.state.busy, false);
      expect(controller.state.error, isNotEmpty);
      expect(port.requests, 1);
      port.release = Completer()..complete(_release);
      await controller.check();
      expect(controller.state.error, isEmpty);
      expect(controller.state.release, _release);
      controller.dispose();
    },
  );
  test('invalid installed identity prevents HTTP', () async {
    final port = _Port()..identity.complete(const InstalledApp('', '', 0));
    final controller = AppUpdateController(port, port);
    await controller.check();
    expect(port.requests, 0);
    expect(controller.state.error, isNotEmpty);
    controller.dispose();
  });
}

const _app = InstalledApp('com.example.preview', '1.0.0', 1);
const _release = AppUpdateRelease(
  hasUpdate: false,
  packageName: 'com.example.preview',
);

class _Port implements InstalledAppSource, AppUpdateRepository {
  final identity = Completer<InstalledApp>();
  var release = Completer<AppUpdateRelease>();
  int reads = 0, requests = 0;
  @override
  Future<InstalledApp> read() {
    reads++;
    return identity.future;
  }

  @override
  Future<AppUpdateRelease> check(InstalledApp app) {
    requests++;
    return release.future;
  }
}

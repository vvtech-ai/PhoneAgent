import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/update_install.dart';
import 'package:phone_agent/features/app_update/presentation/controller/update_install_controller.dart';

const app = InstalledApp('com.example.app', '1.0', 1);
const release = AppUpdateRelease(
  hasUpdate: true,
  packageName: 'com.example.app',
  versionName: '2.0',
  versionCode: 2,
  fileSize: 100,
);
const downloaded = UpdateDownload(
  'job',
  UpdateDownloadStatus.downloaded,
  100,
  100,
);

class Port implements UpdateInstallPort {
  UpdateDownload? restored;
  UpdateDownload initial = downloaded;
  final calls = <String>[];
  bool allowed = true;
  bool failCancel = false, failBegin = false, failPermission = false;
  Future<UpdateDownload>? beginWait, restoreWait;
  Future<void> Function()? handoff;
  List<UpdateDownload> queries = [];
  @override
  Future<UpdateDownload?> restore(AppUpdateRelease release) async {
    calls.add('restore');
    return restoreWait == null ? restored : await restoreWait;
  }

  @override
  Future<UpdateDownload> begin(AppUpdateRelease release) async {
    calls.add('begin');
    if (failBegin) throw StateError('synthetic');
    return beginWait ?? initial;
  }

  @override
  Future<UpdateDownload> query(String job) async {
    calls.add('query');
    return queries.removeAt(0);
  }

  @override
  Future<bool> canInstall() async {
    calls.add('canInstall');
    return allowed;
  }

  @override
  Future<void> openPermission() async {
    calls.add('permission');
    if (failPermission) throw StateError('synthetic');
    await handoff?.call();
  }

  @override
  Future<void> install(String job) async {
    calls.add('install');
    await handoff?.call();
  }

  @override
  Future<void> cancel(String job) async {
    calls.add('cancel');
    if (failCancel) throw StateError('synthetic');
  }
}

void main() {
  late Port port;
  late UpdateInstallController controller;
  var current = true;
  setUp(() {
    current = true;
    port = Port();
    controller = UpdateInstallController(
      app: app,
      release: release,
      port: port,
      isCurrent: () => current,
      delay: (_) async {},
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });

  test('restore empty is read only and once', () async {
    await controller.restore();
    await controller.restore();
    expect(port.calls, ['restore']);
    expect(controller.state.phase, UpdateInstallPhase.idle);
  });
  test('completed restore waits for a fresh install action', () async {
    port.restored = downloaded;
    await controller.restore();
    expect(port.calls, ['restore']);
    expect(controller.state.phase, UpdateInstallPhase.ready);
    await controller.primary();
    expect(port.calls, ['restore', 'canInstall', 'install']);
  });
  test(
    'explicit download hands off to system; return is not success',
    () async {
      await controller.primary();
      expect(port.calls, ['begin', 'canInstall', 'install']);
      expect(controller.state.phase, UpdateInstallPhase.installing);
      await controller.resumed();
      expect(controller.state.phase, UpdateInstallPhase.ready);
      expect(controller.state.error, contains('安装未完成'));
    },
  );
  test('denial then grant resumes installer once', () async {
    port.allowed = false;
    await controller.primary();
    await controller.resumed();
    expect(controller.state.phase, UpdateInstallPhase.permission);
    expect(controller.state.error, contains('尚未授权'));
    await controller.primary();
    port.allowed = true;
    await controller.resumed();
    expect(port.calls.where((e) => e == 'install'), hasLength(1));
    expect(controller.state.phase, UpdateInstallPhase.installing);
  });
  test(
    'resume arriving before permission method completes is retained',
    () async {
      port.allowed = false;
      port.handoff = () async {
        port.allowed = true;
        await controller.resumed();
        port.handoff = null;
      };
      await controller.primary();
      expect(port.calls.where((e) => e == 'install'), hasLength(1));
      expect(controller.state.phase, UpdateInstallPhase.installing);
    },
  );
  test(
    'installer resume arriving before method completes is retained',
    () async {
      port.handoff = controller.resumed;
      await controller.primary();
      expect(controller.state.phase, UpdateInstallPhase.ready);
    },
  );
  test('permission dispatch failure leaves retryable package', () async {
    port.allowed = false;
    port.failPermission = true;
    await controller.primary();
    expect(controller.state.phase, UpdateInstallPhase.ready);
    port.failPermission = false;
    port.allowed = true;
    await controller.primary();
    expect(port.calls.where((e) => e == 'begin'), hasLength(1));
    expect(port.calls.where((e) => e == 'install'), hasLength(1));
  });
  test('paused progress is observable then download continues', () async {
    port.initial = const UpdateDownload(
      'job',
      UpdateDownloadStatus.paused,
      25,
      100,
    );
    port.queries = [downloaded];
    final states = <UpdateInstallState>[];
    final remove = controller.addListener(states.add);
    await controller.primary();
    remove();
    expect(
      states.any(
        (s) => s.phase == UpdateInstallPhase.paused && s.progress == .25,
      ),
      isTrue,
    );
    expect(controller.state.phase, UpdateInstallPhase.installing);
  });
  test('failed download cancels only previous job before retry', () async {
    port.initial = const UpdateDownload(
      'job',
      UpdateDownloadStatus.failed,
      0,
      null,
    );
    await controller.primary();
    expect(controller.state.phase, UpdateInstallPhase.failed);
    port.initial = downloaded;
    await controller.primary();
    expect(port.calls.take(3), ['begin', 'cancel', 'begin']);
  });
  test('different job snapshot cannot continue', () async {
    port.initial = const UpdateDownload(
      'job',
      UpdateDownloadStatus.downloading,
      0,
      null,
    );
    port.queries = [
      const UpdateDownload('other', UpdateDownloadStatus.downloaded, 100, 100),
    ];
    await controller.primary();
    expect(controller.state.phase, UpdateInstallPhase.failed);
    expect(port.calls, isNot(contains('install')));
  });
  test('double action cannot double enqueue', () async {
    final pending = Completer<UpdateDownload>();
    port.beginWait = pending.future;
    final running = controller.primary();
    await controller.primary();
    pending.complete(downloaded);
    await running;
    expect(port.calls.where((e) => e == 'begin'), hasLength(1));
  });
  test('dispose preserves background job but prevents install', () async {
    final pending = Completer<UpdateDownload>();
    port.beginWait = pending.future;
    final running = controller.primary();
    controller.dispose();
    pending.complete(downloaded);
    await running;
    expect(port.calls, ['begin']);
  });
  test('explicit close cancels late enqueue', () async {
    final pending = Completer<UpdateDownload>();
    port.beginWait = pending.future;
    final running = controller.primary();
    expect(await controller.cancel(), isTrue);
    pending.complete(downloaded);
    await running;
    expect(port.calls, ['begin', 'cancel']);
  });
  test('explicit close cancels late restoration', () async {
    final pending = Completer<UpdateDownload>();
    port.restoreWait = pending.future;
    final running = controller.restore();
    await controller.cancel();
    pending.complete(downloaded);
    await running;
    expect(port.calls, ['restore', 'cancel']);
  });
  test('changed account cannot install late package', () async {
    final pending = Completer<UpdateDownload>();
    port.beginWait = pending.future;
    final running = controller.primary();
    current = false;
    pending.complete(downloaded);
    await running;
    expect(port.calls, ['begin']);
  });
  test('cancel cleanup error stays recoverable', () async {
    port.restored = downloaded;
    await controller.restore();
    port.failCancel = true;
    expect(await controller.cancel(), isFalse);
    expect(controller.state.error, contains('清理失败'));
    port.failCancel = false;
    expect(await controller.cancel(), isTrue);
  });
  for (final current in [45, 2026101513]) {
    test(
      'system receives download despite installed version $current',
      () async {
        controller.dispose();
        controller = UpdateInstallController(
          app: InstalledApp(app.packageName, '1.0.52', current),
          release: release,
          port: port,
          isCurrent: () => true,
        );
        await controller.primary();
        expect(port.calls, ['begin', 'canInstall', 'install']);
      },
    );
  }
}

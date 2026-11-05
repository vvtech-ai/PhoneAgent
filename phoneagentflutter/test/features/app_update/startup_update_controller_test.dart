import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/startup_update.dart';
import 'package:phone_agent/features/app_update/presentation/controller/startup_update_controller.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  late StartupSourceFake source;
  late StartupRepositoryFake repo;
  late StartupStoreFake store;
  late StartupRecoveryFake recovery;
  late StartupUpdateController controller;
  var current = true;
  final today = DateTime(2026, 9, 18, 23, 59);
  StartupUpdateController create() => StartupUpdateController(
    source: source,
    repository: repo,
    store: store,
    recovery: recovery,
    isCurrent: () => current,
    now: () => today,
  );
  setUp(() {
    current = true;
    source = StartupSourceFake();
    repo = StartupRepositoryFake();
    store = StartupStoreFake();
    recovery = StartupRecoveryFake();
    controller = create();
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test(
    'first start checks once, remembers local success day and offers optional update',
    () async {
      await controller.start();
      await controller.start();
      expect(repo.checks, 1);
      expect(store.record.lastSuccessDate, '2026-09-18');
      expect(controller.state.offer!.release.forceUpdate, false);
      controller.dismiss();
      expect(controller.state.offer, isNull);
    },
  );
  test(
    'same successful day suppresses next startup but manual refresh bypasses it',
    () async {
      store.record = const StartupUpdateRecord(lastSuccessDate: '2026-09-18');
      await controller.start();
      expect(repo.checks, 0);
      await controller.refresh();
      expect(repo.checks, 1);
    },
  );
  test('yesterday successful checks again', () async {
    store.record = const StartupUpdateRecord(lastSuccessDate: '2026-09-17');
    await controller.start();
    expect(repo.checks, 1);
  });
  test(
    'persisted force rechecks same day and failure does not invent offline gate',
    () async {
      store.record = const StartupUpdateRecord(
        lastSuccessDate: '2026-09-18',
        forceRequired: true,
      );
      repo.fail = true;
      await controller.start();
      expect(repo.checks, 1);
      expect(store.writes, 0);
      expect(store.record.forceRequired, true);
      expect(controller.state.offer, isNull);
      expect(controller.takeNotice(), isNotEmpty);
      expect(controller.takeNotice(), isEmpty);
    },
  );
  test(
    'ordinary startup failure is silent and does not persist a success day',
    () async {
      repo.fail = true;
      await controller.start();
      expect(controller.state.notice, isEmpty);
      expect(store.writes, 0);
      controller.dispose();
      controller = create();
      await controller.start();
      expect(repo.checks, 2);
    },
  );
  test(
    'force response cannot dismiss; authoritative no-update clears force',
    () async {
      repo.release = startupRelease(force: true);
      await controller.start();
      controller.dismiss();
      expect(controller.state.offer, isNotNull);
      expect(store.record.forceRequired, true);
      await controller.acceptManual(
        startupApp,
        startupRelease(update: false, force: true),
      );
      expect(controller.state.offer, isNull);
      expect(store.record.forceRequired, false);
    },
  );
  test('optional update after force response clears persisted force', () async {
    store.record = const StartupUpdateRecord(forceRequired: true);
    await controller.start();
    expect(store.record.forceRequired, false);
  });
  test('download recovery precedes preferences and network', () async {
    recovery.release = startupRelease(force: true);
    repo.fail = true;
    store.failRead = true;
    await controller.start();
    expect(repo.checks, 0);
    expect(store.reads, 0);
    expect(controller.state.offer!.recovered, true);
    controller.dismiss();
    expect(controller.state.offer, isNotNull);
  });
  test(
    'persistence failure preserves effective force offer and warns',
    () async {
      repo.release = startupRelease(force: true);
      store.failWrite = true;
      await controller.start();
      expect(controller.state.offer!.release.forceUpdate, true);
      expect(controller.state.notice, contains('未保存'));
    },
  );
  test('corrupt persistence is not overwritten with default date', () async {
    store.failRead = true;
    await controller.start();
    expect(store.writes, 0);
    expect(repo.checks, 0);
    expect(controller.state.notice, isNotEmpty);
  });
  test(
    'owner change while request pending does not persist or show response',
    () async {
      repo.pending = Completer<AppUpdateRelease>();
      final work = controller.start();
      await Future<void>.delayed(Duration.zero);
      current = false;
      repo.pending!.complete(startupRelease(force: true));
      await work;
      expect(store.writes, 0);
      expect(controller.state.offer, isNull);
    },
  );
  test('close during recovery does not request new API', () async {
    recovery.pending = Completer<AppUpdateRelease?>();
    final work = controller.start();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    recovery.pending!.complete(null);
    await work;
    expect(repo.checks, 0);
    expect(store.writes, 0);
  });
  test('newer manual response wins over older startup response', () async {
    repo.pending = Completer<AppUpdateRelease>();
    final work = controller.start();
    await Future<void>.delayed(Duration.zero);
    await controller.acceptManual(startupApp, startupRelease(update: false));
    repo.pending!.complete(startupRelease(force: true));
    await work;
    expect(store.writes, 1);
    expect(store.record.forceRequired, false);
    expect(controller.state.offer, isNull);
  });
  test('dismiss while saving optional response does not reopen it', () async {
    store.writing = Completer<void>();
    final work = controller.start();
    await Future<void>.delayed(Duration.zero);
    controller.dismiss();
    store.writing!.complete();
    await work;
    expect(controller.state.offer, isNull);
  });
  test('failed refresh retains current force offer', () async {
    repo.release = startupRelease(force: true);
    await controller.start();
    final offer = controller.state.offer;
    repo.fail = true;
    await controller.refresh();
    expect(controller.state.offer, same(offer));
    expect(controller.state.notice, isNotEmpty);
  });
  test('wrong recovered package is rejected', () async {
    recovery.release = const AppUpdateRelease(
      hasUpdate: true,
      packageName: 'com.other.app',
      versionName: '2',
    );
    await controller.start();
    expect(controller.state.offer, isNull);
    expect(store.writes, 0);
  });
  for (final code in [1, 45]) {
    final offered = AppUpdateRelease(
      hasUpdate: true,
      packageName: startupApp.packageName,
      versionName: 'backend metadata',
      versionCode: code,
    );
    test('restores update code $code without a version gate', () async {
      recovery.release = offered;
      await controller.start();
      expect(controller.state.offer?.release, same(offered));
      expect(repo.checks, 0);
    });
    test('accepts manual update code $code without a version gate', () async {
      await controller.acceptManual(
        InstalledApp(startupApp.packageName, '1.0.52', 2026101513),
        offered,
      );
      expect(controller.state.offer?.release, same(offered));
      expect(store.writes, 1);
    });
  }
}

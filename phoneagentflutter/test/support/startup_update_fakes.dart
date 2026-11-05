import 'dart:async';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/startup_update.dart';

const startupApp = InstalledApp('com.example.synthetic', '1.0', 1);
AppUpdateRelease startupRelease({bool update = true, bool force = false}) =>
    AppUpdateRelease(
      hasUpdate: update,
      packageName: startupApp.packageName,
      versionName: '2.0',
      versionCode: 2,
      forceUpdate: force,
      apkUrl: 'https://synthetic.invalid/update.apk',
      releaseNotes: '合成启动更新',
    );

class StartupSourceFake implements InstalledAppSource {
  int reads = 0;
  @override
  Future<InstalledApp> read() async {
    reads++;
    return startupApp;
  }
}

class StartupRepositoryFake implements AppUpdateRepository {
  int checks = 0;
  bool fail = false;
  AppUpdateRelease release = startupRelease();
  Completer<AppUpdateRelease>? pending;
  @override
  Future<AppUpdateRelease> check(InstalledApp app) async {
    checks++;
    if (fail) throw StateError('synthetic');
    return pending == null ? release : pending!.future;
  }
}

class StartupStoreFake implements StartupUpdateStore {
  StartupUpdateRecord record = const StartupUpdateRecord();
  bool failRead = false, failWrite = false;
  int reads = 0, writes = 0;
  Completer<void>? writing;
  @override
  Future<StartupUpdateRecord> read(InstalledApp app) async {
    reads++;
    if (failRead) throw StateError('synthetic');
    return record;
  }

  @override
  Future<void> write(InstalledApp app, StartupUpdateRecord value) async {
    writes++;
    if (failWrite) throw StateError('synthetic');
    await writing?.future;
    record = value;
  }
}

class StartupRecoveryFake implements StartupUpdateRecovery {
  int reads = 0;
  AppUpdateRelease? release;
  Completer<AppUpdateRelease?>? pending;
  @override
  Future<AppUpdateRelease?> peek(InstalledApp app) async {
    reads++;
    return pending == null ? release : pending!.future;
  }
}

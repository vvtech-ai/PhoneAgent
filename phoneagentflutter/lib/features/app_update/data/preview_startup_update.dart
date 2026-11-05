import '../domain/app_update.dart';
import '../domain/startup_update.dart';
import 'preview_update_install_port.dart';

enum StartupUpdateScenario {
  optional,
  forced,
  sameDay,
  offlineForce,
  recovered,
  missingDownload,
}

/// No API, account storage or native dependencies. Only in the explicit preview.
class PreviewStartupUpdate
    implements AppUpdateRepository, StartupUpdateRecovery {
  PreviewStartupUpdate(this.scenario) {
    if (scenario == StartupUpdateScenario.sameDay ||
        scenario == StartupUpdateScenario.offlineForce) {
      store.record = StartupUpdateRecord(
        lastSuccessDate: StartupUpdateRecord.day(DateTime.now()),
        forceRequired: scenario == StartupUpdateScenario.offlineForce,
      );
    }
  }
  final StartupUpdateScenario scenario;
  final store = PreviewStartupStore();
  final source = PreviewStartupSource();
  int checks = 0;
  bool repaired = false;
  @override
  Future<AppUpdateRelease> check(InstalledApp app) async {
    checks++;
    if (scenario == StartupUpdateScenario.offlineForce && !repaired) {
      throw StateError('MOCK offline');
    }
    return AppUpdateRelease(
      hasUpdate: true,
      packageName: app.packageName,
      versionName: '1.1.0',
      versionCode: 2,
      fileSize: 1024,
      forceUpdate:
          scenario == StartupUpdateScenario.forced ||
          scenario == StartupUpdateScenario.offlineForce,
      releaseNotes: '合成版本：验证启动、稍后、强制提示与安装返回。',
      apkUrl: 'https://synthetic.invalid/update.apk',
    );
  }

  @override
  Future<AppUpdateRelease?> peek(InstalledApp app) async =>
      scenario == StartupUpdateScenario.recovered ||
          scenario == StartupUpdateScenario.missingDownload
      ? AppUpdateRelease(
          hasUpdate: true,
          packageName: app.packageName,
          versionName: '1.1.0',
          versionCode: 2,
          fileSize: 1024,
          releaseNotes: '合成恢复：没有保存下载URL或请求头。',
        )
      : null;
}

class PreviewStartupStore implements StartupUpdateStore {
  StartupUpdateRecord record = const StartupUpdateRecord();
  @override
  Future<StartupUpdateRecord> read(InstalledApp app) async => record;
  @override
  Future<void> write(InstalledApp app, StartupUpdateRecord value) async {
    record = value;
  }
}

class PreviewStartupSource implements InstalledAppSource {
  @override
  Future<InstalledApp> read() async => PreviewUpdateInstallPort.app;
}

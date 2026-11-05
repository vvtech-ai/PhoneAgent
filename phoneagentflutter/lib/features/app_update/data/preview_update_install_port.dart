import '../domain/app_update.dart';
import '../domain/update_install.dart';

enum UpdateInstallScenario { normal, denied, failed, restored, paused }

/// No network, account, file or device dependency. Production never injects this.
class PreviewUpdateInstallPort implements UpdateInstallPort {
  PreviewUpdateInstallPort(this.scenario)
    : paused = scenario == UpdateInstallScenario.paused;
  final UpdateInstallScenario scenario;
  static const app = InstalledApp('com.example.preview', '1.0.0', 1);
  static const release = AppUpdateRelease(
    hasUpdate: true,
    packageName: 'com.example.preview',
    versionName: '1.1.0',
    versionCode: 2,
    forceUpdate: false,
    releaseNotes: '合成更新：下载、系统安装交接、权限返回与取消安装。',
    fileSize: 1024,
  );
  static const job = '11111111-1111-4111-8111-111111111111';
  bool allowed = false, paused;
  int _step = 0;
  bool _failed = false;
  @override
  Future<UpdateDownload?> restore(AppUpdateRelease release) async =>
      scenario == UpdateInstallScenario.restored
      ? const UpdateDownload(job, UpdateDownloadStatus.downloaded, 1024, 1024)
      : null;
  @override
  Future<UpdateDownload> begin(AppUpdateRelease release) async {
    _step = 0;
    return const UpdateDownload(job, UpdateDownloadStatus.downloading, 0, 1024);
  }

  @override
  Future<UpdateDownload> query(String job) async {
    if (paused) {
      return UpdateDownload(job, UpdateDownloadStatus.paused, 256, 1024);
    }
    if (scenario == UpdateInstallScenario.failed && !_failed) {
      _failed = true;
      return UpdateDownload(job, UpdateDownloadStatus.failed, 0, 1024);
    }
    ++_step;
    return UpdateDownload(
      job,
      _step >= 4
          ? UpdateDownloadStatus.downloaded
          : UpdateDownloadStatus.downloading,
      (_step * 256).clamp(0, 1024),
      1024,
    );
  }

  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openPermission() async {}
  @override
  Future<void> install(String job) async {}
  @override
  Future<void> cancel(String job) async {}
}

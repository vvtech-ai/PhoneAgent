import 'app_update.dart';

enum UpdateDownloadStatus { downloading, paused, downloaded, failed }

class UpdateDownloadUnavailable implements Exception {
  const UpdateDownloadUnavailable();
}

class UpdateDownload {
  const UpdateDownload(this.job, this.status, this.received, this.total);
  final String job;
  final UpdateDownloadStatus status;
  final int received;
  final int? total;
  double? get progress =>
      total == null || total! <= 0 ? null : (received / total!).clamp(0.0, 1.0);
}

abstract interface class UpdateInstallPort {
  Future<UpdateDownload?> restore(AppUpdateRelease release);
  Future<UpdateDownload> begin(AppUpdateRelease release);
  Future<UpdateDownload> query(String job);
  Future<bool> canInstall();
  Future<void> openPermission();
  Future<void> install(String job);
  Future<void> cancel(String job);
}

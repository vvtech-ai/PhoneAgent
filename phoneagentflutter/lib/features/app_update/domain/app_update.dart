class InstalledApp {
  const InstalledApp(this.packageName, this.versionName, this.versionCode);
  final String packageName, versionName;
  final int versionCode;
  bool get valid =>
      RegExp(
        r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$',
      ).hasMatch(packageName) &&
      versionName.trim().isNotEmpty &&
      versionCode > 0;
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.hasUpdate,
    required this.packageName,
    this.versionName = '',
    this.versionCode,
    this.forceUpdate = false,
    this.releaseNotes = '',
    this.fileSize,
    this.apkUrl = '',
    this.checksumSha256 = '',
    this.downloadHeaders = const {},
    this.sourceType = 0,
    this.iosSourceUrl = '',
  });
  final bool hasUpdate, forceUpdate;
  final String packageName, versionName, releaseNotes, apkUrl, checksumSha256;
  final int? versionCode, fileSize;
  final int sourceType;
  final String iosSourceUrl;
  // Sensitive headers are kept in memory only, never rendered/logged.
  final Map<String, String> downloadHeaders;
}

abstract interface class InstalledAppSource {
  Future<InstalledApp> read();
}

abstract interface class AppUpdateRepository {
  Future<AppUpdateRelease> check(InstalledApp app);
}

import 'app_update.dart';

class StartupUpdateRecord {
  const StartupUpdateRecord({this.lastSuccessDate, this.forceRequired = false});
  final String? lastSuccessDate;
  final bool forceRequired;
  bool shouldCheck(DateTime localNow) =>
      forceRequired || lastSuccessDate != day(localNow);
  static String day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

abstract interface class StartupUpdateStore {
  Future<StartupUpdateRecord> read(InstalledApp app);
  Future<void> write(InstalledApp app, StartupUpdateRecord record);
}

abstract interface class StartupUpdateRecovery {
  /// Only non-secret metadata. No download URL is recovered from persistence.
  Future<AppUpdateRelease?> peek(InstalledApp app);
}

class StartupUpdateOffer {
  const StartupUpdateOffer(this.app, this.release, {this.recovered = false});
  final InstalledApp app;
  final AppUpdateRelease release;
  final bool recovered;
}

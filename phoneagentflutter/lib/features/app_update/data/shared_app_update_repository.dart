import '../domain/app_update.dart';

/// Share only in-flight checks, never cache a result in place of daily policy.
class SharedAppUpdateRepository implements AppUpdateRepository {
  SharedAppUpdateRepository(this.delegate);
  final AppUpdateRepository delegate;
  final _pending = <String, Future<AppUpdateRelease>>{};
  @override
  Future<AppUpdateRelease> check(InstalledApp app) {
    final key = '${app.packageName}/${app.versionCode}/${app.versionName}';
    final existing = _pending[key];
    if (existing != null) return existing;
    late final Future<AppUpdateRelease> request;
    request = Future.sync(() => delegate.check(app)).whenComplete(() {
      if (identical(_pending[key], request)) _pending.remove(key);
    });
    _pending[key] = request;
    return request;
  }
}

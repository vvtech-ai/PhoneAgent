enum AppEnvironment { local, dev, test, prod }

enum ConfigIssue { unknownEnvironment, missingApi, invalidApi, insecureRelease }

/// Validated configuration. Invalid input never produces a usable API endpoint.
class AppConfig {
  const AppConfig._(
    this.environment,
    this.apiBaseUri,
    this.issue, [
    this.sdkApiBaseUri,
    this._runtimeApiBaseUri,
  ]);

  factory AppConfig.parse({
    required String environment,
    required String apiBaseUrl,
    String? sdkApiBaseUrl,
    String? runtimeApiBaseUrl,
    bool release = false,
  }) {
    final matching = AppEnvironment.values.where((e) => e.name == environment);
    if (matching.isEmpty) {
      return const AppConfig._(null, null, ConfigIssue.unknownEnvironment);
    }
    final selected = matching.single;
    if (release &&
        selected != AppEnvironment.prod &&
        selected != AppEnvironment.test) {
      return AppConfig._(selected, null, ConfigIssue.insecureRelease);
    }
    if (apiBaseUrl.trim().isEmpty) {
      return AppConfig._(selected, null, ConfigIssue.missingApi);
    }
    final uri = Uri.tryParse(apiBaseUrl.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return AppConfig._(selected, null, ConfigIssue.invalidApi);
    }
    if ((release || selected == AppEnvironment.prod) && uri.scheme != 'https') {
      return AppConfig._(selected, null, ConfigIssue.insecureRelease);
    }
    Uri? sdk;
    if (sdkApiBaseUrl != null) {
      final parsed = AppConfig.parse(
        environment: environment,
        apiBaseUrl: sdkApiBaseUrl,
        release: release,
      );
      if (!parsed.isConfigured) {
        return AppConfig._(selected, null, parsed.issue);
      }
      sdk = parsed.apiBaseUri;
    }
    Uri? runtime;
    if (runtimeApiBaseUrl != null && runtimeApiBaseUrl.trim().isNotEmpty) {
      final parsed = AppConfig.parse(
        environment: environment,
        apiBaseUrl: runtimeApiBaseUrl,
        release: release,
      );
      if (!parsed.isConfigured) {
        return AppConfig._(selected, null, parsed.issue);
      }
      runtime = parsed.apiBaseUri;
    }
    return AppConfig._(selected, uri, null, sdk, runtime);
  }

  final AppEnvironment? environment;
  final Uri? apiBaseUri;
  final Uri? sdkApiBaseUri;
  final Uri? _runtimeApiBaseUri;
  Uri? get runtimeApiBaseUri => _runtimeApiBaseUri ?? apiBaseUri;
  final ConfigIssue? issue;
  bool get isConfigured => issue == null && apiBaseUri != null;
}

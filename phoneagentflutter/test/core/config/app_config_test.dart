import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';

void main() {
  test('Runtime origin is independent and defaults to the shared gateway', () {
    final separate = AppConfig.parse(
      environment: 'dev',
      apiBaseUrl: 'http://127.0.0.1:28080/',
      runtimeApiBaseUrl: 'http://127.0.0.1:28085/',
    );
    expect(separate.runtimeApiBaseUri?.port, 28085);
    expect(separate.apiBaseUri?.port, 28080);
    expect(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/api/',
      ).runtimeApiBaseUri,
      Uri.parse('https://example.test/api/'),
    );
  });
  test('Runtime URL observes the same credential and release boundaries', () {
    for (final runtime in [
      'https://user:secret@example.test',
      'https://example.test/#fragment',
    ]) {
      expect(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/',
          runtimeApiBaseUrl: runtime,
        ).isConfigured,
        isFalse,
      );
    }
    expect(
      AppConfig.parse(
        environment: 'prod',
        apiBaseUrl: 'https://example.test/',
        runtimeApiBaseUrl: 'http://example.test/',
        release: true,
      ).issue,
      ConfigIssue.insecureRelease,
    );
  });
  test('Missing API cannot create usable configuration', () {
    final config = AppConfig.parse(environment: 'local', apiBaseUrl: '');
    expect(config.issue, ConfigIssue.missingApi);
    expect(config.apiBaseUri, isNull);
  });

  test('Unknown environment fails closed', () {
    final config = AppConfig.parse(
      environment: 'production',
      apiBaseUrl: 'https://example.test',
    );
    expect(config.issue, ConfigIssue.unknownEnvironment);
    expect(config.isConfigured, isFalse);
  });

  for (final url in [
    'invalid',
    'file:///tmp/file',
    'https://u:p@example.test',
    'https://example.test/?token=x',
    'https://example.test/#fragment',
  ]) {
    test('Unsafe URL is rejected: $url', () {
      final config = AppConfig.parse(environment: 'dev', apiBaseUrl: url);
      expect(config.issue, ConfigIssue.invalidApi);
      expect(config.apiBaseUri, isNull);
    });
  }

  test('Local HTTP is allowed but production HTTP is not', () {
    expect(
      AppConfig.parse(
        environment: 'local',
        apiBaseUrl: 'http://localhost:8080',
      ).isConfigured,
      isTrue,
    );
    expect(
      AppConfig.parse(
        environment: 'prod',
        apiBaseUrl: 'http://example.test',
      ).issue,
      ConfigIssue.insecureRelease,
    );
  });

  test(
    'Release rejects dev and local while production still requires HTTPS',
    () {
      expect(
        AppConfig.parse(
          environment: 'local',
          apiBaseUrl: 'https://example.test',
          release: true,
        ).issue,
        ConfigIssue.insecureRelease,
      );
      expect(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test',
          release: true,
        ).issue,
        ConfigIssue.insecureRelease,
      );
      expect(
        AppConfig.parse(
          environment: 'prod',
          apiBaseUrl: 'https://example.test',
          release: true,
        ).isConfigured,
        isTrue,
      );
    },
  );
}

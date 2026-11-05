import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/trusted_caller_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/config/translation_service_config.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/features/trusted_caller/data/device_trusted_caller_port.dart';

AppConfig config({bool release = false, String? sdk}) => AppConfig.parse(
  environment: 'test',
  apiBaseUrl: 'https://agent.example.test/aiassistant-api/',
  sdkApiBaseUrl: sdk ?? 'https://sdk.example.test/aiassistant-sdk-api/',
  runtimeApiBaseUrl: 'https://runtime.example.test/aiassistant-runtime/',
  release: release,
);

void main() {
  test('test keeps three explicitly configured services independent', () {
    final app = config();
    expect(app.isConfigured, isTrue);
    expect(app.environment, AppEnvironment.test);
    final routes = ServiceRoutes(app);
    expect(
      routes.resolve('api/auth/sms/send-code').toString(),
      'https://sdk.example.test/aiassistant-sdk-api/api/auth/sms/send-code',
    );
    expect(routes.resolve('api/agent/events').host, 'agent.example.test');
    expect(app.runtimeApiBaseUri?.host, 'runtime.example.test');
  });

  test('explicit HTTPS test Release preserves all service routes', () {
    final app = config(release: true);
    expect(app.isConfigured, isTrue);
    expect(app.environment, AppEnvironment.test);
    expect(app.sdkApiBaseUri?.host, 'sdk.example.test');
    expect(app.runtimeApiBaseUri?.host, 'runtime.example.test');
    expect(
      ServiceRoutes(app).resolve('api/auth/sms/login').host,
      'sdk.example.test',
    );
  });

  test('test Release rejects HTTP on each service and unsafe endpoints', () {
    for (final field in ['api', 'sdk', 'runtime']) {
      final app = AppConfig.parse(
        environment: 'test',
        apiBaseUrl: '${field == 'api' ? 'http' : 'https'}://example.test/api/',
        sdkApiBaseUrl:
            '${field == 'sdk' ? 'http' : 'https'}://example.test/sdk/',
        runtimeApiBaseUrl:
            '${field == 'runtime' ? 'http' : 'https'}://example.test/runtime/',
        release: true,
      );
      expect(app.issue, ConfigIssue.insecureRelease, reason: field);
      expect(app.isConfigured, isFalse);
    }
    for (final url in [
      'https://u:p@example.test/',
      'https://example.test/?key=x',
      'invalid',
    ]) {
      expect(config(sdk: url, release: true).isConfigured, isFalse);
    }
    expect(
      AppConfig.parse(
        environment: 'TEST',
        apiBaseUrl: 'https://example.test/',
      ).issue,
      ConfigIssue.unknownEnvironment,
    );
  });

  test('test uses non-production trusted caller SDK without invoking it', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(config()),
        trustedCallerOwnerProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    final port = container.read(trustedCallerPortProvider);
    expect(port, isA<DeviceTrustedCallerPort>());
    expect((port as DeviceTrustedCallerPort).sdkEnvironment, 'test');
  });

  test('test preserves non-production translation defaults and overrides', () {
    final test = TranslationServiceConfig.forEnvironment(AppEnvironment.test);
    final dev = TranslationServiceConfig.forEnvironment(AppEnvironment.dev);
    for (final region in ['DEFAULT', 'US', 'JP']) {
      expect(test.resolve(region), dev.resolve(region));
    }
    expect(
      TranslationServiceConfig.forEnvironment(
        AppEnvironment.test,
        defaultUrl: 'https://translation.example.test/',
      ).resolve('DEFAULT').host,
      'translation.example.test',
    );
  });
}

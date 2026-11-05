import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/service_routes.dart';

void main() {
  test(
    'artifact IDs have narrowly allowed segments, canonical colon path and longest-prefix ownership',
    () {
      final r = ServiceRoutes(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test',
          sdkApiBaseUrl: 'https://example.test/sdk',
        ),
      );
      final u = r.resolve('api/agent-artifacts/skill-template:visa:v1/content');
      expect(u.path, '/api/agent-artifacts/skill-template:visa:v1/content');
      expect(r.serviceOf(r.resolve('api/task/detail')), ApiService.sdk);
      for (final invalid in [
        'api/agent-artifacts/a:b/content',
        'api/agent-artifacts/skill-template:x%2Fy:v1/content',
        'api/agent-artifacts/../content',
      ]) {
        expect(() => r.resolve(invalid), throwsA(ApiFailure.invalidResponse));
      }
    },
  );
  test('routes current SDK resources and Agent ledger/actions separately', () {
    final routes = ServiceRoutes(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api',
        sdkApiBaseUrl: 'https://example.test/aiassistant-sdk-api',
      ),
    );
    for (final path in [
      'api/commerce/catalog',
      'api/commerce/orders/synthetic/recovery-preview',
      'api/commerce/orders/synthetic/invoice/files/PDF',
      'api/membership/current',
      'api/assistant/task-list/page',
      'api/task/detail',
      'api/auth/voice-clone/refresh',
      'api/home/config',
      'api/task-ratings',
      'api/agent-calls/recordings',
      'api/agent-calls/monitor/token',
    ]) {
      expect(routes.resolve(path).path, '/aiassistant-sdk-api/$path');
    }
    for (final path in [
      'api/agent/chat/stream',
      'api/agent/conversations/s/timeline',
      'api/agent/call-confirmation/reply',
      'api/assistant/agent/contact-lookup-result',
      'api/assistant/agent/device-contacts-lookup-result',
      'api/agent-artifacts/a/content',
      'api/assistant/realtime/call-models/latency',
      'api/assistant/realtime/call/session/status',
      'api/assistant/realtime/call/hangup',
      'api/assistant/realtime/call/monitor/token',
    ]) {
      expect(routes.resolve(path).path, '/aiassistant-api/$path');
    }
    expect(
      () => routes.resolve('https://other.test/api/x'),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(
      () => routes.resolve('api/../x'),
      throwsA(ApiFailure.invalidResponse),
    );
  });
  test('an explicit invalid SDK endpoint fails closed', () {
    expect(
      AppConfig.parse(
        environment: 'prod',
        apiBaseUrl: 'https://example.test/agent',
        sdkApiBaseUrl: 'http://example.test/sdk',
      ).isConfigured,
      isFalse,
    );
    expect(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/agent',
        sdkApiBaseUrl: '',
      ).isConfigured,
      isFalse,
    );
  });
}

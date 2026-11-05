import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:phone_agent/features/invite/domain/invite_environment_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/invite_registration_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/invite/data/invite_codec.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';

InviteLinkPolicy policy(String environment, String api) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(environment: environment, apiBaseUrl: api),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(inviteLinkPolicyProvider);
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final environment in ['dev', 'test', 'prod']) {
    final host = switch (environment) {
      'dev' => 'chakenai-dev.vvtech.tech',
      'test' => 'chakenai-test.vvtech.tech',
      _ => 'chaken.ai',
    };
    final scheme = environment == 'prod'
        ? 'phoneagent'
        : 'phoneagent-$environment';
    test('Android $environment routes only its environment', () {
      final config = AppConfig.parse(
        environment: environment,
        apiBaseUrl: 'https://$host/aiassistant-api/',
      );
      final p = invitePolicyFor(config, android: true);
      expect(
        p.parse('https://$host/aiassistant-api/invite/?code=ABCD'),
        'ABCD',
      );
      expect(p.parse('$scheme://invite/?code=ABCD'), 'ABCD');
      for (final other in [
        'chakenai-dev.vvtech.tech',
        'chakenai-test.vvtech.tech',
        'chaken.ai',
        'agent.vvtech.tech',
      ]) {
        if (other != host) {
          expect(
            p.parse('https://$other/aiassistant-api/invite/?code=ABCD'),
            isNull,
          );
        }
      }
      expect(p.parse('https://$host/aiassistant-api/invite?code=ABCD'), isNull);
      expect(
        p.parse('https://$host:444/aiassistant-api/invite/?code=ABCD'),
        isNull,
      );
      expect(
        p.parse(
          'https://phoneagent-ioslink.vvtech.tech/phoneagent/ios/invite/?code=ABCD',
        ),
        isNull,
      );
    });
    test('iOS $environment retains Universal Link under current API', () {
      final p = policy(environment, 'https://$host/aiassistant-api/');
      final universalHost = environment == 'prod'
          ? 'ioslink.chaken.ai'
          : 'phoneagent-ioslink.vvtech.tech';
      final webHost = environment == 'prod' ? 'www.chaken.ai' : host;
      expect(p.host, webHost);
      expect(
        p.parse('https://$webHost/aiassistant-api/invite/?code=ABCD'),
        'ABCD',
      );
      for (final other in [
        'chakenai-dev.vvtech.tech',
        'chakenai-test.vvtech.tech',
      ]) {
        if (other != webHost) {
          expect(
            p.parse('https://$other/aiassistant-api/invite/?code=ABCD'),
            isNull,
          );
        }
      }
      expect(
        p.parse('https://$universalHost/phoneagent/ios/invite/?code=ABCD'),
        'ABCD',
      );
      if (environment != 'prod') {
        expect(
          p.parse(
            'https://agent.vvtech.tech/aiassistant-api/invite/?code=ABCD',
          ),
          'ABCD',
        );
        expect(p.parse('phoneagent-test://invite/?code=ABCD'), 'ABCD');
        expect(p.parse('phoneagent-dev://invite/?code=ABCD'), isNull);
      }
    });
  }
  test('mismatched API environment and nonstandard ports remain rejected', () {
    for (final api in [
      'https://chakenai-test.vvtech.tech/aiassistant-api/',
      'https://chakenai-dev.vvtech.tech:444/aiassistant-api/',
    ]) {
      final config = AppConfig.parse(environment: 'dev', apiBaseUrl: api);
      for (final android in [true, false]) {
        final p = invitePolicyFor(config, android: android);
        expect(p.host, isEmpty);
        expect(p.universalHost, isEmpty);
        expect(p.scheme, isEmpty);
      }
    }
  });
  for (final apiHost in [
    'chaken.ai',
    'www.chaken.ai',
    'phoneagent.chaken.net.cn',
  ]) {
    test('prod API $apiHost accepts both real share hosts and iOS link', () {
      final p = policy('prod', 'https://$apiHost/aiassistant-api');
      expect(p.host, 'www.chaken.ai');
      for (final shareHost in ['chaken.ai', 'www.chaken.ai']) {
        final url = 'https://$shareHost/aiassistant-api/invite/?code=ABCD';
        expect(p.parse(url), 'ABCD');
        expect(
          inviteCode({
            'code': 'ABCD',
            'shareUrl': url,
            'expiresAt': '2030-01-01',
            'confirmedUsed': 0,
            'reservedCount': 0,
            'available': 1,
            'activity': {
              'periodId': 'synthetic-period',
              'name': '合成活动',
              'inviterPoints': 10,
              'inviteePoints': 20,
              'quotaPerInviter': 5,
              'fullBonusEnabled': false,
            },
          }, p).url,
          url,
        );
      }
      expect(
        p.parse('https://ioslink.chaken.ai/phoneagent/ios/invite/?code=ABCD'),
        'ABCD',
      );
      for (final url in [
        'https://agent.vvtech.tech/aiassistant-api/invite/?code=ABCD',
        'https://phoneagent-ioslink.vvtech.tech/phoneagent/ios/invite/?code=ABCD',
        'https://www.chaken.ai.evil.test/aiassistant-api/invite/?code=ABCD',
        'http://chaken.ai/aiassistant-api/invite/?code=ABCD',
        'https://www.chaken.ai:444/aiassistant-api/invite/?code=ABCD',
        'https://www.chaken.ai/invite/?code=ABCD',
        'https://chaken.ai/aiassistant-api/invite/?code=ABCD&invite=EFGH',
        'https://chaken.ai/aiassistant-api/invite/?code=ABC',
      ]) {
        expect(p.parse(url), isNull, reason: url);
      }
    });
  }
  test('production API retains exact iOS link and Android entry policy', () {
    final config = AppConfig.parse(
      environment: 'prod',
      apiBaseUrl: 'https://phoneagent.chaken.net.cn/aiassistant-api/',
    );
    final ios = invitePolicyFor(config, android: false);
    expect(
      ios.parse('https://ioslink.chaken.ai/phoneagent/ios/invite/?code=VYFX'),
      'VYFX',
    );
    expect(
      ios.parse(
        'https://phoneagent.chaken.net.cn/aiassistant-api/invite/?code=VYFX',
      ),
      isNull,
    );
    final android = invitePolicyFor(config, android: true);
    expect(
      android.parse('https://chaken.ai/aiassistant-api/invite/?code=VYFX'),
      'VYFX',
    );
    expect(android.parse('phoneagent://invite/?code=VYFX'), 'VYFX');
  });
  test('production API addition preserves environment and host boundaries', () {
    for (final environment in ['dev', 'test', 'prod']) {
      final apis = environment == 'prod'
          ? [
              'https://phoneagent.chaken.net.cn.evil.test/aiassistant-api/',
              'https://phoneagent.chaken.net.cn:444/aiassistant-api/',
            ]
          : ['https://phoneagent.chaken.net.cn/aiassistant-api/'];
      for (final api in apis) {
        final config = AppConfig.parse(
          environment: environment,
          apiBaseUrl: api,
        );
        for (final android in [true, false]) {
          final p = invitePolicyFor(config, android: android);
          expect(p.host, isEmpty);
          expect(p.universalHost, isEmpty);
          expect(p.scheme, isEmpty);
        }
      }
    }
  });
  test('dev accepts only test environment links', () {
    final p = policy('dev', 'https://agent.vvtech.tech/aiassistant-api');
    expect(
      p.parse('https://agent.vvtech.tech/aiassistant-api/invite/?code=ABCD'),
      'ABCD',
    );
    expect(
      p.parse(
        'https://phoneagent-ioslink.vvtech.tech/phoneagent/ios/invite/?code=ABCD',
      ),
      'ABCD',
    );
    for (final host in ['chaken.ai', 'www.chaken.ai']) {
      expect(
        p.parse('https://$host/aiassistant-api/invite/?code=ABCD'),
        isNull,
      );
    }
    expect(
      p.parse('https://ioslink.chaken.ai/phoneagent/ios/invite/?code=ABCD'),
      isNull,
    );
  });
  test('untrusted API does not enable trusted invitation entry points', () {
    final p = policy('prod', 'https://untrusted.test/aiassistant-api');
    expect(
      p.parse('https://www.chaken.ai/aiassistant-api/invite/?code=ABCD'),
      isNull,
    );
    expect(
      p.parse('https://ioslink.chaken.ai/phoneagent/ios/invite/?code=ABCD'),
      isNull,
    );
    expect(p.parse('phoneagent://invite/?code=ABCD'), isNull);
  });
}

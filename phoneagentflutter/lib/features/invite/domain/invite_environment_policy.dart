import '../../../../core/config/app_config.dart';
import 'invite_link_policy.dart';

/// App entry addresses are platform contracts, independent of API gateway paths.
InviteLinkPolicy invitePolicyFor(AppConfig config, {required bool android}) {
  final environment = config.environment;
  final base = config.apiBaseUri;
  final prod = environment == AppEnvironment.prod;
  final apiHosts = switch (environment) {
    AppEnvironment.dev => {'chakenai-dev.vvtech.tech', 'agent.vvtech.tech'},
    AppEnvironment.test => {'chakenai-test.vvtech.tech', 'agent.vvtech.tech'},
    AppEnvironment.prod => {
      'chaken.ai',
      'www.chaken.ai',
      'phoneagent.chaken.net.cn',
    },
    _ => <String>{},
  };
  if (base == null ||
      base.scheme != 'https' ||
      (base.hasPort && base.port != 443) ||
      !apiHosts.contains(base.host)) {
    return const InviteLinkPolicy(host: '', path: '', scheme: '');
  }
  if (android) {
    return InviteLinkPolicy(
      host: switch (environment) {
        AppEnvironment.dev => 'chakenai-dev.vvtech.tech',
        AppEnvironment.test => 'chakenai-test.vvtech.tech',
        _ => 'chaken.ai',
      },
      path: '/aiassistant-api/invite/',
      scheme: switch (environment) {
        AppEnvironment.dev => 'phoneagent-dev',
        AppEnvironment.test => 'phoneagent-test',
        _ => 'phoneagent',
      },
    );
  }
  return InviteLinkPolicy(
    host: switch (environment) {
      AppEnvironment.dev => 'chakenai-dev.vvtech.tech',
      AppEnvironment.test => 'chakenai-test.vvtech.tech',
      _ => 'www.chaken.ai',
    },
    compatibleWebHosts: prod
        ? const {'chaken.ai'}
        : const {'agent.vvtech.tech'},
    path: '/aiassistant-api/invite/',
    scheme: prod ? 'phoneagent' : 'phoneagent-test',
    universalHost: prod
        ? 'ioslink.chaken.ai'
        : 'phoneagent-ioslink.vvtech.tech',
  );
}

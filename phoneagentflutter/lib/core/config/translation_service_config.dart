import 'app_config.dart';

/// Fixed v65 deployment defaults, not the account API host.
class TranslationServiceConfig {
  const TranslationServiceConfig(this.endpoints);
  factory TranslationServiceConfig.forEnvironment(
    AppEnvironment environment, {
    String? defaultUrl,
    String? usUrl,
    String? jpUrl,
  }) => TranslationServiceConfig({
    'DEFAULT':
        defaultUrl ??
        (environment == AppEnvironment.prod
            ? 'https://translate-test-us-webrtc.vvtech.tech'
            : 'https://translate-us-webrtc.vvtech.tech'),
    'US': usUrl ?? 'https://translate-test-us-webrtc.vvtech.tech',
    'JP': jpUrl ?? 'https://translate-test-jp-webrtc.vvtech.tech',
  });
  final Map<String, String> endpoints;

  Uri resolve(String region) {
    if (!const {'DEFAULT', 'US', 'JP'}.contains(region)) {
      throw const FormatException('Unknown translation region');
    }
    final selected = endpoints[region]?.trim() ?? '';
    final raw = selected.isEmpty
        ? endpoints['DEFAULT']?.trim() ?? ''
        : selected;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid translation endpoint');
    }
    return uri.replace(path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/');
  }
}

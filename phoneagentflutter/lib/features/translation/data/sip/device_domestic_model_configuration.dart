import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/domestic_model_endpoints.dart';
import '../../domain/sip/domestic_translation_model.dart';

/// Credentials exist only in the native deployment resource and session memory.
/// This read never initializes a model, accesses audio, or requests a SIP lease.
class DeviceDomesticModelConfigurationSource
    implements DomesticModelConfigurationSource {
  const DeviceDomesticModelConfigurationSource({
    required this.appConfig,
    this.channel = const MethodChannel(
      'com.vvtech.phone_agent/domestic_model_configuration',
    ),
  });
  final AppConfig appConfig;
  final MethodChannel channel;

  @override
  Future<DomesticModelConfiguration?> load(String provider) async {
    if (!appConfig.isConfigured ||
        kIsWeb ||
        !const {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform) ||
        !const {'QWEN', 'DOUBAO'}.contains(provider)) {
      return null;
    }
    try {
      final raw = await channel.invokeMethod<Object?>('read', {
        'provider': provider,
      });
      if (raw is! Map ||
          raw['provider'] != provider ||
          raw['uri'] is! String ||
          raw['model'] is! String ||
          raw['voice'] != 'Nofish' ||
          raw['outputSampleRate'] != (provider == 'QWEN' ? 24000 : 16000) ||
          raw['headers'] is! Map) {
        return null;
      }
      final uri = Uri.tryParse(raw['uri'] as String);
      final expected = domesticModelWebSocketEndpoints[provider];
      if (uri == null || uri.toString() != expected) return null;
      final headers = <String, String>{};
      for (final entry in (raw['headers'] as Map).entries) {
        if (entry.key is! String ||
            entry.value is! String ||
            (entry.value as String).trim().isEmpty ||
            RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(entry.value as String)) {
          return null;
        }
        headers[entry.key as String] = entry.value as String;
      }
      if (provider == 'QWEN') {
        final auth = headers['Authorization'];
        if (headers.length != 1 ||
            auth == null ||
            !auth.startsWith('Bearer ') ||
            auth.substring(7).trim().isEmpty) {
          return null;
        }
      } else if (headers.length != 2 ||
          headers['X-Api-Resource-Id'] != raw['model'] ||
          (headers.containsKey('X-Api-Key') ==
              headers.containsKey('X-Api-Access-Key'))) {
        return null;
      }
      return DomesticModelConfiguration(
        provider: provider,
        uri: uri,
        headers: headers,
        model: raw['model'] as String,
        voice: 'Nofish',
        outputSampleRate: raw['outputSampleRate'] as int,
      );
    } catch (_) {
      // Platform errors may contain private input; never forward their details.
      return null;
    }
  }
}

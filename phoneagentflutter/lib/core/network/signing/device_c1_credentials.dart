import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../account_session.dart';
import '../service_routes.dart';
import 'c1_credentials.dart';
import '../../storage/app_local_storage.dart';
import 'c1_transport.dart';

/// Deployment-provided per-platform app credentials, never source-code defaults.
class DeviceC1Credentials implements C1CredentialSource {
  DeviceC1Credentials({
    this.channel = const MethodChannel('com.vvtech.phone_agent/app_info'),
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
    this.sdkKey = const String.fromEnvironment('SDK_API_KEY'),
    this.sdkSecret = const String.fromEnvironment('SDK_API_SECRET'),
    this.agentKey = const String.fromEnvironment('AGENT_API_KEY'),
    this.agentSecret = const String.fromEnvironment('AGENT_API_SECRET'),
  });
  final MethodChannel channel;
  final FlutterSecureStorage storage;
  final String sdkKey, sdkSecret, agentKey, agentSecret;
  Future<(String, String)>? _metadata;

  @override
  Future<C1Credentials> read(ApiService service) async {
    final key = service == ApiService.sdk ? sdkKey : agentKey;
    final secret = service == ApiService.sdk ? sdkSecret : agentSecret;
    if (key.isEmpty ||
        secret.isEmpty ||
        kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      throw ApiFailure.unavailable;
    }
    try {
      final metadata = await (_metadata ??= _readMetadata());
      return C1Credentials(
        apiKey: key,
        secret: secret,
        deviceId: metadata.$1,
        clientContext: metadata.$2,
      );
    } catch (_) {
      _metadata = null;
      throw ApiFailure.unavailable;
    }
  }

  Future<(String, String)> _readMetadata() async {
    const idKey = 'sdk.c1.installation.v1';
    var id = await storage.read(key: idKey);
    if (id == null) {
      id = C1Transport.newDeviceId();
      await storage.write(key: idKey, value: id);
    }
    final context = await channel.invokeMapMethod<String, Object?>('readC1');
    if (context == null ||
        context['appVersionCode'] is! int ||
        (context['appVersionCode'] as int) < 1 ||
        context['osName'] !=
            (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android')) {
      throw ApiFailure.unavailable;
    }
    return (
      id,
      base64Url.encode(utf8.encode(jsonEncode(context))).replaceAll('=', ''),
    );
  }
}

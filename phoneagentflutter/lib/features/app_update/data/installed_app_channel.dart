import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/app_update.dart';

class InstalledAppChannel implements InstalledAppSource {
  const InstalledAppChannel({
    this.channel = const MethodChannel('com.vvtech.phone_agent/app_info'),
    this.supported,
  });
  final MethodChannel channel;
  final bool? supported;
  @override
  Future<InstalledApp> read() async {
    if (!(supported ??
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)))) {
      throw UnsupportedError('Mobile metadata only');
    }
    final data = await channel.invokeMapMethod<String, Object?>('read');
    if (data == null ||
        data['packageName'] is! String ||
        data['versionName'] is! String ||
        data['versionCode'] is! int) {
      throw const FormatException('Invalid installed metadata');
    }
    final app = InstalledApp(
      data['packageName'] as String,
      data['versionName'] as String,
      data['versionCode'] as int,
    );
    if (!app.valid) throw const FormatException('Invalid installed metadata');
    return app;
  }
}

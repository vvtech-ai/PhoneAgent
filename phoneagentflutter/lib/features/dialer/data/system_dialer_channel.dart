import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/system_dialer.dart';

class SystemDialerChannel implements SystemDialer {
  const SystemDialerChannel({
    MethodChannel channel = const MethodChannel(
      'com.vvtech.phone_agent/system_dialer',
    ),
    bool? supported,
  }) : _channel = channel,
       _supported = supported;
  final MethodChannel _channel;
  final bool? _supported;
  @override
  Future<SystemDialResult> open(String number) async {
    if (!RegExp(r'^\+?[0-9*#]+$').hasMatch(number)) {
      return SystemDialResult.invalid;
    }
    if (!(_supported ??
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)))) {
      return SystemDialResult.unsupported;
    }
    try {
      return switch (await _channel.invokeMethod<String>('open', {
        'number': number,
      })) {
        'opened' => SystemDialResult.opened,
        'unsupported' => SystemDialResult.unsupported,
        'invalid' => SystemDialResult.invalid,
        _ => SystemDialResult.failed,
      };
    } on MissingPluginException {
      return SystemDialResult.unsupported;
    } on PlatformException {
      return SystemDialResult.failed;
    }
  }
}

/// Only injected through the explicitly labelled Web preview switch.
class PreviewSystemDialer implements SystemDialer {
  @override
  Future<SystemDialResult> open(String number) async => SystemDialResult.opened;
}

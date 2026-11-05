import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Called only by the preview player while its media lease is held.
Future<void> prepareClonePreviewAudioSession() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  await const MethodChannel(
    'phone_agent/identity_capture',
  ).invokeMethod<void>('preparePreviewAudio');
}

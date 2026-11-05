import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/recording/domestic_recording_encoder.dart';

class DeviceDomesticRecordingEncoder implements DomesticRecordingEncoder {
  const DeviceDomesticRecordingEncoder({
    this.channel = const MethodChannel('phone_agent/domestic_recording'),
  });
  final MethodChannel channel;

  Future<String> privateRoot() async {
    _guardPlatform();
    final path = await channel.invokeMethod<String>('directory');
    if (path == null || !path.startsWith('/') || path.contains('\u0000')) {
      throw StateError('Private recording directory unavailable');
    }
    return path;
  }

  @override
  Future<void> encode({
    required String pcmPath,
    required String m4aPath,
  }) async {
    _guardPlatform();
    // Await native completion before the finalizer removes the input file.
    await channel.invokeMethod<void>('encode', {
      'pcmPath': pcmPath,
      'm4aPath': m4aPath,
    });
  }

  void _guardPlatform() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Domestic recording requires Android or iOS');
    }
  }
}

import 'dart:typed_data';
import '../../conversation/data/voice/device_pcm_output.dart';
import '../domain/call_monitor_media.dart';

class DeviceCallMonitorOutput implements CallMonitorOutput {
  DeviceCallMonitorOutput({DevicePcmOutput? delegate})
    : delegate = delegate ?? DevicePcmOutput(communication: true);
  final DevicePcmOutput delegate;
  @override
  Future<void> start(int sampleRateHz) => delegate.start(sampleRateHz);
  @override
  Future<void> play(Uint8List bytes) => delegate.play(bytes);
  @override
  Future<void> stop() => delegate.stop();
  @override
  Future<void> setPlaybackEnabled(bool enabled) =>
      delegate.setPlaybackEnabled(enabled);
  @override
  Future<CallMonitorRoute> route({String? select}) async {
    final value = await delegate.communicationRoute(select: select);
    return CallMonitorRoute(
      selected: value['selected']! as String,
      bluetooth: value['bluetooth']! as bool,
    );
  }
}

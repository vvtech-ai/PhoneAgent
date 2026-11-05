import 'package:flutter/services.dart';
import '../domain/invite_device.dart';

class DeviceInvitePort implements InviteDevice {
  const DeviceInvitePort();
  static const _channel = MethodChannel('phone_agent/invite');
  static const _events = EventChannel('phone_agent/invite_links');
  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
  @override
  Future<bool> savePoster(Uint8List png) async =>
      await _channel.invokeMethod<bool>('savePoster', png) ?? false;
  @override
  Future<String?> initialLink() => _channel.invokeMethod<String>('initialLink');
  @override
  Stream<String> get links =>
      _events.receiveBroadcastStream().where((v) => v is String).cast<String>();
}

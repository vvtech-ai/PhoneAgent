import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/context/agent_clock.dart';
import 'browser_agent_clock_stub.dart'
    if (dart.library.js_interop) 'browser_agent_clock_web.dart';

class DeviceAgentClock implements AgentClockSource {
  const DeviceAgentClock({
    this.channel = const MethodChannel('phone_agent/device_clock'),
    this.web,
    this.platform,
  });
  final MethodChannel channel;
  final bool? web;
  final TargetPlatform? platform;

  @override
  Future<AgentClockSnapshot> read() async {
    if (web ?? kIsWeb) return readBrowserAgentClock();
    if (!{
      TargetPlatform.android,
      TargetPlatform.iOS,
    }.contains(platform ?? defaultTargetPlatform)) {
      return AgentClockSnapshot.localNow();
    }
    final raw = await channel.invokeMapMethod<String, Object?>('read');
    final epoch = raw?['epochMillis'],
        offset = raw?['offsetSeconds'],
        zone = raw?['timezone'];
    if (epoch is! int || offset is! int || zone is! String) {
      throw const FormatException('Invalid device clock');
    }
    return AgentClockSnapshot(
      epochMillis: epoch,
      offsetSeconds: offset,
      timezone: zone,
    );
  }
}

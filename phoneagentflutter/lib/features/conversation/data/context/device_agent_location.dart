import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/context/agent_location.dart';

class DeviceAgentLocation implements AgentLocationSource {
  DeviceAgentLocation({
    this.channel = const MethodChannel('phone_agent/agent_location'),
    this.web,
    this.platform,
  });
  final MethodChannel channel;
  final bool? web;
  final TargetPlatform? platform;
  static int _sequence = 0;
  String? _active;

  @override
  Future<AgentLocation?> read() async {
    if ((web ?? kIsWeb) ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(platform ?? defaultTargetPlatform)) {
      return null;
    }
    if (_active != null) throw StateError('Location already pending');
    final id = 'agent-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
    _active = id;
    try {
      final result = await channel
          .invokeMapMethod<String, Object?>('read', {'requestId': id})
          .timeout(const Duration(seconds: 10));
      if (_active != id || result == null) return null;
      final lat = result['lat'], lng = result['lng'];
      if (lat is! num || lng is! num) {
        throw const FormatException('Invalid sample');
      }
      final address = result['address'];
      if (address != null && address is! String) {
        throw const FormatException('Invalid address');
      }
      return AgentLocation(
        lat.toDouble(),
        lng.toDouble(),
        address: address as String? ?? '',
      );
    } finally {
      if (_active == id) _active = null;
      try {
        await _cancel(id);
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    final id = _active;
    _active = null;
    if (id != null) await _cancel(id);
  }

  Future<void> _cancel(String id) => channel
      .invokeMethod<void>('cancel', {'requestId': id})
      .timeout(const Duration(seconds: 1));
}

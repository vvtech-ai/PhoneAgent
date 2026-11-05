import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/trusted_identity_surface_port.dart';
import '../domain/trusted_incoming_identity.dart';
import 'trusted_identity_presentation_payload.dart';

class DeviceTrustedIdentitySurfacePort implements TrustedIdentitySurfacePort {
  DeviceTrustedIdentitySurfacePort({
    required this.environment,
    MethodChannel channel = const MethodChannel(
      'phone_agent/trusted_identity_surface',
    ),
    bool? enabled,
  }) : _channel = channel,
       _enabled =
           enabled ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    if (_enabled) _channel.setMethodCallHandler(_receive);
  }
  final String environment;
  final MethodChannel _channel;
  final bool _enabled;
  final _events = StreamController<TrustedIdentitySurfaceEvent>.broadcast();
  @override
  Stream<TrustedIdentitySurfaceEvent> get events => _events.stream;

  Future<Object?> _receive(MethodCall call) async {
    if (!_events.isClosed &&
        {'dismissed', 'presented', 'retry'}.contains(call.method) &&
        call.arguments is String) {
      _events.add(
        TrustedIdentitySurfaceEvent(call.method, call.arguments as String),
      );
    }
    return null;
  }

  @override
  Future<TrustedIdentitySurfaceResult> synchronize(
    TrustedIncomingIdentity? value,
  ) async {
    if (!_enabled) return TrustedIdentitySurfaceResult.fallback;
    try {
      final result = await _channel.invokeMethod<String>(
        'synchronize',
        value == null
            ? null
            : TrustedIdentityPresentationPayload.encode(value, environment),
      );
      return switch (result) {
        'fallback' => TrustedIdentitySurfaceResult.fallback,
        'overlay' => TrustedIdentitySurfaceResult.overlay,
        _ => TrustedIdentitySurfaceResult.deferred,
      };
    } on MissingPluginException {
      return TrustedIdentitySurfaceResult.fallback;
    } on PlatformException {
      return TrustedIdentitySurfaceResult.deferred;
    }
  }

  @override
  Future<void> dispose() async {
    if (_enabled) {
      await synchronize(null);
      _channel.setMethodCallHandler(null);
    }
    await _events.close();
  }
}

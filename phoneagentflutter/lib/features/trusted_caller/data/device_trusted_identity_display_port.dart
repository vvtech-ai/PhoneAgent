import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/trusted_identity_display_port.dart';
import '../domain/trusted_incoming_identity.dart';
import 'trusted_identity_presentation_payload.dart';

class DeviceTrustedIdentityDisplayPort implements TrustedIdentityDisplayPort {
  DeviceTrustedIdentityDisplayPort({
    MethodChannel channel = const MethodChannel(
      'phone_agent/trusted_identity_overlay',
    ),
  }) : _channel = channel {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'update' && !_updates.isClosed) {
        _updates.add(TrustedIdentityPresentationPayload.decode(call.arguments));
      }
      return null;
    });
  }
  final MethodChannel _channel;
  final _updates = StreamController<TrustedIncomingIdentity?>.broadcast(
    sync: true,
  );
  @override
  Stream<TrustedIncomingIdentity?> get updates => _updates.stream;
  Future<void> _send(String method, [String? id]) async {
    try {
      await _channel.invokeMethod<void>(method, id);
    } on MissingPluginException {
      // The native owner may already have destroyed this display container.
    } on PlatformException {
      // The native owner controls container lifetime and visibility reporting.
    }
  }

  @override
  Future<void> ready() => _send('ready');
  @override
  Future<void> rendered(String presentationId) =>
      _send('rendered', presentationId);
  @override
  Future<void> dismiss(String presentationId) =>
      _send('dismiss', presentationId);
  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _updates.close();
  }
}

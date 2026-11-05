import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/translation_location.dart';

class TranslationLocationChannel implements TranslationLocationSource {
  TranslationLocationChannel({
    this.channel = const MethodChannel('phone_agent/translation_location'),
    this.web,
    this.platform,
  });
  final MethodChannel channel;
  final bool? web;
  final TargetPlatform? platform;
  static int _sequence = 0;
  String? _requestId;
  bool get _supported =>
      !(web ?? kIsWeb) &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(platform ?? defaultTargetPlatform);

  @override
  Future<TranslationLocationResult> locate() async {
    if (!_supported) {
      return const TranslationLocationResult(
        TranslationLocationStatus.unavailable,
      );
    }
    if (_requestId != null) throw StateError('Location request active');
    final id = '${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
    _requestId = id;
    try {
      final raw = await channel
          .invokeMapMethod<String, Object?>('locate', {'requestId': id})
          .timeout(const Duration(seconds: 100));
      final status = switch (raw?['status']) {
        'resolved' => TranslationLocationStatus.resolved,
        'denied' => TranslationLocationStatus.denied,
        'blocked' => TranslationLocationStatus.blocked,
        'unavailable' => TranslationLocationStatus.unavailable,
        'failed' => TranslationLocationStatus.failed,
        _ => throw const FormatException('Invalid location response'),
      };
      final iso = raw?['countryIso'];
      if (status == TranslationLocationStatus.resolved) {
        if (iso is! String) throw const FormatException('Missing country');
        TrustedTranslationLocation(
          iso,
          1,
        ); // Same validation as cache/controller.
      }
      return TranslationLocationResult(
        status,
        countryIso: iso is String ? iso : null,
      );
    } finally {
      if (_requestId == id) _requestId = null;
      // Cancel only this generation, never a newer request on the same engine.
      try {
        await channel.invokeMethod<void>('cancel', {'requestId': id});
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    final id = _requestId;
    _requestId = null;
    if (_supported && id != null) {
      await channel.invokeMethod<void>('cancel', {'requestId': id});
    }
  }

  @override
  Future<void> openSettings() async {
    if (!_supported) throw UnsupportedError('Location settings unavailable');
    await channel.invokeMethod<void>('openSettings');
  }
}

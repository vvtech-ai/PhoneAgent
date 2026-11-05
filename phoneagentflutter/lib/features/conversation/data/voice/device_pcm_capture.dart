import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/audio/pcm_capture.dart';

/// Pull-based bridge: no unbounded EventChannel audio queue, no permission UI.
class DevicePcmCapture implements PcmCapture {
  DevicePcmCapture({
    this.channel = const MethodChannel('phone_agent/pcm_capture'),
    this.platform,
    this.web,
    this.duplex = false,
    this.speechInput = false,
    this.backgroundCallId,
  }) : _id =
           '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  final bool duplex;
  final bool speechInput;
  final String? backgroundCallId;
  final String _id;
  bool _used = false, _requested = false, _stopped = false, _reading = false;
  bool _released = false;
  Future<void>? _stopping;

  @override
  Future<void> start() => _start();

  /// iOS translation only: initialize hardware without retaining pre-call PCM.
  Future<void> prepareDuplexCall() {
    if (!duplex ||
        backgroundCallId == null ||
        (platform ?? defaultTargetPlatform) != TargetPlatform.iOS) {
      throw const PcmCaptureFailure('capture_unavailable');
    }
    return _start(deferDelivery: true);
  }

  Future<void> resumeDuplexCall() async {
    if (!_requested ||
        _stopped ||
        !duplex ||
        (platform ?? defaultTargetPlatform) != TargetPlatform.iOS) {
      throw const PcmCaptureFailure('capture_cancelled');
    }
    if (await _invoke('resumePreparedCall') != true || _stopped) {
      throw const PcmCaptureFailure('capture_start_failed');
    }
  }

  Future<void> _start({bool deferDelivery = false}) async {
    if (_used || _stopped) throw const PcmCaptureFailure('capture_used');
    _used = true;
    if ((web ?? kIsWeb) ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(platform ?? defaultTargetPlatform)) {
      throw const PcmCaptureFailure('capture_unavailable');
    }
    _requested = true;
    final result = await _invoke('start', {
      if (duplex) 'duplex': true,
      if (speechInput) 'speechInput': true,
      if (backgroundCallId != null) 'callAudioId': backgroundCallId,
      if (deferDelivery) 'deferDelivery': true,
    });
    if (result != true) throw const PcmCaptureFailure('capture_start_failed');
    if (_stopped) throw const PcmCaptureFailure('capture_cancelled');
  }

  @override
  Future<Uint8List?> read() async {
    if (_stopped) return null;
    if (!_requested || _reading) {
      throw const PcmCaptureFailure('capture_read_busy');
    }
    _reading = true;
    try {
      final result = await _invoke('read');
      if (_stopped || result == null) return null;
      if (result is! Uint8List ||
          result.isEmpty ||
          result.length.isOdd ||
          result.length > 640) {
        throw const PcmCaptureFailure('capture_invalid_pcm');
      }
      return result;
    } finally {
      _reading = false;
    }
  }

  Future<void> setDuplexSpeaker(bool enabled) async {
    if (!duplex || !_requested || _stopped) {
      throw const PcmCaptureFailure('capture_cancelled');
    }
    if (await _invoke('speaker', {'enabled': enabled}) != true) {
      throw const PcmCaptureFailure('capture_route_failed');
    }
  }

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<Object?>(method, {
        'captureId': _id,
        ...?args,
      });
    } on PlatformException catch (error) {
      const codes = {
        'permission_denied',
        'capture_busy',
        'capture_interrupted',
        'capture_overflow',
        'capture_read_failed',
        'capture_stop_failed',
      };
      throw PcmCaptureFailure(
        codes.contains(error.code) ? error.code : 'capture_failed',
      );
    } on MissingPluginException {
      throw const PcmCaptureFailure('capture_unavailable');
    }
  }

  @override
  Future<void> stop() {
    _stopped = true; // Invalidates a pending read/start before awaiting native.
    if (_released || !_requested) return Future.value();
    return _stopping ??= _release();
  }

  Future<void> _release() async {
    try {
      if (await _invoke('stop') != true) {
        throw const PcmCaptureFailure('capture_stop_failed');
      }
      _released = true;
    } finally {
      _stopping = null;
    }
  }
}

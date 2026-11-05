import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/audio/pcm_output.dart';
import '../../../../core/diagnostics/diagnostic_pcm_details.dart';

class DevicePcmOutput implements PcmOutput {
  DevicePcmOutput({
    this.channel = const MethodChannel('phone_agent/pcm_output'),
    this.platform,
    this.web,
    this.communication = false,
    this.duplex = false,
    this.backgroundCallId,
    this.queuedTranslation = false,
  }) : _id =
           '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  final bool communication;
  final bool duplex;
  bool queuedTranslation;
  bool get _queued =>
      queuedTranslation &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(platform ?? defaultTargetPlatform);
  final String? backgroundCallId;
  final String _id;
  int _sampleRate = 0, _pendingBytes = 0;
  bool _used = false, _requested = false, _started = false, _stopped = false;
  bool _released = false;
  Future<void>? _stopping;

  @override
  Future<void> start(int sampleRateHz) async {
    if (_used || _stopped) throw const PcmOutputFailure('output_used');
    _used = true;
    if (sampleRateHz < 8000 || sampleRateHz > 48000) {
      throw const PcmOutputFailure('output_format');
    }
    if ((web ?? kIsWeb) ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(platform ?? defaultTargetPlatform)) {
      throw const PcmOutputFailure('output_unavailable');
    }
    _sampleRate = sampleRateHz;
    _requested = true;
    if (await _invoke('start', {
          'sampleRate': sampleRateHz,
          if (_queued) 'queuedTranslation': true,
          if (communication) 'communication': true,
          if (duplex) 'duplex': true,
          if (backgroundCallId != null) 'callAudioId': backgroundCallId,
        }) !=
        true) {
      throw const PcmOutputFailure('output_start_failed');
    }
    if (_stopped) throw const PcmOutputFailure('output_cancelled');
    _started = true;
  }

  Future<void> setPlaybackEnabled(bool enabled) async {
    if (!communication || !_started || _stopped) {
      throw const PcmOutputFailure('output_cancelled');
    }
    if (await _invoke('enabled', {'enabled': enabled}) != true) {
      throw const PcmOutputFailure('output_play_failed');
    }
  }

  Future<Map<Object?, Object?>> communicationRoute({String? select}) async {
    if (!communication || !_started || _stopped) {
      throw const PcmOutputFailure('output_cancelled');
    }
    final value = await _invoke('route', {
      if (select != null) 'select': select,
    });
    if (value is! Map ||
        !{'earpiece', 'speaker', 'bluetooth'}.contains(value['selected']) ||
        value['bluetooth'] is! bool) {
      throw const PcmOutputFailure('output_route_failed');
    }
    return value;
  }

  @override
  Future<void> play(Uint8List bytes) async {
    if (!_started || _stopped) {
      throw const PcmOutputFailure('output_cancelled');
    }
    if (bytes.isEmpty ||
        bytes.length.isOdd ||
        _pendingBytes + bytes.length > _sampleRate * 4) {
      throw const PcmOutputFailure('output_capacity');
    }
    _pendingBytes += bytes.length;
    try {
      if (await _invoke('play', {'bytes': bytes}) != true) {
        throw const PcmOutputFailure('output_play_failed');
      }
      if (_stopped) throw const PcmOutputFailure('output_cancelled');
    } finally {
      _pendingBytes -= bytes.length;
    }
  }

  /// Translation-only admission. Ordinary play still waits for audible completion.
  Future<void> enqueue(Uint8List bytes) async {
    if (!_queued) return play(bytes);
    if (!_started || _stopped) throw const PcmOutputFailure('output_cancelled');
    if (bytes.isEmpty || bytes.length.isOdd || bytes.length > _sampleRate * 4) {
      throw const PcmOutputFailure('output_capacity');
    }
    if (await _invoke('enqueue', {'bytes': bytes}) != true) {
      throw const PcmOutputFailure('output_play_failed');
    }
    if (_stopped) throw const PcmOutputFailure('output_cancelled');
  }

  Future<void> drain() async {
    if (!_queued) return;
    if (!_started || _stopped) throw const PcmOutputFailure('output_cancelled');
    if (await _invoke('drain') != true) {
      throw const PcmOutputFailure('output_play_failed');
    }
    if (_stopped) throw const PcmOutputFailure('output_cancelled');
  }

  Future<Map<String, int>> statistics() async {
    if (!_started || _stopped) return {};
    final value = await _invoke('statistics');
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is int)
          entry.key as String: (entry.value as int).clamp(0, 1000000000),
    };
  }

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<Object?>(method, {
        'outputId': _id,
        ...?args,
      });
    } on PlatformException catch (error) {
      // iOS release rejects pending play calls with output_interrupted.
      // An explicit local stop makes those cancellations, not device failures.
      if (_stopped && method != 'stop' && error.code == 'output_interrupted') {
        throw const PcmOutputFailure('output_cancelled');
      }
      const codes = {
        'output_busy',
        'output_stalled',
        'output_focus_lost',
        'output_cancelled',
        'output_interrupted',
        'output_capacity',
        'output_start_failed',
        'output_play_failed',
        'output_stop_failed',
      };
      throw PcmOutputFailure(
        codes.contains(error.code) ? error.code : 'output_failed',
        native: DiagnosticPcmDetails.parse(error.details),
      );
    } on MissingPluginException {
      throw const PcmOutputFailure('output_unavailable');
    }
  }

  @override
  Future<void> stop() {
    _stopped = true;
    if (_released || !_requested) return Future.value();
    return _stopping ??= _release();
  }

  Future<void> _release() async {
    try {
      if (await _invoke('stop') != true) {
        throw const PcmOutputFailure('output_stop_failed');
      }
      _released = true;
    } finally {
      _stopping = null;
    }
  }
}

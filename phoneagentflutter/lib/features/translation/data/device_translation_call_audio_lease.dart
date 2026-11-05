import 'dart:math';
import 'package:flutter/services.dart';
import '../domain/translation_call_audio_lease.dart';

class DeviceTranslationCallAudioLease implements TranslationCallAudioLease {
  DeviceTranslationCallAudioLease({
    this.channel = const MethodChannel('phone_agent/translation_call_audio'),
  }) : id = List.generate(
         16,
         (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
       ).join();
  final MethodChannel channel;
  @override
  final String id;
  bool _requested = false, _closed = false, _released = false;
  Future<void>? _starting, _stopping;
  @override
  Future<void> acquire() {
    if (_closed || _requested) {
      return Future.error(StateError('Call audio lease unavailable'));
    }
    _requested = true;
    return _starting = _acquire();
  }

  Future<void> _acquire() async {
    if (await channel.invokeMethod<Object?>('acquire', {'callAudioId': id}) !=
        true) {
      throw StateError('Call audio lease denied');
    }
    if (_closed) throw StateError('Call audio lease cancelled');
  }

  @override
  Future<void> release() {
    _closed = true;
    if (!_requested || _released) return Future.value();
    return _stopping ??= _release();
  }

  Future<void> _release() async {
    try {
      try {
        await _starting;
      } catch (_) {
        /* Unknown acquisition still needs cleanup. */
      }
      if (await channel.invokeMethod<Object?>('release', {'callAudioId': id}) !=
          true) {
        throw StateError('Call audio lease release unconfirmed');
      }
      _released = true;
    } finally {
      _stopping = null;
    }
  }
}

import 'package:flutter/services.dart';
import 'dart:math';
import '../domain/recording_audio.dart';

/// A per-page export operation. Closing it never cancels another page's picker.
class DeviceRecordingExporter implements RecordingAudioExporter {
  DeviceRecordingExporter({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('phone_agent/history_recordings');
  final MethodChannel _channel;
  String? _operation;
  bool _closed = false;

  Future<String> cacheRoot() async {
    if (_closed) throw StateError('Recording export closed');
    final root = await _channel.invokeMethod<String>('root');
    if (_closed || root == null || root.isEmpty) {
      throw StateError('Recording cache unavailable');
    }
    return root;
  }

  @override
  Future<bool> save(RecordingAudioAsset asset) async {
    if (_closed || _operation != null) {
      throw StateError('Recording export unavailable');
    }
    if (asset.size == null ||
        asset.size! < 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.sha256 ?? '')) {
      throw StateError('Recording not verified');
    }
    final random = Random.secure();
    final id = _operation = List.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    try {
      final result = await _channel.invokeMethod<bool>('save', {
        'id': id,
        'path': asset.localPath,
        'name': asset.fileName,
        'contentType': asset.contentType,
        'size': asset.size,
        'sha256': asset.sha256,
      });
      return !_closed && _operation == id && result == true;
    } finally {
      if (_operation == id) _operation = null;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    final id = _operation;
    _operation = null;
    if (id != null) await _channel.invokeMethod<void>('cancel', {'id': id});
  }
}

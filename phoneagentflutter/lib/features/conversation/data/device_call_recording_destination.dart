import 'dart:math';
import 'package:flutter/services.dart';
import '../../translation_history/data/device_recording_exporter.dart';
import '../../translation_history/domain/recording_audio.dart';
import '../domain/call_recording_save.dart';

/// Keeps the Android URI native and cancels only this operation's destination.
class DeviceCallRecordingDestination implements CallRecordingDestination {
  DeviceCallRecordingDestination({
    required this.chooseFirst,
    MethodChannel? channel,
    DeviceRecordingExporter? exporter,
  }) : _channel =
           channel ??
           const MethodChannel('phone_agent/call_recording_destination'),
       _exporter = exporter ?? DeviceRecordingExporter();
  final bool chooseFirst;
  final MethodChannel _channel;
  final DeviceRecordingExporter _exporter;
  String? _id;
  bool _closed = false, _selected = false;

  Future<String> cacheRoot() => _exporter.cacheRoot();
  @override
  Future<bool> reserve(String fileName) async {
    if (_closed || _id != null) throw StateError('Recording destination busy');
    final id = _id = List.generate(
      4,
      (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    final selected =
        !chooseFirst ||
        await _channel.invokeMethod<bool>('choose', {
              'id': id,
              'name': fileName,
              'contentType': 'audio/mp4',
            }) ==
            true;
    _selected = !_closed && _id == id && selected;
    return _selected;
  }

  @override
  Future<bool> write(RecordingAudioAsset asset) async {
    final id = _id;
    if (_closed ||
        id == null ||
        !_selected ||
        asset.remoteUri != null ||
        asset.size == null ||
        asset.size! < 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.sha256 ?? '')) {
      throw StateError('Recording destination unavailable');
    }
    final saved = chooseFirst
        ? await _channel.invokeMethod<bool>('write', {
                'id': id,
                'path': asset.localPath,
                'size': asset.size,
                'sha256': asset.sha256,
              }) ==
              true
        : await _exporter.save(asset);
    if (saved && !_closed && _id == id) {
      _id = null;
      _selected = false;
      return true;
    }
    return false;
  }

  @override
  Future<void> abort() async {
    final id = _id;
    _id = null;
    _selected = false;
    if (chooseFirst && id != null) {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await abort();
    } finally {
      await _exporter.close();
    }
  }
}

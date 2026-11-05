import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/certified_recording_store.dart';
import 'certified_recording_codec.dart';

/// Native side encrypts opaque bytes; it never receives an arbitrary file path.
class DeviceCertifiedRecordingStore implements CertifiedRecordingBlobStore {
  DeviceCertifiedRecordingStore(
    this.slot, {
    this.channel = const MethodChannel('phone_agent/certified_recording'),
    this.platform,
    this.web,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(slot)) {
      throw ArgumentError('Invalid recording slot');
    }
  }
  final String slot;
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  bool get supported =>
      !(web ?? kIsWeb) &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(platform ?? defaultTargetPlatform);

  @override
  Future<Uint8List?> read() async {
    if (!supported) return null;
    try {
      final result = await channel.invokeMethod<Uint8List>('read', {
        'slot': slot,
      });
      if (result != null &&
          (result.isEmpty ||
              result.length > CertifiedRecordingCodec.maxPayloadBytes)) {
        throw RecordingStoreFailure.corrupt;
      }
      return result;
    } on PlatformException catch (error) {
      throw error.code == 'recording_corrupt'
          ? RecordingStoreFailure.corrupt
          : RecordingStoreFailure.unavailable;
    }
  }

  @override
  Future<void> replace(Uint8List payload) async {
    if (!supported) throw RecordingStoreFailure.unavailable;
    if (payload.isEmpty ||
        payload.length > CertifiedRecordingCodec.maxPayloadBytes) {
      throw RecordingStoreFailure.corrupt;
    }
    await channel.invokeMethod<void>('replace', {
      'slot': slot,
      'payload': payload,
    });
  }

  @override
  Future<void> clear() async {
    // Web never creates this native store; no browser storage fallback.
    if (supported) await channel.invokeMethod<void>('clear', {'slot': slot});
  }
}

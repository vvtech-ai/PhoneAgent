import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/config/app_config.dart';
import '../../auth/data/device_legacy_session_source.dart';
import '../domain/certified_recording_store.dart';
import '../domain/clone_candidate.dart';
import 'certified_recording_codec.dart';

class DeviceLegacyCertifiedRecordingSource {
  const DeviceLegacyCertifiedRecordingSource({
    required this.config,
    required this.accountId,
    this.channel = const MethodChannel(
      'phone_agent/legacy_certified_recording',
    ),
    this.platform,
    this.web,
  });
  final AppConfig config;
  final String accountId;
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;

  static bool eligible(
    AppConfig config, {
    TargetPlatform? platform,
    bool? web,
  }) =>
      !(web ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.android &&
      DeviceLegacySessionSource.eligible(config);

  Future<CertifiedCloneRecording?> read() async {
    if (!eligible(config, platform: platform, web: web)) return null;
    if (accountId.trim().isEmpty) throw RecordingStoreFailure.sessionChanged;
    try {
      final data = await channel.invokeMapMethod<String, Object?>('read');
      if (data == null) return null;
      if (data['version'] != 1) throw RecordingStoreFailure.unavailable;
      final oldAccount = data['accountRef'];
      if (oldAccount is! String || oldAccount.isEmpty) {
        throw RecordingStoreFailure.corrupt;
      }
      if (oldAccount != accountId) return null;
      String text(String key) {
        final value = data[key];
        if (value is! String || value.trim().isEmpty) {
          throw RecordingStoreFailure.corrupt;
        }
        return value;
      }

      final audio = data['audio'];
      final hash = text('audioSha256').toLowerCase();
      if (audio is! Uint8List ||
          audio.isEmpty ||
          audio.length > CertifiedRecordingCodec.maxAudioBytes ||
          sha256.convert(audio).toString() != hash) {
        throw RecordingStoreFailure.corrupt;
      }
      return CertifiedCloneRecording(
        audio: audio,
        audioSha256: hash,
        personFingerprint: text('personFingerprint'),
        scriptVersion: text('scriptVersion'),
        receipt: text('receipt'),
      );
    } on PlatformException catch (error) {
      throw error.code == 'recording_corrupt'
          ? RecordingStoreFailure.corrupt
          : RecordingStoreFailure.unavailable;
    }
  }
}

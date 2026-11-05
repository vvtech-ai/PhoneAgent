import 'package:flutter/services.dart';
import '../../voice_clone/domain/clone_preview_player.dart';
import '../domain/system_voice_preview.dart';

class BundledSystemVoicePreview implements SystemVoicePreviewPort {
  BundledSystemVoicePreview(this.player, {AssetBundle? bundle, this.loadClone})
    : bundle = bundle ?? rootBundle;
  final ClonePreviewPlayer player;
  final AssetBundle bundle;
  final Future<Uint8List> Function(bool current)? loadClone;

  @override
  Future<Uint8List> load(String voiceId) async {
    if (voiceId == cloneCurrentPreviewId ||
        voiceId == cloneCandidatePreviewId) {
      final loader = loadClone;
      if (loader == null) throw StateError('Clone preview unavailable');
      return loader(voiceId == cloneCurrentPreviewId);
    }
    final asset = systemVoicePreviewAssets[voiceId];
    if (asset == null) throw StateError('Voice preview resource unavailable');
    final data = await bundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<void> play(Uint8List bytes) => player.play(bytes);
  @override
  Future<void> stop() => player.stop();
  @override
  Future<void> close() => player.close();
}

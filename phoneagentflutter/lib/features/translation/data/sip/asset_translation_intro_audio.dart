import 'package:flutter/services.dart';
import '../../domain/sip/translation_intro_audio.dart';

class AssetTranslationIntroAudio implements TranslationIntroAudioSource {
  AssetTranslationIntroAudio({AssetBundle? bundle})
    : bundle = bundle ?? rootBundle;
  final AssetBundle bundle;
  final _cache = <String, Future<List<Uint8List>>>{};
  @override
  Future<List<Uint8List>> load(String language) =>
      _load(TranslationIntroAudio.languageCode(language));
  @override
  Future<List<Uint8List>> trigger() => _load('trigger_zh');
  Future<List<Uint8List>> _load(String language) =>
      _cache.putIfAbsent(language, () async {
        final value = await bundle.load(
          'assets/audio/translation_intro/translation_intro_$language.wav',
        );
        return TranslationIntroAudio.frames(
          value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes),
          quietSuppression: language != 'trigger_zh',
        );
      });
}

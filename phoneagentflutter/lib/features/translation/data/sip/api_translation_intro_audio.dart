import '../../domain/translation_directory.dart';
import 'dart:typed_data';
import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/sip/translation_intro_audio.dart';
import '../api_translation_directory.dart';
import 'asset_translation_intro_audio.dart';

/// Prompt downloads remain SDK authenticated; trigger is a bundled protocol cue.
class ApiTranslationIntroAudio implements TranslationIntroAudioSource {
  ApiTranslationIntroAudio(this.api, {this.directory});
  final TranslationDirectory? directory;
  final AccountApi api;
  final _cache = <String, List<Uint8List>>{};
  final _trigger = AssetTranslationIntroAudio();
  @override
  Future<List<Uint8List>> load(String language) async {
    final cached = _cache[language];
    if (cached != null) return cached;
    final directory =
        this.directory ?? await ApiTranslationDirectory(api).load();
    final prompt = directory.languages
        .where((l) => l.code == language)
        .firstOrNull;
    final code = prompt?.code ?? '';
    if (prompt == null ||
        !prompt.welcomeAudio ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9-]{0,31}$').hasMatch(code)) {
      throw ApiFailure.invalidResponse;
    }
    final bytes = await api.download(
      'api/v1/realtime-translation/welcome-prompts/$code/audio',
      maxBytes: 5 * 1024 * 1024,
      mediaTypes: const {'audio/wav', 'audio/x-wav', 'audio/wave'},
    );
    return _cache[language] = TranslationIntroAudio.frames(bytes);
  }

  @override
  Future<List<Uint8List>> trigger() => _trigger.trigger();
}

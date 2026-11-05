import 'task_voice_codec.dart';

abstract final class TaskVoiceEndpoint {
  static Uri asr(Uri apiBase, String language) => _build(
    apiBase,
    TaskVoiceCodec.asrPath,
    {'languageCode': _language(language)},
  );
  static Uri transcription(
    Uri apiBase, {
    required String userId,
    String language = 'zh-CN',
    String? taskId,
  }) {
    if (userId.trim().isEmpty) throw ArgumentError('Missing voice account');
    return _build(apiBase, '/ws/assistant/realtime/transcription', {
      'userId': userId.trim(),
      if (taskId != null && taskId.trim().isNotEmpty) 'taskId': taskId.trim(),
      'languageCode': _language(language),
    });
  }

  static String _language(String language) =>
      switch (language.trim().toLowerCase()) {
        'en' || 'en-us' => 'en-US',
        'ja' || 'jp' || 'ja-jp' => 'ja-JP',
        _ => 'zh-CN',
      };
  static Uri tts(Uri apiBase) => _build(apiBase, TaskVoiceCodec.ttsPath, {});
  static Uri _build(Uri base, String suffix, Map<String, String> query) {
    if (!{'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw ArgumentError('Invalid voice API base');
    }
    final path = base.path.replaceAll(RegExp(r'/+$'), '');
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '$path$suffix',
      queryParameters: query.isEmpty ? null : query,
    );
  }
}

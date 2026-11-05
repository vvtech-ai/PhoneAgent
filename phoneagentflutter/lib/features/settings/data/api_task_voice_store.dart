import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/task_voice.dart';

/// Runtime uses this account preference, rather than the device's old setting.
class ApiTaskVoiceStore implements TaskVoiceCatalogStore {
  const ApiTaskVoiceStore(this.api);
  final AccountApi api;
  static const path = 'api/account/settings/task-tts-voice';

  @override
  Future<TaskVoice> read() async => (await load()).voice;

  @override
  Future<TaskVoiceCatalog> load() async => _catalog(await api.request(path));

  @override
  Future<void> write(TaskVoice voice) async {
    if (voice.modelId.isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    final current = _catalog(await api.request(path));
    if (current.modelId != voice.modelId || !current.voices.contains(voice)) {
      throw ApiFailure.invalidResponse;
    }
    final saved = _catalog(
      await api.request(
        path,
        method: 'PUT',
        body: {'modelId': voice.modelId, 'voiceCode': voice.speaker},
      ),
    );
    if (saved.modelId != current.modelId || saved.voice != voice) {
      throw ApiFailure.invalidResponse;
    }
  }

  static TaskVoiceCatalog _catalog(Object? value) {
    final map = AccountApi.object(value);
    String text(Map<String, dynamic> object, String key) {
      final value = object[key];
      if (value is! String || value.trim().isEmpty) {
        throw ApiFailure.invalidResponse;
      }
      return value;
    }

    final modelId = text(map, 'modelId');
    final selected = text(map, 'selectedVoice');
    final defaultVoice = text(map, 'defaultVoice');
    final items = map['voices'];
    if (items is! List || items.isEmpty) throw ApiFailure.invalidResponse;
    final available = <String>{};
    final voices = <TaskVoice>[];
    for (final item in items) {
      final row = AccountApi.object(item);
      final code = text(row, 'voice');
      if (!available.add(code)) {
        throw ApiFailure.invalidResponse;
      }
      final description = row['description'];
      final previewAudioUrl = row['previewAudioUrl'];
      if (previewAudioUrl != null && previewAudioUrl is! String) {
        throw ApiFailure.invalidResponse;
      }
      if (description != null && description is! String) {
        throw ApiFailure.invalidResponse;
      }
      voices.add(
        TaskVoice(
          code,
          description is String
              ? description
              : TaskVoice.values
                        .where((voice) => voice.speaker == code)
                        .firstOrNull
                        ?.description ??
                    '',
          displayName: text(row, 'displayName'),
          previewAudioUrl: previewAudioUrl is String ? previewAudioUrl : '',
          modelId: modelId,
        ),
      );
    }
    if (!available.contains(selected) || !available.contains(defaultVoice)) {
      throw ApiFailure.invalidResponse;
    }
    return TaskVoiceCatalog(
      modelId,
      voices.firstWhere((voice) => voice.speaker == selected),
      List.unmodifiable(voices),
    );
  }
}

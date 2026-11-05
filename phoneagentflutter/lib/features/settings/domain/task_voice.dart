class TaskVoice {
  const TaskVoice(
    this.speaker,
    this.description, {
    String? displayName,
    this.previewAudioUrl = '',
    this.modelId = '',
  }) : displayName = displayName ?? speaker;
  static const maia = TaskVoice('Maia', '温柔女声');
  static const andre = TaskVoice('Andre', '沉稳男声');
  static const values = [maia, andre];
  // Formal catalog choices retain the model shown to the user for safe saves.
  final String speaker, description, displayName, previewAudioUrl, modelId;
  static TaskVoice parse(String value) => values.firstWhere(
    (voice) => voice.speaker == value,
    orElse: () => throw const FormatException('Invalid task voice'),
  );
  @override
  bool operator ==(Object other) =>
      other is TaskVoice && speaker == other.speaker;
  @override
  int get hashCode => speaker.hashCode;
}

class TaskVoiceCatalog {
  const TaskVoiceCatalog(this.modelId, this.voice, this.voices);
  final String modelId;
  final TaskVoice voice;
  final List<TaskVoice> voices;
}

abstract interface class TaskVoiceStore {
  Future<TaskVoice> read();
  Future<void> write(TaskVoice voice);
}

abstract interface class TaskVoiceCatalogStore implements TaskVoiceStore {
  Future<TaskVoiceCatalog> load();
}

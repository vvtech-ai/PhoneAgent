enum TaskResourceType { agentConversation, legacyTask, realtimeTranslation }

class TaskRef {
  const TaskRef(this.type, this.id);
  final TaskResourceType type;
  final String id;
  String get wireType => switch (type) {
    TaskResourceType.agentConversation => 'AGENT_CONVERSATION',
    TaskResourceType.legacyTask => 'LEGACY_TASK',
    TaskResourceType.realtimeTranslation => 'REALTIME_TRANSLATION',
  };
  String get key => '$wireType:$id';
  @override
  bool operator ==(Object other) => other is TaskRef && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

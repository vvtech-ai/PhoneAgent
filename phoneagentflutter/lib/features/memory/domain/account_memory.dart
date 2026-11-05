enum MemoryScope { all, selected }

class MemoryEntry {
  MemoryEntry({
    required this.id,
    required this.content,
    required this.scope,
    List<String> skillIds = const [],
  }) : skillIds = List.unmodifiable(skillIds);
  final String id, content;
  final MemoryScope scope;
  final List<String> skillIds;
}

class MemorySkill {
  const MemorySkill(this.id, this.name, this.enabled);
  final String id, name;
  final bool enabled;
}

class MemorySnapshot {
  MemorySnapshot({
    required this.enabled,
    required List<MemoryEntry> entries,
    required List<MemorySkill> skills,
    required this.usedCharacters,
    required this.maxCharacters,
    required this.maxEntries,
  }) : entries = List.unmodifiable(entries),
       skills = List.unmodifiable(skills);
  final bool enabled;
  final List<MemoryEntry> entries;
  final List<MemorySkill> skills;
  final int usedCharacters, maxCharacters, maxEntries;
  MemorySnapshot withEnabled(bool value) => MemorySnapshot(
    enabled: value,
    entries: entries,
    skills: skills,
    usedCharacters: usedCharacters,
    maxCharacters: maxCharacters,
    maxEntries: maxEntries,
  );
}

class MemoryAction {
  const MemoryAction(
    this.action, {
    this.id,
    this.content,
    this.scope,
    this.skillIds,
    this.enabled,
    this.operationId,
  });
  final String action;
  final String? id, content, operationId;
  final MemoryScope? scope;
  final List<String>? skillIds;
  final bool? enabled;
  MemoryAction withOperationId(String value) => MemoryAction(
    action,
    id: id,
    content: content,
    scope: scope,
    skillIds: skillIds,
    enabled: enabled,
    operationId: value,
  );
}

abstract interface class MemoryRepository {
  Future<MemorySnapshot> load();
  Future<MemorySnapshot> apply(MemoryAction action);
}

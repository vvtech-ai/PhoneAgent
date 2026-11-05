import 'account_memory.dart';

class MemorySkillSelection {
  MemorySkillSelection(this.all, Iterable<String> ids)
    : ids = Set.unmodifiable(ids);
  final bool all;
  final Set<String> ids;
  MemorySkillSelection toggleAll() => MemorySkillSelection(!all, const []);
  MemorySkillSelection toggle(String id, Set<String> available) {
    final next = {...(all ? available : ids)};
    if (!next.remove(id)) next.add(id);
    return available.isNotEmpty && next.containsAll(available)
        ? MemorySkillSelection(true, const [])
        : MemorySkillSelection(false, next);
  }

  Set<String> applyTo(Set<String> original, Set<String> available) => {
    ...original.difference(available),
    if (!all) ...ids,
  };
}

double memoryCapacity(MemorySnapshot snapshot) {
  final characters =
      snapshot.usedCharacters /
      (snapshot.maxCharacters > 0 ? snapshot.maxCharacters : 1);
  final entries =
      snapshot.entries.length /
      (snapshot.maxEntries > 0 ? snapshot.maxEntries : 1);
  return (characters > entries ? characters : entries).clamp(0, 1);
}

String memoryPreview(String content) =>
    content.split('\n').where((line) => line.trim().isNotEmpty).firstOrNull ??
    '';

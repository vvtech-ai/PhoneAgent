import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/account_memory.dart';
import 'memory_api_failure_policy.dart';

class ApiMemoryRepository implements MemoryRepository {
  const ApiMemoryRepository(this.api);
  final AccountApi api;
  static const path = 'api/account/settings/memory';
  @override
  Future<MemorySnapshot> load() async => parse(await api.request(path));
  @override
  Future<MemorySnapshot> apply(MemoryAction action) async => parse(
    await api.request(
      '$path/actions',
      method: 'POST',
      exposedMessage: MemoryApiFailurePolicy.message,
      body: {
        'action': action.action,
        if (action.operationId != null) 'operationId': action.operationId,
        if (action.id != null) 'id': action.id,
        if (action.content != null) 'content': action.content,
        if (action.scope != null)
          'scope': action.scope == MemoryScope.all ? 'ALL' : 'SELECTED',
        if (action.skillIds != null) 'skillIds': action.skillIds,
        if (action.enabled != null) 'enabled': action.enabled,
      },
    ),
  );
  static MemorySnapshot parse(Object? value) {
    Never invalid() => throw ApiFailure.invalidResponse;
    final map = AccountApi.object(value);
    String text(Map<String, dynamic> item, String key) =>
        item[key] is String && (item[key] as String).trim().isNotEmpty
        ? item[key] as String
        : invalid();
    int number(String key, {bool positive = false}) =>
        map[key] is int && (map[key] as int) >= (positive ? 1 : 0)
        ? map[key] as int
        : invalid();
    if (map['enabled'] is! bool ||
        map['entries'] is! List ||
        map['skills'] is! List) {
      invalid();
    }
    final entries = (map['entries'] as List).map((value) {
      final item = AccountApi.object(value);
      final ids = item['skillIds'];
      if (ids is! List || ids.any((id) => id is! String || id.trim().isEmpty)) {
        invalid();
      }
      final scope = switch (item['scope']) {
        'ALL' => MemoryScope.all,
        'SELECTED' => MemoryScope.selected,
        _ => invalid(),
      };
      return MemoryEntry(
        id: text(item, 'id'),
        content: text(item, 'content'),
        scope: scope,
        skillIds: ids.cast<String>(),
      );
    }).toList();
    final skills = (map['skills'] as List).map((value) {
      final item = AccountApi.object(value);
      if (item['enabled'] is! bool) invalid();
      return MemorySkill(
        text(item, 'id'),
        text(item, 'name'),
        item['enabled'] as bool,
      );
    }).toList();
    if (entries.map((e) => e.id).toSet().length != entries.length ||
        skills.map((e) => e.id).toSet().length != skills.length) {
      invalid();
    }
    return MemorySnapshot(
      enabled: map['enabled'] as bool,
      entries: entries,
      skills: skills,
      usedCharacters: number('usedCharacters'),
      maxCharacters: number('maxCharacters', positive: true),
      maxEntries: number('maxEntries', positive: true),
    );
  }
}

import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/task_scene_titles.dart';

class ApiTaskSceneTitles implements TaskSceneTitleSource {
  ApiTaskSceneTitles(this.api, this.accountId);
  final AccountApi api;
  final String accountId;

  @override
  Future<Map<String, String>> load() async {
    final value = await api.request(
      'api/agent/conversations',
      query: {'userId': accountId},
    );
    if (value is! List) throw ApiFailure.invalidResponse;
    final titles = <String, String>{};
    for (final value in value) {
      final row = AccountApi.object(value);
      String text(String key) =>
          row[key] is String ? (row[key] as String).trim() : '';
      final id = text('sessionId'), title = text('activeSkillTitle');
      if (id.isEmpty) continue;
      final label = title.isNotEmpty
          ? title
          : TaskSceneTitles.skills[text('activeSkillId')];
      if (label != null) titles[id] = label;
    }
    return Map.unmodifiable(titles);
  }
}

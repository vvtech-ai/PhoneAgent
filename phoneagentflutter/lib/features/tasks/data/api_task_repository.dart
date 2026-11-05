import '../../../core/network/account_api.dart';
import '../domain/task_records.dart';
import '../domain/task_page.dart';
import '../../../core/network/account_session.dart';
import 'task_record_mapper.dart';
import 'task_page_mapper.dart';
import 'translation_task_history_projection.dart';
import '../domain/task_scene_titles.dart';

class ApiTaskRepository implements PagedTaskRepository, TaskPinRepository {
  ApiTaskRepository(this._api, this.accountId, {this.sceneTitles});
  final AccountApi _api;
  final String accountId;
  final TaskSceneTitleSource? sceneTitles;
  Map<String, String> _titles = const {};
  int _titleGeneration = 0;
  static const _base = 'api/assistant/task-list';
  @override
  Future<TaskPage> loadPage({int offset = 0, int limit = 15}) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ApiFailure.invalidResponse;
    }
    final generation = offset == 0 ? ++_titleGeneration : _titleGeneration;
    final page = const TaskPageMapper().decode(
      await _api.request(
        '$_base/page',
        query: {'offset': offset, 'limit': limit, 'userId': accountId},
      ),
    );
    var titles = _titles;
    if (offset == 0 && sceneTitles != null) {
      try {
        titles = await sceneTitles!.load();
        if (generation == _titleGeneration) _titles = titles;
      } catch (error) {
        if (error == ApiFailure.sessionChanged ||
            error == ApiFailure.signedOut) {
          rethrow;
        }
        // Metadata failure keeps the authoritative SDK page and existing labels.
      }
    }
    return _translationPresentation(TaskSceneTitles.page(page, titles));
  }

  Future<TaskPage> _translationPresentation(TaskPage page) async {
    if (![
      ...page.pinnedItems,
      ...page.items,
    ].any((row) => row.kind == TaskRecordKind.translation)) {
      return page;
    }
    try {
      final history = await load(TaskSource.calls);
      return projectTranslationTaskHistory(page, history);
    } catch (error) {
      if (error == ApiFailure.sessionChanged || error == ApiFailure.signedOut) {
        rethrow;
      }
      return page;
    }
  }

  String _item(TaskRef ref) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(ref.id)) {
      throw ApiFailure.invalidResponse;
    }
    return '$_base/items/${ref.wireType}/${ref.id}';
  }

  @override
  Future<void> pin(TaskRef ref, bool pinned) async {
    await _pinResponse(ref, pinned);
  }

  Future<Object?> _pinResponse(TaskRef ref, bool pinned) => _api.request(
    '${_item(ref)}/pin',
    method: 'PUT',
    body: {'pinned': pinned},
    exposedCodes: const {'TASK_LIST_ITEM_NOT_FOUND'},
  );

  @override
  Future<TaskRecord> updatePin(TaskRef ref, bool pinned) async {
    final target = const TaskPageMapper().record(
      await _pinResponse(ref, pinned),
    );
    if (target.ref?.key != ref.key || (target.pinnedAt != null) != pinned) {
      throw ApiFailure.invalidResponse;
    }
    final page = await _translationPresentation(
      TaskPage(
        pinnedItems: const [],
        items: [TaskSceneTitles.record(target, _titles)],
        nextOffset: 0,
        hasMore: false,
        hasUnread: false,
      ),
    );
    return page.items.single;
  }

  @override
  Future<void> hide(TaskRef ref) async {
    await _api.request(
      _item(ref),
      method: 'DELETE',
      exposedCodes: const {
        'TASK_LIST_ITEM_NOT_FOUND',
        'TASK_DIALING_DELETE_BLOCKED',
      },
    );
  }

  @override
  Future<void> markRead(TaskRef ref) async {
    await _api.request('${_item(ref)}/read', method: 'PUT');
  }

  @override
  Future<void> clearUnread() async {
    await _api.request('$_base/read/clear', method: 'PUT');
  }

  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    final path = switch (source) {
      TaskSource.conversations => 'api/agent/conversations',
      TaskSource.calls => 'api/task/call-history',
      TaskSource.legacyTasks => 'api/task/list',
    };
    return const TaskRecordMapper().decode(
      await _api.request(path, query: {'userId': accountId}),
      source,
    );
  }
}

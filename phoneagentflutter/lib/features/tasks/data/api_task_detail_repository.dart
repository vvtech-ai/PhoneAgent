import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/task_details.dart';

class ApiTaskDetailRepository implements TaskDetailRepository {
  ApiTaskDetailRepository(this._api);
  final AccountApi _api;
  @override
  Future<LegacyTaskDetail> load(String taskId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(taskId)) {
      throw ApiFailure.invalidResponse;
    }
    final dto = AccountApi.object(
      await _api.request('api/task/detail/$taskId'),
    );
    if (dto['taskId'] != taskId) throw ApiFailure.invalidResponse;
    String text(Map<String, dynamic> map, String key) {
      final value = map[key];
      if (value != null && value is! String) throw ApiFailure.invalidResponse;
      return value as String? ?? '';
    }

    final fields = <String, String>{};
    void add(Object? value, Map<String, String> labels) {
      if (value == null) return;
      final object = AccountApi.object(value);
      for (final entry in labels.entries) {
        final raw = object[entry.key];
        if (raw is String && raw.isNotEmpty || raw is num || raw is bool) {
          fields[entry.value] = raw.toString();
        }
      }
    }

    add(dto['slot'], const {
      'reservationTime': '预订时间',
      'partySize': '人数',
      'restaurantName': '餐厅',
      'locationIntent': '地点',
      'cuisine': '菜系',
      'contactPhone': '联系电话',
    });
    add(dto['selectedRestaurant'], const {
      'name': '选定餐厅',
      'phone': '餐厅电话',
      'address': '餐厅地址',
    });
    final rawCalls = dto['callRecords'];
    if (rawCalls != null && rawCalls is! List) throw ApiFailure.invalidResponse;
    return LegacyTaskDetail(
      taskId: taskId,
      title: text(dto, 'originText'),
      status: text(dto, 'status'),
      result: text(dto, 'finalResult'),
      createdAt: text(dto, 'createdAt'),
      fields: Map.unmodifiable(fields),
      calls: List.unmodifiable(
        (rawCalls as List? ?? []).map((value) {
          final row = AccountApi.object(value);
          return LegacyTaskCall(
            callId: text(row, 'callId'),
            status: text(row, 'status'),
            result: text(row, 'result'),
            summary: text(row, 'summary'),
          );
        }),
      ),
    );
  }
}

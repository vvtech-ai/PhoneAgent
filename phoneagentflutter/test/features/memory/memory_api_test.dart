import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/memory/data/api_memory_repository.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import '../../support/synthetic_account_api.dart';
import 'package:phone_agent/features/memory/presentation/controller/memory_controller.dart';

class _BusinessWire extends SyntheticAccountApi {
  String? failure;
  String code = 'AC0001';
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final response = await super.fetch(request, stream, cancel);
    if (failure == null) return response;
    return ResponseBody.fromString(
      jsonEncode({'code': code, 'message': failure}),
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test(
    'memory business reasons are allowlisted while arbitrary messages stay opaque',
    () async {
      final wire = _BusinessWire();
      addTearDown(wire.api.close);
      wire.data = {
        'enabled': true,
        'entries': [],
        'skills': [],
        'usedCharacters': 0,
        'maxCharacters': 3000,
        'maxEntries': 30,
      };
      final c = MemoryController(
        ApiMemoryRepository(wire.api),
        isCurrent: () => true,
      );
      addTearDown(c.dispose);
      await c.load();
      for (final reason in [
        '记忆容量已满，请先精简或删除已有记忆',
        '该任务暂不可选，请重新选择适用任务',
        '该条记忆已不存在，请刷新后重试',
      ]) {
        wire.failure = reason;
        expect(
          await c.apply(
            const MemoryAction('ADD', content: '合成内容', scope: MemoryScope.all),
          ),
          isFalse,
        );
        expect(c.state.error, reason);
        expect(c.failedAction, isNull);
      }
      wire.failure = 'private backend internals';
      expect(await c.apply(const MemoryAction('CLEAR')), isFalse);
      expect(c.state.error, '操作失败，请重试');
      expect(c.state.error, isNot(contains('private')));
    },
  );
  test('memory uses current authenticated SDK path and typed action', () async {
    final wire = SyntheticAccountApi();
    addTearDown(wire.api.close);
    wire.data = {
      'enabled': true,
      'entries': [],
      'skills': [],
      'usedCharacters': 0,
      'maxCharacters': 3000,
      'maxEntries': 30,
    };
    final repo = ApiMemoryRepository(wire.api);
    await repo.load();
    expect(wire.requests.last.uri.path, '/api/account/settings/memory');
    expect(wire.requests.last.method, 'GET');
    await repo.apply(
      const MemoryAction(
        'ADD',
        content: '合成偏好',
        scope: MemoryScope.selected,
        skillIds: ['restaurant-booking'],
      ),
    );
    expect(wire.requests.last.uri.path, '/api/account/settings/memory/actions');
    expect(wire.requests.last.method, 'POST');
    expect(wire.requests.last.headers['Authorization'], 'Bearer synthetic');
    expect(wire.requests.last.headers['X-Account-Id'], 'a');
    expect(wire.requests.last.data, {
      'action': 'ADD',
      'content': '合成偏好',
      'scope': 'SELECTED',
      'skillIds': ['restaurant-booking'],
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/memory_providers.dart';
import 'package:phone_agent/features/memory/data/api_memory_repository.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/presentation/controller/memory_controller.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_editor_page.dart';
import '../../support/synthetic_account_api.dart';

MemorySnapshot limits({List<MemoryEntry> entries = const [], int used = 0}) =>
    MemorySnapshot(
      enabled: true,
      entries: entries,
      skills: const [MemorySkill('restaurant', '订餐厅', true)],
      usedCharacters: used,
      maxCharacters: 10,
      maxEntries: 1,
    );

class _Repository implements MemoryRepository {
  _Repository(this.snapshot);
  final MemorySnapshot snapshot;
  final actions = <MemoryAction>[];
  @override
  Future<MemorySnapshot> load() async => snapshot;
  @override
  Future<MemorySnapshot> apply(MemoryAction action) async {
    actions.add(action);
    return snapshot;
  }
}

void main() {
  testWidgets('editor shows limit before submit and disables save', (
    tester,
  ) async {
    final repo = _Repository(limits());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginEpochProvider.overrideWithValue(7),
          memoryRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: MemoryEditorPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '超过十个字符的合成记忆内容');
    await tester.pump();
    expect(find.text('记忆内容过长，请缩短后保存'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repo.actions, isEmpty);
  });
  test(
    'ADD lost response retry reuses operationId while a new ADD gets a new id',
    () async {
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
      final controller = MemoryController(
        ApiMemoryRepository(wire.api),
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await controller.load();
      var lost = true;
      wire.beforeResponse = (request) async {
        if (lost && request.method == 'POST') {
          lost = false;
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
      };
      const action = MemoryAction(
        'ADD',
        content: '合成偏好',
        scope: MemoryScope.all,
      );
      expect(await controller.apply(action), isFalse);
      final first = (wire.requests.last.data as Map)['operationId'];
      expect(
        first,
        isA<String>().having(
          (id) => id.length,
          'length',
          greaterThanOrEqualTo(16),
        ),
      );
      lost = true;
      expect(await controller.apply(action), isFalse);
      expect(
        (wire.requests.last.data as Map)['operationId'],
        first,
        reason: 'unchanged Save after lost response is the same ADD operation',
      );
      expect(await controller.retry(), isTrue);
      expect((wire.requests.last.data as Map)['operationId'], first);
      expect(await controller.apply(action), isTrue);
      expect((wire.requests.last.data as Map)['operationId'], isNot(first));
    },
  );

  test(
    'capacity preflight rejects ADD without calling the repository',
    () async {
      final repo = _Repository(
        limits(
          entries: [
            MemoryEntry(id: 'one', content: '已有', scope: MemoryScope.all),
          ],
          used: 2,
        ),
      );
      final controller = MemoryController(repo, isCurrent: () => true);
      addTearDown(controller.dispose);
      await controller.load();
      expect(
        await controller.apply(
          const MemoryAction('ADD', content: '新增', scope: MemoryScope.all),
        ),
        isFalse,
      );
      expect(controller.state.error, contains('条数'));
      expect(repo.actions, isEmpty);
      expect(controller.failedAction, isNull);
    },
  );

  test(
    'character preflight counts Unicode and credits original UPDATE content',
    () async {
      final repo = _Repository(
        limits(
          entries: [
            MemoryEntry(id: 'one', content: '旧内容', scope: MemoryScope.all),
          ],
          used: 8,
        ),
      );
      final controller = MemoryController(repo, isCurrent: () => true);
      addTearDown(controller.dispose);
      await controller.load();
      expect(
        await controller.apply(
          const MemoryAction(
            'UPDATE',
            id: 'one',
            content: '😀😀😀😀😀😀',
            scope: MemoryScope.all,
          ),
        ),
        isFalse,
      );
      expect(controller.state.error, contains('容量'));
      expect(repo.actions, isEmpty);
      expect(
        await controller.apply(
          const MemoryAction(
            'UPDATE',
            id: 'one',
            content: '😀😀😀😀😀',
            scope: MemoryScope.all,
          ),
        ),
        isTrue,
      );
      expect(repo.actions, hasLength(1));
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/memory_providers.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_editor_page.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_settings_page.dart';

MemorySnapshot snapshot({
  List<MemoryEntry> entries = const [],
  bool oldEnabled = true,
}) => MemorySnapshot(
  enabled: true,
  entries: entries,
  skills: [
    MemorySkill('old', '旧任务', oldEnabled),
    const MemorySkill('new', '新任务', true),
  ],
  usedCharacters: entries.fold(
    0,
    (sum, item) => sum + item.content.runes.length,
  ),
  maxCharacters: 3000,
  maxEntries: 30,
);

class _Repository implements MemoryRepository {
  _Repository(this.current);
  MemorySnapshot current;
  String? failure;
  int loads = 0;
  final actions = <MemoryAction>[];
  @override
  Future<MemorySnapshot> load() async {
    loads++;
    return current;
  }

  @override
  Future<MemorySnapshot> apply(MemoryAction action) async {
    actions.add(action);
    if (failure != null) throw ApiCodeFailure(failure!);
    if (action.action == 'ADD') {
      current = snapshot(
        entries: [
          ...current.entries,
          MemoryEntry(
            id: 'new-${actions.length}',
            content: action.content!,
            scope: action.scope!,
            skillIds: action.skillIds ?? [],
          ),
        ],
        oldEnabled: current.skills.first.enabled,
      );
    }
    return current;
  }
}

Future<void> _boot(WidgetTester tester, _Repository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWithValue(7),
        memoryRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: MemorySettingsPage(list: true)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const Key('memory-open-skills')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('memory-skill-$id')));
  await tester.tap(find.text('完成'));
  await tester.pumpAndSettle();
}

void main() {
  for (final reason in ['记忆容量已满，请先精简或删除已有记忆', '记忆内容不能为空']) {
    testWidgets('ordinary rejection does not offer blind ADD retry: $reason', (
      tester,
    ) async {
      final repo = _Repository(snapshot());
      await _boot(tester, repo);
      await tester.tap(find.text('＋ 添加记忆'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '合成记忆');
      await _select(tester, 'old');
      repo.failure = reason;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text(reason), findsOneWidget);
      expect(find.text('刷新'), findsNothing);
      expect(find.text('重试'), findsNothing);
      expect(repo.loads, 1);
      expect(repo.actions.map((a) => a.action), ['ADD']);
    });
  }
  testWidgets(
    'missing entry refresh only loads and preserves the draft until an explicit new operation',
    (tester) async {
      final repo = _Repository(
        snapshot(
          entries: [
            MemoryEntry(
              id: 'old-entry',
              content: '原记忆',
              scope: MemoryScope.all,
            ),
          ],
        ),
      );
      await _boot(tester, repo);
      await tester.tap(find.text('原记忆'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '已修改记忆');
      await tester.pump();
      repo.failure = '该条记忆已不存在，请刷新后重试';
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.actions.map((a) => a.action), ['UPDATE']);
      expect(find.text('刷新'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      repo.current = snapshot();
      await tester.tap(find.text('刷新'));
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      expect(repo.actions.map((a) => a.action), ['UPDATE']);
      expect(find.byType(MemoryEditorPage), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '已修改记忆',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('该条记忆已不存在，请返回后重新选择'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('暂无记忆'), findsOneWidget);
      expect(find.text('已保存'), findsNothing);
      await tester.tap(find.text('＋ 添加记忆'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '明确新增记忆');
      await _select(tester, 'new');
      repo.failure = null;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.actions.map((a) => a.action), ['UPDATE', 'ADD']);
      expect(repo.current.entries.single.content, '明确新增记忆');
    },
  );

  testWidgets(
    'stale Skill refresh keeps the draft and requires an updated selection before ADD',
    (tester) async {
      final repo = _Repository(snapshot());
      await _boot(tester, repo);
      await tester.tap(find.text('＋ 添加记忆'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '待保存草稿');
      await _select(tester, 'old');
      repo.failure = '该任务暂不可选，请重新选择适用任务';
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.actions, hasLength(1));
      expect(find.text('刷新'), findsOneWidget);
      repo.current = snapshot(oldEnabled: false);
      await tester.tap(find.text('刷新'));
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      expect(repo.actions, hasLength(1));
      expect(find.byType(MemoryEditorPage), findsOneWidget);
      expect(find.text('旧任务 · 已停用'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '待保存草稿',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await _select(tester, 'new');
      repo.failure = null;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.actions, hasLength(2));
      expect(
        repo.actions.last.operationId,
        isNot(repo.actions.first.operationId),
      );
      expect(repo.current.entries.single.content, '待保存草稿');
    },
  );
}

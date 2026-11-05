import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/memory_providers.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/domain/memory_skill_selection.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_settings_page.dart';
import 'package:phone_agent/features/memory/presentation/widgets/memory_skill_sheet.dart';
import 'memory_pages_test.dart' show Repository;

Future<void> boot(
  WidgetTester tester,
  Repository repo,
  TargetPlatform platform,
  double scale,
) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWithValue(7),
        memoryRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const MemorySettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.pump();
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'native selection preserves disabled ids and normalizes all; capacity uses stricter limit',
    () {
      const available = {'a', 'b'};
      final selection = MemorySkillSelection(false, {
        'a',
      }).toggle('b', available);
      expect(selection.all, isTrue);
      expect(selection.applyTo({'a', 'old'}, available), {'old'});
      final partial = selection.toggle('a', available);
      expect(partial.all, isFalse);
      expect(partial.ids, {'b'});
      expect(partial.applyTo({'a', 'old'}, available), {'b', 'old'});
      expect(selection.toggleAll().ids, isEmpty);
      final repo = Repository()
        ..entries.add(
          MemoryEntry(
            id: 'one',
            content: '\nfirst\nsecond',
            scope: MemoryScope.all,
          ),
        );
      expect(memoryPreview(repo.entries.single.content), 'first');
      expect(memoryCapacity(repo.snapshot), closeTo(1 / 30, .0001));
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform $scale native memory tags cancel save retry delete and clear',
        (tester) async {
          final repo = Repository()
            ..entries.addAll([
              MemoryEntry(
                id: 'one',
                content: '合成记忆一',
                scope: MemoryScope.selected,
                skillIds: ['restaurant-booking', 'old'],
              ),
              MemoryEntry(id: 'two', content: '合成记忆二', scope: MemoryScope.all),
            ]);
          await boot(tester, repo, platform, scale);
          expect(find.text('容量使用'), findsNothing);
          await tap(tester, find.text('记忆内容'));
          expect(find.text('容量使用'), findsOneWidget);
          expect(find.byTooltip('删除记忆'), findsNothing);
          await tap(tester, find.text('合成记忆一'));
          expect(find.text('旧任务 · 已停用'), findsOneWidget);
          expect(find.byType(Checkbox), findsNothing);
          await tap(tester, find.byKey(const Key('memory-open-skills')));
          expect(find.text('旧任务'), findsNothing);
          await tap(tester, find.byKey(const ValueKey('memory-skill-taxi')));
          await tap(tester, find.text('取消'));
          expect(find.text('叫车'), findsNothing);
          await tap(tester, find.byKey(const Key('memory-open-skills')));
          await tap(tester, find.byKey(const ValueKey('memory-skill-taxi')));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('叫车'), findsNothing);
          await tap(tester, find.byKey(const Key('memory-open-skills')));
          await tap(tester, find.byKey(const ValueKey('memory-skill-taxi')));
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(find.text('叫车'), findsNothing);
          await tap(tester, find.byKey(const Key('memory-open-skills')));
          await tap(tester, find.byKey(const ValueKey('memory-skill-taxi')));
          await tap(tester, find.text('完成'));
          expect(find.text('全部任务'), findsOneWidget);
          expect(find.text('旧任务 · 已停用'), findsOneWidget);
          await tap(tester, find.byTooltip('移除全部任务标签'));
          await tap(tester, find.byKey(const Key('memory-open-skills')));
          expect(
            tester
                .widget<MemorySkillSheet>(find.byType(MemorySkillSheet))
                .initial
                .all,
            isFalse,
          );
          expect(
            tester
                .widget<MemorySkillSheet>(find.byType(MemorySkillSheet))
                .initial
                .ids,
            isEmpty,
          );
          await tap(
            tester,
            find.byKey(const ValueKey('memory-skill-restaurant-booking')),
          );
          await tap(tester, find.text('完成'));
          await tester.enterText(find.byType(TextField), '合成记忆已修改');
          expect(find.text('订餐厅'), findsOneWidget);
          repo.failAction = 'UPDATE';
          await tap(tester, find.text('保存'));
          expect(find.text('操作失败，请重试'), findsOneWidget);
          expect(repo.entries.first.content, '合成记忆一');
          final loads = repo.loads;
          repo.failAction = null;
          repo.pending = Completer<void>();
          await tap(tester, find.text('重试'));
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.text('编辑记忆'), findsOneWidget);
          expect(repo.entries.first.content, '合成记忆一');
          repo.pending!.complete();
          await tester.pumpAndSettle();
          repo.pending = null;
          expect(repo.loads, loads);
          expect(
            repo.actions.where((action) => action.action == 'UPDATE'),
            hasLength(2),
          );
          expect(repo.entries.first.skillIds.toSet(), {
            'restaurant-booking',
            'old',
          });
          await tap(tester, find.text('合成记忆已修改'));
          await tester.enterText(find.byType(TextField), '未保存草稿');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(repo.entries.first.content, '合成记忆已修改');
          await tap(tester, find.text('合成记忆已修改'));
          await tap(tester, find.text('删除这条记忆'));
          expect(find.text('删除后，AI 将不再使用这条记忆。'), findsOneWidget);
          await tap(tester, find.text('取消'));
          expect(repo.entries, hasLength(2));
          repo.failAction = 'DELETE';
          await tap(tester, find.text('删除这条记忆'));
          await tap(tester, find.text('确认删除'));
          expect(find.text('操作失败，请重试'), findsOneWidget);
          repo.failAction = null;
          await tap(tester, find.text('重试'));
          expect(repo.entries, hasLength(1));
          await tap(tester, find.byTooltip('更多操作'));
          await tap(tester, find.text('删除全部记忆'));
          expect(find.text('列表中的记忆将全部删除，删除后无法恢复。'), findsOneWidget);
          await tap(tester, find.text('取消'));
          expect(repo.entries, hasLength(1));
          repo.failAction = 'CLEAR';
          await tap(tester, find.byTooltip('更多操作'));
          await tap(tester, find.text('删除全部记忆'));
          await tap(tester, find.text('确认删除'));
          repo.failAction = null;
          await tap(tester, find.text('重试'));
          expect(repo.entries, isEmpty);
          expect(find.text('暂无记忆'), findsOneWidget);
          expect(repo.loads, loads);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
      testWidgets(
        '$platform $scale switch rollback retry and busy navigation',
        (tester) async {
          final repo = Repository()..failAction = 'SET_ENABLED';
          await boot(tester, repo, platform, scale);
          await tap(tester, find.byType(CupertinoSwitch));
          expect(repo.enabled, isFalse);
          expect(
            tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
            isFalse,
          );
          repo.failAction = null;
          repo.pending = Completer<void>();
          await tester.tap(find.text('重试'));
          await tester.pump();
          expect(
            tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
            isTrue,
          );
          await tester.tap(find.text('记忆内容'));
          await tester.pump();
          expect(find.text('容量使用'), findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.text('记忆内容'), findsOneWidget);
          repo.pending!.complete();
          await tester.pumpAndSettle();
          expect(repo.enabled, isTrue);
          expect(repo.loads, 1);
          expect(repo.actions, hasLength(2));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}

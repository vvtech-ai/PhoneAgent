import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/memory_providers.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_settings_page.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_editor_page.dart';

class Repository implements MemoryRepository {
  bool enabled = false;
  String? failAction;
  Completer<void>? pending;
  int loads = 0;
  final entries = <MemoryEntry>[];
  final actions = <MemoryAction>[];
  MemorySnapshot get snapshot => MemorySnapshot(
    enabled: enabled,
    entries: entries,
    skills: [
      const MemorySkill('restaurant-booking', '订餐厅', true),
      const MemorySkill('taxi', '叫车', true),
      const MemorySkill('old', '旧任务', false),
    ],
    usedCharacters: entries.fold(0, (sum, e) => sum + e.content.runes.length),
    maxCharacters: 3000,
    maxEntries: 30,
  );
  @override
  Future<MemorySnapshot> load() async {
    loads++;
    return snapshot;
  }

  @override
  Future<MemorySnapshot> apply(MemoryAction action) async {
    actions.add(action);
    await pending?.future;
    if (action.action == failAction) throw StateError("network");
    if (action.action == 'SET_ENABLED') enabled = action.enabled!;
    if (action.action == 'ADD') {
      entries.add(
        MemoryEntry(
          id: 'synthetic-${entries.length}',
          content: action.content!,
          scope: action.scope!,
          skillIds: action.skillIds!,
        ),
      );
    }
    if (action.action == 'UPDATE') {
      final index = entries.indexWhere((entry) => entry.id == action.id);
      entries[index] = MemoryEntry(
        id: action.id!,
        content: action.content!,
        scope: action.scope!,
        skillIds: action.skillIds!,
      );
    }
    if (action.action == 'DELETE') {
      entries.removeWhere((e) => e.id == action.id);
    }
    if (action.action == 'CLEAR') entries.clear();
    return snapshot;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform memory settings add scope save delete and keyboard layout',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = Repository();
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
        expect(find.text('保存'), findsNothing);
        await tester.tap(find.byType(CupertinoSwitch));
        await tester.pumpAndSettle();
        expect(repo.enabled, isTrue);
        await tester.tap(find.text('记忆内容'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('＋ 添加记忆'));
        await tester.pumpAndSettle();
        expect(find.byType(MemoryEditorPage), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), '合成偏好：靠窗');
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        await tester.tap(find.byKey(const Key('memory-open-skills')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('订餐厅'));
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(repo.entries.single.content, '合成偏好：靠窗');
        expect(repo.entries.single.skillIds, ['restaurant-booking']);
        expect(find.byType(MemoryEditorPage), findsNothing);
        await tester.tap(find.text('合成偏好：靠窗'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('删除这条记忆'));
        await tester.tap(find.text('删除这条记忆'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(repo.entries, hasLength(1));
        await tester.tap(find.text('删除这条记忆'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确认删除'));
        await tester.pumpAndSettle();
        expect(repo.entries, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}

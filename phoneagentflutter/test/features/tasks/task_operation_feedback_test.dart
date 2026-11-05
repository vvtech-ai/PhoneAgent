import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/core/design/page_route_visibility.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/domain/task_pinned_visibility.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_presentation_host.dart';
import 'task_pagination_test.dart' show row;

class _Repository implements PagedTaskRepository, TaskPinRepository {
  bool loadFails = false;
  List<TaskRecord> rows = [row('a').copyWith(unreadResult: true)];
  final pins = <({TaskRef ref, bool pinned, Completer<TaskRecord> result})>[];
  final deletes = <({TaskRef ref, Completer<void> result})>[];
  @override
  Future<TaskPage> loadPage({int offset = 0, int limit = 15}) async {
    if (loadFails) throw StateError('offline');
    return TaskPage(
      pinnedItems: rows.where((r) => r.pinnedAt != null).toList(),
      items: rows.where((r) => r.pinnedAt == null).toList(),
      nextOffset: rows.where((r) => r.pinnedAt == null).length,
      hasMore: false,
      hasUnread: rows.any((r) => r.unreadResult),
    );
  }

  @override
  Future<TaskRecord> updatePin(TaskRef ref, bool pinned) async {
    final result = Completer<TaskRecord>();
    pins.add((ref: ref, pinned: pinned, result: result));
    final saved = await result.future;
    rows = [for (final r in rows) r.ref == ref ? saved : r];
    return saved;
  }

  @override
  Future<void> hide(TaskRef ref) async {
    final result = Completer<void>();
    deletes.add((ref: ref, result: result));
    await result.future;
    rows = rows.where((r) => r.ref != ref).toList();
  }

  @override
  Future<void> clearUnread() async {
    rows = [for (final r in rows) r.copyWith(unreadResult: false)];
  }

  @override
  Future<void> markRead(TaskRef ref) async {}
  @override
  Future<void> pin(TaskRef ref, bool pinned) => throw UnimplementedError();
  @override
  Future<List<TaskRecord>> load(TaskSource source) async => rows;
}

class _Preferences implements TaskPinnedPreferenceRepository {
  @override
  String get scopeKey => 'account-a';
  @override
  Future<bool> read() async => false;
  @override
  Future<void> save(bool value) async {}
}

class _Harness extends StatefulWidget {
  const _Harness(this.controller);
  final TaskController controller;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final remove = widget.controller.addListener((_) {
    if (mounted) setState(() {});
  }, fireImmediately: false);
  final preferences = _Preferences();
  @override
  void initState() {
    super.initState();
    remove;
  }

  @override
  void dispose() {
    remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TasksPresentationHost(
    state: widget.controller.state,
    preferences: preferences,
    onRefresh: () => widget.controller.refresh(synchronizeStatus: false),
    onOpen: (_) {},
    onPin: widget.controller.pin,
    onDelete: widget.controller.hide,
    onClearUnread: widget.controller.clearUnread,
    onLoadMore: widget.controller.loadMore,
  );
}

Future<void> _mount(
  WidgetTester tester,
  TaskController controller,
  TargetPlatform platform,
) {
  final observer = PageRouteVisibilityObserver();
  return tester.pumpWidget(
    PageRouteVisibilityScope(
      observer: observer,
      child: MaterialApp(
        navigatorObservers: [observer],
        theme: ThemeData(platform: platform),
        home: Scaffold(body: _Harness(controller)),
      ),
    ),
  );
}

Future<void> _menu(WidgetTester tester, String action) async {
  await tester.longPress(find.text('AI 通话 · a'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Finder _notice(String text) => find.descendant(
  of: find.byKey(const ValueKey('nativeNoticeSurface')),
  matching: find.text(text, findRichText: true),
);

Future<void> _expire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
}

void main() {
  tearDown(dismissNativeNotice);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform pin-unpin-pin and confirmed delete notify once', (
      tester,
    ) async {
      final repo = _Repository();
      final clearedDrafts = <TaskRef>[];
      final controller = TaskController(
        repo,
        afterHide: (r) async => clearedDrafts.add(r.ref!),
      );
      addTearDown(controller.dispose);
      await controller.refresh(synchronizeStatus: false);
      await _mount(tester, controller, platform);
      await tester.pumpAndSettle();
      var operations = 0;
      for (final pinned in [true, false, true]) {
        operations++;
        final current = controller.state.catalog.records.single;
        await _menu(tester, pinned ? '置顶' : '取消置顶');
        expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
        expect(await controller.pin(current), isFalse);
        expect(repo.pins, hasLength(operations));
        expect(
          repo.pins.last.ref,
          const TaskRef(TaskResourceType.agentConversation, 'a'),
        );
        expect(repo.pins.last.pinned, pinned);
        repo.pins.last.result.complete(
          current.copyWith(pinnedAt: '2026-10-21', clearPin: !pinned),
        );
        await tester.pumpAndSettle();
        expect(_notice(pinned ? '置顶成功' : '取消置顶成功'), findsOneWidget);
        expect(
          controller.state.catalog.records.single.pinnedAt != null,
          pinned,
        );
        await _expire(tester);
        await controller.refresh(synchronizeStatus: false);
        controller.reproject();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      }
      await _menu(tester, '删除');
      expect(find.text('删除任务？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(repo.deletes, isEmpty);
      expect(clearedDrafts, isEmpty);
      await _menu(tester, '删除');
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(
        repo.deletes.single.ref,
        const TaskRef(TaskResourceType.agentConversation, 'a'),
      );
      expect(
        await controller.hide(controller.state.catalog.records.single),
        isFalse,
      );
      expect(repo.deletes, hasLength(1));
      expect(clearedDrafts, isEmpty);
      repo.deletes.single.result.complete();
      await tester.pumpAndSettle();
      expect(controller.state.catalog.records, isEmpty);
      expect(clearedDrafts, [
        const TaskRef(TaskResourceType.agentConversation, 'a'),
      ]);
      expect(_notice('任务删除成功'), findsOneWidget);
      await _expire(tester);
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, controller, platform);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
    });

    testWidgets(
      '$platform failures are safe, specific and keep current unread',
      (tester) async {
        final repo = _Repository();
        var clearedDrafts = 0;
        final controller = TaskController(
          repo,
          afterHide: (_) async => clearedDrafts++,
        );
        addTearDown(controller.dispose);
        await controller.refresh(synchronizeStatus: false);
        await _mount(tester, controller, platform);
        await tester.pumpAndSettle();
        await _menu(tester, '置顶');
        await controller.clearUnread();
        repo.pins.last.result.completeError(
          StateError('private upstream body'),
        );
        await tester.pumpAndSettle();
        expect(_notice('置顶失败，请重试'), findsOneWidget);
        expect(find.textContaining('private upstream'), findsNothing);
        expect(controller.state.catalog.records.single.pinnedAt, isNull);
        expect(controller.state.hasUnread, isFalse);
        expect(controller.state.catalog.records.single.unreadResult, isFalse);
        await _expire(tester);
        final pin = controller.pin(controller.state.catalog.records.single);
        repo.pins.last.result.complete(
          repo.rows.single.copyWith(pinnedAt: '2026-10-21'),
        );
        expect(await pin, isTrue);
        await tester.pumpAndSettle();
        await _expire(tester);
        await _menu(tester, '取消置顶');
        repo.pins.last.result.completeError(
          StateError('private upstream body'),
        );
        await tester.pumpAndSettle();
        expect(_notice('取消置顶失败，请重试'), findsOneWidget);
        expect(controller.state.catalog.records.single.pinnedAt, isNotNull);
        await _expire(tester);
        for (final blocked in [false, true]) {
          await _menu(tester, '删除');
          await tester.tap(find.text('删除'));
          await tester.pumpAndSettle();
          repo.deletes.last.result.completeError(
            blocked
                ? const ApiCodeFailure('TASK_DIALING_DELETE_BLOCKED')
                : StateError('private upstream body'),
          );
          await tester.pumpAndSettle();
          expect(
            _notice(blocked ? '正在通话的任务不能删除，请通话结束后重试' : '任务删除失败，请稍后重试'),
            findsOneWidget,
          );
          expect(controller.state.catalog.records.single.id, 'a');
          expect(clearedDrafts, 0);
          await _expire(tester);
        }
        await controller.clearUnread();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      },
    );
  }

  testWidgets('leaving host drops late feedback; reentry never replays it', (
    tester,
  ) async {
    final repo = _Repository();
    final controller = TaskController(repo);
    addTearDown(controller.dispose);
    await controller.refresh(synchronizeStatus: false);
    await _mount(tester, controller, TargetPlatform.iOS);
    await tester.pumpAndSettle();
    await _menu(tester, '置顶');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('其他页面'))),
    );
    repo.pins.single.result.complete(
      repo.rows.single.copyWith(pinnedAt: '2026-10-21'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
    expect(controller.state.catalog.records.single.pinnedAt, isNotNull);
    await _mount(tester, controller, TargetPlatform.iOS);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
  });

  testWidgets('refresh invalidates late pin success and failure feedback', (
    tester,
  ) async {
    final repo = _Repository();
    final controller = TaskController(repo);
    addTearDown(controller.dispose);
    await controller.refresh(synchronizeStatus: false);
    await _mount(tester, controller, TargetPlatform.android);
    await tester.pumpAndSettle();
    for (final fail in [false, true]) {
      final pin = controller.pin(controller.state.catalog.records.single);
      repo.rows = [row('fresh')];
      await controller.refresh(synchronizeStatus: false);
      if (fail) {
        repo.pins.last.result.completeError(StateError('offline'));
      } else {
        repo.pins.last.result.complete(
          row('a').copyWith(pinnedAt: '2026-10-21'),
        );
      }
      expect(await pin, isFalse);
      await tester.pumpAndSettle();
      expect(controller.state.catalog.records.single.id, 'fresh');
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      expect(controller.state.notice, isEmpty);
    }
  });

  testWidgets('released account cannot clear drafts or affect the next host', (
    tester,
  ) async {
    final oldRepo = _Repository();
    var clearedDrafts = 0;
    final old = TaskController(
      oldRepo,
      afterHide: (_) async => clearedDrafts++,
    );
    await old.refresh(synchronizeStatus: false);
    await _mount(tester, old, TargetPlatform.android);
    await tester.pumpAndSettle();
    final deletion = old.hide(old.state.catalog.records.single);
    await tester.pumpWidget(const SizedBox());
    old.dispose();
    final nextRepo = _Repository()..rows = [row('next-account')];
    final next = TaskController(nextRepo);
    addTearDown(next.dispose);
    await next.refresh(synchronizeStatus: false);
    await _mount(tester, next, TargetPlatform.android);
    oldRepo.deletes.single.result.complete();
    expect(await deletion, isFalse);
    await tester.pumpAndSettle();
    expect(clearedDrafts, 0);
    expect(next.state.catalog.records.single.id, 'next-account');
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
  });

  testWidgets('successful delete remains removed when its refresh fails', (
    tester,
  ) async {
    final repo = _Repository();
    final drafts = <TaskRef>[];
    final controller = TaskController(
      repo,
      afterHide: (r) async => drafts.add(r.ref!),
    );
    addTearDown(controller.dispose);
    await controller.refresh(synchronizeStatus: false);
    await _mount(tester, controller, TargetPlatform.iOS);
    await tester.pumpAndSettle();
    await _menu(tester, '删除');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    repo.loadFails = true;
    repo.deletes.single.result.complete();
    await tester.pumpAndSettle();
    expect(controller.state.catalog.records, isEmpty);
    expect(controller.state.notificationRecords, isEmpty);
    expect(drafts, [const TaskRef(TaskResourceType.agentConversation, 'a')]);
    expect(_notice('任务删除成功'), findsOneWidget);
    expect(controller.state.catalog.failedSources, {TaskSource.conversations});
    await _expire(tester);
    repo.loadFails = false;
    await controller.refresh(synchronizeStatus: false);
    await tester.pumpAndSettle();
    expect(controller.state.catalog.records, isEmpty);
    expect(controller.state.catalog.failedSources, isEmpty);
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
  });

  testWidgets(
    'back-to-back completed actions keep each one-shot effect before a rebuild',
    (tester) async {
      final repo = _Repository();
      final controller = TaskController(repo);
      addTearDown(controller.dispose);
      await controller.refresh(synchronizeStatus: false);
      await _mount(tester, controller, TargetPlatform.android);
      await tester.pumpAndSettle();
      for (final pinned in [true, false, true]) {
        final current = controller.state.catalog.records.single;
        final operation = controller.pin(current);
        repo.pins.last.result.complete(
          current.copyWith(pinnedAt: '2026-10-21', clearPin: !pinned),
        );
        expect(await operation, isTrue);
      }
      await tester.pumpAndSettle();
      for (final message in ['置顶成功', '取消置顶成功', '置顶成功']) {
        expect(_notice(message), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
    },
  );
}

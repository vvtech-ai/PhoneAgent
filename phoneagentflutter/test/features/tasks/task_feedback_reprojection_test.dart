import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/core/design/page_route_visibility.dart';

import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/domain/task_pinned_visibility.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_presentation_host.dart';
import 'task_pagination_test.dart' show row;

class _Repository implements PagedTaskRepository, TaskPinRepository {
  final firstPage = Completer<TaskPage>();
  int loads = 0;
  List<TaskRecord> rows = [row('a').copyWith(unreadResult: true)];
  final pins = <({TaskRef ref, bool pinned, Completer<TaskRecord> result})>[];
  final deletes = <({TaskRef ref, Completer<void> result})>[];
  @override
  Future<TaskPage> loadPage({int offset = 0, int limit = 15}) async {
    if (loads++ == 0) return firstPage.future;
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

class _LegacyRepository implements TaskRepository {
  @override
  Future<List<TaskRecord>> load(TaskSource source) async =>
      source == TaskSource.conversations ? [row('legacy')] : [];
}

void main() {
  tearDown(dismissNativeNotice);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final operation in ['pin', 'unpin', 'delete']) {
      testWidgets(
        '$platform initial-page reproject retains $operation notice subscription',
        (tester) async {
          final logs = <String>[];
          final originalPrint = debugPrint;
          debugPrint = (String? message, {int? wrapWidth}) {
            if (message?.startsWith('TaskFeedbackTrace ') == true) {
              logs.add(message!);
            }
          };
          try {
            final repo = _Repository();
            if (operation == 'unpin') {
              repo.rows = [repo.rows.single.copyWith(pinnedAt: '2026-10-21')];
            }
            final controller = TaskController(repo);
            addTearDown(controller.dispose);
            final originalFeedback = controller.state.operationFeedback!;
            final delivered = <String>[];
            final subscription = originalFeedback.listen(
              (event) => delivered.add(event.message),
            );
            addTearDown(subscription.cancel);
            final initialLoad = controller.refresh(synchronizeStatus: false);
            await _mount(tester, controller, platform);
            await tester.pump();
            expect(controller.state.loading, isTrue);
            expect(repo.loads, 1);
            // Status recovery can reproject while the first paged response is pending.
            controller.reproject();
            await tester.pump();
            repo.firstPage.complete(
              TaskPage(
                pinnedItems: repo.rows
                    .where((r) => r.pinnedAt != null)
                    .toList(),
                items: repo.rows.where((r) => r.pinnedAt == null).toList(),
                nextOffset: operation == 'unpin' ? 0 : 1,
                hasMore: false,
                hasUnread: true,
              ),
            );
            await initialLoad;
            await tester.pumpAndSettle();
            expect(find.text('AI 通话 · a'), findsOneWidget);
            final action = switch (operation) {
              'pin' => '置顶',
              'unpin' => '取消置顶',
              _ => '删除',
            };
            await _menu(tester, action);
            if (operation == 'delete') {
              expect(find.text('删除任务？'), findsOneWidget);
              await tester.tap(find.text('删除'));
              await tester.pumpAndSettle();
              repo.deletes.single.result.complete();
            } else {
              final current = repo.rows.single;
              expect(repo.pins.single.pinned, operation == 'pin');
              repo.pins.single.result.complete(
                current.copyWith(
                  pinnedAt: '2026-10-21',
                  clearPin: operation == 'unpin',
                ),
              );
            }
            await tester.pumpAndSettle();
            final message = switch (operation) {
              'pin' => '置顶成功',
              'unpin' => '取消置顶成功',
              _ => '任务删除成功',
            };
            expect(delivered, [message], reason: '业务成功事件确实发给原始反馈流');
            expect(
              logs.any(
                (line) =>
                    line.contains('stage=feedbackEmitted ') &&
                    line.contains('succeeded=true'),
              ),
              isTrue,
            );
            if (operation == 'delete') {
              expect(repo.rows, isEmpty);
              expect(controller.state.catalog.records, isEmpty);
            } else {
              expect(repo.rows.single.pinnedAt != null, operation == 'pin');
              expect(
                controller.state.catalog.records.single.pinnedAt != null,
                operation == 'pin',
              );
            }
            expect(
              _notice(message),
              findsOneWidget,
              reason: '保存成功后宿主必须接收事件。实际诊断：${logs.join(' | ')}',
            );
            expect(
              logs.any((line) => line.contains('stage=hostReceived ')),
              isTrue,
            );
            expect(controller.state.operationFeedback, same(originalFeedback));
            await _expire(tester);
            await controller.refresh(synchronizeStatus: false);
            controller.reproject();
            await tester.pumpAndSettle();
            expect(controller.state.operationFeedback, same(originalFeedback));
            expect(
              find.byKey(const ValueKey('nativeNoticeSurface')),
              findsNothing,
              reason: '刷新或重建不能重播原反馈',
            );
            expect(delivered, [message]);
          } finally {
            debugPrint = originalPrint;
          }
        },
      );
    }
  }
  test(
    'legacy refresh and reproject preserve the same feedback stream',
    () async {
      final controller = TaskController(_LegacyRepository());
      addTearDown(controller.dispose);
      final stream = controller.state.operationFeedback;
      expect(stream, isNotNull);
      await controller.refresh(synchronizeStatus: false);
      expect(controller.state.catalog.records.single.id, 'legacy');
      expect(controller.state.operationFeedback, same(stream));
      controller.reproject();
      expect(controller.state.operationFeedback, same(stream));
    },
  );
}

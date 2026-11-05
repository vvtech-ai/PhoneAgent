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
import 'package:phone_agent/features/tasks/presentation/pages/task_action_overlay.dart';
import 'task_pagination_test.dart' show row;

class _Repository implements PagedTaskRepository, TaskPinRepository {
  List<TaskRecord> rows = [row('a'), row('b')];
  final pinResponse = Completer<TaskRecord>();
  final deleteResponse = Completer<void>();
  @override
  Future<TaskRecord> updatePin(TaskRef ref, bool pinned) async {
    final saved = await pinResponse.future;
    rows = [for (final r in rows) r.ref == ref ? saved : r];
    return saved;
  }

  @override
  Future<void> hide(TaskRef ref) async {
    await deleteResponse.future;
    rows = rows.where((r) => r.ref != ref).toList();
  }

  @override
  Future<TaskPage> loadPage({int offset = 0, int limit = 15}) async => TaskPage(
    pinnedItems: rows.where((r) => r.pinnedAt != null).toList(),
    items: rows.where((r) => r.pinnedAt == null).toList(),
    nextOffset: rows.where((r) => r.pinnedAt == null).length,
    hasMore: false,
    hasUnread: false,
  );
  @override
  Future<List<TaskRecord>> load(TaskSource source) async => rows;
  @override
  Future<void> pin(TaskRef ref, bool pinned) => throw UnimplementedError();
  @override
  Future<void> clearUnread() async {}
  @override
  Future<void> markRead(TaskRef ref) async {}
}

class _Preferences implements TaskPinnedPreferenceRepository {
  _Preferences(this.scopeKey);
  @override
  final String scopeKey;
  @override
  Future<bool> read() async => false;
  @override
  Future<void> save(bool value) async {}
}

class _Harness extends StatefulWidget {
  const _Harness(this.controller, this.scope);
  final TaskController controller;
  final String scope;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late void Function() remove;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    remove = widget.controller.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void didUpdateWidget(_Harness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      remove();
      _listen();
    }
  }

  @override
  void dispose() {
    remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TasksPresentationHost(
    state: widget.controller.state,
    preferences: _Preferences(widget.scope),
    onRefresh: widget.controller.refresh,
    onOpen: (r) => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => Scaffold(body: Text('详情 ${r.id}'))),
    ),
    onPin: widget.controller.pin,
    onDelete: widget.controller.hide,
    onClearUnread: widget.controller.clearUnread,
    onLoadMore: widget.controller.loadMore,
  );
}

Finder get _surface => find.byKey(const ValueKey('nativeNoticeSurface'));
Widget _app({required TargetPlatform platform, required Widget body}) {
  final observer = PageRouteVisibilityObserver();
  return PageRouteVisibilityScope(
    observer: observer,
    child: MaterialApp(
      navigatorObservers: [observer],
      theme: ThemeData(platform: platform),
      home: Scaffold(body: body),
    ),
  );
}

Finder _message(String text) => find.descendant(
  of: _surface,
  matching: find.text(text, findRichText: true),
);

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.text('AI 通话 · b'));
  await tester.pumpAndSettle();
  expect(find.text('详情 b'), findsOneWidget);
  expect(
    find.byType(TasksPresentationHost, skipOffstage: false),
    findsOneWidget,
  );
}

Future<void> _openMenu(WidgetTester tester, bool confirmation) async {
  await tester.longPress(find.text('AI 通话 · b'));
  await tester.pumpAndSettle();
  expect(find.byType(TaskActionOverlay), findsOneWidget);
  if (confirmation) {
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除任务？'), findsOneWidget);
  }
}

void main() {
  tearDown(dismissNativeNotice);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final confirmation in [false, true]) {
      for (final deleting in [false, true]) {
        for (final fail in [false, true]) {
          testWidgets(
            '$platform popup ${confirmation ? 'confirmation' : 'menu'} preserves ${deleting ? 'delete' : 'pin'} ${fail ? 'failure' : 'success'} feedback',
            (tester) async {
              final repo = _Repository();
              final controller = TaskController(repo);
              addTearDown(controller.dispose);
              await controller.refresh(synchronizeStatus: false);
              await tester.pumpWidget(
                _app(
                  platform: platform,
                  body: _Harness(controller, 'account-a'),
                ),
              );
              await tester.pumpAndSettle();
              final target = controller.state.catalog.records.first;
              final operation = deleting
                  ? controller.hide(target)
                  : controller.pin(target);
              await tester.pumpAndSettle();
              await _openMenu(tester, confirmation);
              if (deleting) {
                if (fail) {
                  repo.deleteResponse.completeError(StateError('offline'));
                } else {
                  repo.deleteResponse.complete();
                }
              } else if (fail) {
                repo.pinResponse.completeError(StateError('offline'));
              } else {
                repo.pinResponse.complete(
                  target.copyWith(pinnedAt: '2026-10-21'),
                );
              }
              expect(await operation, !fail);
              await tester.pumpAndSettle();
              final message = deleting
                  ? (fail ? '任务删除失败，请稍后重试' : '任务删除成功')
                  : (fail ? '置顶失败，请重试' : '置顶成功');
              expect(_message(message), findsOneWidget);
              expect(find.byType(TaskActionOverlay), findsOneWidget);
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
              expect(_message(message), findsOneWidget);
              expect(
                controller.state.catalog.records.where((r) => r.id == 'b'),
                hasLength(1),
              );
              await tester.pump(const Duration(seconds: 4));
              await tester.pumpAndSettle();
              expect(_surface, findsNothing);
            },
          );
        }
      }
      testWidgets(
        '$platform popup ${confirmation ? 'confirmation' : 'menu'} preserves queued feedback',
        (tester) async {
          final repo = _Repository();
          final controller = TaskController(repo);
          addTearDown(controller.dispose);
          await controller.refresh(synchronizeStatus: false);
          await tester.pumpWidget(
            _app(platform: platform, body: _Harness(controller, 'account-a')),
          );
          await tester.pumpAndSettle();
          showNativeNotice(
            tester.element(find.byType(TasksPresentationHost)),
            '其他能力消息',
            duration: const Duration(seconds: 10),
          );
          final target = controller.state.catalog.records.first;
          final pin = controller.pin(target);
          repo.pinResponse.complete(target.copyWith(pinnedAt: '2026-10-21'));
          expect(await pin, isTrue);
          await tester.pumpAndSettle();
          await _openMenu(tester, confirmation);
          expect(_message('其他能力消息'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 11));
          await tester.pumpAndSettle();
          expect(_message('置顶成功'), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(_surface, findsNothing);
        },
      );
    }
    for (final deleting in [false, true]) {
      for (final fail in [false, true]) {
        testWidgets(
          '$platform retained route drops late ${deleting ? 'delete' : 'pin'} ${fail ? 'failure' : 'success'}',
          (tester) async {
            final repo = _Repository();
            final drafts = <TaskRef>[];
            final controller = TaskController(
              repo,
              afterHide: (r) async => drafts.add(r.ref!),
            );
            addTearDown(controller.dispose);
            await controller.refresh(synchronizeStatus: false);
            await tester.pumpWidget(
              _app(platform: platform, body: _Harness(controller, 'account-a')),
            );
            await tester.pumpAndSettle();
            final target = controller.state.catalog.records.first;
            final pending = deleting
                ? controller.hide(target)
                : controller.pin(target);
            await tester.pumpAndSettle();
            await _openDetail(tester);
            if (deleting) {
              if (fail) {
                repo.deleteResponse.completeError(StateError('offline'));
              } else {
                repo.deleteResponse.complete();
              }
            } else if (fail) {
              repo.pinResponse.completeError(StateError('offline'));
            } else {
              repo.pinResponse.complete(
                target.copyWith(pinnedAt: '2026-10-21'),
              );
            }
            expect(await pending, !fail);
            await tester.pumpAndSettle();
            expect(_surface, findsNothing);
            final remaining = controller.state.catalog.records.where(
              (r) => r.ref == target.ref,
            );
            if (deleting && !fail) {
              expect(remaining, isEmpty);
              expect(drafts, [target.ref]);
            } else {
              expect(remaining.single.pinnedAt != null, !deleting && !fail);
              expect(drafts, isEmpty);
            }
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('AI 通话 · b'), findsOneWidget);
            expect(_surface, findsNothing);
            await tester.pump(const Duration(seconds: 4));
            await tester.pumpAndSettle();
            expect(_surface, findsNothing);
          },
        );
      }
    }

    for (final departure in ['route', 'tab', 'account']) {
      testWidgets(
        '$platform $departure departure drops queued task feedback only',
        (tester) async {
          final repo = _Repository();
          final controller = TaskController(repo);
          addTearDown(controller.dispose);
          final next = TaskController(_Repository());
          addTearDown(next.dispose);
          await controller.refresh(synchronizeStatus: false);
          await next.refresh(synchronizeStatus: false);
          final active = ValueNotifier('tasks');
          addTearDown(active.dispose);
          await tester.pumpWidget(
            _app(
              platform: platform,
              body: ValueListenableBuilder<String>(
                valueListenable: active,
                builder: (_, value, __) => value == 'tab'
                    ? const Text('其他标签')
                    : _Harness(
                        value == 'account' ? next : controller,
                        value == 'account' ? 'account-b' : 'account-a',
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(TasksPresentationHost));
          showNativeNotice(
            context,
            '其他能力消息',
            duration: const Duration(seconds: 10),
          );
          final target = controller.state.catalog.records.first;
          final pin = controller.pin(target);
          repo.pinResponse.complete(target.copyWith(pinnedAt: '2026-10-21'));
          expect(await pin, isTrue);
          await tester.pumpAndSettle();
          expect(_message('其他能力消息'), findsOneWidget);
          expect(_message('置顶成功'), findsNothing);
          if (departure == 'route') {
            await _openDetail(tester);
          } else {
            active.value = departure;
            await tester.pumpAndSettle();
          }
          expect(_message('其他能力消息'), findsOneWidget);
          // Another feature's queued notice must survive targeted task invalidation.
          showNativeNotice(
            tester.element(find.byType(Scaffold).last),
            '后续其他能力消息',
          );
          if (departure == 'route') {
            await tester.binding.handlePopRoute();
          } else {
            active.value = 'tasks';
          }
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 11));
          await tester.pumpAndSettle();
          expect(_message('置顶成功'), findsNothing);
          expect(_message('后续其他能力消息'), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(_surface, findsNothing);
          expect(controller.state.pinnedItems.single.ref, target.ref);
        },
      );
    }

    testWidgets(
      '$platform route departure removes visible task notice and preserves other queued notice',
      (tester) async {
        final repo = _Repository();
        final controller = TaskController(repo);
        addTearDown(controller.dispose);
        await controller.refresh(synchronizeStatus: false);
        await tester.pumpWidget(
          _app(platform: platform, body: _Harness(controller, 'account-a')),
        );
        await tester.pumpAndSettle();
        final target = controller.state.catalog.records.first;
        final pin = controller.pin(target);
        repo.pinResponse.complete(target.copyWith(pinnedAt: '2026-10-21'));
        expect(await pin, isTrue);
        await tester.pumpAndSettle();
        expect(_message('置顶成功'), findsOneWidget);
        showNativeNotice(
          tester.element(find.byType(TasksPresentationHost)),
          '其他能力排队消息',
        );
        await _openDetail(tester);
        expect(_message('置顶成功'), findsNothing);
        expect(_message('其他能力排队消息'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_message('置顶成功'), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(_surface, findsNothing);
      },
    );
  }
}

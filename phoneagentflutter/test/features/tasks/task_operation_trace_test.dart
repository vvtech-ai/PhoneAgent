import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    onOpen: (_) => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('合成覆盖页'))),
    ),
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
  late DebugPrintCallback originalPrint;
  late List<String> logs;
  setUp(() {
    logs = [];
    originalPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message?.startsWith('TaskFeedbackTrace ') == true) logs.add(message!);
    };
  });
  tearDown(() {
    debugPrint = originalPrint;
    dismissNativeNotice();
  });

  List<String> stage(String value) =>
      logs.where((line) => line.contains('stage=$value ')).toList();

  testWidgets('trace successful pin unpin delete without leaking task data', (
    tester,
  ) async {
    final repo = _Repository()
      ..rows = [row('private-task-id-sentinel').copyWith(unreadResult: true)];
    final controller = TaskController(repo);
    addTearDown(controller.dispose);
    await controller.refresh(synchronizeStatus: false);
    await _mount(tester, controller, TargetPlatform.android);
    await tester.pumpAndSettle();
    for (final pinned in [true, false]) {
      final current = controller.state.catalog.records.single;
      final pending = controller.pin(current);
      repo.pins.last.result.complete(
        current.copyWith(pinnedAt: '2026-10-21', clearPin: !pinned),
      );
      expect(await pending, isTrue);
      await tester.pumpAndSettle();
      expect(_notice(pinned ? '置顶成功' : '取消置顶成功'), findsOneWidget);
      await _expire(tester);
    }
    final deleting = controller.hide(controller.state.catalog.records.single);
    repo.deletes.single.result.complete();
    expect(await deleting, isTrue);
    await tester.pumpAndSettle();
    expect(_notice('任务删除成功'), findsOneWidget);
    expect(stage('operationStarted'), hasLength(3));
    expect(stage('actionCompleted'), hasLength(3));
    expect(
      stage('feedbackEmitted').map((line) => line.contains('succeeded=true')),
      everyElement(isTrue),
    );
    expect(stage('feedbackEmitted'), hasLength(3));
    expect(stage('hostReceived'), hasLength(3));
    expect(stage('noticeRequested'), hasLength(3));
    expect(logs.join('\n'), isNot(contains('private-task-id-sentinel')));
    expect(logs.join('\n'), isNot(contains('account-a')));
    expect(logs.join('\n'), isNot(contains('置顶成功')));
    for (final operation in ['pin', 'unpin', 'delete']) {
      expect(
        stage(
          'feedbackEmitted',
        ).any((line) => line.contains('operation=$operation ')),
        isTrue,
      );
    }
    await _expire(tester);
    debugPrint = tester.binding.debugPrintOverride;
  });

  test('trace epoch invalidation keeps obsolete feedback suppressed', () async {
    final repo = _Repository();
    final controller = TaskController(repo);
    addTearDown(controller.dispose);
    await controller.refresh(synchronizeStatus: false);
    final pending = controller.pin(controller.state.catalog.records.single);
    await controller.refresh(synchronizeStatus: false);
    repo.pins.single.result.complete(row('a').copyWith(pinnedAt: '2026-10-21'));
    expect(await pending, isFalse);
    expect(stage('actionCompleted'), hasLength(1));
    expect(
      stage('operationInvalidated').single,
      contains('epochCurrent=false'),
    );
    expect(stage('feedbackEmitted'), isEmpty);
  });

  testWidgets('trace route gate separates received from suppressed notice', (
    tester,
  ) async {
    final repo = _Repository();
    final controller = TaskController(repo);
    addTearDown(controller.dispose);
    await controller.refresh(synchronizeStatus: false);
    await _mount(tester, controller, TargetPlatform.android);
    await tester.pumpAndSettle();
    final pending = controller.pin(controller.state.catalog.records.single);
    final context = tester.element(find.byType(TasksPresentationHost));
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('合成覆盖页'))),
    );
    await tester.pumpAndSettle();
    repo.pins.single.result.complete(row('a').copyWith(pinnedAt: '2026-10-21'));
    expect(await pending, isTrue);
    await tester.pumpAndSettle();
    expect(
      stage('hostReceived').single,
      contains('mounted=true active=true visiblePage=false'),
    );
    expect(stage('hostSuppressed'), hasLength(1));
    expect(stage('noticeRequested'), isEmpty);
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
    debugPrint = tester.binding.debugPrintOverride;
  });

  test(
    'trace rejected duplicate and failed action contains no error body',
    () async {
      final repo = _Repository();
      final controller = TaskController(repo);
      addTearDown(controller.dispose);
      await controller.refresh(synchronizeStatus: false);
      final current = controller.state.catalog.records.single;
      final pending = controller.hide(current);
      expect(await controller.hide(current), isFalse);
      repo.deletes.single.result.completeError(
        StateError('private-exception-token-sentinel'),
      );
      expect(await pending, isFalse);
      expect(stage('guardRejected').single, contains('busy=true'));
      expect(stage('feedbackEmitted').single, contains('succeeded=false'));
      expect(
        logs.join('\n'),
        isNot(contains('private-exception-token-sentinel')),
      );
    },
  );

  test(
    'trace output failure cannot change a successful task operation',
    () async {
      var attempts = 0;
      debugPrint = (String? message, {int? wrapWidth}) {
        attempts++;
        throw StateError('log sink failed');
      };
      final repo = _Repository();
      final controller = TaskController(repo);
      addTearDown(controller.dispose);
      await controller.refresh(synchronizeStatus: false);
      final effects = <String>[];
      final subscription = controller.state.operationFeedback!.listen(
        (result) => effects.add(result.message),
      );
      final pending = controller.pin(controller.state.catalog.records.single);
      repo.pins.single.result.complete(
        row('a').copyWith(pinnedAt: '2026-10-21'),
      );
      expect(await pending, isTrue);
      expect(effects, ['置顶成功']);
      expect(attempts, greaterThan(0));
      await subscription.cancel();
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/page_route_visibility.dart';
import 'package:phone_agent/features/tasks/domain/task_pinned_visibility.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_presentation_host.dart';
import 'task_pinned_visibility_test.dart' show row;

class _Fold implements TaskPinnedPreferenceRepository {
  _Fold(this.scopeKey);
  @override
  final String scopeKey;
  bool folded = true;
  @override
  Future<bool> read() async => folded;
  @override
  Future<void> save(bool value) async {
    folded = value;
  }
}

void main() {
  testWidgets(
    'read pins fold, unread remain, expansion persists and account identity restores separately',
    (tester) async {
      final store = _Fold('user-a');
      final rows = [
        row('已读置顶', pinned: true),
        row('未读置顶', pinned: true, unread: true),
        row('普通任务'),
      ];
      final observer = PageRouteVisibilityObserver();
      Widget page(_Fold prefs) {
        return PageRouteVisibilityScope(
          observer: observer,
          child: MaterialApp(
            navigatorObservers: [observer],
            home: Scaffold(
              body: TasksPresentationHost(
                key: ValueKey(prefs.scopeKey),
                state: TaskState(catalog: TaskCatalog(rows)),
                preferences: prefs,
                onRefresh: () async {},
                onOpen: (_) {},
                onPin: (_) async => false,
                onDelete: (_) {},
                onClearUnread: () {},
                onLoadMore: () {},
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(page(store));
      await tester.pumpAndSettle();
      expect(find.text('AI 通话 · 已读置顶'), findsNothing);
      expect(find.text('AI 通话 · 未读置顶'), findsOneWidget);
      await tester.tap(find.text('1 个置顶任务'));
      await tester.pumpAndSettle();
      expect(store.folded, isFalse);
      expect(find.text('AI 通话 · 已读置顶'), findsOneWidget);
      await tester.pumpWidget(page(_Fold('user-b')));
      await tester.pumpAndSettle();
      expect(find.text('AI 通话 · 已读置顶'), findsNothing);
      expect(store.folded, isFalse);
      await tester.pumpWidget(page(store));
      await tester.pumpAndSettle();
      expect(find.text('AI 通话 · 已读置顶'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

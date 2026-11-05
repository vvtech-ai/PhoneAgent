import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/recording_providers.dart';
import 'package:phone_agent/app/task_detail_providers.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_detail_route.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'task_detail_controller_test.dart' show History, Legacy, row;

final epoch = StateProvider<int>((ref) => 1);
void main() {
  testWidgets('account changes before detail mounts never load old task', (
    tester,
  ) async {
    final history = History();
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          historyRepositoryProvider.overrideWithValue(history),
        ],
        child: MaterialApp(
          navigatorKey: key,
          home: const Scaffold(body: Text('列表')),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    key.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const TaskDetailRoute(record: row, ownerEpoch: 1),
      ),
    );
    container.read(epoch.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(history.reads, 0);
    expect(find.byType(TaskDetailRoute), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'detail retries, gates restoration and closes on account switch',
    (tester) async {
      final history = History();
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
            historyRepositoryProvider.overrideWithValue(history),
            taskDetailRepositoryProvider.overrideWithValue(Legacy()),
            recordingSupportedProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            navigatorKey: key,
            home: const Scaffold(body: Text('列表')),
          ),
        ),
      );
      key.currentState!.push(
        MaterialPageRoute(builder: (_) => const TaskDetailRoute(record: row)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('task-detail-restore')),
            )
            .onPressed,
        isNull,
      );
      history.pending.completeError(TimelineFailure.unavailable);
      await tester.pumpAndSettle();
      expect(find.text('重新加载详情'), findsOneWidget);
      history.pending = Completer();
      await tester.tap(find.text('重新加载详情'));
      await tester.tap(find.text('重新加载详情'));
      await tester.pump();
      expect(history.reads, 2);
      history.pending.complete(
        const RestoredConversation(
          ConversationDetail(
            sessionId: 'same',
            title: '服务端详情',
            status: 'COMPLETED',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('服务端详情'), findsOneWidget);
      expect(find.text('状态：已完成'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDetailRoute)),
      );
      container.read(epoch.notifier).state = 2;
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailRoute), findsNothing);
      expect(history.reads, 2, reason: '新账号不能加载旧详情');
    },
  );
}

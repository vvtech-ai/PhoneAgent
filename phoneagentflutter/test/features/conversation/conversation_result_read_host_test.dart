import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_result_read_host.dart';
import '../tasks/visible_task_result_read_test.dart' show result;
import '../tasks/batch_result_read_protocol_test.dart' show payload;

void main() {
  testWidgets(
    'visible PENDING/FINISHED batch records journal acknowledgement',
    (tester) async {
      const session = '0123456789abcdef0123456789abcdef';
      final store = _Store();
      final journal = DiagnosticJournal(store);
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationResultReadHost(
            sessionId: session,
            messages: ReceiptMessageMapper.fromFinal(payload(), 'c'),
            isCurrent: () => true,
            markRead: (_) async {
              reads++;
            },
            diagnostic: taskResultReadDiagnostics(journal.record),
            child: const Scaffold(body: Text('批量结果')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await journal.flush();
      journal.close();
      final restored = DiagnosticJournal(store);
      addTearDown(restored.close);
      final events = (await restored.snapshot()).events;
      expect(reads, 1);
      expect(events.map((e) => e.result), [
        DiagnosticResult.started,
        DiagnosticResult.succeeded,
      ]);
      expect(
        events.every(
          (e) =>
              e.operation == DiagnosticOperation.taskResultRead &&
              e.sessionId == session,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'read diagnostics use fixed categories and reject unsafe identifiers',
    () {
      final events = <DiagnosticEvent>[];
      final record = taskResultReadDiagnostics(events.add);
      record('private phone and token', 'ack_failed', 'private exception');
      expect(events.single.sessionId, isEmpty);
      expect(events.single.failureKind, DiagnosticFailureKind.other);
      expect(events.single.toJson().toString(), isNot(contains('private')));
      record('01234567-89ab-cdef-0123-456789abcdef', 'ack_failed', 'timeout');
      expect(events.last.sessionId, isNotEmpty);
      expect(events.last.failureKind, DiagnosticFailureKind.timeout);
      final unrelated = DiagnosticEvent(
        operation: DiagnosticOperation.accountRequest,
        result: DiagnosticResult.started,
        sessionId: '0123456789abcdef0123456789abcdef',
      );
      expect(unrelated.sessionId, isEmpty);
      taskResultReadDiagnostics((_) => throw StateError('sink'))(
        's',
        'ack_started',
        'terminal_visible',
      );
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform only visible current owner acknowledges final results',
      (tester) async {
        var reads = 0, current = true;
        final diagnostics = <String>[];
        final route = GlobalKey<NavigatorState>();
        final messages = ValueNotifier([result('DIALING')]);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: route,
            theme: ThemeData(platform: platform),
            home: ValueListenableBuilder(
              valueListenable: messages,
              builder: (_, value, __) => ConversationResultReadHost(
                sessionId: 's',
                messages: value,
                isCurrent: () => current,
                markRead: (_) async {
                  reads++;
                },
                diagnostic: (_, stage, outcome) {
                  diagnostics.add('$stage:$outcome');
                },
                child: const Scaffold(body: Text('当前任务')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(reads, 0);
        route.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('覆盖页')),
          ),
        );
        await tester.pumpAndSettle();
        messages.value = [result('SUCCESS')];
        await tester.pumpAndSettle();
        expect(reads, 0);
        route.currentState!.pop();
        await tester.pumpAndSettle();
        expect(reads, 1);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        messages.value = [result('FAILED', attempt: 'new')];
        await tester.pumpAndSettle();
        expect(reads, 1);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(diagnostics, [
          'ack_started:terminal_visible',
          'ack_succeeded:terminal_visible',
          'ack_started:terminal_visible',
          'ack_succeeded:terminal_visible',
        ]);
        current = false;
        messages.value = [result('SUCCESS', attempt: 'old-account')];
        await tester.pumpAndSettle();
        expect(reads, 2);
        await tester.pumpWidget(const SizedBox());
        messages.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('exit flushes a visible incomplete result acknowledgement', (
    tester,
  ) async {
    final pending = Completer<void>();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationResultReadHost(
          sessionId: 's',
          messages: [result('INCOMPLETE')],
          isCurrent: () => true,
          markRead: (_) {
            reads++;
            return pending.future;
          },
          child: const Scaffold(body: Text('当前任务')),
        ),
      ),
    );
    await tester.pump();
    expect(reads, 1);
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

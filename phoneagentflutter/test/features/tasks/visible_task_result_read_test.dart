import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/visible_task_result_read.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/native_call_receipt_presentation.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_status.dart';

ConversationMessage result(String status, {String attempt = 'attempt'}) =>
    ConversationMessage(
      id: attempt,
      role: MessageRole.assistant,
      text: '',
      receipt: CallReceipt(attemptId: attempt, status: status),
    );
void main() {
  test('unowned SDK physical end does not mark a result read', () async {
    final physical = LedgerEvent(
      eventId: 'physical-without-attempt',
      sessionId: 's',
      sequence: 1,
      type: 'CALL_COMPLETED',
      schemaVersion: 1,
      commandId: 'call-command',
      payload: {'resultCode': 'SDK_PHYSICAL_ENDED', 'summary': '任务失败，等待业务结果'},
    );
    var reads = 0;
    final owner = VisibleTaskResultRead('s', (_) async {
      reads++;
    }, () => true);
    final message = ConversationMessages.project([
      physical,
    ]).where((item) => item.receipt != null).single;
    expect(message.receipt!.status, 'SDK_PHYSICAL_ENDED');
    await owner.show([message], visible: true);
    expect(reads, 0);
  });
  test(
    'SDK physical end with failure wording waits for a semantic result',
    () async {
      LedgerEvent fact(
        int sequence,
        String type,
        Map<String, Object?> payload,
      ) => LedgerEvent(
        eventId: 'e$sequence',
        sessionId: 's',
        sequence: sequence,
        type: type,
        schemaVersion: 1,
        commandId: 'call-command',
        callAttemptId: 'attempt',
        payload: payload,
      );
      final physical = fact(1, 'CALL_COMPLETED', {
        'resultCode': 'SDK_PHYSICAL_ENDED',
        'summary': '任务失败，等待业务结果',
        'callReceipt': {
          'callId': 'call-a',
          'callState': 'ENDED',
          'resultCode': 'SDK_PHYSICAL_ENDED',
          'resultReason': '任务失败，等待业务结果',
        },
      });
      var reads = 0;
      final owner = VisibleTaskResultRead('s', (_) async {
        reads++;
      }, () => true);
      final physicalMessage = ConversationMessages.project([
        physical,
      ]).where((message) => message.receipt != null).single;
      final physicalReceipt = physicalMessage.receipt!;
      expect(physicalReceipt.metadata['physicalTerminalOnly'], 'true');
      expect(
        NativeCallReceiptPresentation(physicalReceipt).physicalResultPending,
        isTrue,
      );
      expect(
        CallReceiptStatus.outcome(physicalReceipt),
        CallReceiptOutcome.unclear,
      );
      await owner.show([physicalMessage], visible: true);
      expect(reads, 0);

      for (final outcome in ['FAILED', 'UNCLEAR']) {
        final report = fact(2, 'CALL_OUTCOME_REPORTED', {
          'outcome': outcome,
          'reason': '业务报告：未能确认',
        });
        final reportedMessage = ConversationMessages.project([
          physical,
          report,
        ]).where((message) => message.receipt != null).single;
        expect(
          reportedMessage.receipt!.metadata['physicalTerminalOnly'],
          isNull,
        );
        await owner.show([reportedMessage], visible: true);
        expect(reads, outcome == 'FAILED' ? 1 : 2);
      }
    },
  );
  test(
    'physical end, intermediate, SSE text, exit and old account do not mark read',
    () async {
      var current = true, reads = 0;
      final owner = VisibleTaskResultRead('s', (_) async {
        reads++;
      }, () => current);
      await owner.show([
        result('ENDED'),
        result('CALL_COMPLETED'),
        result('DIALING'),
      ], visible: true);
      await owner.show([result('SUCCESS')], visible: false);
      current = false;
      await owner.show([result('SUCCESS')], visible: true);
      expect(reads, 0);
      current = true;
      owner.close();
      await owner.show([result('SUCCESS')], visible: true);
      expect(reads, 0);
    },
  );
  test('incomplete and execution-error cards are result states', () async {
    var reads = 0;
    final owner = VisibleTaskResultRead('s', (_) async {
      reads++;
    }, () => true);
    await owner.show([result('INCOMPLETE')], visible: true);
    await owner.show([
      result('EXECUTION_ERROR', attempt: 'error'),
    ], visible: true);
    expect(reads, 2);
  });
  test(
    'visible result is read once, next attempt read, failure retries on reentry',
    () async {
      var reads = 0, fail = true;
      final diagnostics = <String>[];
      final owner = VisibleTaskResultRead(
        's',
        (ref) async {
          expect(ref.id, 's');
          reads++;
          if (fail) throw StateError('offline');
        },
        () => true,
        diagnostic: (_, stage, outcome) {
          diagnostics.add('$stage:$outcome');
        },
      );
      await owner.show([result('SUCCESS')], visible: true);
      fail = false;
      await owner.show([result('SUCCESS')], visible: true);
      await owner.show([result('SUCCESS')], visible: true);
      expect(reads, 2);
      await owner.show([result('FAILED', attempt: 'retry')], visible: true);
      expect(reads, 3);
      expect(diagnostics, [
        'ack_started:terminal_visible',
        'ack_failed:state',
        'ack_started:terminal_visible',
        'ack_succeeded:terminal_visible',
        'ack_started:terminal_visible',
        'ack_succeeded:terminal_visible',
      ]);
    },
  );
  test(
    'inflight duplicate does not replay and late result after exit is unread',
    () async {
      final pending = Completer<void>();
      var reads = 0;
      final owner = VisibleTaskResultRead('s', (_) {
        reads++;
        return pending.future;
      }, () => true);
      final read = owner.show([result('SUCCESS')], visible: true);
      await owner.show([result('SUCCESS')], visible: true);
      await owner.show([result('FAILED', attempt: 'late')], visible: false);
      pending.complete();
      await read;
      expect(reads, 1);
    },
  );
  test('exit waits for an in-flight visible result acknowledgement', () async {
    final pending = Completer<void>();
    var reads = 0;
    final owner = VisibleTaskResultRead('s', (_) {
      reads++;
      return pending.future;
    }, () => true);
    final showing = owner.show([result('INCOMPLETE')], visible: true);
    expect(reads, 1);
    final closing = owner.close([result('INCOMPLETE')]);
    pending.complete();
    await Future.wait([showing, closing]);
    expect(reads, 1);
  });
  test(
    'partial batch remains unread until final aggregate is rendered',
    () async {
      var reads = 0;
      final owner = VisibleTaskResultRead('s', (_) async {
        reads++;
      }, () => true);
      ConversationMessage batch(String status, String itemStatus) =>
          ConversationMessage(
            id: 'batch',
            role: MessageRole.assistant,
            text: '',
            batchReceipt: BatchReceipt.fromJson({
              'batchId': 'b',
              'status': status,
              'items': [
                {'status': itemStatus},
              ],
            }, fallbackId: 'b'),
          );
      await owner.show([batch('COMPLETED', 'DIALING')], visible: true);
      expect(reads, 0);
      await owner.show([batch('COMPLETED', 'SUCCESS')], visible: true);
      expect(reads, 1);
    },
  );
}

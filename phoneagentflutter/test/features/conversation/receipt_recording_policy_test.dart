import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';

void main() {
  CallReceipt single({String transcript = 'AI：您好', String anchor = 'call-a'}) =>
      CallReceipt(
        attemptId: 'attempt',
        callId: 'not-the-metadata-anchor',
        status: 'COMPLETED',
        transcript: transcript,
        metadata: {'callId': anchor},
      );
  BatchReceiptItem batch(List<int?> connected, {String callId = 'call-b'}) =>
      BatchReceiptItem.fromJson({
        'callId': callId,
        'status': 'FAILED',
        'billingSummaries': [
          for (final (index, value) in connected.indexed)
            {
              'billingSessionId': 'bill-$index',
              'displayDurationSeconds': 60,
              if (value != null) 'connectedDurationMs': value,
            },
        ],
      }, 'item');
  test('single uses trimmed metadata anchor', () {
    expect(single(anchor: ' call-a ').recordingCallId, 'call-a');
  });
  test('single does not substitute callId or attempt for missing anchor', () {
    expect(single(anchor: '').recordingCallId, isNull);
  });
  test('v66 single hides recording for summary or missing dialogue', () {
    expect(single(transcript: '总结：已完成').recordingCallId, isNull);
    expect(single(transcript: '').recordingCallId, isNull);
    expect(single(transcript: 'AI代打结果：通话未接通').recordingCallId, isNull);
  });
  test('failed task with recorded dialogue retains recording', () {
    for (final transcript in ['AI：您好', '对方：现在不方便']) {
      expect(
        CallReceipt(
          attemptId: 'attempt',
          status: 'FAILED',
          transcript: transcript,
          metadata: const {'callId': 'call-a'},
        ).recordingCallId,
        'call-a',
      );
    }
  });
  test('explicit unanswered or zero duration cannot create recording', () {
    for (final metadata in [
      {'callId': 'call-a', 'answered': 'false'},
      {'callId': 'call-a', 'durationMillis': '0'},
    ]) {
      expect(
        CallReceipt(
          attemptId: 'attempt',
          status: 'FAILED',
          transcript: 'AI：开场白',
          metadata: metadata,
        ).recordingCallId,
        isNull,
      );
    }
  });
  test(
    'batch without settlement retains call anchor even with failed outcome',
    () {
      expect(batch([]).recordingCallId, 'call-b');
      expect(batch([], callId: ' ').recordingCallId, isNull);
    },
  );
  test(
    'batch uses final settlement not display seconds or earlier connection',
    () {
      expect(batch([12000, 0]).recordingCallId, isNull);
      expect(batch([12000, null]).recordingCallId, isNull);
      expect(batch([0, 1]).recordingCallId, 'call-b');
    },
  );
  test(
    'connected milliseconds remain separate from rounded display seconds',
    () {
      final billing = batch([12001]).billing.single;
      expect(billing.connectedDurationMillis, 12001);
      expect(billing.durationSeconds, 60);
    },
  );
}

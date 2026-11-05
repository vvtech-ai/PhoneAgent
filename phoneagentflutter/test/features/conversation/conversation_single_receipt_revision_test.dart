import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_content_revision.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_timeline.dart';

CallReceipt single({
  String summary = '合成回执',
  String outcome = 'SUCCESS',
  String hidden = '隐藏',
  String transcript = 'callee:合成回复',
  int points = 1,
}) => CallReceipt(
  attemptId: hidden,
  callId: hidden,
  targetName: '合成联系人',
  status: 'COMPLETED',
  headline: summary,
  transcript: transcript,
  fields: [ReceiptField(hidden, '事项', '合成事项')],
  metadata: {'agentOutcome': outcome, 'unused': hidden},
  billing: ReceiptBilling(
    sessionId: hidden,
    state: 'SETTLED',
    chargedPoints: points,
  ),
);
ConversationContentRevision revision(CallReceipt receipt) =>
    ConversationContentRevision('synthetic', [
      ConversationMessage(
        id: 'same',
        role: MessageRole.assistant,
        text: '',
        receipt: receipt,
      ),
    ]);

void main() {
  test('visible single values and semantic status affect revision', () {
    final old = revision(single());
    expect(revision(single()), old);
    expect(revision(single(hidden: '新隐藏参数')), old);
    expect(revision(single(summary: '更新回执')), isNot(old));
    expect(revision(single(outcome: 'FAILED')), isNot(old));
    expect(revision(single(transcript: 'callee:新的合成回复')), isNot(old));
    expect(revision(single(points: 2)), isNot(old));
  });
  test('only displayed detail and semantic metadata affect revision', () {
    CallReceipt receipt(String hidden, {String outcome = 'SUCCESS'}) =>
        CallReceipt(
          attemptId: 'synthetic',
          status: 'COMPLETED',
          headline: '合成回执',
          detail: hidden,
          metadata: {'agentOutcome': outcome, 'unused': '未显示参数'},
        );
    expect(revision(receipt('合成详情')), isNot(revision(receipt('更新详情'))));
    expect(
      revision(receipt('合成详情', outcome: 'FAILED')),
      isNot(revision(receipt('合成详情'))),
    );
  });
  test('reported UNCLEAR reason refreshes the same structured card', () {
    CallReceipt receipt(String reason) => CallReceiptProjector.project([
      LedgerEvent(
        eventId: 'reported',
        sessionId: 'session',
        sequence: 1,
        type: 'CALL_OUTCOME_REPORTED',
        schemaVersion: 1,
        commandId: 'command',
        callId: 'call-a',
        callAttemptId: 'synthetic',
        payload: {
          'outcome': 'UNCLEAR',
          'reason': reason,
          'headline': '订餐未完成',
          'receiptFields': [
            {'key': 'taskType', 'label': '任务类型', 'value': '订餐'},
          ],
        },
      ),
    ]).single.receipt;
    expect(
      receipt('等待最终说明').metadata[CallReceipt.ledgerOutcomeSourceKey],
      'reported',
    );
    expect(
      revision(receipt('等待最终说明')),
      isNot(revision(receipt('商家未确认订位，短信发送未确认'))),
    );
  });
  test(
    'an incomplete receipt revises when its visible reason is finalized',
    () {
      CallReceipt receipt(String reason) => CallReceipt(
        attemptId: 'same-attempt',
        status: 'UNCLEAR',
        headline: '订餐未完成',
        metadata: {
          'sceneType': 'restaurant_booking',
          'agentOutcome': 'UNCLEAR',
          'agentReason': reason,
        },
      );
      expect(
        revision(receipt('等待最终说明')),
        isNot(revision(receipt('通话未获明确订位确认，短信发送未确认'))),
      );
    },
  );
  test(
    'visible booking labels change revision; unrelated metadata does not',
    () {
      CallReceipt receipt(String scene, String hidden) => CallReceipt(
        attemptId: 'synthetic',
        status: 'FAILED',
        detail: '合成失败原因',
        metadata: {
          'sceneType': scene,
          'resultCode': 'NO_ANSWER',
          'unused': hidden,
        },
      );
      expect(
        revision(receipt('FOOD_ORDERING', 'a')),
        isNot(revision(receipt('AI_CALL', 'a'))),
      );
      expect(
        revision(receipt('FOOD_ORDERING', 'a')),
        revision(receipt('FOOD_ORDERING', 'b')),
      );
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform same message single update returns to tail', (
      tester,
    ) async {
      var receipt = single();
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return NativeConversationTimeline(
                  reverse: true,
                  tailRevision: revision(receipt),
                  children: [
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 80, child: Text('合成历史$i')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('conversation-timeline'));
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      await tester.drag(list, const Offset(0, 250));
      await tester.pumpAndSettle();
      final oldOffset = position().pixels;
      expect(oldOffset, greaterThan(100));
      change(() => receipt = single(hidden: '更新隐藏参数'));
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(oldOffset, .01));
      change(() => receipt = single(outcome: 'FAILED'));
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(0, .01));
    });
  }
}

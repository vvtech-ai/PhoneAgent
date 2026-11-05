import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/user_document_presentation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_content_revision.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_timeline.dart';

BatchReceipt batch({
  String summary = '合成结果',
  String hidden = '隐藏',
  String transcript = '',
  int points = 1,
}) => BatchReceipt.fromJson({
  'batchId': 'synthetic',
  'status': 'COMPLETED',
  'headline': '合成批量',
  'items': [
    {
      'itemId': 'one',
      'targetName': '合成联系人',
      'status': 'SUCCESS',
      'headline': summary,
      'detail': hidden,
      'transcript': transcript,
      'receiptFields': [
        {'key': 'purpose', 'label': '事项', 'value': hidden},
      ],
      'billingSummaries': [
        {'billingSessionId': 'synthetic', 'chargedPoints': points},
      ],
    },
  ],
}, fallbackId: 'synthetic');
ConversationContentRevision revision({
  BatchReceipt? receipt,
  UserDocumentPresentation? document,
}) => ConversationContentRevision('synthetic', [
  ConversationMessage(
    id: 'same',
    role: MessageRole.assistant,
    text: '',
    batchReceipt: receipt,
    document: document,
  ),
]);

void main() {
  test('batch visible values change while hidden fields preserve history', () {
    final old = revision(receipt: batch());
    expect(revision(receipt: batch()), old);
    expect(revision(receipt: batch(hidden: '新的隐藏参数')), old);
    expect(revision(receipt: batch(summary: '更新结果')), isNot(old));
    expect(revision(receipt: batch(points: 2)), isNot(old));
    expect(revision(receipt: batch(transcript: 'callee:合成回复')), isNot(old));
    expect(revision(), isNot(old));
  });
  test(
    'document values ignore hidden identity and retain immutable snapshot',
    () {
      final files = [const UserDocumentFile('合成.docx', charCount: 10)];
      UserDocumentPresentation doc(String id) =>
          UserDocumentPresentation(id, files);
      final old = revision(document: doc('one'));
      expect(revision(document: doc('two')), old);
      files[0] = const UserDocumentFile('更新.docx', charCount: 20);
      expect(revision(document: doc('one')), isNot(old));
      expect(
        revision(
          document: UserDocumentPresentation('three', [
            const UserDocumentFile('合成.docx', charCount: 10),
          ]),
        ),
        old,
      );
    },
  );
  test('running summary and empty billing have no displayed change', () {
    BatchReceipt receipt(String title, List<Object?> bills) =>
        BatchReceipt.fromJson({
          'status': 'RUNNING',
          'headline': title,
          'items': [
            {'itemId': 'one', 'status': 'RUNNING', 'billingSummaries': bills},
          ],
        }, fallbackId: 'synthetic');
    final old = revision(receipt: receipt('隐藏摘要', []));
    expect(revision(receipt: receipt('更新隐藏摘要', [])), old);
    expect(
      revision(
        receipt: receipt('隐藏摘要', [
          {'billingSessionId': 'synthetic', 'billingState': 'PENDING'},
        ]),
      ),
      old,
    );
    expect(
      revision(
        receipt: receipt('隐藏摘要', [
          {'billingSessionId': 'synthetic', 'chargedPoints': 1},
        ]),
      ),
      isNot(old),
    );
  });
  test('billing attempt heading remains a visible change', () {
    BatchReceipt receipt(List<Object?> bills) => BatchReceipt.fromJson({
      'status': 'COMPLETED',
      'items': [
        {'itemId': 'one', 'status': 'SUCCESS', 'billingSummaries': bills},
      ],
    }, fallbackId: 'synthetic');
    const visible = {'billingSessionId': 'synthetic', 'chargedPoints': 1};
    const hidden = {'billingSessionId': 'hidden', 'billingState': 'PENDING'};
    expect(
      revision(receipt: receipt([visible])),
      isNot(revision(receipt: receipt([visible, hidden]))),
    );
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform same message visible updates return to tail', (
      tester,
    ) async {
      var receipt = batch();
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
                  tailRevision: revision(receipt: receipt),
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
      change(() => receipt = batch(hidden: '更新隐藏参数'));
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(oldOffset, .01));
      change(() => receipt = batch(summary: '更新可见结果'));
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(0, .01));
    });
  }
}

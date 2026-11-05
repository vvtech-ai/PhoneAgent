import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/receipt_feedback_target.dart';
import 'package:phone_agent/features/feedback/presentation/controller/call_evaluation_controller.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/call_evaluation_card.dart';

void main() {
  ConversationMessage message({CallReceipt? call, BatchReceipt? batch}) =>
      ConversationMessage(
        id: 'synthetic',
        role: MessageRole.assistant,
        text: '',
        receipt: call,
        batchReceipt: batch,
      );
  test(
    'only stable server call/batch IDs can mount feedback; running batch hidden',
    () {
      expect(receiptFeedbackTarget(message()), isNull);
      expect(
        receiptFeedbackTarget(
          message(
            call: CallReceipt(attemptId: 'attempt', status: 'DONE'),
          ),
        ),
        isNull,
      );
      expect(
        receiptFeedbackTarget(
          message(
            call: CallReceipt(
              attemptId: 'attempt',
              status: 'DONE',
              callId: ' call ',
            ),
          ),
        ),
        const FeedbackTarget(FeedbackTargetKind.call, 'call'),
      );
      expect(
        receiptFeedbackTarget(
          message(
            batch: BatchReceipt.fromJson({
              'status': 'DONE',
            }, fallbackId: 'local'),
          ),
        ),
        isNull,
      );
      expect(
        receiptFeedbackTarget(
          message(
            batch: BatchReceipt.fromJson({
              'status': 'running',
              'batchId': 'batch',
            }, fallbackId: 'local'),
          ),
        ),
        isNull,
      );
      expect(
        receiptFeedbackTarget(
          message(
            batch: BatchReceipt.fromJson({
              'status': 'DONE',
              'batchId': 'batch',
            }, fallbackId: 'local'),
          ),
        ),
        const FeedbackTarget(FeedbackTargetKind.batch, 'batch'),
      );
    },
  );
  testWidgets(
    'hidden until model known; buttons submit GOOD/BAD, no invented reward',
    (tester) async {
      final ratings = <CallRating>[];
      Future<void> render(CallEvaluationState state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: CallEvaluationCard(state: state, onRate: ratings.add),
            ),
          ),
        ),
      );
      await render(const CallEvaluationState());
      expect(find.byTooltip('好评'), findsNothing);
      const result = CallEvaluation(
        target: FeedbackTarget(FeedbackTargetKind.call, 'call'),
        modelName: '合成模型',
        minimumLatencyMs: 120,
        maximumLatencyMs: 240,
      );
      await render(const CallEvaluationState(evaluation: result));
      await tester.pumpAndSettle();
      expect(find.text('合成模型'), findsOneWidget);
      expect(find.text('120ms～240ms'), findsOneWidget);
      expect(find.textContaining('100积分'), findsNothing);
      await tester.tap(find.byTooltip('好评'));
      await tester.tap(find.byTooltip('差评'));
      expect(ratings, [CallRating.good, CallRating.bad]);
      await render(const CallEvaluationState(evaluation: result, saving: true));
      for (final button in tester.widgetList<IconButton>(
        find.byType(IconButton),
      )) {
        expect(button.onPressed, isNull);
      }
      await render(
        const CallEvaluationState(evaluation: result, error: '评价提交失败，请重试'),
      );
      expect(find.text('评价提交失败，请重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

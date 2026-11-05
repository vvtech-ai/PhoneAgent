import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/presentation/pages/call_evaluation_route.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/native_task_rating_entry.dart';

import '../../support/task_rating_result_refresh_fakes.dart';

const _target = FeedbackTarget(FeedbackTargetKind.batch, 'structured-batch');

ConversationMessage _result(
  String completion, {
  bool completed = false,
  String targetName = '合成联系人',
}) => ConversationMessage(
  id: 'structured-result',
  role: MessageRole.assistant,
  text: '',
  batchReceipt: BatchReceipt.fromJson({
    'batchId': _target.id,
    'status': 'COMPLETED',
    'headline': '通知任务已完成',
    'totalCount': completed && completion == 'totalCount' ? 2 : 1,
    'items': [
      {
        'itemId': 'one',
        'callId': 'structured-call',
        'callAttemptId': 'structured-attempt',
        'targetName': targetName,
        'status': 'COMPLETED',
        'headline': '通知已送达',
        'detail': '固定结果正文',
        'recalled': completed && completion == 'recalled',
        'abnormal': completed && completion == 'abnormal',
        'receiptFields': [
          if (completed && completion == 'receiptFields')
            {'key': 'attendance', 'label': '到场意向', 'value': '确认参加'},
        ],
      },
    ],
  }, fallbackId: 'structured-result'),
);

void main() {
  for (final completion in [
    'receiptFields',
    'recalled',
    'abnormal',
    'totalCount',
  ]) {
    testWidgets(
      'RATING-01 batch $completion-only completion refreshes its original provider once',
      (tester) async {
        final message = ValueNotifier(_result(completion));
        addTearDown(message.dispose);
        final ratings = RefreshRatingRepository()
          ..result = const TaskRatingEligibility(
            target: _target,
            eligible: false,
          );
        await tester.pumpWidget(
          ratingRefreshScope(
            ratings,
            ValueListenableBuilder<ConversationMessage>(
              valueListenable: message,
              builder: (_, value, __) => Column(
                children: [
                  const Text('任务结果'),
                  CallEvaluationRoute.forReceipt(value)!,
                  const Text('Agent 结果说明'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NativeTaskRatingEntry), findsNothing);
        expect(ratings.reads, 1);
        ratings.result = const TaskRatingEligibility(
          target: _target,
          eligible: true,
          id: 'structured-eligibility',
          taskId: 'structured-task',
          taskType: 'BATCH',
        );
        message.value = _result(completion, completed: true);
        await tester.pumpAndSettle();
        expect(find.text('去评分'), findsOneWidget);
        expect(ratings.reads, 2);
        expect(
          tester
              .widget<CallEvaluationRoute>(find.byType(CallEvaluationRoute))
              .target,
          _target,
        );
        final card = find.byType(NativeTaskRatingEntry);
        expect(
          tester.getTopLeft(card).dy,
          greaterThan(tester.getTopLeft(find.text('任务结果')).dy),
        );
        expect(
          tester.getTopLeft(card).dy,
          lessThan(tester.getTopLeft(find.text('Agent 结果说明')).dy),
        );

        message.value = _result(completion, completed: true);
        await tester.pumpAndSettle();
        expect(ratings.reads, 2, reason: 'same business values do not poll');
        message.value = _result(
          completion,
          completed: true,
          targetName: '更新显示名',
        );
        await tester.pumpAndSettle();
        expect(
          ratings.reads,
          2,
          reason: 'display-only target names do not refresh eligibility',
        );
        expect(find.byType(NativeTaskRatingEntry), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

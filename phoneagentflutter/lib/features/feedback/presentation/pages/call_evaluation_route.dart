import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/feedback_providers.dart';
import '../../../conversation/domain/conversation_messages.dart';
import '../../domain/call_evaluation.dart';
import '../../domain/receipt_feedback_target.dart';
import '../widgets/call_evaluation_card.dart';
import 'task_rating_route.dart';

class CallEvaluationRoute extends ConsumerWidget {
  const CallEvaluationRoute({
    super.key,
    required this.target,
    this.resultRevision,
  });
  final FeedbackTarget target;
  final String? resultRevision;

  static Widget? forReceipt(ConversationMessage message) {
    final target = receiptFeedbackTarget(message);
    return target == null
        ? null
        : CallEvaluationRoute(
            target: target,
            resultRevision: receiptFeedbackRevision(message),
          );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CallEvaluationCard(
        state: ref.watch(callEvaluationControllerProvider(target)),
        onRate: ref
            .read(callEvaluationControllerProvider(target).notifier)
            .rate,
      ),
      TaskRatingRoute(
        key: ValueKey(target),
        target: target,
        resultRevision: resultRevision,
      ),
    ],
  );
}

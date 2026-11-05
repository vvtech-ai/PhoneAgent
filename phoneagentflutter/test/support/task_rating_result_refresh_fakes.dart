import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/feedback_providers.dart';
import 'package:phone_agent/app/recording_providers.dart';
import 'package:phone_agent/app/task_detail_providers.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_detail_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_detail_route.dart';
import 'rating_fakes.dart';

const ratingRefreshRow = TaskRecord(
  id: 'row',
  kind: TaskRecordKind.conversation,
  title: '合成任务',
  status: TaskStatus.completed,
  rawStatus: 'COMPLETED',
  sessionId: 'session',
);

ConversationMessage ratingRefreshResult(String detail) => ConversationMessage(
  id: 'result',
  role: MessageRole.assistant,
  text: '',
  receipt: CallReceipt(
    attemptId: 'attempt',
    callId: ratingTarget.id,
    status: 'COMPLETED',
    headline: '任务结果',
    detail: detail,
  ),
);

class RatingRefreshDetailState extends TaskDetailState {
  RatingRefreshDetailState(this.results) : super(ratingRefreshRow);
  final List<ConversationMessage> results;
  @override
  List<ConversationMessage> get messages => results;
}

// Only the read-only history boundary is controlled; feedback providers,
// eligibility controller, detail builder and rendered rating entry remain real.
class RatingRefreshDetail extends TaskDetailController {
  RatingRefreshDetail() : super.inactive(ratingRefreshRow) {
    publish('初始结果');
  }
  void publish(String detail) => publishResults([ratingRefreshResult(detail)]);
  void publishResults(List<ConversationMessage> results) =>
      state = RatingRefreshDetailState([
        ...results,
        const ConversationMessage(
          id: 'explanation',
          role: MessageRole.assistant,
          text: 'Agent 结果说明',
        ),
      ]);
}

class RefreshRatingRepository extends FakeRatingRepository {
  int reads = 0;
  bool failEligibility = false;
  final pending = <Completer<TaskRatingEligibility>>[];
  @override
  Future<TaskRatingEligibility> eligibility(
    FeedbackTarget target, {
    required String clientVersion,
  }) async {
    reads++;
    if (failEligibility) throw StateError('synthetic eligibility failure');
    if (pending.isNotEmpty) return pending.removeAt(0).future;
    return result;
  }
}

Widget ratingRefreshScope(RefreshRatingRepository ratings, Widget child) =>
    ProviderScope(
      overrides: [
        taskRatingRepositoryProvider.overrideWithValue(ratings),
        taskRatingDraftStoreProvider.overrideWithValue(FakeRatingDraftStore()),
        taskRatingClientVersionProvider.overrideWith((ref) async => '1.0.52'),
        callEvaluationRepositoryProvider.overrideWithValue(
          RefreshEvaluationRepository(),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

class RefreshEvaluationRepository implements CallEvaluationRepository {
  @override
  Future<CallEvaluation> load(FeedbackTarget target) async =>
      CallEvaluation(target: target, modelName: '合成模型');
  @override
  Future<CallEvaluation> rate(FeedbackTarget target, CallRating rating) async =>
      CallEvaluation(target: target, modelName: '合成模型', rating: rating);
}

Future<ProviderContainer> mountRatingRefreshDetail(
  WidgetTester tester,
  RatingRefreshDetail detail,
  RefreshRatingRepository ratings,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWithValue(1),
        recordingSupportedProvider.overrideWithValue(false),
        taskDetailControllerProvider((
          record: ratingRefreshRow,
          epoch: 1,
        )).overrideWith((ref) => detail),
        callEvaluationRepositoryProvider.overrideWithValue(
          RefreshEvaluationRepository(),
        ),
        taskRatingRepositoryProvider.overrideWithValue(ratings),
        taskRatingDraftStoreProvider.overrideWithValue(FakeRatingDraftStore()),
        taskRatingClientVersionProvider.overrideWith((ref) async => '1.0.52'),
      ],
      child: const MaterialApp(
        home: TaskDetailRoute(record: ratingRefreshRow, ownerEpoch: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(TaskDetailRoute)),
  );
}

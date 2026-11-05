import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/feedback/data/api_call_evaluation_repository.dart';
import '../features/feedback/domain/call_evaluation.dart';
import '../features/feedback/presentation/controller/call_evaluation_controller.dart';
import 'business_providers.dart';

final callEvaluationRepositoryProvider =
    Provider.autoDispose<CallEvaluationRepository>(
      (ref) => ApiCallEvaluationRepository(ref.watch(accountApiProvider)),
    );
final callEvaluationControllerProvider = StateNotifierProvider.autoDispose
    .family<CallEvaluationController, CallEvaluationState, FeedbackTarget>((
      ref,
      target,
    ) {
      final controller = CallEvaluationController(
        target,
        ref.watch(callEvaluationRepositoryProvider),
      );
      controller.load();
      return controller;
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/tasks/data/api_task_detail_repository.dart';
import '../features/tasks/domain/task_details.dart';
import '../features/tasks/domain/task_records.dart';
import '../features/tasks/presentation/controller/task_detail_controller.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';

final taskDetailRepositoryProvider = Provider.autoDispose<TaskDetailRepository>(
  (ref) => ApiTaskDetailRepository(ref.watch(accountApiProvider)),
);
final taskDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<
      TaskDetailController,
      TaskDetailState,
      ({TaskRecord record, int? epoch})
    >((ref, request) {
      if (ref.watch(loginEpochProvider) != request.epoch) {
        return TaskDetailController.inactive(request.record);
      }
      final controller = TaskDetailController(
        request.record,
        ref.watch(historyRepositoryProvider),
        ref.watch(taskDetailRepositoryProvider),
      );
      controller.load();
      return controller;
    });

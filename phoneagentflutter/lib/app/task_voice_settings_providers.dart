import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/data/api_task_voice_store.dart';
import '../features/settings/domain/task_voice.dart';
import '../features/settings/presentation/controller/task_voice_controller.dart';
import 'business_providers.dart';

final taskVoiceStoreProvider = Provider.autoDispose<TaskVoiceStore>(
  (ref) => ApiTaskVoiceStore(ref.watch(accountApiProvider)),
);
final taskVoiceControllerProvider =
    StateNotifierProvider.autoDispose<TaskVoiceController, TaskVoiceState>((
      ref,
    ) {
      final controller = TaskVoiceController(ref.watch(taskVoiceStoreProvider));
      controller.load();
      return controller;
    });

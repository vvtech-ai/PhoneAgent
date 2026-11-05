import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/data/voice/secure_task_voice_preferences.dart';
import '../features/conversation/domain/voice/task_voice_preferences.dart';
import '../features/conversation/presentation/controller/task_voice_preference_controller.dart';
import '../features/conversation/presentation/controller/task_voice_guide_controller.dart';
import '../features/conversation/presentation/controller/conversation_state.dart';

final taskVoicePreferenceRepositoryProvider =
    Provider<TaskVoicePreferenceRepository>(
      (_) => const SecureTaskVoicePreferences(),
    );
final taskVoicePreferenceProvider =
    ChangeNotifierProvider<TaskVoicePreferenceController>((ref) {
      final controller = TaskVoicePreferenceController(
        ref.watch(taskVoicePreferenceRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
final taskVoiceGuideProvider = Provider.autoDispose
    .family<TaskVoiceGuideController, ConversationEntry>((ref, entry) {
      final controller = TaskVoiceGuideController(
        ref.watch(taskVoicePreferenceProvider.notifier),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

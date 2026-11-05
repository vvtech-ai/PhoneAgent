import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/apology/data/api_apology_voice_port.dart';
import '../features/apology/domain/apology_voice.dart';
import '../features/call_models/domain/call_models.dart';
import '../features/call_models/presentation/controller/call_model_controller.dart';
import '../features/apology/presentation/controller/apology_conversation_binding.dart';
import '../features/conversation/presentation/controller/conversation_controller.dart';
import 'business_providers.dart';
import 'task_call_model_providers.dart';
import 'conversation_precheck_providers.dart';
import '../features/conversation/presentation/controller/conversation_state.dart';

final apologyVoicePortProvider = Provider.autoDispose<ApologyVoicePort>(
  (ref) => ApiApologyVoicePort(ref.watch(accountApiProvider)),
);

/// Called after the conversation's OCR owner and speech dependencies are ready.
void bindApologyPrecheck(
  Ref ref,
  ConversationController controller,
  ConversationEntry entry,
) {
  if (controller.apology == null || entry.restore) return;
  ref.listen(conversationPrecheckProvider(entry), (_, check) {
    if (!check.presentation.visible) controller.apology?.begin();
  }, fireImmediately: true);
}

/// A normal conversation must not start model-directory requests for this Skill.
void bindApologyModelChanges(Ref ref, ConversationController controller) {
  var sourceBound = false;
  var listening = false;
  var disposed = false;
  ref.onDispose(() => disposed = true);
  void bind(ConversationState state) {
    if (!sourceBound) {
      sourceBound = true;
      final taskModel = ref.watch(
        taskCallModelSourceProvider(state.entry.sessionId),
      );
      ref.onDispose(
        taskModel.bind(() {
          final voice = controller.apology?.voice;
          return voice == null
              ? null
              : (
                  modelId: voice.modelId,
                  ready: controller.isOpen && !voice.blocked,
                );
        }),
      );
    }
    if (listening || controller.apology == null) return;
    listening = true;
    ref.listen(callModelControllerProvider, (_, after) {
      _reconcileApologyModel(controller, after);
    });
    Future.microtask(() {
      if (!disposed && controller.isOpen) {
        _reconcileApologyModel(
          controller,
          ref.read(callModelControllerProvider),
        );
      }
    });
  }

  ref.onDispose(controller.addListener(bind));
}

void _reconcileApologyModel(
  ConversationController controller,
  CallModelState state,
) {
  final catalog = state.catalog;
  final voice = controller.apology?.voice;
  final taskModel = voice?.modelId;
  if (catalog == null ||
      state.loading ||
      state.saving ||
      state.error.isNotEmpty ||
      voice == null ||
      taskModel == null && voice.stage != ApologyVoiceStage.needsVoice) {
    return;
  }
  final allowed =
      taskModel != null &&
      catalog.models.any(
        (model) =>
            model.available &&
            normalizeProvider(model.id) == normalizeProvider(taskModel),
      );
  if (allowed) return;
  final fallback = catalog.current;
  if (fallback == null) {
    voice.modelUnavailable();
  } else {
    voice.modelChanged(fallback.id);
  }
}

ApologyVoiceDependencies apologyVoiceDependencies(
  Ref ref, {
  bool waitForPrecheck = false,
}) => ApologyVoiceDependencies(
  port: ref.watch(apologyVoicePortProvider),
  waitForPrecheck: waitForPrecheck,
  model: () => ref.read(callModelControllerProvider).catalog?.current?.id ?? '',
  modelName: () =>
      ref.read(callModelControllerProvider).catalog?.current?.name ?? '当前模型',
  modelNameFor: (id) =>
      ref
          .read(callModelControllerProvider)
          .catalog
          ?.models
          .where(
            (model) => normalizeProvider(model.id) == normalizeProvider(id),
          )
          .firstOrNull
          ?.name ??
      '当前模型',
);

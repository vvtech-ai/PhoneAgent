import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/task_voice_settings_providers.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_task_port_providers.dart';
import 'package:phone_agent/app/home_card_preference_providers.dart';
import 'package:phone_agent/app/task_draft_providers.dart';
import 'package:phone_agent/app/task_pinned_preference_providers.dart';
import 'package:phone_agent/app/task_voice_preference_providers.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_reply.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/confirmation_supplement.dart';
import 'package:phone_agent/features/conversation/domain/drafts/task_draft.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/domain/voice/task_voice_preferences.dart';
import 'package:phone_agent/features/home/domain/home_card_preferences.dart';
import 'package:phone_agent/features/tasks/domain/task_pinned_visibility.dart';

/// Explicit in-memory ports for MOCK/test hosts; never used by the product App.
List<Override> shellTaskParityOverrides() {
  final drafts = <String, _Drafts>{}, homes = <String, _Home>{};
  final pinned = <String, _Pinned>{}, supplements = <String, _Supplements>{};
  String account(Ref ref) => ref.watch(currentAccountIdProvider);
  return [
    taskVoiceStoreProvider.overrideWithValue(_TaskVoiceStore()),
    homeInstalledVersionProvider.overrideWith((_) async => '1.0.0'),
    homeCardPreferenceRepositoryProvider.overrideWith(
      (ref) => homes.putIfAbsent(account(ref), _Home.new),
    ),
    taskPinnedPreferenceProvider.overrideWith((ref) {
      final id = account(ref);
      return pinned.putIfAbsent(id, () => _Pinned(id));
    }),
    taskDraftRepositoryProvider.overrideWith(
      (ref, entry) =>
          drafts.putIfAbsent('${account(ref)}:${entry.sessionId}', _Drafts.new),
    ),
    taskVoicePreferenceRepositoryProvider.overrideWithValue(_Voice()),
    confirmationSupplementStoreProvider.overrideWith(
      (ref, session) =>
          supplements.putIfAbsent('${account(ref)}:$session', _Supplements.new),
    ),
    callConfirmationReplyRepositoryProvider.overrideWithValue(_Replies()),
    confirmationSupplementRepositoryProvider.overrideWithValue(
      _SupplementServer(),
    ),
    conversationStopRepositoryProvider.overrideWithValue(_Stop()),
  ];
}

class _Drafts implements TaskDraftRepository {
  TaskDraft? value;
  @override
  Future<TaskDraft?> read() async => value;
  @override
  Future<void> save(TaskDraft? draft) async {
    value = draft;
  }
}

class _Home implements HomeCardPreferenceRepository {
  HomeCardPreferences value = const HomeCardPreferences();
  @override
  Future<HomeCardPreferences> read() async => value;
  @override
  Future<void> save(HomeCardPreferences value) async {
    this.value = value;
  }
}

class _Pinned implements TaskPinnedPreferenceRepository {
  _Pinned(this.scopeKey);
  @override
  final String scopeKey;
  bool value = false;
  @override
  Future<bool> read() async => value;
  @override
  Future<void> save(bool value) async {
    this.value = value;
  }
}

class _Voice implements TaskVoicePreferenceRepository {
  TaskVoicePreferences value = const TaskVoicePreferences();
  @override
  Future<TaskVoicePreferences> read() async => value;
  @override
  Future<void> speech(bool enabled) async {
    value = TaskVoicePreferences(
      speechEnabled: enabled,
      guideCompleted: value.guideCompleted,
    );
  }

  @override
  Future<void> completeGuide() async {
    value = TaskVoicePreferences(
      speechEnabled: value.speechEnabled,
      guideCompleted: true,
    );
  }
}

class _Supplements implements ConfirmationSupplementStore {
  List<ConfirmationSupplement> value = [];
  @override
  Future<List<ConfirmationSupplement>> read() async => List.of(value);
  @override
  Future<void> write(List<ConfirmationSupplement> records) async {
    value = List.of(records);
  }
}

class _Replies implements CallConfirmationReplyRepository {
  @override
  Future<CallReply> classify(CallReplyScope scope, String text) async =>
      const CallReply(CallReplyDecision.unclear);
}

class _SupplementServer implements ConfirmationSupplementRepository {
  @override
  Future<String> save(String sessionId, ConfirmationSupplement record) async =>
      throw StateError('MOCK supplement ledger is not configured');
}

class _Stop implements ConversationStopRepository {
  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async =>
      const TurnStopResult(TurnStopStatus.notActive);
  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async =>
      throw StateError('MOCK batch stop is not configured');
}

class _TaskVoiceStore implements TaskVoiceStore {
  TaskVoice value = TaskVoice.maia;
  @override
  Future<TaskVoice> read() async => value;
  @override
  Future<void> write(TaskVoice voice) async {
    value = voice;
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_admission_providers.dart';
import 'package:phone_agent/app/call_session_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_task_speech_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/app/ocr_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/app/task_voice_preference_providers.dart';
import 'package:phone_agent/features/attachments/domain/ocr_image_source.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/voice/task_voice_preferences.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import '../../tool/previews/shell_catalog_fakes.dart';
import '../../tool/previews/shell_conversation_fakes.dart';
import '../../tool/previews/shell_preview_ports.dart';
import '../features/conversation/voice/conversation_speech_controller_test.dart'
    show SpeechFake;
import 'call_admission_fixture.dart';
import 'synthetic_account_api.dart';
import 'granted_task_entry.dart';
import 'package:phone_agent/app/agent_context_providers.dart';

class CancelledOcrPicker implements OcrImageSource {
  int picks = 0;
  @override
  Future<SelectedOcrImage?> pick() async {
    picks++;
    return null;
  }
}

class ApologyTestNetwork
    implements NetworkAvailabilitySource, NetworkAvailabilityEvents {
  final initial = Completer<NetworkAvailability>();
  final changes = StreamController<NetworkAvailability>.broadcast(sync: true);
  @override
  Future<NetworkAvailability> read() => initial.future;
  @override
  Stream<NetworkAvailability> watch() => changes.stream;
}

class _Preferences implements TaskVoicePreferenceRepository {
  @override
  Future<TaskVoicePreferences> read() async =>
      const TaskVoicePreferences(guideCompleted: true);
  @override
  Future<void> speech(bool enabled) async {}
  @override
  Future<void> completeGuide() async {}
}

class ApologyProviderFixture {
  ApologyProviderFixture(
    this.entry, {
    ConversationHistoryRepository? history,
    List<Override> extra = const [],
  }) {
    container = ProviderContainer(
      overrides: [
        accountApiProvider.overrideWithValue(api.api),
        pointsWalletRepositoryProvider.overrideWithValue(ShellPreviewPoints()),
        networkAvailabilitySourceProvider.overrideWithValue(network),
        networkAvailabilityEventsProvider.overrideWithValue(network),
        sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
        ocrImageSourceProvider.overrideWithValue(picker),
        currentAccountIdProvider.overrideWithValue('synthetic'),
        conversationPermissionSourceProvider.overrideWithValue(
          const GrantedTaskEntry(),
        ),
        agentGatewayProvider.overrideWithValue(gateway),
        historyRepositoryProvider.overrideWithValue(
          history ?? OfflineHistory(),
        ),
        callModelRepositoryProvider.overrideWithValue(
          FakeCallModelRepository(),
        ),
        conversationTaskSpeechProvider.overrideWith(
          (ref, entry) => ConversationTaskSpeech(
            factory: (_, __) {
              final player = SpeechFake();
              players.add(player);
              return player;
            },
            prepare: () => speechPreparations++,
            close: () => speechClosures++,
          ),
        ),
        taskVoicePreferenceRepositoryProvider.overrideWithValue(_Preferences()),
        voiceInputFactoryProvider.overrideWithValue(
          (_) => PreviewVoiceSession(),
        ),
        taskErrorStatusSyncProvider.overrideWith((ref) {
          final sync = PreviewTaskErrorStatusPorts().createSync();
          ref.onDispose(sync.close);
          return sync;
        }),
        callAdmissionProvider(
          entry.sessionId,
        ).overrideWithValue(AdmissionFixture().service),
        callSessionRepositoryProvider.overrideWithValue(
          PreviewCallFlow(CallFlowScenario.single),
        ),
        ...extra,
      ],
    );
  }
  final ConversationEntry entry;
  final api = SyntheticAccountApi();
  final network = ApologyTestNetwork();
  final picker = CancelledOcrPicker();
  final gateway = OfflineAgent();
  final players = <SpeechFake>[];
  int speechPreparations = 0, speechClosures = 0;
  late final ProviderContainer container;
  ProviderSubscription<ConversationState>? _keep;
  Future<void> open(WidgetTester tester) async {
    container.read(sessionControllerProvider);
    await tester.pump();
    _keep = container.listen(conversationControllerProvider(entry), (_, __) {});
    await tester.pump();
  }

  Future<void> complete(WidgetTester tester) async {
    network.initial.complete(NetworkAvailability.available);
    await tester.pump();
    for (final ms in [300, 350, 350, 500]) {
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  Future<void> dispose() async {
    _keep?.close();
    container.dispose();
    api.api.close();
    await network.changes.close();
  }
}

import 'package:phone_agent/app/home_notification_providers.dart';
import 'package:phone_agent/features/task_notifications/data/secure_home_notification_read_store.dart';
import 'package:phone_agent/app/call_model_quality_providers.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'shell_network_error_ports.dart';
import 'shell_error_controls.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/app/points_session_providers.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/identity/data/preview_identity_cleanup.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'shell_conversation_ports.dart';
import 'shell_catalog_fakes.dart';
import 'package:phone_agent/app/system_voice_preview_providers.dart';
import 'auth_scenario.dart';
import 'shell_preview_ports.dart';
import 'shell_translation_preview.dart';
import 'shell_clone_ports.dart';
import 'shell_clone_preview.dart';
import 'shell_history_preview.dart';
import 'shell_settings_preview.dart';
import 'shell_contacts_preview.dart';
import 'shell_attachment_ports.dart';
import 'shell_agent_document_ports.dart';
import 'shell_receipt_preview.dart';
import 'shell_diagnostics_preview.dart';
import 'shell_startup_preview.dart';
import 'shell_session_controls.dart';
import 'shell_call_preview.dart';
import 'shell_task_parity_ports.dart';
import 'shell_initialization_store.dart';
import 'shell_permission_ports.dart';
import 'shell_invite_ports.dart';
import 'commerce_preview_ports.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';

/// Formal App navigation with isolated basic external ports. Hosted only in the
/// MOCK workbench. Unsupported APIs fail unconfigured, never use a real server.
class ShellPreviewPage extends StatefulWidget {
  const ShellPreviewPage({
    super.key,
    this.sessionControls = false,
    this.errorControls = false,
    this.initializeIdentity = false,
    this.startSignedIn = true,
    this.formalClone = false,
    this.nativeSystemVoices = false,
    this.modelQuality,
    this.commerce,
  });
  final CommerceRepository? commerce;
  final CallModelQualityRepository? modelQuality;
  final bool sessionControls;
  final bool errorControls;
  final bool initializeIdentity;
  final bool startSignedIn;
  final bool formalClone, nativeSystemVoices;
  @override
  State<ShellPreviewPage> createState() => _ShellPreviewPageState();
}

class _ShellPreviewPageState extends State<ShellPreviewPage> {
  late final _auth = AuthScenario(AuthScenarioKind.direct)
    ..saved = widget.startSignedIn
        ? const AuthSession(
            accountId: 'synthetic-preview',
            phone: '13800000000',
            accessToken: 'synthetic-not-a-credential',
          )
        : null;
  final _home = FakeHomeRepository(translationEnabled: true);
  late final _models = FakeCallModelRepository(
    includeCloneModels: true,
    nativeSystemVoices: widget.nativeSystemVoices,
  );
  final _notificationReads = <String, MemoryHomeNotificationReadStore>{};
  late final _taskParity = shellTaskParityOverrides();
  final _points = ShellPreviewPoints();
  final _audio = ShellPreviewAudioStore();
  late final _translation = ShellTranslationPreviewPorts(
    originalAudio: () => _audio.value,
  );
  late final _identity = PreviewIdentityCleanup()
    ..value = IdentityProfile(
      accountId: 'synthetic',
      name: widget.initializeIdentity ? '' : '合成身份',
    );
  late final _initializationStore = ShellInitializationStore(_identity);
  late final _clones = ShellClonePorts(_identity, _models);

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) throw UnsupportedError('Preview is debug-only');
    return ProviderScope(
      overrides: [
        ..._taskParity,
        homeNotificationReadStoreProvider.overrideWith((ref) {
          ref.watch(loginEpochProvider);
          final owner = ref
              .read(sessionControllerProvider.notifier)
              .credentials;
          if (owner == null) return null;
          return _notificationReads.putIfAbsent(
            owner.accountId,
            MemoryHomeNotificationReadStore.new,
          );
        }),
        cloneVoicePreviewLoaderProvider.overrideWithValue(
          (_, {bool current = false}) async =>
              throw StateError('Synthetic clone preview not configured'),
        ),
        ...shellInviteOverrides(),
        ...shellCallOverrides(),
        ...shellDiagnosticsOverrides(),
        ...shellStartupOverrides(),
        ...shellAttachmentOverrides(),
        if (shellAgentDocumentEnabled) ...shellAgentDocumentOverrides(),
        ...shellReceiptOverrides(context),
        ...shellContactsOverrides(),
        ...shellSettingsOverrides(),
        ...shellHistoryOverrides(context),
        ..._translation.overrides,
        ...shellCloneOverrides(_clones, formal: widget.formalClone),
        conversationPermissionSourceProvider.overrideWith(
          (ref) => ref.watch(shellPermissionPortsProvider),
        ),
        appConfigProvider.overrideWithValue(
          AppConfig.parse(environment: 'local', apiBaseUrl: ''),
        ),
        authGatewayProvider.overrideWithValue(_auth),
        sessionStoreProvider.overrideWithValue(_auth),
        networkAvailabilitySourceProvider.overrideWithValue(
          const UnknownNetworkAvailability(),
        ),
        networkAvailabilityEventsProvider.overrideWith(
          (ref) => ref.watch(shellNetworkErrorPortsProvider),
        ),
        homeRepositoryProvider.overrideWithValue(_home),
        callModelRepositoryProvider.overrideWithValue(_models),
        callModelQualityRepositoryProvider.overrideWithValue(
          widget.modelQuality ?? const _PreviewModelQuality(),
        ),
        taskRepositoryProvider.overrideWith(
          (ref) => ref.watch(shellConversationPortsProvider),
        ),
        taskErrorStatusSyncProvider.overrideWith((ref) {
          ref.watch(loginEpochProvider);
          var active = true;
          final sync = ref
              .watch(shellNetworkErrorPortsProvider)
              .createSync(isCurrent: () => active);
          ref.keepAlive();
          ref.onDispose(() {
            active = false;
            sync.close();
          });
          return sync;
        }),
        historyRepositoryProvider.overrideWith(
          (ref) => ref.watch(shellConversationPortsProvider),
        ),
        agentGatewayProvider.overrideWith(
          (ref) => shellAgentDocumentEnabled
              ? ref.watch(shellAgentDocumentPortsProvider)
              : ref.watch(shellConversationPortsProvider),
        ),
        pointsWalletRepositoryProvider.overrideWithValue(_points),
        ...commercePreviewOverrides(repository: widget.commerce),
        pointsActivationRepositoryProvider.overrideWithValue(_points),
        pointsWalletCacheProvider.overrideWithValue(
          const EmptyPointsWalletCache(),
        ),
        originalAudioStoreProvider.overrideWithValue(_audio),
        identityRepositoryProvider.overrideWithValue(_identity),
        identityInitializationStoreProvider.overrideWithValue(
          _initializationStore,
        ),
        identityDeletedEffectProvider.overrideWithValue(() {
          _clones.clearIdentityAssets();
          return _identity.createCleanup();
        }),
      ],
      child: widget.errorControls
          ? const ShellErrorControls(child: PhoneAgentApp())
          : widget.sessionControls
          ? const ShellSessionControls(child: PhoneAgentApp())
          : const PhoneAgentApp(),
    );
  }
}

class _PreviewModelQuality implements CallModelQualityRepository {
  const _PreviewModelQuality();
  @override
  Future<Map<String, CallModelReading>> refresh() async => {
    'QWEN_OMNI_PLUS': CallModelReading.probe(available: true, latencyMs: 120),
    'DOUBAO': CallModelReading.probe(available: true, latencyMs: 260),
    'DOUBAO_SEEDUPLEX_3_0': CallModelReading.probe(
      available: true,
      latencyMs: 530,
    ),
  };
}

import '../core/diagnostics/translation_recording_diagnostics.dart';
import '../core/audio/pcm_capture.dart';
import '../core/audio/pcm_output.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../core/diagnostics/diagnostic_event.dart';
import '../core/diagnostics/diagnostic_translation_details.dart';
import 'dart:async';
import '../core/audio/audio_playback_focus.dart';
import '../core/network/account_api.dart';
import '../core/network/account_session.dart';
import '../features/settings/domain/network_availability.dart';
import '../features/settings/data/device_network_availability.dart';
import '../features/conversation/domain/tools/conversation_permission.dart';
import '../features/settings/domain/original_audio_settings.dart';
import '../features/translation/data/recording/domestic_recording_session.dart';
import '../features/translation/data/recording/private_domestic_recording_files.dart';
import '../features/translation/data/sip/api_domestic_points_repository.dart';
import '../features/translation/data/sip/api_sip_lease_repository.dart';
import '../features/translation/data/sip/api_translation_intro_audio.dart';
import '../features/translation/data/sip/device_sip_route.dart';
import '../features/translation/data/sip/doubao_translation_protocol.dart';
import '../features/translation/data/sip/focused_domestic_pcm_bridge.dart';
import '../features/translation/data/sip/io_domestic_model_socket.dart';
import '../features/translation/data/sip/qwen_translation_protocol.dart';
import '../features/translation/data/sip/udp_domestic_sip_connection.dart';
import '../features/translation/domain/recording/domestic_recording_encoder.dart';
import '../features/translation/domain/sip/domestic_sip_call_coordinator.dart';
import '../features/translation/domain/sip/domestic_points_repository.dart';
import '../features/translation/domain/sip/domestic_sip_media.dart';
import '../features/translation/domain/sip/domestic_translation_model.dart';
import '../features/translation/domain/sip/domestic_translation_processor.dart';
import '../features/translation/domain/sip/sip_lease.dart';
import '../features/translation/domain/sip/translation_call_plan.dart';
import '../features/translation/domain/translation_archive.dart';
import '../features/translation/domain/translation_call_finished.dart';
import '../features/translation/domain/translation_call_view.dart';
import '../features/translation/domain/translation_pcm_bridge.dart';
import '../features/translation/presentation/controller/domestic_translation_session_controller.dart';

/// Account-owned assembly. Safe configuration is required before admission.
class DomesticTranslationSessionFactory {
  DomesticTranslationSessionFactory({
    required this.accountId,
    required this.api,
    required this.isCurrent,
    required this.configurations,
    required this.permissions,
    required this.focus,
    required this.pcm,
    required this.files,
    required this.encoder,
    required this.readOriginalAudio,
    this.network = const DeviceNetworkAvailability(),
    this.onArchive,
    this.onFinished,
    this.onSettled,
  }) {
    if (files.accountId != accountId) {
      throw ArgumentError('Domestic recording account mismatch');
    }
  }
  final String accountId;
  final AccountApi api;
  final NetworkAvailabilitySource network;
  final bool Function() isCurrent;
  final DomesticModelConfigurationSource configurations;
  final ConversationPermissionSource permissions;
  final AudioPlaybackFocus focus;
  final TranslationPcmBridge Function() pcm;
  final PrivateDomesticRecordingFiles files;
  final DomesticRecordingEncoder encoder;
  final Future<OriginalAudioSettings> Function() readOriginalAudio;
  final void Function(TranslationArchiveEntry)? onArchive;
  final void Function(TranslationCallFinished)? onFinished;
  final void Function(DomesticPointsSession)? onSettled;
  final _cancelled = Completer<void>();
  DomesticTranslationSessionController? _controller;
  FocusedDomesticPcmBridge? _audio;
  bool _closed = false, _creating = false;
  bool get current => !_closed && isCurrent();
  void _guard() {
    if (!current) throw const SipLeaseFailure('DOMESTIC_CALL_CANCELLED');
  }

  Future<DomesticTranslationSessionController> create(
    TranslationCallPlan plan,
    TranslationCallContext context,
  ) async {
    _guard();
    if (_creating ||
        _controller != null ||
        !plan.usesSip ||
        accountId.isEmpty) {
      throw const SipLeaseFailure('DOMESTIC_PLAN_UNAVAILABLE');
    }
    _creating = true;
    FocusedDomesticPcmBridge? audio;
    DomesticSipCallCoordinator? coordinator;
    try {
      final config = await Future.any<DomesticModelConfiguration?>([
        configurations is SelectedDomesticModelConfigurationSource &&
                plan.modelId.isNotEmpty
            ? (configurations as SelectedDomesticModelConfigurationSource)
                  .loadSelectedFor(plan.locationCountry, plan.modelId)
            : configurations is ContextualDomesticModelConfigurationSource
            ? (configurations as ContextualDomesticModelConfigurationSource)
                  .loadFor(
                    plan.locationCountry,
                    plan.modelId.isEmpty ? plan.provider : plan.modelId,
                  )
            : configurations.load(plan.provider),
        _cancelled.future.then((_) => null),
      ]);
      _guard();
      if (config == null || config.provider != plan.provider) {
        throw const SipLeaseFailure('MODEL_CONFIGURATION_UNAVAILABLE');
      }
      if (config.sourceLanguages.isNotEmpty &&
              !config.sourceLanguages.contains(plan.callerLanguage) ||
          config.targetLanguages.isNotEmpty &&
              !config.targetLanguages.contains(plan.peerLanguage)) {
        throw const SipLeaseFailure('MODEL_LANGUAGE_UNAVAILABLE');
      }
      final callee = config.directory?.country(context.countryIso);
      if (config.directory != null &&
          (callee == null ||
              (!context.allowUnverifiedNumber &&
                  !callee.acceptsPhone(plan.networkNumber)))) {
        throw const SipLeaseFailure('TARGET_PHONE_UNAVAILABLE');
      }
      final original = await readOriginalAudio();
      _guard();
      final clock = Stopwatch()..start();
      void statistics(Map<String, int> stats) => emitDiagnostic(
        api.diagnostics,
        DiagnosticEvent(
          operation: DiagnosticOperation.translationCall,
          result: DiagnosticResult.received,
          elapsedMs: clock.elapsedMilliseconds,
          sessionId: context.clientCallId,
          translation: DiagnosticTranslationDetails(
            'audioStats',
            '',
            '',
            stats,
          ),
        ),
      );
      final ownedAudio = audio = _audio = FocusedDomesticPcmBridge(
        delegate: pcm(),
        onStatistics: statistics,
        permissions: permissions,
        focus: focus,
        isCurrent: () => current,
        onInterrupted: () async {
          await coordinator?.close();
        },
      );
      await ownedAudio.prepare();
      _guard();
      void diagnostic(String stage, String result, String code, Object? error) {
        emitDiagnostic(
          api.diagnostics,
          DiagnosticEvent(
            operation: DiagnosticOperation.translationCall,
            result: DiagnosticResult.values.byName(result),
            sessionId: context.clientCallId,
            elapsedMs: clock.elapsedMilliseconds,
            translation: DiagnosticTranslationDetails(
              stage,
              code,
              switch (error) {
                PlatformException() => error.code,
                PcmCaptureFailure() => error.code,
                PcmOutputFailure() => error.code,
                _ => '',
              },
            ),
            failureKind: error == null
                ? null
                : switch (error) {
                    PlatformException() => DiagnosticFailureKind.platform,
                    TimeoutException() => DiagnosticFailureKind.timeout,
                    FormatException() => DiagnosticFailureKind.format,
                    StateError() => DiagnosticFailureKind.state,
                    _ => DiagnosticFailureKind.other,
                  },
          ),
        );
      }

      int nowNanos() => clock.elapsedMicroseconds * 1000;
      final prepareBeforeConnected =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      int? connectedNanos;
      Future<DomesticRecordingSession?>? recording;
      final controller = DomesticTranslationSessionController(
        accountId: accountId,
        plan: plan,
        context: context,
        isCurrent: () => current,
        onArchive: onArchive,
        onFinished: onFinished,
        onReleased: () => unawaited(_release(ownedAudio)),
        recordingDiagnostics: TranslationRecordingDiagnostics(api.diagnostics),
        finalizeRecording: (duration) async {
          final session = await recording;
          if (session == null) return null;
          return session.finish(duration);
        },
        createCoordinator:
            ({
              required onPhase,
              required onTranscript,
              required onMediaStopped,
              required onEnvironment,
            }) => coordinator = DomesticSipCallCoordinator(
              plan: plan,
              callId: context.clientCallId,
              prepareMediaBeforeConnected: prepareBeforeConnected,
              configurations: _FrozenModelConfiguration(config),
              points: ApiDomesticPointsRepository(api),
              leases: ApiSipLeaseRepository(api),
              isCurrent: () => current,
              onPhase: (phase, error) {
                if (phase == TranslationPhase.connected) {
                  connectedNanos ??= nowNanos();
                }
                onPhase(phase, error);
              },
              onTranscript: onTranscript,
              onEnvironment: onEnvironment,
              network: network,
              onMediaStopped: onMediaStopped,
              onSettled: onSettled,
              onDiagnostic: diagnostic,
              createModels: (configuration, event, active) =>
                  DomesticTranslationProcessor(
                    local: _protocol(configuration, plan, 'local'),
                    remote: _protocol(configuration, plan, 'remote'),
                    connect: connectDomesticModelSocket,
                    isCurrent: active,
                    onEvent: event,
                    keepAlive: plan.provider == 'DOUBAO',
                  ),
              createConnection: (lease, plan, phase) async {
                final route = await const DeviceSipRouteResolver().resolve(
                  lease,
                );
                _guard();
                return UdpDomesticSipConnection.open(
                  lease: lease,
                  plan: plan,
                  localAddress: route.localAddress,
                  peerAddress: route.peerAddress,
                  callId: context.clientCallId,
                  onPhase: phase,
                );
              },
              createMedia: (rtp, endpoint, models, active, failure) async {
                Future<DomesticRecordingSession?> startRecording() =>
                    recording ??=
                        DomesticRecordingSession.start(
                          files: files,
                          clientCallId: context.clientCallId,
                          encoder: encoder,
                          nowNanos: nowNanos,
                          originNanos: connectedNanos,
                        ).then<DomesticRecordingSession?>(
                          (v) => v,
                          onError: (Object _) => null,
                        );
                final session = prepareBeforeConnected
                    ? null
                    : await startRecording();
                return DomesticSipMedia(
                  pcm: ownedAudio,
                  onDiagnostic: diagnostic,
                  onStatistics: statistics,
                  models: models,
                  rtp: rtp,
                  endpoint: endpoint,
                  isCurrent: active,
                  onFailure: failure,
                  ssrc: int.parse(
                    newDomesticModelToken().substring(0, 8),
                    radix: 16,
                  ),
                  introSource: ApiTranslationIntroAudio(
                    api,
                    directory: config.directory,
                  ),
                  callerLanguage: plan.callerLanguage,
                  peerLanguage: plan.peerLanguage,
                  introResponseBoundary: plan.provider == 'QWEN',
                  recordingTap: session?.tap,
                  createRecordingTap: prepareBeforeConnected
                      ? () async => (await startRecording())?.tap
                      : null,
                  originalAudioEnabled: original.enabled,
                  originalRatio: original.gain / 100,
                  originalVolume: original.volume / 100,
                  dynamicOriginalBoost: plan.provider == 'QWEN',
                  responseBoundarySupported: plan.provider == 'QWEN',
                );
              },
            ),
      );
      _controller = controller;
      await _admitNetwork();
      _guard();
      try {
        await coordinator!.prepare();
      } on ApiCodeFailure catch (error) {
        throw TranslationPlanFailure(
          error.code,
          error.code == 'POINTS_INSUFFICIENT_BALANCE'
              ? '积分不足，无法发起通话'
              : '积分服务暂不可用，请稍后重试',
        );
      } on SipLeaseFailure catch (error) {
        if (error.code == 'DOMESTIC_CALL_CANCELLED') rethrow;
        throw TranslationPlanFailure(
          error.code,
          error.code == 'POINTS_PREFLIGHT_REJECTED'
              ? '积分服务暂不可用，请稍后重试'
              : '通话未接通，请稍后重试',
        );
      } catch (_) {
        throw const TranslationPlanFailure(
          'POINTS_SERVICE_UNAVAILABLE',
          '积分服务暂不可用，请稍后重试',
        );
      }
      _guard();
      return controller;
    } catch (_) {
      await coordinator?.close();
      _controller?.dispose();
      _controller = null;
      await audio?.close();
      _audio = null;
      rethrow;
    } finally {
      _creating = false;
    }
  }

  Future<void> _admitNetwork() async {
    final clock = Stopwatch()..start();
    for (var attempt = 0; attempt < 40; attempt++) {
      _guard();
      final value = await Future.any<NetworkAvailability>([
        network.read().timeout(
          const Duration(seconds: 1),
          onTimeout: () => NetworkAvailability.unknown,
        ),
        _cancelled.future.then((_) => NetworkAvailability.unknown),
      ]);
      _guard();
      if (value == NetworkAvailability.available) return;
      if (value == NetworkAvailability.unavailable) {
        throw const TranslationPlanFailure('NETWORK_UNAVAILABLE', '当前无可用网络');
      }
      if (clock.elapsed >= const Duration(seconds: 10)) break;
      await Future.any<void>([
        Future<void>.delayed(const Duration(milliseconds: 250)),
        _cancelled.future,
      ]);
    }
    throw const TranslationPlanFailure(
      'NETWORK_VALIDATION_TIMEOUT',
      '网络可用性验证超时，请检查网络后重试',
    );
  }

  DomesticModelProtocol _protocol(
    DomesticModelConfiguration config,
    TranslationCallPlan plan,
    String leg,
  ) {
    final local = leg == 'local';
    final source = local ? plan.callerLanguage : plan.peerLanguage,
        target = local ? plan.peerLanguage : plan.callerLanguage;
    return config.provider == 'QWEN'
        ? QwenTranslationProtocol(
            configuration: config,
            leg: leg,
            sourceLanguage: source,
            targetLanguage: target,
          )
        : DoubaoTranslationProtocol(
            configuration: config,
            leg: leg,
            sourceLanguage: source,
            targetLanguage: target,
          );
  }

  Future<void> _release(FocusedDomesticPcmBridge audio) async {
    try {
      await audio.close();
      if (identical(_audio, audio)) {
        _audio = null;
        _controller = null;
      }
    } catch (_) {
      /* Retain admission on unconfirmed shutdown. */
    }
  }

  Future<void> close() async {
    _closed = true;
    if (!_cancelled.isCompleted) _cancelled.complete();
    await _controller?.coordinator.close();
    await _audio?.close();
  }
}

class _FrozenModelConfiguration implements DomesticModelConfigurationSource {
  const _FrozenModelConfiguration(this.value);
  final DomesticModelConfiguration value;
  @override
  Future<DomesticModelConfiguration?> load(String provider) async =>
      provider == value.provider ? value : null;
}

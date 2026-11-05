import '../translation_call_failure.dart';
import '../../../settings/domain/network_availability.dart';
import '../translation_call_environment.dart';
import 'domestic_translation_environment.dart';
import 'dart:async';
import '../translation_call_view.dart';
import 'domestic_points_owner.dart';
import 'domestic_points_repository.dart';
import 'domestic_sip_connection.dart';
import 'domestic_sip_media.dart';
import 'domestic_translation_model.dart';
import 'domestic_translation_processor.dart';
import 'sip_lease.dart';
import 'sip_lease_owner.dart';
import 'sip_transactions.dart';
import 'translation_call_plan.dart';

/// Domestic flow is independent of the overseas backend session and grants.
class DomesticSipCallCoordinator {
  DomesticSipCallCoordinator({
    required this.plan,
    required this.callId,
    required this.configurations,
    required DomesticPointsRepository points,
    required SipLeaseRepository leases,
    required this.createModels,
    required this.createConnection,
    required this.createMedia,
    required this.isCurrent,
    required this.onPhase,
    required this.onTranscript,
    void Function(TranslationCallEnvironment)? onEnvironment,
    NetworkAvailabilitySource network = const UnknownNetworkAvailability(),
    this.onSettled,
    this.onMediaStopped,
    this.onDiagnostic,
    this.prepareMediaBeforeConnected = false,
  }) {
    _environment = DomesticTranslationEnvironment(
      network: network,
      isCurrent: isCurrent,
      onChanged: onEnvironment,
    );
    billing = DomesticPointsOwner(
      repository: points,
      callId: callId,
      provider: plan.modelId.isEmpty ? plan.provider : plan.modelId,
      isCurrent: isCurrent,
      onStop: _fail,
    );
    leaseOwner = SipLeaseOwner(
      leases,
      SipLeaseRequest(route: plan.leaseRoute, callId: callId),
      isCurrent: () => !_closed && isCurrent(),
    );
  }
  final void Function(String stage, String result, String code, Object? error)?
  onDiagnostic;
  void trace(String stage, String result, [String code = '', Object? error]) {
    try {
      onDiagnostic?.call(stage, result, code, error);
    } catch (_) {
      /* isolated */
    }
  }

  final TranslationCallPlan plan;
  final String callId;
  final DomesticModelConfigurationSource configurations;
  final DomesticTranslationProcessorFactory createModels;
  final DomesticSipConnectionFactory createConnection;
  final DomesticSipMediaFactory createMedia;
  final bool prepareMediaBeforeConnected;
  final bool Function() isCurrent;
  final void Function(TranslationPhase, String) onPhase;
  final void Function(TranslationTranscript) onTranscript;
  final void Function(DomesticPointsSession)? onSettled;
  final void Function(int durationMillis)? onMediaStopped;
  late final DomesticTranslationEnvironment _environment;
  late final DomesticPointsOwner billing;
  late final SipLeaseOwner leaseOwner;
  DomesticTranslationProcessor? _models;
  DomesticSipConnection? _connection;
  DomesticSipMedia? _media;
  Future<void>? _prepareWork, _startWork, _closeWork, _connectedWork;
  DomesticModelConfiguration? _configuration;
  final _cancelled = Completer<void>();
  bool _closed = false, _connected = false;
  bool cleanupUnconfirmed = false;
  String _failure = '';
  bool _desiredMuted = false, _desiredSpeaker = true;
  int? _mediaStoppedDuration;
  bool get connected => _connected;
  bool get active => !_closed && isCurrent() && billing.mediaAuthorized;

  /// Admission only: no model socket, SIP lease, recording or call starts here.
  Future<void> prepare() => _prepareWork ??= _prepare();
  Future<void> _prepare() async {
    try {
      if (_closed ||
          !isCurrent() ||
          plan.transport == TranslationCallTransport.overseas) {
        throw const SipLeaseFailure('DOMESTIC_PLAN_UNAVAILABLE');
      }
      final config = await Future.any<DomesticModelConfiguration?>([
        configurations.load(plan.provider),
        _cancelled.future.then((_) => null),
      ]);
      if (_closed || !isCurrent()) {
        throw const SipLeaseFailure('DOMESTIC_CALL_CANCELLED');
      }
      if (config == null || config.provider != plan.provider) {
        throw const SipLeaseFailure('MODEL_CONFIGURATION_UNAVAILABLE');
      }
      // Missing model credentials must refuse before even allocating points/SIP.
      if (!await billing.prepare()) {
        throw const SipLeaseFailure('DOMESTIC_CALL_CANCELLED');
      }
      _configuration = config;
      _check();
    } catch (error) {
      if (error is SipLeaseFailure && error.code.startsWith('MODEL_')) {
        _environment.modelFailed();
      }
      trace(
        'terminal',
        'failed',
        error is SipLeaseFailure ? error.code : 'DOMESTIC_CALL_FAILED',
        error,
      );
      if (!_closed) {
        _failure = translationFailureCode(error);
      }
      await close();
      rethrow;
    }
  }

  Future<void> start() => _startWork ??= Future<void>.microtask(_start);
  Future<void> _start() async {
    try {
      if (_closed) return;
      _environment.start();
      onPhase(TranslationPhase.preflight, '');
      await prepare();
      _check();
      final config = _configuration!;
      final models = _models = createModels(config, _modelEvent, () => active);
      _environment.preparingModels();
      trace('models', 'started');
      await models.start();
      trace('models', 'succeeded');
      _environment.modelReady();
      _check();
      _environment.preparingSip();
      final lease = await leaseOwner.acquire();
      _check();
      if (lease == null) {
        throw const SipLeaseFailure('SIP_LEASE_UNAVAILABLE');
      }
      final connection = await createConnection(lease, plan, _sipPhase);
      if (!active) {
        await _dispose(connection.close);
        return;
      }
      _connection = connection;
      trace('sip', 'started');
      final endpoint = await connection.start();
      trace('sip', 'succeeded');
      _check();
      // Some adapters report connected only via their start result.
      _sipPhase(SipCallPhase.connected);
      if (prepareMediaBeforeConnected) {
        // Observe BYE/errors while iOS is preparing or waiting for billing.
        unawaited(_hold(connection));
      } else {
        await _connectedWork;
        trace('pointsConnected', active ? 'succeeded' : 'failed');
        _check();
      }
      final mediaWork = Future<DomesticSipMedia>.sync(
        () => createMedia(
          connection.media(endpoint),
          endpoint,
          models,
          () => active,
          _fail,
        ),
      );
      unawaited(
        mediaWork.then((media) async {
          if (_closed) await _dispose(media.close);
        }, onError: (Object _) {}),
      );
      final media = await Future.any<DomesticSipMedia?>([
        mediaWork,
        _cancelled.future.then((_) => null),
      ]);
      if (media == null) return;
      if (!active) {
        await _dispose(media.close);
        return;
      }
      _media = media;
      media.setMuted(_desiredMuted);
      await media.setSpeaker(_desiredSpeaker);
      trace('media', 'started');
      if (prepareMediaBeforeConnected) {
        await media.prepare();
        _check();
        _beginConnected();
        await _connectedWork;
        trace('pointsConnected', active ? 'succeeded' : 'failed');
        _check();
      }
      await media.start();
      trace('media', 'succeeded');
      await media.setSpeaker(_desiredSpeaker);
      _check();
      onPhase(TranslationPhase.translating, '');
      if (!prepareMediaBeforeConnected) unawaited(_hold(connection));
    } catch (error) {
      _environment.preparationFailed();
      trace(
        'terminal',
        'failed',
        error is SipLeaseFailure ? error.code : 'DOMESTIC_CALL_FAILED',
        error,
      );
      if (!_closed) {
        _failure = translationFailureCode(error);
      }
      await close();
    }
  }

  void _check() {
    if (!active) {
      throw const SipLeaseFailure('DOMESTIC_CALL_CANCELLED');
    }
  }

  void _sipPhase(SipCallPhase phase) {
    if (_closed) {
      return;
    }
    switch (phase) {
      case SipCallPhase.registering:
        onPhase(TranslationPhase.preflight, '');
      case SipCallPhase.dialing:
        _environment.sipReady();
        onPhase(TranslationPhase.dialing, '');
      case SipCallPhase.ringing:
        onPhase(TranslationPhase.ringing, '');
      case SipCallPhase.connected:
        _environment.sipReady();
        if (prepareMediaBeforeConnected) {
          trace('sip', 'received');
        } else {
          _beginConnected();
        }
      case SipCallPhase.ended:
        unawaited(close());
    }
  }

  void _beginConnected() {
    if (_connected) return;
    _connected = true;
    trace('pointsConnected', 'started');
    _connectedWork = billing.connected();
    onPhase(TranslationPhase.connected, '');
  }

  void _modelEvent(DomesticTranslationLeg direction, DomesticModelEvent event) {
    if (_closed) {
      if (isCurrent() && _connected && event is DomesticModelTranscript) {
        onTranscript(event.transcript);
      }
      return;
    }
    if (event is DomesticModelError) {
      _environment.modelFailed();
      _fail(event.code);
      return;
    }
    _media?.onModelEvent(direction, event);
    if (event is DomesticModelTranscript &&
        _connected &&
        (_media?.acceptsModelOutput ?? false)) {
      onTranscript(event.transcript);
    }
  }

  Future<void> _hold(DomesticSipConnection connection) async {
    try {
      await connection.holdUntilEnded();
    } catch (_) {
      if (!_closed) {
        _environment.sipFailed();
        _failure = 'SIP_CONNECTION_LOST';
      }
    }
    await close();
  }

  void setMuted(bool enabled) {
    _check();
    _desiredMuted = enabled;
    _media?.setMuted(enabled);
  }

  Future<void> setSpeaker(bool enabled) async {
    _check();
    _desiredSpeaker = enabled;
    await _media?.setSpeaker(enabled);
    _check();
  }

  Future<void> sendDtmf(String digit) async {
    _check();
    if (_media == null || _connection == null) {
      throw const SipLeaseFailure('MEDIA_NOT_CONNECTED');
    }
    await _media!.sendDtmf(digit, sendInfo: _connection!.sendInfo);
  }

  void _fail(String code) {
    if (_closed) {
      return;
    }
    trace('terminal', 'failed', code);
    _failure = code;
    unawaited(close());
  }

  Future<void> close() {
    if (_closeWork != null) {
      return _closeWork!;
    }
    _closed = true;
    unawaited(_environment.stop());
    _cancelled.complete();
    return _closeWork = _close();
  }

  Future<void> _close() async {
    trace('terminal', 'started', _failure);
    await Future.wait([
      _stopMedia(),
      _dispose(() async {
        await _connection?.close();
      }),
    ]);
    await _dispose(leaseOwner.close);
    try {
      final settled = await billing.finish(
        _failure.isEmpty ? 'ENDED' : _failure,
        mediaStoppedDurationMs: _mediaStoppedDuration,
      );
      if (settled != null && isCurrent()) {
        onSettled?.call(settled);
      }
    } catch (_) {
      cleanupUnconfirmed = true;
    }
    cleanupUnconfirmed =
        cleanupUnconfirmed ||
        leaseOwner.cleanupUnconfirmed ||
        (_models?.cleanupUnconfirmed ?? false) ||
        (_media?.cleanupUnconfirmed ?? false);
    trace(
      'terminal',
      cleanupUnconfirmed ? 'failed' : 'succeeded',
      cleanupUnconfirmed ? 'CALL_CLEANUP_UNCONFIRMED' : _failure,
    );
    try {
      onPhase(
        _failure.isEmpty && !cleanupUnconfirmed
            ? TranslationPhase.ended
            : TranslationPhase.failed,
        _failure.isNotEmpty
            ? _failure
            : billing.settlementUnconfirmed
            ? 'POINTS_SETTLEMENT_UNCONFIRMED'
            : cleanupUnconfirmed
            ? 'CALL_CLEANUP_UNCONFIRMED'
            : '',
      );
    } catch (_) {
      /* Disposal is complete even if presentation is gone. */
    }
  }

  Future<void> _stopMedia() async {
    await Future.wait([
      _dispose(() async {
        await _media?.close();
      }),
      _dispose(() async {
        await _models?.close();
      }),
    ]);
    _mediaStoppedDuration = billing.durationMs;
    if (_connected) {
      try {
        onMediaStopped?.call(_mediaStoppedDuration!);
      } catch (_) {
        /* Recording cannot block SIP cleanup or points settlement. */
      }
    }
  }

  Future<void> _dispose(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      cleanupUnconfirmed = true;
    }
  }
}

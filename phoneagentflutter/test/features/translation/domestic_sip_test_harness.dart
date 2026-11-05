import 'package:phone_agent/features/translation/domain/translation_call_environment.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:phone_agent/features/translation/domain/sip/domestic_model_socket.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_points_repository.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_sip_call_coordinator.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_sip_connection.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_sip_media.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_model.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_processor.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_transactions.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';

const _endpoint = SipAudioEndpoint(
  '127.0.0.1',
  9000,
  8,
  SipAudioCodec.pcma,
  101,
);
const syntheticDomesticLease = SipLease(
  id: 'synthetic-lease',
  accountId: 'synthetic-account',
  server: 'example.test',
  port: 5060,
  transport: 'UDP',
  username: 'synthetic',
  password: 'synthetic',
  callerNumber: 'synthetic',
);
DomesticPointsSession _points(String state) => DomesticPointsSession(
  id: 'synthetic-billing',
  state: state,
  authorizedThroughMs: 60000,
  authorizationVersion: 1,
  connectedDurationMs: 0,
  chargedPoints: 0,
  availableBalance: 600,
  heldBalance: 150,
  stopState: 'NONE',
  pricing: const DomesticPointsPricing(
    provider: 'QWEN',
    modelId: 'QWEN',
    firstMinutePoints: 150,
    blockDurationMs: 6000,
    blockPoints: 15,
    priceVersion: 'synthetic',
  ),
);

class DomesticSipTestHarness {
  DomesticSipTestHarness({
    void Function(DomesticPointsSession)? onSettled,
    bool prepareMediaBeforeConnected = false,
  }) {
    source = DomesticSipTestSource(trace);
    points = DomesticSipTestPoints(trace);
    leases = DomesticSipTestLeases(trace);
    media = DomesticSipTestMedia(trace);
    connection = DomesticSipTestConnection(trace);
    coordinator = DomesticSipCallCoordinator(
      plan: TranslationCallPlan.resolve(
        location: TrustedTranslationLocation('CN', 1),
        rawNumber: '13800138000',
        targetCountry: 'CN',
        preferences: const TranslationPreferences(),
        domestic: internalDefaultSipPreferences,
      ),
      callId: 'synthetic-call',
      configurations: source,
      points: points,
      leases: leases,
      createModels: (config, event, current) => DomesticTranslationProcessor(
        local: _Protocol(),
        remote: _Protocol(),
        connect: (_, _) async => _Socket(trace),
        isCurrent: current,
        onEvent: event,
      ),
      createConnection: (lease, _, phase) async {
        connectionLease = lease;
        trace.add('sip.open');
        connection.phase = phase;
        return connection;
      },
      createMedia: (_, _, _, _, _) => pendingMedia?.future ?? media,
      onDiagnostic: (stage, result, code, error) {
        diagnostics.add('$stage:$result:$code');
        throw StateError('diagnostic sink failure');
      },
      onMediaStopped: (duration) => stoppedDurations.add(duration),
      isCurrent: () => current,
      onPhase: (phase, error) {
        phases.add(phase);
        errors.add(error);
      },
      onSettled: onSettled,
      prepareMediaBeforeConnected: prepareMediaBeforeConnected,
      onTranscript: (_) {},
      onEnvironment: environments.add,
    );
  }
  Completer<DomesticSipMedia>? pendingMedia;
  bool current = true;
  final diagnostics = <String>[];
  final stoppedDurations = <int>[];
  final trace = <String>[], errors = <String>[];
  final phases = <TranslationPhase>[];
  final environments = <TranslationCallEnvironment>[];
  late final DomesticSipTestSource source;
  late final DomesticSipTestPoints points;
  late final DomesticSipTestLeases leases;
  SipLease? connectionLease;
  late final DomesticSipTestMedia media;
  late final DomesticSipTestConnection connection;
  late final DomesticSipCallCoordinator coordinator;
}

class DomesticSipTestSource implements DomesticModelConfigurationSource {
  DomesticSipTestSource(this.trace);
  final List<String> trace;
  bool available = true;
  Completer<DomesticModelConfiguration?>? pending;
  final config = DomesticModelConfiguration(
    provider: 'QWEN',
    uri: Uri.parse('wss://example.test'),
    headers: {'Authorization': 'synthetic'},
    model: 'synthetic',
  );
  @override
  Future<DomesticModelConfiguration?> load(String provider) async {
    trace.add('config');
    return pending != null
        ? pending!.future
        : available
        ? config
        : null;
  }
}

class DomesticSipTestPoints implements DomesticPointsRepository {
  DomesticSipTestPoints(this.trace);
  final List<String> trace;
  bool failTerminal = false, unconfirmedTerminal = false;
  bool failConnected = false;
  final events = <DomesticPointsEvent>[];
  @override
  Future<DomesticPointsSession> create(String callId, String provider) async {
    trace.add('points.create');
    return _points('PREPARED');
  }

  @override
  Future<DomesticPointsSession> update(
    String id,
    DomesticPointsAction action,
    DomesticPointsEvent event,
  ) async {
    trace.add('points.${action.name}');
    events.add(event);
    if (action == DomesticPointsAction.connected && failConnected) {
      throw StateError('synthetic connected failure');
    }
    if (action == DomesticPointsAction.terminal) {
      if (failTerminal) {
        throw StateError('synthetic');
      }
      if (unconfirmedTerminal) return _points('PREPARED');
      return _points(event.connected! ? 'SETTLED' : 'RELEASED');
    }
    return _points('PREPARED');
  }
}

class DomesticSipTestLeases implements SipLeaseRepository {
  DomesticSipTestLeases(this.trace);
  final List<String> trace;
  Completer<SipLease>? pending;
  bool failRelease = false;
  @override
  Future<SipLease> acquire(SipLeaseRequest request) async {
    trace.add('lease.acquire');
    return pending == null ? syntheticDomesticLease : pending!.future;
  }

  @override
  Future<void> release(String leaseId, String callId) async {
    trace.add('lease.release');
    if (failRelease) throw StateError('synthetic release failure');
  }
}

class DomesticSipTestConnection implements DomesticSipConnection {
  DomesticSipTestConnection(this.trace);
  bool failStart = false;

  String failureCode = 'SIP_START_FAILED';
  final List<String> trace;
  final ended = Completer<void>();
  void Function(SipCallPhase)? phase;
  @override
  Future<SipAudioEndpoint> start() async {
    trace.add('sip.start');
    if (failStart) throw SipLeaseFailure(failureCode);
    phase?.call(SipCallPhase.dialing);
    phase?.call(SipCallPhase.connected);
    return _endpoint;
  }

  @override
  Future<void> holdUntilEnded() => ended.future;
  @override
  Future<void> sendInfo(String digit) async {}
  @override
  SipRtpTransport media(SipAudioEndpoint endpoint) => _Rtp();
  @override
  Future<void> close() async {
    trace.add('sip.close');
    if (!ended.isCompleted) {
      ended.complete();
    }
  }
}

class _Rtp implements SipRtpTransport {
  @override
  Stream<SipRtpPacket> get packets => const Stream.empty();
  @override
  void send(SipRtpPacket packet) {}
  @override
  Future<void> close() async {}
}

class DomesticSipTestMedia implements DomesticSipMedia {
  DomesticSipTestMedia(this.trace);
  final List<String> trace;
  bool muted = false, speaker = false, closed = false;
  bool failStart = false;
  bool failPrepare = false;
  Completer<void>? pendingPrepare;
  @override
  Future<void> prepare() async {
    trace.add('media.prepare');
    await pendingPrepare?.future;
    if (failPrepare) throw const SipLeaseFailure('MEDIA_PREPARE_FAILED');
  }

  bool? speakerAtStart;
  final digits = <String>[];
  @override
  bool get cleanupUnconfirmed => false;
  @override
  Future<void> start() async {
    speakerAtStart = speaker;
    trace.add('media.start');
    if (failStart) throw const SipLeaseFailure('MEDIA_PREPARE_FAILED');
  }

  @override
  void setMuted(bool enabled) {
    muted = enabled;
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    speaker = enabled;
  }

  @override
  Future<void> sendDtmf(
    String digit, {
    required Future<void> Function(String) sendInfo,
  }) async {
    digits.add(digit);
  }

  @override
  Future<void> close() async {
    closed = true;
    trace.add('media.close');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Protocol implements DomesticModelProtocol {
  @override
  Uri get uri => Uri.parse('wss://example.test');
  @override
  Map<String, String> get headers => {'Authorization': 'synthetic'};
  @override
  Object start() => 'start';
  @override
  Object finish() => 'finish';
  @override
  Object audio(Uint8List pcm16k) => pcm16k;
  @override
  List<DomesticModelEvent> decode(Object message) => [
    const DomesticModelReady(),
  ];
}

class _Socket implements DomesticModelSocket {
  _Socket(this.trace);
  final List<String> trace;
  final messagesController = StreamController<Object>();
  @override
  Stream<Object> get messages => messagesController.stream;
  @override
  void send(Object event) {
    if (event == 'start') {
      trace.add('model.start');
      messagesController.add('ready');
    }
  }

  @override
  Future<void> close() async {
    unawaited(messagesController.close());
  }
}

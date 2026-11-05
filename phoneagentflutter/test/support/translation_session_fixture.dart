import 'dart:async';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_media_port.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';
import 'package:phone_agent/features/translation/domain/translation_session_coordinator.dart';

const translationRequest = TranslationCreateRequest(
  phone: '+12025550101',
  userLanguage: 'zh',
  merchantLanguage: 'en',
  provider: 'GEMINI',
  userId: 'synthetic',
);
const translationTicket = TranslationBackendSession(
  id: 'session',
  clusterId: 'US',
  recordingAccessGrant: 'synthetic-grant',
  mediaTransport: 'livekit',
  appAudioWsUrl: 'wss://example.test/audio',
  liveKit: TranslationLiveKitConnection(
    url: 'wss://example.test/room',
    token: 'synthetic',
  ),
);

class SessionBackend implements TranslationBackendRepository {
  final List<String> events;
  SessionBackend(this.events);
  Completer<TranslationBackendSession>? createGate;
  TranslationBackendFailure? createFailure;
  Completer<TranslationMerchantResult>? merchantGate;
  final failures = <TranslationBackendFailure>[];
  bool hangupFails = false, started = true;
  TranslationCreateRequest? received;
  @override
  Future<TranslationBackendSession> create(
    TranslationCreateRequest request,
  ) async {
    events.add('create');
    received = request;
    if (createFailure != null) throw createFailure!;
    return createGate == null ? translationTicket : createGate!.future;
  }

  @override
  Future<TranslationMerchantResult> startMerchant(
    TranslationBackendSession session,
    TranslationCreateRequest request,
  ) async {
    events.add('merchant');
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return merchantGate == null
        ? TranslationMerchantResult(started)
        : merchantGate!.future;
  }

  @override
  Future<void> hangup(TranslationBackendSession session, String userId) async {
    events.add('hangup');
    if (hangupFails) throw const TranslationBackendFailure('NETWORK');
  }
}

class SessionMedia implements TranslationMediaPort {
  SessionMedia(this.name, this.events);
  final String name;
  final List<String> events;
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<void> connect(TranslationBackendSession session) async {
    events.add('connect:$name');
    if (fail) throw StateError('synthetic');
    await gate?.future;
  }

  @override
  Future<void> close() async {
    events.add('close:$name');
  }
}

class SessionFixture {
  final events = <String>[];
  final stages = <TranslationSessionStage>[];
  final errors = <String>[];
  Duration readyTimeout = const Duration(seconds: 10);
  void Function(TranslationSessionStage)? onStage;
  late final backend = SessionBackend(events);
  late final live = SessionMedia('live', events);
  late final ws = SessionMedia('ws', events);
  Completer<TranslationServiceCatalog>? catalogGate;
  TranslationServiceCatalog catalog = const TranslationServiceCatalog([
    TranslationServiceLanguage('zh-CN', 'Chinese'),
    TranslationServiceLanguage('en-US', 'English'),
  ]);
  late final coordinator = TranslationSessionCoordinator(
    backend: backend,
    readyTimeout: readyTimeout,
    loadLanguages: () async {
      events.add('languages');
      return catalogGate == null ? catalog : catalogGate!.future;
    },
    mediaFactory: (kind) =>
        kind == TranslationMediaTransport.liveKit ? live : ws,
    onStage: (stage, error) {
      stages.add(stage);
      errors.add(error);
      onStage?.call(stage);
    },
    wait: (_) async {
      events.add('wait');
    },
  );
}

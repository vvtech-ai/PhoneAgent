import 'dart:async';
import 'dart:convert';
import '../domain/translation_backend_session.dart';
import '../domain/translation_media_port.dart';
import '../domain/translation_realtime_event.dart';
import '../domain/translation_service_catalog.dart';
import 'translation_realtime_codec.dart';

/// Memory-only external ports. No Dio, device access, account, or persistence.
class PreviewTranslationSession implements TranslationBackendRepository {
  PreviewTranslationSession({this.scenario = 'normal'}) {
    live = PreviewTranslationMedia(this, TranslationMediaTransport.liveKit);
    ws = PreviewTranslationMedia(this, TranslationMediaTransport.websocket);
  }
  final String scenario;
  final trace = <String>[];
  late final PreviewTranslationMedia live, ws;
  PreviewTranslationMedia? active;
  int creates = 0, merchants = 0, hangups = 0, segments = 0;
  TranslationCreateRequest? lastCreate;
  static const request = TranslationCreateRequest(
    phone: '+12025550101',
    userLanguage: 'zh',
    merchantLanguage: 'en',
    provider: 'GEMINI',
    userId: 'synthetic',
  );
  static const ticket = TranslationBackendSession(
    id: 'mock-session',
    clusterId: 'US',
    recordingAccessGrant: 'synthetic',
    mediaTransport: 'livekit',
    appAudioWsUrl: 'wss://example.invalid/audio',
    liveKit: TranslationLiveKitConnection(
      url: 'wss://example.invalid/room',
      token: 'synthetic',
    ),
  );
  Future<TranslationServiceCatalog> languages() async {
    trace.add('languages');
    return const TranslationServiceCatalog([
      TranslationServiceLanguage('zh-CN', '中文'),
      TranslationServiceLanguage('en-US', 'English'),
      TranslationServiceLanguage('ja-JP', '日本語'),
      TranslationServiceLanguage('ko', '한국어'),
      TranslationServiceLanguage('fr', 'Français'),
      TranslationServiceLanguage('de', 'Deutsch'),
      TranslationServiceLanguage('es', 'Español'),
    ]);
  }

  TranslationMediaPort media(TranslationMediaTransport transport) =>
      transport == TranslationMediaTransport.liveKit ? live : ws;
  @override
  Future<TranslationBackendSession> create(
    TranslationCreateRequest request,
  ) async {
    creates++;
    lastCreate = request;
    trace.add('create');
    if (scenario == 'create-failure') {
      throw const TranslationBackendFailure('SYNTHETIC');
    }
    return ticket;
  }

  @override
  Future<TranslationMerchantResult> startMerchant(
    TranslationBackendSession session,
    TranslationCreateRequest request,
  ) async {
    merchants++;
    trace.add('merchant-call');
    return const TranslationMerchantResult(true);
  }

  @override
  Future<void> hangup(TranslationBackendSession session, String userId) async {
    hangups++;
    trace.add('hangup');
    if (scenario == 'hangup-failure') {
      throw const TranslationBackendFailure('SYNTHETIC');
    }
  }

  void ready() => active?.wire({
    'event': active == live ? 'realtime_ready' : 'app_audio_ready',
  });
  void connected() => active?.wire({'event': 'call_connected'});
  void ended() => active?.wire({'event': 'call_ended', 'reason': 'synthetic'});
  void disconnect() => active?.disconnect();
  void transcript() {
    final id = 'segment-${++segments}';
    for (final leg in ['user', 'merchant']) {
      active?.wire({
        'event': 'transcript_delta',
        'segmentId': id,
        'sourceLeg': leg,
        'kind': 'input',
        'text': leg == 'user' ? '这是一条合成对话。' : 'I understand.',
        'isFinal': true,
      });
      active?.wire({
        'event': 'transcript_delta',
        'segmentId': id,
        'sourceLeg': leg,
        'kind': 'output',
        'text': leg == 'user' ? 'This is a synthetic message.' : '我明白了。',
        'isFinal': true,
      });
    }
  }
}

class PreviewTranslationMedia implements TranslationInteractiveMediaPort {
  PreviewTranslationMedia(this.owner, this.transport);
  final PreviewTranslationSession owner;
  final TranslationMediaTransport transport;
  // Single session owner, including a zone-local asynchronous cancellation.
  // Avoid the broadcast controller's globally cached completed cancel Future
  // escaping Flutter's fake clock in deterministic preview/widget tests.
  final _events = StreamController<TranslationRealtimeMessage>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  final _ready = Completer<void>();
  bool closed = false;
  String get name => transport.name;
  @override
  Stream<TranslationRealtimeMessage> get events => _events.stream;
  @override
  bool get supportsDtmf => transport == TranslationMediaTransport.liveKit;
  @override
  Future<void> connect(TranslationBackendSession session) async {
    owner.active = this;
    owner.trace.add('connect:$name');
    if (owner.scenario == 'fallback' && supportsDtmf) {
      throw StateError('Synthetic connect failure');
    }
    await _ready.future;
  }

  void wire(Map<String, Object?> value) {
    if (closed) return;
    final message = TranslationRealtimeCodec.text(
      jsonEncode({
        'callSessionId': PreviewTranslationSession.ticket.id,
        ...value,
      }),
    );
    final event = message.event;
    if (event is TranslationReady &&
        !_ready.isCompleted &&
        event.kind ==
            (supportsDtmf
                ? TranslationReadyKind.realtime
                : TranslationReadyKind.appAudio)) {
      owner.trace.add('ready:$name');
      _ready.complete();
    }
    _events.add(message);
  }

  void disconnect() {
    if (!closed) _events.addError(StateError('Synthetic disconnect'));
  }

  @override
  Future<void> close() {
    if (closed) return Future<void>.microtask(() {});
    closed = true;
    owner.trace.add('close:$name');
    // Release a pending connect without triggering a late merchant-call.
    if (!_ready.isCompleted) _ready.complete();
    // No external resource to await. close synchronously seals the memory sink;
    // its already-cancelled done Future may belong to another test clock zone.
    unawaited(_events.close());
    return Future<void>.microtask(() {});
  }

  void _control(String value) {
    if (closed || owner.scenario == 'control-failure') {
      throw StateError('Synthetic control failure');
    }
    owner.trace.add(value);
  }

  @override
  Future<void> setMuted(bool muted) async => _control('mute:$muted');
  @override
  Future<void> setSpeaker(bool enabled) async => _control('speaker:$enabled');
  @override
  Future<void> sendDtmf(String digit) async {
    if (!supportsDtmf) throw UnsupportedError('DTMF');
    TranslationRealtimeCodec.dtmf(
      PreviewTranslationSession.ticket.id,
      digit,
      1,
    );
    _control('dtmf:$digit');
  }
}

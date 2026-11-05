import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/audio/audio_playback_focus.dart';
import '../../conversation/domain/tools/conversation_permission.dart';
import '../domain/translation_backend_session.dart';
import '../domain/translation_livekit_room.dart';
import '../domain/translation_media_port.dart';
import '../domain/translation_service_catalog.dart';
import 'livekit_translation_media.dart';
import 'app_audio_translation_media.dart';
import 'preview_app_audio_ports.dart';
import 'preview_translation_session.dart';
import 'translation_realtime_codec.dart';

/// Synthetic backend/room only: production adapter/coordinator own all states.
class PreviewLiveKitTranslation
    implements TranslationBackendRepository, ConversationPermissionSource {
  PreviewLiveKitTranslation({this.appAudio = false}) {
    room = PreviewTranslationRoom(trace, failConnect: appAudio);
    media = LiveKitTranslationMedia(
      roomFactory: () => room,
      permissions: this,
      focus: focus,
      isCurrent: () => alive,
    );
  }
  final trace = <String>[];
  final focus = AudioPlaybackFocus();
  final bool appAudio;
  final socket = PreviewAppAudioSocket();
  final pcm = PreviewTranslationPcm();
  late final PreviewTranslationRoom room;
  late final LiveKitTranslationMedia media;
  bool alive = true;
  int merchants = 0, hangups = 0;
  TranslationMediaPort factory(TranslationMediaTransport transport) {
    if (transport != TranslationMediaTransport.liveKit) {
      if (!appAudio) throw StateError('Synthetic fallback omitted');
      trace.add('AppAudio fallback');
      return AppAudioTranslationMedia(
        connector: (_) async => socket,
        audio: pcm,
        permissions: this,
        focus: focus,
        isCurrent: () => alive,
      );
    }
    return media;
  }

  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async => PermissionGrant.granted;
  Future<TranslationServiceCatalog> languages() async =>
      const TranslationServiceCatalog([
        TranslationServiceLanguage('zh-CN', '中文'),
        TranslationServiceLanguage('en-US', 'English'),
      ]);
  @override
  Future<TranslationBackendSession> create(
    TranslationCreateRequest request,
  ) async {
    trace.add('create');
    return PreviewTranslationSession.ticket;
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
  }

  void wire(Map<String, Object?> value) {
    if (appAudio) {
      socket.wire(value['event']! as String, extra: value);
    } else {
      room.wire(value);
    }
  }

  void subtitle() {
    wire({
      'event': 'transcript_delta',
      'segmentId': 'mock-segment',
      'sourceLeg': 'merchant',
      'kind': 'input',
      'text': 'Hello, how can I help?',
      'isFinal': true,
    });
    wire({
      'event': 'transcript_delta',
      'segmentId': 'mock-segment',
      'sourceLeg': 'merchant',
      'kind': 'output',
      'text': '你好，有什么可以帮助你？',
      'isFinal': true,
    });
  }
}

class PreviewTranslationRoom implements TranslationLiveKitRoom {
  PreviewTranslationRoom(this.trace, {this.failConnect = false});
  final List<String> trace;
  final bool failConnect;
  final _gate = Completer<void>();
  final _events = StreamController<TranslationRoomEvent>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  bool closed = false;
  @override
  Stream<TranslationRoomEvent> get events => _events.stream;
  void roomReady() {
    if (!_gate.isCompleted) _gate.complete();
  }

  void wire(Map<String, Object?> value) {
    if (!closed) {
      _events.add(
        TranslationRoomData(
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'callSessionId': PreviewTranslationSession.ticket.id,
                ...value,
              }),
            ),
          ),
          TranslationRealtimeCodec.controlTopic,
        ),
      );
    }
  }

  @override
  Future<void> connect(String url, String token) async {
    trace.add('room.connect');
    if (failConnect) throw StateError('Synthetic room unavailable');
    await _gate.future;
  }

  @override
  Future<void> microphone(bool enabled) async {
    trace.add('microphone:$enabled');
  }

  @override
  Future<void> speaker(bool enabled) async {
    trace.add('speaker:$enabled');
  }

  @override
  Future<void> publish(Uint8List bytes, String topic) async {
    final value = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    trace.add(value['event'] as String);
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    roomReady();
    trace.add('room.close');
    unawaited(_events.close());
  }
}

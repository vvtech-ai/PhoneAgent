import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'dart:async';
import 'dart:convert';
import 'package:phone_agent/features/translation/data/translation_realtime_codec.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_media_port.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';
import 'translation_session_fixture.dart';

class InteractiveSessionFixture {
  InteractiveSessionFixture({this.onDtmfInput, this.onArchive});
  final void Function(TranslationArchiveEntry)? onArchive;
  final void Function()? onDtmfInput;
  final trace = <String>[];
  late final backend = SessionBackend(trace);
  late final live = InteractiveMedia(trace, 'live', true);
  late final ws = InteractiveMedia(trace, 'ws', false);
  DateTime now = DateTime(2026);
  late final controller = TranslationSessionController(
    backend: backend,
    mediaFactory: (kind) =>
        kind == TranslationMediaTransport.liveKit ? live : ws,
    loadLanguages: () async => const TranslationServiceCatalog([
      TranslationServiceLanguage('zh-CN', 'Chinese'),
      TranslationServiceLanguage('en-US', 'English'),
    ]),
    request: translationRequest,
    now: () => now,
    onDtmfInput: onDtmfInput,
    onArchive: onArchive,
  );
  Future<void> close() async {
    controller.dispose();
    await controller.coordinator.stop();
    await live.stream.close();
    await ws.stream.close();
  }
}

class InteractiveMedia implements TranslationInteractiveMediaPort {
  InteractiveMedia(this.trace, this.name, this.supportsDtmf);
  final List<String> trace;
  final String name;
  @override
  final bool supportsDtmf;
  final stream = StreamController<TranslationRealtimeMessage>.broadcast(
    sync: true,
  );
  Completer<void>? connectGate, controlGate;
  bool failConnect = false, failControl = false;
  bool releaseConnectOnClose = true;
  @override
  Stream<TranslationRealtimeMessage> get events => stream.stream;
  void wire(
    String name, {
    String id = 'session',
    Map<String, Object?> fields = const {},
  }) => stream.add(
    TranslationRealtimeCodec.text(
      jsonEncode({'event': name, 'callSessionId': id, ...fields}),
    ),
  );
  @override
  Future<void> connect(TranslationBackendSession session) async {
    trace.add('connect:$name');
    if (failConnect) throw StateError('synthetic');
    await connectGate?.future;
  }

  @override
  Future<void> close() async {
    trace.add('close:$name');
    if (releaseConnectOnClose &&
        connectGate != null &&
        !connectGate!.isCompleted) {
      connectGate!.complete();
    }
    // Intentionally allow late events: the shared owner must unsubscribe.
  }

  Future<void> _command(String command) async {
    trace.add(command);
    await controlGate?.future;
    if (failControl) throw StateError('synthetic');
  }

  @override
  Future<void> setMuted(bool value) => _command('mute:$value');
  @override
  Future<void> setSpeaker(bool value) => _command('speaker:$value');
  @override
  Future<void> sendDtmf(String value) => _command('dtmf:$value');
}

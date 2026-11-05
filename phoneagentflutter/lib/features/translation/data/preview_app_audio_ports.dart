import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../conversation/data/voice/voice_socket.dart';
import '../domain/translation_pcm_bridge.dart';
import '../domain/translation_realtime_event.dart';

/// Isolated external wire/hardware only. No real network, recording or files.
class PreviewAppAudioSocket implements VoiceSocket {
  final controller = StreamController<Object>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  final sent = <Map<String, dynamic>>[];
  bool closed = false;
  @override
  Stream<Object> get messages => controller.stream;
  void wire(
    String event, {
    String id = 'mock-session',
    Map<String, Object?> extra = const {},
  }) {
    if (!closed) {
      controller.add(
        jsonEncode({'event': event, 'callSessionId': id, ...extra}),
      );
    }
  }

  void downlink({int sequence = 1, int rate = 24000}) => wire(
    'translated_audio',
    extra: {
      'audioFormat': 'pcm16',
      'sampleRate': rate,
      'sequence': sequence,
      'payload': base64Encode(Uint8List(480)),
    },
  );
  @override
  void send(Object value) {
    if (closed) throw StateError('Synthetic socket closed');
    sent.add(jsonDecode(value as String) as Map<String, dynamic>);
  }

  @override
  Future<void> close() async {
    closed = true;
    unawaited(controller.close());
  }
}

class PreviewTranslationPcm extends ChangeNotifier
    implements TranslationPcmBridge {
  final _queue = Queue<Uint8List>();
  Completer<Uint8List?>? _read;
  final played = <TranslationAudio>[];
  Completer<void>? startGate, playGate;
  bool started = false, closed = false, speaker = false;
  bool failClose = false, failPlay = false;
  int starts = 0, reads = 0, closes = 0;
  void pcm() {
    final bytes = Uint8List.fromList(List.filled(640, 1));
    if (!started || closed) return;
    final read = _read;
    _read = null;
    if (read == null) {
      _queue.add(bytes);
    } else {
      read.complete(bytes);
    }
  }

  @override
  Future<void> start() async {
    starts++;
    await startGate?.future;
    if (closed) throw StateError('Synthetic PCM closed');
    started = true;
    notifyListeners();
  }

  @override
  Future<Uint8List?> read() {
    reads++;
    if (closed) return Future.value();
    if (_queue.isNotEmpty) return Future.value(_queue.removeFirst());
    return (_read = Completer<Uint8List?>()).future;
  }

  @override
  Future<void> play(TranslationAudio audio) async {
    if (failPlay || closed) throw StateError('Synthetic playback failed');
    played.add(audio);
    notifyListeners();
    await playGate?.future;
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    if (closed) throw StateError('Synthetic PCM closed');
    speaker = enabled;
  }

  @override
  Future<void> close() async {
    closes++;
    closed = true;
    _read?.complete();
    _read = null;
    _queue.clear();
    if (failClose) throw StateError('Synthetic release failed');
  }
}

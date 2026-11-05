import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:phone_agent/features/translation/domain/translation_livekit_room.dart';
import 'package:phone_agent/features/translation/data/translation_realtime_codec.dart';

class TranslationLiveKitRoomFake implements TranslationLiveKitRoom {
  final controller = StreamController<TranslationRoomEvent>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  final operations = <String>[];
  final published = <Map<String, dynamic>>[];
  Completer<void>? connectGate, microphoneGate, closeGate;
  bool failClose = false, failControl = false;
  void Function()? onPublish;
  int closes = 0;
  void wire(
    Map<String, Object?> json, {
    String? topic = TranslationRealtimeCodec.controlTopic,
  }) {
    controller.add(
      TranslationRoomData(
        Uint8List.fromList(utf8.encode(jsonEncode(json))),
        topic,
      ),
    );
  }

  @override
  Stream<TranslationRoomEvent> get events => controller.stream;
  @override
  Future<void> connect(String url, String token) async {
    operations.add('connect');
    if (connectGate != null) await connectGate!.future;
  }

  @override
  Future<void> microphone(bool enabled) async {
    operations.add('microphone:$enabled');
    if (microphoneGate != null) await microphoneGate!.future;
    if (failControl) throw StateError('synthetic');
  }

  @override
  Future<void> speaker(bool enabled) async {
    operations.add('speaker:$enabled');
    if (failControl) throw StateError('synthetic');
  }

  @override
  Future<void> publish(Uint8List bytes, String topic) async {
    operations.add('publish:$topic');
    published.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    onPublish?.call();
    if (failControl) throw StateError('synthetic');
  }

  @override
  Future<void> close() async {
    closes++;
    operations.add('close');
    if (closeGate != null) await closeGate!.future;
    if (failClose) throw StateError('synthetic close failure');
  }
}

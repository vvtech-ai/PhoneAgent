import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_model_socket.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_model.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_processor.dart';

void main() {
  test('both confirmations gate audio and close is idempotent', () async {
    final sockets = [_Socket(), _Socket()];
    var index = 0;
    final processor = _processor((_, _) async => sockets[index++]);
    final start = processor.start();
    await Future<void>.delayed(Duration.zero);
    processor.sendAudio(DomesticTranslationLeg.local, Uint8List(640));
    expect(sockets[0].sent, ['start']);
    sockets[0].events.add('ready');
    await Future<void>.delayed(Duration.zero);
    expect(processor.ready, false);
    sockets[1].events.add('ready');
    await start;
    expect(processor.ready, true);
    processor.sendAudio(DomesticTranslationLeg.local, Uint8List(640));
    expect(sockets[0].sent.last, 'audio');
    await processor.close();
    await processor.close();
    expect(sockets.map((socket) => socket.closes), [1, 1]);
  });

  test(
    'cancel completes while connectors remain pending and reaps late sockets',
    () async {
      final pending = [
        Completer<DomesticModelSocket>(),
        Completer<DomesticModelSocket>(),
      ];
      var index = 0;
      final processor = _processor((_, _) => pending[index++].future);
      final start = processor.start();
      final rejected = expectLater(start, throwsA(anything));
      await processor.close();
      await rejected;
      final sockets = [_Socket(), _Socket()];
      pending[0].complete(sockets[0]);
      pending[1].complete(sockets[1]);
      await Future<void>.delayed(Duration.zero);
      expect(sockets.map((socket) => socket.closes), [1, 1]);
      expect(sockets.expand((socket) => socket.sent), isEmpty);
    },
  );

  test(
    'one failure closes sibling and emits a single terminal event',
    () async {
      final sockets = [_Socket(), _Socket()];
      final events = <DomesticModelEvent>[];
      var index = 0;
      final processor = _processor(
        (_, _) async => sockets[index++],
        events: events,
      );
      final start = processor.start();
      final rejected = expectLater(start, throwsA(anything));
      await Future<void>.delayed(Duration.zero);
      sockets[0].events.add('failed');
      await rejected;
      expect(events.whereType<DomesticModelError>().length, 1);
      expect(sockets.map((socket) => socket.closes), [1, 1]);
    },
  );

  test('ready connection loss never reopens or accepts more audio', () async {
    final sockets = [_Socket(), _Socket()];
    var index = 0;
    final processor = _processor((_, _) async => sockets[index++]);
    final start = processor.start();
    await Future<void>.delayed(Duration.zero);
    for (final socket in sockets) {
      socket.events.add('ready');
    }
    await start;
    sockets[1].events.addError(StateError('synthetic'));
    await Future<void>.delayed(Duration.zero);
    processor.sendAudio(DomesticTranslationLeg.remote, Uint8List(640));
    expect(processor.ready, false);
    expect(index, 2);
    expect(sockets[1].sent.where((event) => event == 'audio'), isEmpty);
    await processor.close();
  });

  test(
    'timeout reaps late resources and failed close remains unconfirmed',
    () async {
      final pending = Completer<DomesticModelSocket>();
      final processor = _processor(
        (_, _) => pending.future,
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(processor.start(), throwsA(anything));
      final socket = _Socket()..failClose = true;
      pending.complete(socket);
      await Future<void>.delayed(Duration.zero);
      expect(processor.cleanupUnconfirmed, true);
      // This connector returns the same object for both requests only in this test.
      expect(socket.closes, 2);
    },
  );
}

DomesticTranslationProcessor _processor(
  DomesticModelConnector connect, {
  List<DomesticModelEvent>? events,
  Duration timeout = const Duration(seconds: 1),
}) => DomesticTranslationProcessor(
  local: _Protocol(),
  remote: _Protocol(),
  connect: connect,
  isCurrent: () => true,
  onEvent: (_, event) => events?.add(event),
  prepareTimeout: timeout,
);

class _Socket implements DomesticModelSocket {
  final events = StreamController<Object>();
  final sent = <Object>[];
  int closes = 0;
  bool failClose = false;
  @override
  Stream<Object> get messages => events.stream;
  @override
  void send(Object message) => sent.add(message);
  @override
  Future<void> close() async {
    closes++;
    if (failClose) {
      throw StateError('synthetic cleanup failure');
    }
    unawaited(events.close());
  }
}

class _Protocol implements DomesticModelProtocol {
  @override
  Uri get uri => Uri.parse('wss://example.test');
  @override
  Map<String, String> get headers => {'Authorization': 'synthetic'};
  @override
  Object start() => 'start';
  @override
  Object audio(Uint8List pcm16k) => 'audio';
  @override
  Object finish() => 'finish';
  @override
  List<DomesticModelEvent> decode(Object message) => switch (message) {
    'ready' => [const DomesticModelReady()],
    'failed' => [const DomesticModelError('MODEL_SERVICE_ERROR')],
    _ => [],
  };
}

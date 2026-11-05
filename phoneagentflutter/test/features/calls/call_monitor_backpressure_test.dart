import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/call_monitor_stream.dart';
import 'package:phone_agent/features/calls/data/preview_call_monitor.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket_io.dart';
import '../../support/call_monitor_fixture.dart';

void main() {
  test('real WebSocket PCM burst remains ordered under backpressure', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final connected = Completer<WebSocket>();
    server.listen((request) async {
      connected.complete(await WebSocketTransformer.upgrade(request));
    });
    final output = TestMonitorOutput();
    final monitor = CallMonitorStream(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}/'),
      connect: connectVoiceSocket,
      output: output,
    );
    var lost = 0;
    final subscription = monitor.disconnected.listen((_) => lost++);
    addTearDown(() async {
      await monitor.close();
      await subscription.cancel();
      await server.close(force: true);
    });
    await monitor.start(monitorTicket(), 'earpiece');
    final peer = await connected.future;
    for (var i = 0; i < 170; i++) {
      peer.add(Uint8List(640)..[0] = i);
    }
    for (var pass = 0; pass < 40; pass++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      for (final gate in output.gates) {
        if (!gate.isCompleted) gate.complete();
      }
      if (output.played.length == 170) break;
    }
    expect(lost, 0);
    expect(
      output.played.map((bytes) => bytes[0]),
      List.generate(170, (i) => i),
    );
  });

  test(
    'burst of valid twenty-ms frames drains without dropping the monitor',
    () async {
      final socket = PreviewMonitorSocket();
      final output = TestMonitorOutput();
      final monitor = CallMonitorStream(
        apiBase: Uri.parse('https://synthetic.invalid/'),
        connect: (_) async => socket,
        output: output,
      );
      var lost = 0;
      final events = monitor.disconnected.listen((_) => lost++);
      addTearDown(() async {
        await monitor.close();
        await events.cancel();
      });
      await monitor.start(monitorTicket(), 'earpiece');
      for (var index = 0; index < 170; index++) {
        socket.add(Uint8List(640)..[0] = index);
      }
      await Future<void>.delayed(Duration.zero);
      expect(
        lost,
        0,
        reason: 'AI downlink bursts must backpressure rather than reconnect',
      );
      expect(output.played.length, lessThanOrEqualTo(50));
      for (var pass = 0; pass < 10; pass++) {
        for (final gate in output.gates) {
          if (!gate.isCompleted) gate.complete();
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(await monitor.audioStarted, isTrue);
      expect(
        output.played.map((bytes) => bytes[0]),
        List.generate(170, (i) => i),
      );
      expect(lost, 0);
    },
  );

  test(
    'muting a paused receive queue discards old audio before resuming',
    () async {
      final socket = PreviewMonitorSocket();
      final output = TestMonitorOutput();
      final monitor = CallMonitorStream(
        apiBase: Uri.parse('https://synthetic.invalid/'),
        connect: (_) async => socket,
        output: output,
      );
      final events = monitor.disconnected.listen(
        (_) {},
        onError: (Object _) {},
      );
      addTearDown(() async {
        await monitor.close();
        await events.cancel();
      });
      await monitor.start(monitorTicket(), 'earpiece');
      for (var i = 0; i < 80; i++) {
        socket.add(Uint8List(640));
      }
      await Future<void>.delayed(Duration.zero);
      await monitor.setPlaybackEnabled(false);
      final old = output.played.length;
      await monitor.setPlaybackEnabled(true);
      socket.add(Uint8List(640)..[0] = 99);
      await Future<void>.delayed(Duration.zero);
      expect(output.played.length, old + 1);
      expect(output.played.last[0], 99);
    },
  );
}

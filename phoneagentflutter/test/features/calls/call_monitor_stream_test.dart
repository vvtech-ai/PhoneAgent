import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/calls/data/call_monitor_stream.dart';
import 'package:phone_agent/features/calls/data/focused_call_monitor_media.dart';
import 'package:phone_agent/features/calls/data/preview_call_monitor.dart';
import 'package:phone_agent/features/calls/domain/call_monitor_media.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket_io.dart';
import '../../support/call_monitor_fixture.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'endpoint retains API path, encodes ticket, rejects invalid format/expiry',
    () {
      final ticket = monitorTicket();
      final uri = CallMonitorStream.endpoint(
        Uri.parse('https://synthetic.invalid/aiassistant-api/'),
        ticket,
        DateTime.now(),
      );
      expect(uri.path, '/aiassistant-api/ws/assistant/call/monitor');
      expect(uri.scheme, 'wss');
      expect(uri.queryParameters, {'ticket': ticket.ticket});
      for (final ticket in [
        monitorTicket(rate: 0),
        monitorTicket(channels: 2),
        monitorTicket(encoding: 'mp3'),
        monitorTicket(expires: DateTime(2000)),
      ]) {
        expect(
          () => CallMonitorStream.endpoint(
            Uri.parse('https://synthetic.invalid/'),
            ticket,
            DateTime.now(),
          ),
          throwsA(isA<CallMonitorFailure>()),
        );
      }
      expect(
        () => CallMonitorStream.endpoint(
          Uri.parse('https://user:secret@synthetic.invalid/?x=1'),
          ticket,
          DateTime.now(),
        ),
        throwsA(isA<CallMonitorFailure>()),
      );
    },
  );
  test(
    'binary receive-only, muted flush never replays old frames or opens another socket',
    () async {
      final socket = PreviewMonitorSocket();
      final output = TestMonitorOutput();
      var connections = 0, lost = 0;
      final stream = CallMonitorStream(
        apiBase: Uri.parse('https://synthetic.invalid/'),
        output: output,
        connect: (_) async {
          connections++;
          return socket;
        },
      );
      final subscription = stream.disconnected.listen((_) => lost++);
      await stream.start(monitorTicket(), 'earpiece');
      socket.add('ignored control');
      socket.add(Uint8List(3200));
      await flush();
      expect(output.played, hasLength(1));
      await stream.setPlaybackEnabled(false);
      socket.add(Uint8List(3200));
      await flush();
      expect(lost, 0);
      expect(output.played, hasLength(1));
      await stream.setPlaybackEnabled(true);
      socket.add(Uint8List(640));
      await flush();
      expect(output.played.map((e) => e.length), [3200, 640]);
      expect(connections, 1);
      await stream.close();
      await subscription.cancel();
      expect(socket.closed, isTrue);
      expect(output.stopped, isTrue);
    },
  );
  for (final size in [1, 64002]) {
    test(
      'malformed/overflow PCM $size fails once without unbounded allocation',
      () async {
        final socket = PreviewMonitorSocket();
        final output = TestMonitorOutput();
        final stream = CallMonitorStream(
          apiBase: Uri.parse('https://synthetic.invalid/'),
          output: output,
          connect: (_) async => socket,
        );
        var lost = 0;
        final subscription = stream.disconnected.listen((_) => lost++);
        await stream.start(monitorTicket(), 'earpiece');
        socket.add(Uint8List(size));
        socket.add(Uint8List(size));
        expect(lost, 1);
        expect(output.played, isEmpty);
        await stream.close();
        await subscription.cancel();
      },
    );
  }
  test(
    'late socket after close is immediately closed, never subscribed/played',
    () async {
      final gate = Completer<VoiceSocket>();
      final output = TestMonitorOutput();
      final stream = CallMonitorStream(
        apiBase: Uri.parse('https://synthetic.invalid/'),
        output: output,
        connect: (_) => gate.future,
      );
      final start = expectLater(
        stream.start(monitorTicket(), 'earpiece'),
        throwsA(isA<CallMonitorFailure>()),
      );
      await flush();
      await stream.close();
      final socket = PreviewMonitorSocket();
      gate.complete(socket);
      await start;
      expect(socket.closed, isTrue);
      expect(output.played, isEmpty);
    },
  );
  test(
    'real IO loopback upgrades correct path and accepts PCM without client upload',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peer = Completer<WebSocket>();
      var messages = 0;
      server.listen((request) async {
        expect(request.uri.path, '/api/ws/assistant/call/monitor');
        expect(request.uri.queryParameters['ticket'], 'synthetic+/=?');
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((_) => messages++);
        peer.complete(socket);
      });
      final output = TestMonitorOutput();
      final stream = CallMonitorStream(
        apiBase: Uri.parse('http://127.0.0.1:${server.port}/api/'),
        output: output,
        connect: connectVoiceSocket,
      );
      try {
        await stream.start(monitorTicket(), 'earpiece');
        (await peer.future).add(Uint8List(64));
        for (var i = 0; i < 20 && output.played.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(output.played.single.length, 64);
        expect(messages, 0);
      } finally {
        await stream.close();
        await server.close(force: true);
      }
    },
  );
  test(
    'muted retains lease; release failure blocks other output until explicit retry',
    () async {
      final focus = AudioPlaybackFocus();
      final media = TestMonitorMedia();
      var interrupted = 0;
      final wrapped = FocusedCallMonitorMedia(
        delegate: media,
        focus: focus,
        isCurrent: () => true,
        onInterrupted: () => interrupted++,
      );
      await wrapped.start(monitorTicket(), 'earpiece');
      await wrapped.setPlaybackEnabled(false);
      expect(focus.active?.owner, 'call-monitor');
      media.failClose = true;
      await expectLater(
        focus.acquire(
          owner: 'other',
          isCurrent: () => true,
          stop: (_) async {},
        ),
        throwsA(isA<CallMonitorFailure>()),
      );
      expect(focus.active?.owner, 'call-monitor');
      media.failClose = false;
      await wrapped.close();
      expect(focus.active, isNull);
      expect(interrupted, 1);
    },
  );
  test(
    'stopping before queued focus acquisition cannot orphan lease',
    () async {
      final focus = AudioPlaybackFocus();
      final media = TestMonitorMedia();
      final wrapped = FocusedCallMonitorMedia(
        delegate: media,
        focus: focus,
        isCurrent: () => true,
        onInterrupted: () {},
      );
      final starting = expectLater(
        wrapped.start(monitorTicket(), 'earpiece'),
        throwsA(anything),
      );
      await wrapped.close();
      await starting;
      expect(focus.active, isNull);
      expect(media.starts, 0);
    },
  );
}

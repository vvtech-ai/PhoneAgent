import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/conversation/data/voice/conversation_tts_stream.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_connection_owner.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../../core/audio/pcm_output_fake.dart';
import 'voice_socket_fake.dart';

void main() {
  test('idle expiry releases only wire while queued PCM keeps draining', () {
    fakeAsync((clock) {
      final fixture = _Fixture();
      fixture.owner.configure(modelId: 'A', speaker: 'Maia');
      final stream = fixture.reply()
        ..enqueue('A')
        ..complete();
      clock.flushMicrotasks();
      fixture.sockets.single.emit('{"type":"ready"}');
      fixture.sockets.single.emit(Uint8List(24000));
      fixture.sockets.single.emit('{"type":"complete"}');
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 60));
      clock.flushMicrotasks();
      expect(fixture.sockets.single.closes, 1);
      expect(stream.phase, ReplySpeechPhase.draining);
      expect(stream.queuedBytes, 42240);
      fixture.owner.configure(modelId: 'B', speaker: 'Maia');
      clock.flushMicrotasks();
      expect(stream.queuedBytes, 0);
      fixture.dispose(clock);
    });
  });
  test('owner network recovery replays only undelivered audio once', () {
    fakeAsync((clock) {
      final network = StreamController<NetworkAvailability>.broadcast(
        sync: true,
      );
      final fixture = _Fixture(networkEvents: network.stream);
      final stream = fixture.reply()
        ..enqueue('A')
        ..complete();
      clock.flushMicrotasks();
      final old = fixture.sockets.single;
      old.emit('{"type":"ready"}');
      old.emit(Uint8List(2));
      clock.flushMicrotasks();
      network.add(NetworkAvailability.unavailable);
      clock.flushMicrotasks();
      expect(old.closes, 1);
      network.add(NetworkAvailability.available);
      clock.flushMicrotasks();
      expect(fixture.sockets, hasLength(2));
      old.emit(Uint8List(24000));
      old.emit('{"type":"complete"}');
      fixture.sockets.last.emit('{"type":"ready"}');
      fixture.sockets.last.emit(Uint8List(4));
      fixture.sockets.last.emit('{"type":"complete"}');
      clock.flushMicrotasks();
      expect(stream.failures, 0);
      expect(stream.queuedBytes, 15360 + 4 + 2880);
      fixture.dispose(clock);
      network.close();
      clock.flushMicrotasks();
    });
  });
  test(
    'reply created after owner offline still has a bounded offline wait',
    () {
      fakeAsync((clock) {
        final network = StreamController<NetworkAvailability>.broadcast(
          sync: true,
        );
        final fixture = _Fixture(networkEvents: network.stream);
        network.add(NetworkAvailability.unavailable);
        final stream = fixture.reply()..enqueue('A');
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 15));
        clock.flushMicrotasks();
        expect(stream.phase, ReplySpeechPhase.failed);
        expect(fixture.sockets, isEmpty);
        fixture.dispose(clock);
        network.close();
        clock.flushMicrotasks();
      });
    },
  );
  test('A B C separate replies share socket; late A cancel cannot close C', () {
    fakeAsync((clock) {
      final fixture = _Fixture();
      fixture.owner.prewarm();
      clock.flushMicrotasks();
      final socket = fixture.sockets.single;
      socket.emit('{"type":"ready"}');
      clock.flushMicrotasks();
      expect(socket.sent, isEmpty);
      final replies = <ConversationTtsStream>[];
      for (final text in ['A', 'B', 'C']) {
        final stream = fixture.reply();
        replies.add(stream);
        stream.enqueue(text);
        stream.complete();
        clock.flushMicrotasks();
        expect(fixture.sockets, hasLength(1));
        if (text == 'C') replies.first.cancel();
        socket.emit(Uint8List(2));
        socket.emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(socket.closes, 0);
      }
      expect(
        socket.sent
            .whereType<String>()
            .map(jsonDecode)
            .where((row) => row['type'] == 'synthesize')
            .map((row) => row['text']),
        ['A', 'B', 'C'],
      );
      fixture.dispose(clock);
    });
  });

  test('idle boundary releases at 60 seconds and next reply reconnects', () {
    fakeAsync((clock) {
      final fixture = _Fixture();
      fixture.owner.prewarm();
      clock.flushMicrotasks();
      final old = fixture.sockets.single;
      old.emit('{"type":"ready"}');
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 59, milliseconds: 999));
      expect(old.closes, 0);
      clock.elapse(const Duration(milliseconds: 1));
      clock.flushMicrotasks();
      expect(old.closes, 1);
      fixture.reply().enqueue('B');
      clock.flushMicrotasks();
      expect(fixture.sockets, hasLength(2));
      fixture.dispose(clock);
    });
  });

  test(
    'cancel unfinished synthesis isolates old PCM and old lease release',
    () {
      fakeAsync((clock) {
        final fixture = _Fixture();
        final first = fixture.reply()..enqueue('A');
        clock.flushMicrotasks();
        fixture.sockets.single.emit('{"type":"ready"}');
        fixture.sockets.single.emit(Uint8List(2));
        clock.flushMicrotasks();
        first.cancel();
        final second = fixture.reply()
          ..enqueue('B')
          ..complete();
        clock.flushMicrotasks();
        expect(fixture.sockets, hasLength(2));
        fixture.sockets.first.emit(Uint8List(24000));
        fixture.sockets.first.emit('{"type":"complete"}');
        fixture.sockets.last.emit('{"type":"ready"}');
        fixture.sockets.last.emit(Uint8List(4));
        fixture.sockets.last.emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(second.queuedBytes, 15360 + 4 + 2880);
        expect(first.queuedBytes, 0);
        expect(fixture.sockets.last.closes, 0);
        fixture.dispose(clock);
      });
    },
  );

  test('voice model change stops already synthesized but unplayed PCM', () {
    fakeAsync((clock) {
      final fixture = _Fixture();
      fixture.owner.configure(modelId: 'A', speaker: 'Maia');
      final stream = fixture.reply()
        ..enqueue('A')
        ..complete();
      clock.flushMicrotasks();
      fixture.sockets.single.emit('{"type":"ready"}');
      fixture.sockets.single.emit(Uint8List(24000));
      fixture.sockets.single.emit('{"type":"complete"}');
      clock.flushMicrotasks();
      expect(stream.phase, ReplySpeechPhase.draining);
      fixture.owner.configure(modelId: 'B', speaker: 'Maia');
      clock.flushMicrotasks();
      expect(stream.queuedBytes, 0);
      expect(stream.phase, ReplySpeechPhase.cancelled);
      fixture.dispose(clock);
    });
  });

  test(
    'background invalidates idle wire; resume never synthesizes old reply',
    () {
      fakeAsync((clock) {
        final fixture = _Fixture();
        final stream = fixture.reply()..enqueue('A');
        clock.flushMicrotasks();
        final old = fixture.sockets.single;
        old.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        fixture.owner.handleAppLifecycle(AppLifecycleState.paused);
        clock.flushMicrotasks();
        expect(stream.phase, ReplySpeechPhase.cancelled);
        expect(old.closes, 1);
        fixture.owner.handleAppLifecycle(AppLifecycleState.resumed);
        clock.flushMicrotasks();
        expect(fixture.sockets, hasLength(1));
        fixture.reply().enqueue('B');
        clock.flushMicrotasks();
        expect(fixture.sockets, hasLength(2));
        fixture.dispose(clock);
      });
    },
  );
}

class _Fixture {
  _Fixture({this.networkEvents}) {
    owner = TaskTtsConnectionOwner(
      endpoint: endpoint,
      createSession: createSession,
      networkEvents: networkEvents,
    );
  }
  final Stream<NetworkAvailability>? networkEvents;
  final endpoint = Uri.parse('ws://synthetic.invalid/tts');
  final sockets = <VoiceSocketFake>[];
  final focus = AudioPlaybackFocus();
  final replies = <ConversationTtsStream>[];
  late final TaskTtsConnectionOwner owner;
  TaskTtsSession createSession() => TaskTtsSession(
    heartbeatInterval: const Duration(seconds: 120),
    connector: (_) async {
      final socket = VoiceSocketFake(closeMessagesOnClose: false);
      sockets.add(socket);
      return socket;
    },
  );
  ConversationTtsStream reply() {
    final stream = ConversationTtsStream(
      endpoint: endpoint,
      createSession: createSession,
      connectionOwner: owner,
      networkEvents: networkEvents,
      output: PcmOutputFake(),
      focus: focus,
      isCurrent: () => true,
      onChanged: () {},
    );
    replies.add(stream);
    return stream;
  }

  void dispose(FakeAsync clock) {
    for (final reply in replies) {
      reply.cancel();
    }
    owner.dispose();
    for (final socket in sockets) {
      socket.input.close();
    }
    clock.flushMicrotasks();
    expect(clock.nonPeriodicTimerCount, 0);
    expect(clock.periodicTimerCount, 0);
  }
}

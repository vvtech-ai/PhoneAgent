import 'dart:async';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/translation/data/livekit_translation_media.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_livekit_room.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';
import '../conversation/voice/voice_input_fake.dart';
import 'translation_livekit_room_fake.dart';

void main() {
  late TranslationLiveKitRoomFake room;
  late InputPermissionFake permissions;
  late AudioPlaybackFocus focus;
  late LiveKitTranslationMedia media;
  late List<TranslationRealtimeMessage> messages;
  late List<Object> failures;
  bool current = true;
  setUp(() {
    current = true;
    room = TranslationLiveKitRoomFake();
    permissions = InputPermissionFake();
    focus = AudioPlaybackFocus();
    media = LiveKitTranslationMedia(
      roomFactory: () => room,
      permissions: permissions,
      focus: focus,
      isCurrent: () => current,
      now: () => DateTime.fromMillisecondsSinceEpoch(123),
    );
    messages = [];
    failures = [];
    media.events.listen(messages.add, onError: failures.add);
  });
  tearDown(() async {
    room.failClose = false;
    await media.close();
  });
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  void ready({
    String id = 'mock-session',
    String kind = 'realtime_ready',
    String? topic,
  }) => room.wire({'event': kind, 'callSessionId': id}, topic: topic);
  Future<void> connect() => media.connect(PreviewTranslationSession.ticket);
  Future<void> connected() async {
    final pending = connect();
    await flush();
    ready();
    await pending;
  }

  test(
    'room shutdown forwards only matching subtitle before subscription release',
    () async {
      await connected();
      room.closeGate = Completer<void>();
      final closing = media.close();
      await flush();
      final before = messages.length;
      room.wire({
        'event': 'transcript_delta',
        'callSessionId': 'mock-session',
        'segmentId': 'known',
        'sourceLeg': 'merchant',
        'kind': 'output',
        'text': '最终译文',
      });
      room.wire({'event': 'call_connected', 'callSessionId': 'mock-session'});
      room.wire({
        'event': 'transcript_delta',
        'callSessionId': 'other',
        'segmentId': 'known',
        'sourceLeg': 'merchant',
        'kind': 'output',
        'text': '错误会话',
      });
      expect(messages.length, before + 1);
      expect(messages.last.event, isA<TranslationTranscriptDelta>());
      current = false;
      room.wire({
        'event': 'transcript_delta',
        'callSessionId': 'mock-session',
        'segmentId': 'known',
        'sourceLeg': 'merchant',
        'kind': 'output',
        'text': '过期账号',
      });
      expect(messages.length, before + 1);
      room.closeGate!.complete();
      await closing;
    },
  );
  test('room alone or worker_ready does not open double-ready gate', () async {
    var done = false;
    final pending = connect().then((_) => done = true);
    await flush();
    ready(kind: 'worker_ready');
    await flush();
    expect(done, false);
    expect(room.operations.take(3), [
      'connect',
      'speaker:false',
      'microphone:true',
    ]);
    expect(room.published.single, {
      'event': 'web_client_ready',
      'callSessionId': 'mock-session',
    });
    ready();
    await pending;
    expect(done, true);
    expect(permissions.requests, [false]);
  });
  test(
    'early realtime waits for room and microphone, ready published once',
    () async {
      room.connectGate = Completer<void>();
      var done = false;
      final pending = connect().then((_) => done = true);
      await flush();
      ready();
      await flush();
      expect(done, false);
      room.connectGate!.complete();
      await pending;
      expect(room.published.length, 1);
    },
  );
  test(
    'wrong session/topic ignored while empty session/topic is compatible',
    () async {
      var done = false;
      final pending = connect().then((_) => done = true);
      await flush();
      ready(id: 'other');
      ready(topic: 'other.topic');
      await flush();
      expect(done, false);
      ready(id: '', topic: '');
      await pending;
      expect(messages.length, 1);
    },
  );
  test(
    'mute, route, DTMF use shared protocol and propagate failures',
    () async {
      await connected();
      await media.setMuted(true);
      await media.setSpeaker(true);
      await media.sendDtmf('#');
      expect(room.published.last, {
        'event': 'dtmf_digit',
        'callSessionId': 'mock-session',
        'digit': '#',
        'sequence': 123,
      });
      expect(room.operations, contains('microphone:false'));
      expect(room.operations, contains('speaker:true'));
      await expectLater(media.sendDtmf('12'), throwsStateError);
      room.failControl = true;
      await expectLater(media.setMuted(false), throwsStateError);
    },
  );
  test(
    'cancel during room connect prevents late microphone and publish',
    () async {
      room.connectGate = Completer<void>();
      final pending = expectLater(connect(), throwsStateError);
      await flush();
      var stopped = false;
      final close = media.close().then((_) => stopped = true);
      await flush();
      expect(stopped, false);
      expect(focus.active, isNotNull);
      room.connectGate!.complete();
      await close;
      await pending;
      expect(room.operations, ['connect', 'close']);
      expect(focus.active, isNull);
    },
  );
  test(
    'cancel during microphone operation waits for release and never publishes',
    () async {
      room.microphoneGate = Completer<void>();
      final pending = expectLater(connect(), throwsStateError);
      await flush();
      final close = media.close();
      await flush();
      expect(focus.active, isNotNull);
      room.microphoneGate!.complete();
      await close;
      await pending;
      expect(room.published, isEmpty);
      expect(focus.active, isNull);
    },
  );
  test(
    'permission late after close does not create room or audio lease',
    () async {
      permissions.gate = Completer<PermissionGrant>();
      final pending = expectLater(connect(), throwsStateError);
      await flush();
      await media.close();
      permissions.gate!.complete(PermissionGrant.granted);
      await pending;
      expect(room.operations, isEmpty);
      expect(focus.active, isNull);
    },
  );
  test('denied permission never requests it or connects', () async {
    permissions.grant = PermissionGrant.denied;
    await expectLater(connect(), throwsStateError);
    expect(room.operations, isEmpty);
    expect(permissions.requests, [false]);
  });
  test(
    'cleanup failure keeps lease; explicit retry releases only after success',
    () async {
      await connected();
      room.failClose = true;
      await expectLater(media.close(), throwsStateError);
      expect(focus.active, isNotNull);
      room.failClose = false;
      await media.close();
      expect(focus.active, isNull);
      expect(room.closes, 2);
    },
  );
  test(
    'playback must stop first; protected translation cannot be stolen',
    () async {
      final prior = Completer<void>();
      await focus.acquire(
        owner: 'old',
        stop: (_) => prior.future,
        isCurrent: () => true,
      );
      final pending = connect();
      await flush();
      expect(room.operations, isEmpty);
      prior.complete();
      await flush();
      ready();
      await pending;
      await expectLater(
        focus.acquire(owner: 'new', stop: (_) async {}, isCurrent: () => true),
        throwsStateError,
      );
      await focus.stopAll();
      expect(room.closes, 1);
      expect(focus.active, isNull);
    },
  );
  test(
    'disconnect after ready errors; before ready fails preparation only',
    () async {
      final pending = expectLater(connect(), throwsStateError);
      await flush();
      room.controller.add(const TranslationRoomDisconnected());
      await pending;
      expect(failures, isEmpty);
    },
  );
  test(
    'disconnect while ready publish is pending cannot report success',
    () async {
      room.onPublish = () {
        ready();
        room.controller.add(const TranslationRoomDisconnected());
      };
      await expectLater(connect(), throwsStateError);
      expect(focus.active, isNull);
    },
  );
  test('real link lost after successful connect is observable', () async {
    await connected();
    room.controller.add(const TranslationRoomDisconnected());
    expect(failures.length, 1);
    await expectLater(media.setMuted(true), throwsStateError);
  });
  test(
    'malformed/oversized frame fails safely without payload in error',
    () async {
      await connected();
      room.controller.add(
        TranslationRoomData(Uint8List(1024 * 1024 + 1), null),
      );
      expect(failures.single.toString(), isNot(contains('token')));
    },
  );
  test(
    'invalid insecure ticket fails before permission or SDK calls',
    () async {
      await expectLater(
        media.connect(
          const TranslationBackendSession(
            id: 's',
            clusterId: 'US',
            recordingAccessGrant: 'synthetic',
            mediaTransport: 'livekit',
            liveKit: TranslationLiveKitConnection(
              url: 'ws://example.invalid',
              token: 'synthetic',
            ),
          ),
        ),
        throwsStateError,
      );
      expect(permissions.requests, isEmpty);
      expect(room.operations, isEmpty);
    },
  );
  for (final scheme in ['https', 'wss']) {
    test(
      '$scheme room URL with query reaches SDK and requires ready',
      () async {
        var done = false;
        final pending = media
            .connect(
              TranslationBackendSession(
                id: 'mock-session',
                clusterId: 'US',
                recordingAccessGrant: 'synthetic',
                mediaTransport: 'livekit',
                liveKit: TranslationLiveKitConnection(
                  url: '$scheme://example.invalid/room?region=us',
                  token: 'synthetic',
                ),
              ),
            )
            .then((_) => done = true);
        await flush();
        expect(room.operations, contains('connect'));
        expect(done, false);
        ready();
        await pending;
        expect(done, true);
      },
    );
  }
  test('ready deadline is bounded and releases room', () {
    fakeAsync((time) {
      final localRoom = TranslationLiveKitRoomFake();
      final localFocus = AudioPlaybackFocus();
      final localMedia = LiveKitTranslationMedia(
        roomFactory: () => localRoom,
        permissions: InputPermissionFake(),
        focus: localFocus,
        isCurrent: () => true,
      );
      Object? error;
      unawaited(
        localMedia.connect(PreviewTranslationSession.ticket).catchError((
          Object value,
        ) {
          error = value;
        }),
      );
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 10));
      time.flushMicrotasks();
      expect(error, isA<StateError>());
      expect(localRoom.closes, 1);
      expect(localFocus.active, isNull);
    });
  });
  test(
    'account invalidation during room connection does not start mic',
    () async {
      room.connectGate = Completer<void>();
      final pending = expectLater(connect(), throwsStateError);
      await flush();
      current = false;
      room.connectGate!.complete();
      await pending;
      expect(room.operations, ['connect', 'close']);
    },
  );
}

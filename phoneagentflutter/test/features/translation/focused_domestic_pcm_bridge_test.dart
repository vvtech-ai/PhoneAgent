import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/translation/data/sip/focused_domestic_pcm_bridge.dart';
import 'package:phone_agent/features/translation/domain/translation_pcm_bridge.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';

class Pcm implements TranslationPcmBridge, TranslationPcmQueue {
  int starts = 0, closes = 0, drains = 0;
  bool queued = false;
  @override
  void enableQueuedPlayback() {
    queued = true;
  }

  @override
  Future<void> drain() async {
    drains++;
  }

  bool failClose = false;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<Uint8List?> read() async => Uint8List(640);
  @override
  Future<void> play(TranslationAudio audio) async {}
  @override
  Future<void> setSpeaker(bool enabled) async {}
  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw StateError('synthetic close failure');
  }
}

class Permissions implements ConversationPermissionSource {
  PermissionGrant value = PermissionGrant.granted;
  Completer<PermissionGrant>? pending;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async => pending?.future ?? value;
}

void main() {
  test(
    'playback statistics never delay drain and reporting errors do not block cleanup',
    () async {
      final pcm = _StatisticsPcm(), focus = AudioPlaybackFocus();
      final stats = <Map<String, int>>[];
      final bridge = FocusedDomesticPcmBridge(
        delegate: pcm,
        permissions: Permissions(),
        focus: focus,
        isCurrent: () => true,
        onInterrupted: () async {},
        onStatistics: (value) {
          stats.add(value);
          throw StateError('synthetic reporter failure');
        },
      );
      await bridge.prepare();
      await bridge.start();
      await bridge.drain();
      expect(pcm.drains, 1);
      expect(stats, isEmpty);
      pcm.sample.complete({'outputPlatform': 2, 'outputMaxQueuedMs': 600});
      await Future<void>.delayed(Duration.zero);
      expect(stats.single['outputPlatform'], 2);
      await bridge.close();
      expect(pcm.closes, 1);
      expect(focus.active, isNull);
    },
  );
  test(
    'admission reserves exclusive audio without starting capture, interruption closes once',
    () async {
      final focus = AudioPlaybackFocus(),
          pcm = Pcm(),
          permissions = Permissions();
      var interruptions = 0;
      final bridge = FocusedDomesticPcmBridge(
        delegate: pcm,
        permissions: permissions,
        focus: focus,
        isCurrent: () => true,
        onInterrupted: () async {
          interruptions++;
        },
      );
      await bridge.prepare();
      expect(pcm.starts, 0);
      expect(pcm.queued, true);
      await bridge.drain();
      expect(pcm.drains, 1);
      await expectLater(
        focus.acquire(
          owner: 'another-owner',
          stop: (_) async {},
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      await bridge.start();
      expect(pcm.starts, 1);
      await focus.stopAll();
      expect(interruptions, 1);
      expect(pcm.closes, 1);
      expect(focus.active, isNull);
      await bridge.close();
      expect(pcm.closes, 1);
    },
  );
  test(
    'cancel pending permission completes and late result never reserves audio',
    () async {
      final focus = AudioPlaybackFocus(),
          pcm = Pcm(),
          permissions = Permissions()..pending = Completer<PermissionGrant>();
      final bridge = FocusedDomesticPcmBridge(
        delegate: pcm,
        permissions: permissions,
        focus: focus,
        isCurrent: () => true,
        onInterrupted: () async {},
      );
      final prepare = bridge.prepare();
      final failed = expectLater(prepare, throwsStateError);
      await bridge.close();
      await failed;
      permissions.pending!.complete(PermissionGrant.granted);
      await Future<void>.delayed(Duration.zero);
      expect(focus.active, isNull);
      expect(pcm.starts, 0);
    },
  );
  test('unconfirmed native stop keeps exclusive lease blocked', () async {
    final focus = AudioPlaybackFocus(), pcm = Pcm()..failClose = true;
    final bridge = FocusedDomesticPcmBridge(
      delegate: pcm,
      permissions: Permissions(),
      focus: focus,
      isCurrent: () => true,
      onInterrupted: () async {},
    );
    await bridge.prepare();
    await bridge.start();
    await expectLater(bridge.close(), throwsStateError);
    expect(focus.active, isNotNull);
    await expectLater(
      focus.acquire(
        owner: 'another-owner',
        stop: (_) async {},
        isCurrent: () => true,
      ),
      throwsStateError,
    );
  });
}

class _StatisticsPcm extends Pcm implements TranslationPcmStatistics {
  final sample = Completer<Map<String, int>>();
  @override
  Future<Map<String, int>> playbackStatistics() => sample.future;
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/audio_focus_providers.dart';
import 'package:phone_agent/app/translation_device_media_providers.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/translation/data/app_audio_translation_media.dart';
import 'package:phone_agent/features/translation/data/livekit_translation_media.dart';
import 'package:phone_agent/features/translation/data/preview_app_audio_ports.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/domain/translation_media_port.dart';
import '../conversation/voice/voice_input_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final mobile in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$mobile complete factory uses shared focus; AppAudio waits before capture',
      () async {
        debugDefaultTargetPlatformOverride = mobile;
        final focus = AudioPlaybackFocus(), permissions = InputPermissionFake();
        final pcm = PreviewTranslationPcm(), socket = PreviewAppAudioSocket();
        var connects = 0, bridges = 0;
        final container = ProviderContainer(
          overrides: [
            audioPlaybackFocusProvider.overrideWithValue(focus),
            conversationPermissionSourceProvider.overrideWithValue(permissions),
            translationPcmBridgeFactoryProvider.overrideWithValue(() {
              bridges++;
              return pcm;
            }),
            translationAppAudioConnectorProvider.overrideWithValue((uri) async {
              connects++;
              expect(uri.queryParameters['downlinkAudio'], 'binary');
              return socket;
            }),
          ],
        );
        addTearDown(container.dispose);
        final factory = container.read(translationDeviceMediaFactoryProvider)!;
        expect(bridges, 0);
        expect(connects, 0);
        var current = true;
        final room =
            factory(TranslationMediaTransport.liveKit, () => current)
                as LiveKitTranslationMedia;
        expect(room.focus, same(focus));
        expect(room.permissions, same(permissions));
        final audio =
            factory(TranslationMediaTransport.websocket, () => current)
                as AppAudioTranslationMedia;
        expect(audio.focus, same(focus));
        expect(audio.audio, same(pcm));
        final subscription = audio.events.listen((_) {});
        final pending = audio.connect(PreviewTranslationSession.ticket);
        await Future<void>.delayed(Duration.zero);
        socket.wire('app_audio_ready');
        await pending;
        expect(connects, 1);
        expect(pcm.starts, 0);
        socket.wire('merchant_audio_ready');
        await Future<void>.delayed(Duration.zero);
        expect(pcm.starts, 1);
        current = false;
        await expectLater(
          room.connect(PreviewTranslationSession.ticket),
          throwsStateError,
        );
        await room.close();
        await audio.close();
        await subscription.cancel();
        expect(socket.closed, isTrue);
        expect(pcm.closed, isTrue);
        expect(focus.active, isNull);
        expect(permissions.requests, [false]);
      },
    );
  }
  test('desktop remains unavailable without constructing ports', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer(
        overrides: [
          translationPcmBridgeFactoryProvider.overrideWith(
            (_) => throw StateError('must not load'),
          ),
        ],
      );
      expect(container.read(translationDeviceMediaFactoryProvider), isNull);
      container.dispose();
    }
  });
}

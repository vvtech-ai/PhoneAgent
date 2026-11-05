import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/device_pcm_capture.dart';
import 'package:phone_agent/features/conversation/data/voice/device_pcm_output.dart';
import 'package:phone_agent/features/translation/data/device_translation_pcm_bridge.dart';
import 'package:phone_agent/features/translation/data/device_translation_call_audio_lease.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const captureChannel = MethodChannel('test/duplex/capture');
  const outputChannel = MethodChannel('test/duplex/output');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <(String, MethodCall)>[];
  var failOutputStop = false;
  late DeviceTranslationPcmBridge bridge;
  setUp(() {
    calls.clear();
    failOutputStop = false;
    for (final pair in [
      ('capture', captureChannel),
      ('output', outputChannel),
    ]) {
      messenger.setMockMethodCallHandler(pair.$2, (call) async {
        calls.add((pair.$1, call));
        if (pair.$1 == 'output' && call.method == 'stop' && failOutputStop) {
          return false;
        }
        if (call.method == 'route') {
          return {'selected': call.arguments['select'], 'bluetooth': false};
        }
        if (call.method == 'read') return Uint8List(640);
        return true;
      });
    }
    bridge = DeviceTranslationPcmBridge(
      capture: DevicePcmCapture(
        channel: captureChannel,
        duplex: true,
        web: false,
        platform: TargetPlatform.iOS,
      ),
      createOutput: () => DevicePcmOutput(
        channel: outputChannel,
        duplex: true,
        communication: true,
        web: false,
        platform: TargetPlatform.iOS,
      ),
    );
  });
  tearDown(() async {
    failOutputStop = false;
    await bridge.close();
    messenger.setMockMethodCallHandler(captureChannel, null);
    messenger.setMockMethodCallHandler(outputChannel, null);
  });
  TranslationAudio frame(int rate) => TranslationAudio(Uint8List(480), rate, 1);
  for (final failPlayback in [false, true]) {
    test(
      'iOS prepares both devices without delivering PCM; output failure=$failPlayback',
      () async {
        const leaseChannel = MethodChannel('test/duplex/lease');
        messenger.setMockMethodCallHandler(leaseChannel, (call) async {
          calls.add(('lease', call));
          return true;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(leaseChannel, null),
        );
        final lease = DeviceTranslationCallAudioLease(channel: leaseChannel);
        bridge = DeviceTranslationPcmBridge(
          callAudio: lease,
          capture: DevicePcmCapture(
            channel: captureChannel,
            duplex: true,
            backgroundCallId: lease.id,
            web: false,
            platform: TargetPlatform.iOS,
          ),
          createOutput: () => DevicePcmOutput(
            channel: outputChannel,
            duplex: true,
            communication: true,
            backgroundCallId: lease.id,
            web: false,
            platform: TargetPlatform.iOS,
          ),
        );
        if (failPlayback) {
          messenger.setMockMethodCallHandler(outputChannel, (call) async {
            calls.add(('output', call));
            return call.method != 'start';
          });
          await expectLater(bridge.prepareCallAudio(), throwsA(anything));
          await bridge.close();
          expect(
            calls.where((c) => c.$2.method == 'resumePreparedCall'),
            isEmpty,
          );
          expect(calls.last.$2.method, 'release');
          return;
        }
        await bridge.prepareCallAudio();
        await bridge.prepareCallAudio();
        expect(
          calls
              .where((c) => c.$1 == 'capture' && c.$2.method == 'start')
              .single
              .$2
              .arguments['deferDelivery'],
          true,
        );
        expect(
          calls.where((c) => c.$1 == 'output' && c.$2.method == 'start'),
          hasLength(1),
        );
        expect(
          calls.any(
            (c) => {
              'read',
              'play',
              'enqueue',
              'resumePreparedCall',
            }.contains(c.$2.method),
          ),
          false,
        );
        await bridge.start();
        await bridge.play(frame(16000));
        expect(
          calls.where((c) => c.$2.method == 'resumePreparedCall'),
          hasLength(1),
        );
        expect(
          calls.where((c) => c.$1 == 'output' && c.$2.method == 'start'),
          hasLength(1),
        );
        await bridge.close();
      },
    );
  }
  test(
    'domestic opt-in uses Android enqueue and real drain; default retains play',
    () async {
      for (final queue in [false, true]) {
        bridge = DeviceTranslationPcmBridge(
          capture: DevicePcmCapture(
            channel: captureChannel,
            duplex: true,
            web: false,
            platform: TargetPlatform.android,
          ),
          createOutput: () => DevicePcmOutput(
            channel: outputChannel,
            duplex: true,
            communication: true,
            web: false,
            platform: TargetPlatform.android,
          ),
        );
        if (queue) bridge.enableQueuedPlayback();
        await bridge.start();
        await bridge.play(frame(16000));
        await bridge.drain();
        expect(
          calls.any((c) => c.$2.method == (queue ? 'enqueue' : 'play')),
          true,
        );
        expect(calls.any((c) => c.$2.method == 'drain'), queue);
        await bridge.close();
        calls.clear();
      }
    },
  );
  test(
    'duplex flags and rate change preserve capture, close output before capture',
    () async {
      await bridge.start();
      await bridge.setSpeaker(true);
      await bridge.play(frame(24000));
      await bridge.play(frame(16000));
      expect(
        calls.where((e) => e.$1 == 'capture' && e.$2.method == 'stop'),
        isEmpty,
      );
      final starts = calls.where((e) => e.$2.method == 'start').toList();
      expect(starts, hasLength(3));
      expect(starts.every((e) => e.$2.arguments['duplex'] == true), isTrue);
      expect(
        starts.skip(1).every((e) => e.$2.arguments['communication'] == true),
        isTrue,
      );
      expect(
        calls
            .where((e) => e.$2.method == 'route')
            .every((e) => e.$2.arguments['select'] == 'speaker'),
        isTrue,
      );
      expect(await bridge.read(), hasLength(640));
      await bridge.close();
      expect(
        calls.sublist(calls.length - 2).map((e) => '${e.$1}.${e.$2.method}'),
        ['output.stop', 'capture.stop'],
      );
      await expectLater(bridge.play(frame(24000)), throwsA(anything));
    },
  );
  test(
    'output release failure still stops capture and supports explicit retry',
    () async {
      await bridge.start();
      await bridge.play(frame(24000));
      failOutputStop = true;
      await expectLater(bridge.close(), throwsStateError);
      expect(calls.last.$1, 'capture');
      expect(calls.last.$2.method, 'stop');
      failOutputStop = false;
      await bridge.close();
      expect(calls.last.$1, 'output');
      expect(await bridge.read(), isNull);
    },
  );
  test(
    'call lease precedes capture and remains held until hardware stop is confirmed',
    () async {
      const leaseChannel = MethodChannel('test/duplex/lease');
      messenger.setMockMethodCallHandler(leaseChannel, (call) async {
        calls.add(('lease', call));
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(leaseChannel, null));
      final lease = DeviceTranslationCallAudioLease(channel: leaseChannel);
      bridge = DeviceTranslationPcmBridge(
        callAudio: lease,
        capture: DevicePcmCapture(
          channel: captureChannel,
          duplex: true,
          backgroundCallId: lease.id,
          web: false,
          platform: TargetPlatform.android,
        ),
        createOutput: () => DevicePcmOutput(
          channel: outputChannel,
          duplex: true,
          communication: true,
          backgroundCallId: lease.id,
          web: false,
          platform: TargetPlatform.android,
        ),
      );
      await bridge.start();
      await bridge.play(frame(16000));
      expect(calls.first.$1, 'lease');
      for (final call in calls.where((v) => v.$2.method == 'start')) {
        expect(call.$2.arguments['callAudioId'], lease.id);
      }
      failOutputStop = true;
      await expectLater(bridge.close(), throwsStateError);
      expect(
        calls.where((v) => v.$1 == 'lease' && v.$2.method == 'release'),
        isEmpty,
      );
      failOutputStop = false;
      await bridge.close();
      expect(calls.last.$1, 'lease');
      expect(calls.last.$2.method, 'release');
    },
  );
  test('ordinary ASR and TTS do not opt into duplex communication', () async {
    final capture = DevicePcmCapture(
      channel: captureChannel,
      web: false,
      platform: TargetPlatform.android,
    );
    final output = DevicePcmOutput(
      channel: outputChannel,
      web: false,
      platform: TargetPlatform.android,
    );
    await capture.start();
    await output.start(24000);
    expect(
      calls
          .where((e) => e.$2.method == 'start')
          .every(
            (e) =>
                e.$2.arguments['duplex'] == null &&
                e.$2.arguments['communication'] == null &&
                e.$2.arguments['callAudioId'] == null,
          ),
      isTrue,
    );
    await capture.stop();
    await output.stop();
  });
}
